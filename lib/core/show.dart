import '../content/sponsors.dart';
import 'events.dart';

enum HypeTier {
  zapping('ZAPPING', 0xFF7A7A8A),
  tiede('TIEDE', 0xFF5EC8FF),
  captivant('CAPTIVANT', 0xFF8BE58B),
  enFeu('EN FEU', 0xFFFF9F40),
  viral('VIRAL', 0xFFFF4FD8);

  const HypeTier(this.label, this.color);
  final String label;
  final int color;
}

class SponsorState {
  SponsorState(this.def);
  final SponsorDef def;
  double satisfaction = 0;
  int gifts = 0;

  /// Satisfaction nécessaire pour le prochain colis (de plus en plus exigeant).
  double get threshold => 100 * (1 + 0.5 * gifts);
  double get ratio => (satisfaction / threshold).clamp(0, 1);
}

/// La couche « télé-réalité » : hype, audience, sponsors.
/// Réagit aux événements du moteur ; le [Game] applique les récompenses.
class Show {
  Show(List<SponsorDef> defs) : sponsors = [for (final d in defs) SponsorState(d)];

  static const playerId = 0;

  final List<SponsorState> sponsors;
  double hype = 30;
  double viewers = 1200;
  double peakViewers = 1200;

  // Modificateurs venant des talents
  bool crowdFav = false;
  bool showman = false;
  bool sponsorFriend = false;

  int combo = 0;
  int _lastKillTurn = -100;
  int _boredTurns = 0;
  int _twistCooldown = 20;

  HypeTier get tier => switch (hype) {
        < 20 => HypeTier.zapping,
        < 40 => HypeTier.tiede,
        < 60 => HypeTier.captivant,
        < 80 => HypeTier.enFeu,
        _ => HypeTier.viral,
      };

  void addHype(double v) => hype = (hype + v).clamp(0, 100);

  /// Fait plaisir aux sponsors qui aiment [taste] (amplifié par la hype).
  void please(Taste taste, double amount) {
    final factor = (0.5 + hype / 100) * (sponsorFriend ? 1.3 : 1);
    for (final s in sponsors) {
      if (s.def.taste == taste) s.satisfaction += amount * factor;
    }
  }

  /// Modifie directement un sponsor ([index] -1 = tous).
  void adjustSponsor(int index, double delta) {
    for (var i = 0; i < sponsors.length; i++) {
      if (index == -1 || index == i) {
        sponsors[i].satisfaction = (sponsors[i].satisfaction + delta).clamp(0, double.infinity);
      }
    }
  }

  void onEvents(List<GameEvent> events, int turn) {
    for (final e in events) {
      switch (e) {
        case DeathEvent(isPlayer: false):
          combo = turn - _lastKillTurn <= 3 ? combo + 1 : 1;
          _lastKillTurn = turn;
          addHype((4 + (combo - 1) * 3) * (showman ? 1.5 : 1));
          please(Taste.kills, 10);
        case AttackEvent(:final attackerId, :final crit) when attackerId == playerId && crit:
          addHype(3);
          please(Taste.kills, 4);
        case AttackEvent(:final targetId, :final miss) when targetId == playerId && !miss:
          addHype(0.5);
        case ItemUsedEvent(:final unknown):
          please(Taste.potions, 22);
          if (unknown) addHype(5);
        case GoldEvent(:final amount):
          please(Taste.gold, amount * 0.8);
        case ItemPickedEvent():
          please(Taste.loot, 15);
        case AchievementEvent():
          addHype(6);
          please(Taste.achievements, 30);
        case LevelUpEvent():
          addHype(5);
        case RevealEvent():
          addHype(8);
        case BoxGainedEvent():
          addHype(2);
        default:
          break;
      }
    }
  }

  void onBoxOpened() => please(Taste.loot, 10);

  void onDescend(int turnsOnFloor) {
    please(Taste.speed, ((140 - turnsOnFloor).clamp(0, 140)) * 0.8);
    addHype(turnsOnFloor < 60 ? 8 : 3);
  }

  /// Fin de tour : la hype retombe, l'audience suit la hype.
  void endTurn({required bool waited, required bool lowHp, required bool timerLow, required int newTiles}) {
    final slow = crowdFav ? 0.5 : 1.0;
    addHype(-(0.8 + (waited ? 1.0 : 0)) * slow);
    // Plus on est haut, plus il est dur d'y rester.
    if (hype > 50) addHype(-0.6 * slow);
    if (hype > 70) addHype(-1.6 * slow);
    if (lowHp) {
      addHype(0.4);
      please(Taste.lowHp, 3);
    }
    if (timerLow) addHype(0.5);
    if (newTiles > 0) please(Taste.exploration, newTiles * 0.35);

    viewers = (viewers * (1 + (hype - 35) / 2500)).clamp(100, double.infinity);
    if (viewers > peakViewers) peakViewers = viewers;

    _boredTurns = hype < 12 ? _boredTurns + 1 : 0;
    if (_twistCooldown > 0) _twistCooldown--;
  }

  /// Vrai si la régie doit lancer un rebondissement (audience trop ennuyée).
  bool takeTwist() {
    if (_boredTurns < 8 || _twistCooldown > 0) return false;
    _boredTurns = 0;
    _twistCooldown = 40;
    addHype(20);
    return true;
  }

  /// Sponsors prêts à envoyer un colis (leur compteur est remis à zéro).
  List<int> takeGifts() {
    final ready = <int>[];
    for (var i = 0; i < sponsors.length; i++) {
      final s = sponsors[i];
      if (s.satisfaction >= s.threshold) {
        s.satisfaction -= s.threshold;
        s.gifts++;
        ready.add(i);
      }
    }
    return ready;
  }
}

/// « 12,4k » / « 1,3M ».
String formatViewers(double v) {
  if (v >= 1e9) return '${(v / 1e9).toStringAsFixed(1).replaceAll('.', ',')}G';
  if (v >= 1e6) return '${(v / 1e6).toStringAsFixed(1).replaceAll('.', ',')}M';
  if (v >= 1e3) return '${(v / 1e3).toStringAsFixed(1).replaceAll('.', ',')}k';
  return v.round().toString();
}
