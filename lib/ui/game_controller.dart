import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../content/achievements.dart';
import '../content/features.dart';
import 'audio.dart';
import '../content/items.dart';
import '../content/status.dart';
import '../content/interviews.dart';
import '../core/backstage.dart';
import '../core/events.dart';
import '../core/game.dart';
import '../core/grid.dart';
import '../core/pathfinding.dart';

/// Texte flottant (dégâts, soins, butin) en coordonnées de tuiles.
class Floater {
  Floater(this.text, this.x, this.y, this.color, this.bornMs, {this.big = false});
  final String text;
  final double x;
  final double y;
  final Color color;
  final int bornMs;
  final bool big;
}

class LogLine {
  const LogLine(this.text, this.kind);
  final String text;
  final MessageKind kind;
}

/// Fait le lien entre le moteur (pur Dart) et l'écran : animations, déplacement auto, journal.
class GameController extends ChangeNotifier {
  GameController(TickerProvider vsync, int seed, {RunSetup setup = const RunSetup()})
      : game = Game.newRun(seed, setup: setup) {
    _start(vsync, game.initialEvents);
  }

  /// Reprend une partie sauvegardée (déjà rejouée).
  GameController.resume(TickerProvider vsync, this.game) {
    _start(vsync, [
      MessageEvent(
        "Et nous revoilà en direct ! Notre candidat avait fait une petite pause. "
        "Étage ${game.floor}, on reprend exactement où on en était.",
        MessageKind.maestro,
      ),
    ]);
  }

  void _start(TickerProvider vsync, List<GameEvent> initial) {
    _ticker = vsync.createTicker(_onTick);
    _ingest(initial);
    _snapshotPositions();
    _snapCamera = true;
    _ensureTicking();
  }

  static const turnMs = 130;
  static const floaterMs = 900;
  /// Nombre de tours pendant lesquels la bulle de MAESTRO reste affichée.
  static const maestroTurns = 6;

  final Game game;
  late final Ticker _ticker;

  /// Horloge (ms) mise à jour à chaque image tant qu'il y a quelque chose à animer.
  int nowMs = 0;
  int _turnStartMs = -100000;
  int _shakeStartMs = -100000;
  int _maestroSinceTurn = 0;

  /// Positions des acteurs avant le dernier tour (pour interpoler les déplacements).
  Map<int, Pos> prevPos = {};
  List<GameEvent> turnEvents = const [];
  bool _snapCamera = false;

  final floaters = <Floater>[];
  final log = <LogLine>[];
  String? maestro;

  List<Pos> _autoPath = [];
  Set<int> _autoKnownMonsters = {};

  /// Vibrations activées (réglage du profil).
  bool vibrations = true;

  int _fadeStartMs = -100000;
  int _levelUpMs = -100000;

  /// Fondu au noir à l'arrivée sur un étage (1 = noir, 0 = rien).
  double get floorFade {
    final age = nowMs - _fadeStartMs;
    return age >= 450 ? 0 : 1 - age / 450;
  }

  /// Éclat doré autour du joueur après une montée de niveau (0..1).
  double get levelUpGlow {
    final age = nowMs - _levelUpMs;
    return age >= 700 ? 0 : 1 - age / 700;
  }

  void _buzz(void Function() f) {
    if (vibrations) f();
  }

  /// Avancement de l'animation du tour courant (0..1).
  double get turnT {
    if (_snapCamera) return 1;
    final t = (nowMs - _turnStartMs) / turnMs;
    return t.clamp(0.0, 1.0);
  }

  bool get animating => turnT < 1;

  /// Secousse de caméra (en pixels) quand le joueur prend un coup.
  double get shake {
    final age = nowMs - _shakeStartMs;
    if (age > 220) return 0;
    return 5 * (1 - age / 220);
  }

  bool get maestroVisible => maestro != null && game.turn - _maestroSinceTurn < maestroTurns;

  bool get autoWalking => _autoPath.isNotEmpty;

  void dismissMaestro() {
    maestro = null;
    notifyListeners();
  }

  // --------------------------------------------------------------- actions

  void move(Dir dir) {
    _autoPath = [];
    _perform(MoveAction(dir));
  }

  void wait() {
    _autoPath = [];
    _perform(const WaitAction());
  }

  void descend() {
    _autoPath = [];
    _perform(const DescendAction());
  }

  void quaff() {
    _autoPath = [];
    _perform(const QuaffAction());
  }

  /// Interrompt le déplacement automatique (ex. : un conseil s'affiche).
  void stopAutoWalk() => _autoPath = [];

  /// Compétence active du rôle.
  void skill() {
    _autoPath = [];
    _perform(const SkillAction());
  }

  /// Action d'inventaire (utiliser, équiper, retirer, jeter) : consomme un tour.
  void inventoryAction(PlayerAction action) {
    _autoPath = [];
    _perform(action);
  }

  /// Ouvre la prochaine loot box (ne consomme pas de tour).
  BoxResult? openBox() {
    final r = game.openBox();
    if (r != null) {
      for (final it in r.items) {
        log.add(LogLine('Loot box ${r.tier.label} : ${game.nameOf(it)}', MessageKind.good));
      }
      log.add(LogLine('Loot box ${r.tier.label} : +${r.gold} or', MessageKind.good));
      notifyListeners();
    }
    return r;
  }

  // --------------------------------------------------------------- coulisses

  AnswerResult? answer(int index) {
    final r = game.answer(index);
    if (r != null) {
      final crowd = switch (r.crowd) {
        Crowd.applause => Sfx.applause,
        Crowd.laughs => Sfx.laugh,
        Crowd.boos => Sfx.boo,
        Crowd.gasps => Sfx.door,
        Crowd.silence => null,
      };
      if (crowd != null) GameAudio.instance.play(crowd);
      log.add(LogLine('Interview : « ${r.answerText} » — ${r.crowd.label}', MessageKind.maestro));
      notifyListeners();
    }
    return r;
  }

  bool buy(int index) {
    final offer = game.backstage?.shop[index];
    final ok = game.buy(index);
    if (ok && offer != null) log.add(LogLine('Achat : ${game.nameOf(offer.item)} (-${offer.price} or)', MessageKind.good));
    notifyListeners();
    return ok;
  }

  bool heal() {
    final ok = game.healAtInfirmary();
    if (ok) log.add(const LogLine("Infirmerie : PV au maximum.", MessageKind.good));
    notifyListeners();
    return ok;
  }

  bool pickTalent(int index) {
    final t = game.backstage?.talents[index];
    final ok = game.pickTalent(index);
    if (ok && t != null) log.add(LogLine('Talent acquis : ${t.name}', MessageKind.good));
    notifyListeners();
    return ok;
  }

  /// Choix devant un lieu interactif.
  FeatureResult chooseFeature(int index) {
    final r = game.chooseFeature(index);
    if (r.text.isNotEmpty) log.add(LogLine(r.text, MessageKind.info));
    _ingest(r.events);
    _ensureTicking();
    notifyListeners();
    return r;
  }

  /// Retour en scène : étage suivant.
  void leaveBackstage() {
    final events = game.leaveBackstage();
    if (events.isEmpty) return;
    _snapshotPositions();
    turnEvents = events;
    _snapCamera = true;
    _ingest(events);
    _ensureTicking();
    notifyListeners();
  }

  /// Outil de développement : téléporte sur l'escalier.
  void debugToStairs() {
    game.debugToStairs();
    _snapshotPositions();
    _snapCamera = true;
    notifyListeners();
  }

  /// Outil de développement : ajoute une loot box.
  void debugGrantBox(BoxTier tier) {
    game.debugGrantBox(tier);
    notifyListeners();
  }

  /// Succès débloqués récemment, affichés en bandeau quelques tours.
  final achievementToasts = <(String, int)>[];

  /// Les deux succès les plus récents (pour ne pas masquer la carte).
  List<String> get visibleToasts {
    final recent = [for (final t in achievementToasts) if (game.turn - t.$2 < 5) t.$1];
    return recent.length > 2 ? recent.sublist(recent.length - 2) : recent;
  }

  /// Tap sur une case : attaque/pas si adjacente, sinon déplacement automatique.
  void tapTile(Pos target) {
    if (game.gameOver) return;
    final p = game.player.pos;
    if (target == p) {
      game.onStairs ? descend() : wait();
      return;
    }
    if (target.isAdjacent4(p)) {
      move(Dir.fromDelta(target - p)!);
      return;
    }
    if (!game.explored.contains(target) || !game.level.walkable(target)) return;
    final path = findPath(
      game.level.tiles,
      p,
      target,
      (q) =>
          game.level.walkable(q) &&
          game.explored.contains(q) &&
          game.monsterAt(q) == null &&
          game.chestAt(q) == null &&
          game.featureAt(q) == null &&
          !(game.trapAt(q)?.revealed ?? false),
      // On peut viser un coffre (ou un « coffre ») : le dernier pas le frappe.
      allowBlockedGoal: true,
    );
    if (path == null || path.isEmpty) return;
    _autoPath = path;
    _autoKnownMonsters = _visibleMonsterIds();
    _stepAuto();
  }

  void _stepAuto() {
    if (_autoPath.isEmpty || game.gameOver) return;
    final next = _autoPath.removeAt(0);
    final dir = Dir.fromDelta(next - game.player.pos);
    final blocker = game.monsterAt(next);
    if (dir == null || (blocker != null && !blocker.disguised)) {
      _autoPath = [];
      return;
    }
    _perform(MoveAction(dir));
    // Un nouveau monstre en vue ou un coup reçu interrompt la marche.
    final hurt = turnEvents.any((e) => (e is AttackEvent && e.targetId == game.player.id) || e is TrapEvent);
    if (hurt || !_autoKnownMonsters.containsAll(_visibleMonsterIds())) _autoPath = [];
  }

  Set<int> _visibleMonsterIds() =>
      {for (final m in game.monsters) if (game.visible.contains(m.pos) && !m.disguised) m.id};

  void _perform(PlayerAction action) {
    if (game.gameOver) return;
    _snapshotPositions();
    final events = game.act(action);
    if (events.isEmpty) {
      _autoPath = [];
      return;
    }
    turnEvents = events;
    _snapCamera = events.any((e) => e is FloorEvent);
    if (_snapCamera) _snapshotPositions();
    _turnStartMs = nowMs;
    _ingest(events);
    _ensureTicking();
    notifyListeners();
  }

  void _snapshotPositions() {
    prevPos = {game.player.id: game.player.pos, for (final m in game.monsters) m.id: m.pos};
  }

  // --------------------------------------------------------------- événements → effets

  void _ingest(List<GameEvent> events) {
    _sounds(events);
    for (final e in events) {
      switch (e) {
        case AttackEvent():
          final x = e.to.x.toDouble(), y = e.to.y.toDouble();
          final onPlayer = e.targetId == game.player.id;
          if (e.miss) {
            floaters.add(Floater('raté', x, y, const Color(0xFFB0B0C0), nowMs));
          } else {
            floaters.add(Floater(
              e.crit ? '-${e.damage}!' : '-${e.damage}',
              x,
              y,
              onPlayer ? const Color(0xFFFF5050) : (e.crit ? const Color(0xFFFFA030) : const Color(0xFFFFFFFF)),
              nowMs,
              big: e.crit,
            ));
            if (onPlayer) {
              _shakeStartMs = nowMs;
              _buzz(HapticFeedback.lightImpact);
            }
          }
        case HealEvent():
          floaters.add(Floater('+${e.amount}', e.pos.x.toDouble(), e.pos.y.toDouble(), const Color(0xFF60FF80), nowMs));
        case PickupEvent():
          floaters.add(Floater(e.label, e.pos.x.toDouble(), e.pos.y.toDouble(), const Color(0xFFFFD84D), nowMs));
        case DeathEvent(isPlayer: final dead):
          _buzz(dead ? HapticFeedback.heavyImpact : HapticFeedback.selectionClick);
        case FloorEvent():
          _fadeStartMs = nowMs;
        case LevelUpEvent():
          _levelUpMs = nowMs;
          _buzz(HapticFeedback.mediumImpact);
          final p = game.player.pos;
          floaters.add(Floater('NIVEAU ${e.level}!', p.x.toDouble(), p.y.toDouble() - 0.5, const Color(0xFFFFD84D), nowMs,
              big: true));
        case MessageEvent():
          if (e.kind == MessageKind.maestro) {
            maestro = e.text;
            _maestroSinceTurn = game.turn;
          }
          log.add(LogLine(e.text, e.kind));
          if (log.length > 60) log.removeAt(0);
        case AchievementEvent():
          achievementToasts.add((achievementById(e.id).name, game.turn));
          if (achievementToasts.length > 6) achievementToasts.removeAt(0);
        case BoxGainedEvent():
          final p = game.player.pos;
          floaters.add(Floater('+ LOOT BOX', p.x.toDouble(), p.y.toDouble() - 0.6,
              Color(BoxTier.values[e.tierIndex].color), nowMs));
        case SponsorGiftEvent():
          final p = game.player.pos;
          floaters.add(Floater('COLIS !', p.x.toDouble(), p.y.toDouble() - 0.9,
              Color(game.show.sponsors[e.sponsorIndex].def.color), nowMs,
              big: true));
        case DemolitionEvent():
          _buzz(HapticFeedback.mediumImpact);
          final p = game.player.pos;
          floaters.add(Floater('-${e.damage}', p.x.toDouble(), p.y.toDouble(), const Color(0xFFFF5050), nowMs));
          _shakeStartMs = nowMs;
        case TwistEvent():
          _shakeStartMs = nowMs;
        case StatusEvent():
          final s = Status.values[e.statusIndex];
          floaters.add(Floater(s.short, e.pos.x.toDouble(), e.pos.y.toDouble() - 0.5, Color(s.color), nowMs));
        case StatusDamageEvent():
          floaters.add(Floater('-${e.damage}', e.pos.x.toDouble(), e.pos.y.toDouble(),
              Color(Status.values[e.statusIndex].color), nowMs));
        case BossEvent():
          _shakeStartMs = nowMs;
          _buzz(HapticFeedback.heavyImpact);
        case VictoryEvent():
          final p = game.player.pos;
          floaters.add(Floater('VICTOIRE !', p.x.toDouble(), p.y.toDouble() - 0.8, const Color(0xFFFFD84D), nowMs,
              big: true));
        case TrapEvent():
          final k = TrapKind.values[e.kindIndex];
          floaters.add(Floater(e.triggered ? 'PIEGE !' : '?!', e.pos.x.toDouble(), e.pos.y.toDouble() - 0.4,
              Color(k.color), nowMs, big: e.triggered));
          if (e.triggered) {
            _shakeStartMs = nowMs;
            _buzz(HapticFeedback.mediumImpact);
          }
        case KamikazeEvent(:final exploded):
          floaters.add(Floater(exploded ? 'BOUM !' : '!!', e.pos.x.toDouble(), e.pos.y.toDouble() - 0.4,
              const Color(0xFFFF5030), nowMs, big: true));
          if (exploded) {
            _shakeStartMs = nowMs;
            _buzz(HapticFeedback.heavyImpact);
          }
        case SkillEvent():
          final p = game.player.pos;
          floaters.add(Floater(game.skill.name.toUpperCase(), p.x.toDouble(), p.y.toDouble() - 0.7,
              const Color(0xFF5EC8FF), nowMs, big: true));
        case RevealEvent():
          floaters.add(Floater('!!!', e.pos.x.toDouble(), e.pos.y.toDouble() - 0.4, const Color(0xFFFF5050), nowMs,
              big: true));
        default:
          break;
      }
    }
  }

  // --------------------------------------------------------------- sons

  /// Un son par type d'événement et par tour (évite la cacophonie).
  void _sounds(List<GameEvent> events) {
    final played = <Sfx>{};
    void p(Sfx s) {
      if (played.add(s)) GameAudio.instance.play(s);
    }

    for (final e in events) {
      switch (e) {
        case AttackEvent(:final attackerId, :final targetId, :final miss, :final crit):
          if (miss) break;
          if (targetId == game.player.id) {
            p(Sfx.hurt);
          } else if (attackerId == game.player.id) {
            p(crit ? Sfx.crit : Sfx.hit);
          }
        case DeathEvent(:final isPlayer):
          p(isPlayer ? Sfx.death : Sfx.kill);
        case PickupEvent(:final label):
          if (!label.startsWith('-')) p(label.contains('or') ? Sfx.coin : Sfx.pickup);
        case ItemUsedEvent():
          p(Sfx.potion);
        case LevelUpEvent():
          p(Sfx.levelup);
        case AchievementEvent():
          p(Sfx.achievement);
        case BoxGainedEvent() || SponsorGiftEvent():
          p(Sfx.boxGained);
        case BossEvent(:final defeated):
          p(defeated ? Sfx.applause : Sfx.boss);
        case VictoryEvent():
          p(Sfx.victory);
        case TrapEvent(:final triggered):
          p(triggered ? Sfx.trap : Sfx.click);
        case FloorEvent():
          if (game.floor > 1) p(Sfx.stairs);
        case RevealEvent() || FeatureEvent():
          p(Sfx.door);
        case DemolitionEvent() || StatusDamageEvent():
          p(Sfx.hurt);
        case TwistEvent():
          p(Sfx.boss);
        case KamikazeEvent(:final exploded):
          p(exploded ? Sfx.trap : Sfx.door);
        case SkillEvent():
          p(Sfx.crit);
        default:
          break;
      }
    }
  }

  // --------------------------------------------------------------- horloge

  void _ensureTicking() {
    if (!_ticker.isActive) _ticker.start();
  }

  Duration _base = Duration.zero;

  void _onTick(Duration elapsed) {
    nowMs = (_base + elapsed).inMilliseconds;
    floaters.removeWhere((f) => nowMs - f.bornMs > floaterMs);
    final turnDone = turnT >= 1;
    if (turnDone && _autoPath.isNotEmpty) {
      _stepAuto();
    }
    notifyListeners();
    if (turnDone && floaters.isEmpty && shake == 0 && _autoPath.isEmpty && floorFade == 0 && levelUpGlow == 0) {
      _base += elapsed;
      _ticker.stop();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }
}

/// Courbe utilisée pour les glissements de case à case.
double easeMove(double t) => Curves.easeOut.transform(t);
