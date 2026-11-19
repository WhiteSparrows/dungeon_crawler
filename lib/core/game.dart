import '../content/achievements.dart';
import '../content/features.dart';
import '../content/interviews.dart';
import '../content/items.dart';
import '../content/lines_fr.dart';
import '../content/monsters.dart';
import '../content/roles.dart';
import '../content/sponsors.dart';
import '../content/status.dart';
import '../content/talents.dart';
import '../content/themes.dart';
import 'backstage.dart';
import 'combat.dart';
import 'dungeon_gen.dart';
import 'entities.dart';
import 'events.dart';
import 'fov.dart';
import 'grid.dart';
import 'pathfinding.dart';
import 'rng.dart';
import 'show.dart';

/// Actions possibles du joueur (une action = un tour).
sealed class PlayerAction {
  const PlayerAction();
}

class MoveAction extends PlayerAction {
  const MoveAction(this.dir);
  final Dir dir;
}

class WaitAction extends PlayerAction {
  const WaitAction();
}

class DescendAction extends PlayerAction {
  const DescendAction();
}

/// Boire une potion de soin (raccourci de la barre d'actions).
class QuaffAction extends PlayerAction {
  const QuaffAction();
}

class UseItemAction extends PlayerAction {
  const UseItemAction(this.itemId);
  final String itemId;
}

class EquipAction extends PlayerAction {
  const EquipAction(this.itemId);
  final String itemId;
}

class UnequipAction extends PlayerAction {
  const UnequipAction(this.slot);
  final ItemKind slot;
}

class DropAction extends PlayerAction {
  const DropAction(this.itemId);
  final String itemId;
}

/// Résultat d'un choix devant un lieu interactif.
class FeatureResult {
  const FeatureResult(this.text, this.events, {this.closed = true});
  final String text;
  final List<GameEvent> events;

  /// Faux si le choix n'a rien fait (pas assez d'or…) : le dialogue reste ouvert.
  final bool closed;
}

/// Contenu d'une loot box ouverte.
class BoxResult {
  const BoxResult(this.tier, this.items, this.gold, {this.overflow = false});
  final BoxTier tier;
  final List<ItemDef> items;
  final int gold;

  /// Sac plein : une partie du contenu a été posée au sol.
  final bool overflow;
}

/// Configuration de départ d'une run : rôle choisi et contrats permanents (méta-progression).
class RunSetup {
  const RunSetup({this.roleId = 'lambda', this.upgrades = const {}, this.daily = false});

  /// Défi du jour : rôle de base, aucun contrat, même graine pour tout le monde.
  static const dailyChallenge = RunSetup(daily: true);

  final String roleId;
  final Map<String, int> upgrades;
  final bool daily;

  RoleDef get role => roleById(roleId);
  int level(String id) => upgrades[id] ?? 0;
}

/// Graine du défi du jour (identique pour une même date).
int dailySeed(DateTime d) => ((d.year * 10000 + d.month * 100 + d.day) * 2654435761) & 0x7fffffff;

/// État complet d'une run + moteur de tours. Pur Dart, déterministe pour une graine donnée.
class Game {
  Game.newRun(this.seed, {this.setup = const RunSetup()}) : rng = Rng(seed) {
    final role = setup.role;
    baseAtk += role.atk;
    baseDef += role.def;
    baseMaxHp += role.maxHp + 5 * setup.level('health');
    player = Actor(
      id: 0,
      name: 'Vous',
      sprite: role.sprite,
      pos: const Pos(0, 0),
      maxHp: baseMaxHp,
      atk: baseAtk,
      def: baseDef,
    );
    // Aspects des fioles mystère, différents à chaque run.
    final looks = List.of(potionLooks);
    rng.shuffle(looks);
    for (var i = 0; i < mysteryPotions.length; i++) {
      _looks[mysteryPotions[i].effect!] = looks[i];
    }
    // Trois sponsors au hasard pour cette run.
    final sp = List.of(sponsorDefs);
    rng.shuffle(sp);
    show = Show(sp.take(3).toList());
    weapon = itemById('butter_knife');
    final potions = 1 + role.potions + setup.level('kit');
    if (potions > 0) inventory.add(InvItem(healPotion, potions));
    for (var i = 0; i < role.mysteryPotions; i++) {
      _addToBag(rng.pick(mysteryPotions));
    }
    for (final t in role.talents) {
      _applyTalent(t);
    }
    gold += role.gold + 25 * setup.level('bonus');
    show.addHype(role.hype + 10 * setup.level('agent'));
    _airtime = 15 * setup.level('airtime');
    final welcome = setup.level('welcome');
    if (welcome > 0) pendingBoxes.add(welcome == 1 ? BoxTier.bronze : BoxTier.argent);
    _recalcStats();
    player.hp = player.maxHp;
    _enterFloor(1, initialEvents);
    _say(MaestroLines.runStart, initialEvents);
  }

  static const fovRadius = 7;
  static const maxSlots = 10;

  final Rng rng;
  final RunSetup setup;

  /// Graine de la run (avec [setup] et [commands], elle suffit à tout reconstruire).
  final int seed;

  /// Journal des commandes du joueur : la sauvegarde rejoue ce journal à l'identique.
  final commands = <String>[];
  int _airtime = 0;
  late Actor player;
  late Level level;
  int floor = 0;
  final monsters = <Actor>[];
  final floorItems = <FloorItem>[];
  final chests = <Chest>[];
  Set<Pos> visible = {};
  final explored = <Pos>{};

  // Progression du joueur
  int baseAtk = 3;
  int baseDef = 1;
  int baseMaxHp = 30;
  ItemDef? weapon;
  ItemDef? trinket;
  final inventory = <InvItem>[];
  final pendingBoxes = <BoxTier>[];
  int rageTurns = 0;

  int turn = 0;
  int gold = 0;
  int kills = 0;
  int xp = 0;
  int playerLevel = 1;
  bool gameOver = false;

  /// Saison gagnée (boss final vaincu).
  bool victory = false;

  /// Boss de l'étage (étages 3, 6, 9, 12, 15).
  Actor? boss;
  bool _bossAnnounced = false;

  // Variété : lieux, pièges, modificateurs
  final features = <Feature>[];
  final traps = <Trap>[];
  FloorMod? floorMod;

  /// Lieu devant lequel le joueur se trouve (dialogue de choix ouvert).
  Feature? activeFeature;
  bool _fallPending = false;
  bool _fellRecently = false;
  bool _prayedThisFloor = false;
  int _lastMaestroTurn = 0;

  int get sightRadius => floorMod == FloorMod.blackout ? 3 : fovRadius;

  Feature? featureAt(Pos p) {
    for (final f in features) {
      if (f.pos == p) return f;
    }
    return null;
  }

  Trap? trapAt(Pos p) {
    for (final t in traps) {
      if (t.pos == p) return t;
    }
    return null;
  }

  bool get bossAnnounced => _bossAnnounced;
  bool get bossAlive => boss != null && boss!.alive && monsters.contains(boss);
  ThemeDef get theme => themeFor(floor);
  String? killedBy;

  // Fioles mystère
  final _looks = <Effect, (String, int)>{};
  final identified = <Effect>{};

  // Succès et statistiques
  final unlocked = <String>{};
  final _killsById = <String, int>{};
  int crits = 0;
  int potionsDrunk = 0;
  int _butterKills = 0;
  int _mimicKills = 0;
  final _killTurns = <int>[];
  int _floorArrivalTurn = 0;
  int _floorKills = 0;
  Set<Pos> _floorWalkable = {};

  /// Événements produits à la création de la run (accueil de MAESTRO, etc.).
  final initialEvents = <GameEvent>[];

  // Le show : hype, audience, sponsors, compte à rebours, coulisses
  late final Show show;
  final talents = <String>{};
  Backstage? backstage;
  int floorTimer = 0;
  int _nextTimerDelta = 0;
  int _nextExtraMonsters = 0;
  bool _secondWindUsed = false;
  int applause = 0;
  final _usedQuestions = <int>{};
  bool _viralAnnounced = false;
  bool _poisonedThisFloor = false;
  bool _mimicThisFloor = false;
  double _minHpRatioFloor = 1;

  int _nextId = 1;
  bool _firstKillDone = false;
  bool _lowHpWarned = false;

  bool has(String talent) => talents.contains(talent);
  int get xpToNext => 8 + playerLevel * 6;
  bool get onStairs => level.tiles[player.pos] == Tile.stairsDown;
  double get critChance =>
      0.10 + (weapon?.crit ?? 0) + (trinket?.crit ?? 0) + (has('lynx') ? 0.08 : 0);
  int get lifesteal => (weapon?.lifesteal ?? 0) + (trinket?.lifesteal ?? 0) + (has('vampire') ? 1 : 0);

  /// Tours restants avant la démolition de l'étage (négatif = démolition en cours).
  int get turnsLeft => floorTimer - (turn - _floorArrivalTurn);
  int get turnsOnFloor => turn - _floorArrivalTurn;

  /// Remplace {s0}, {s1}, {s2} par les noms des sponsors.
  String withSponsors(String s) {
    var out = s;
    for (var i = 0; i < show.sponsors.length; i++) {
      out = out.replaceAll('{s$i}', show.sponsors[i].def.name);
    }
    return out;
  }
  int get healPotions => inventory.where((i) => i.def.id == healPotion.id).fold(0, (s, i) => s + i.count);
  bool get bagFull => inventory.length >= maxSlots;

  /// Nom affiché d'un objet (aspect si fiole non identifiée).
  String nameOf(ItemDef d) => d.mystery && !identified.contains(d.effect) ? _looks[d.effect]!.$1 : d.name;

  /// Description affichée (inconnue tant que non identifiée).
  String descOf(ItemDef d) =>
      d.mystery && !identified.contains(d.effect) ? 'Effet inconnu. Il faut goûter pour savoir.' : d.desc;

  int spriteOf(ItemDef d) => d.mystery ? _looks[d.effect]!.$2 : d.sprite;

  Actor? monsterAt(Pos p) {
    for (final m in monsters) {
      if (m.pos == p && m.alive) return m;
    }
    return null;
  }

  Chest? chestAt(Pos p) {
    for (final c in chests) {
      if (c.pos == p) return c;
    }
    return null;
  }

  Iterable<FloorItem> itemsAt(Pos p) => floorItems.where((i) => i.pos == p);

  bool isFree(Pos p) =>
      level.walkable(p) && monsterAt(p) == null && player.pos != p && chestAt(p) == null && featureAt(p) == null;

  // ================================================================ tour de jeu

  /// Joue une action du joueur puis le tour des monstres. Renvoie les événements du tour.
  /// Une action impossible ne consomme pas de tour (liste vide ou simple message).
  List<GameEvent> act(PlayerAction action) {
    final events = _act(action);
    // Une action sans effet (mur, sac plein…) ne change rien : inutile de l'enregistrer.
    if (events.isNotEmpty) commands.add(_encode(action));
    return events;
  }

  List<GameEvent> _act(PlayerAction action) {
    if (gameOver || backstage != null || activeFeature != null) return const [];
    final events = <GameEvent>[];
    final exploredBefore = explored.length;
    if (player.hasStatus(Status.stun) && action is! DescendAction) {
      // Étourdi : le tour passe sans rien faire.
      action = const WaitAction();
      events.add(const MessageEvent('Vous êtes étourdi ! Des petits oiseaux tournent autour de votre tête.',
          MessageKind.danger));
    }

    switch (action) {
      case MoveAction(:final dir):
        final target = player.pos + dir.delta;
        final m = monsterAt(target);
        final chest = chestAt(target);
        final feature = featureAt(target);
        if (feature != null && m == null) {
          if (feature.used) return [MessageEvent('${feature.kind.title} : déjà utilisé. Il boude.')];
          activeFeature = feature;
          return [FeatureEvent(feature.pos)];
        }
        if (m != null && m.disguised) {
          _reveal(m, events);
        } else if (m != null) {
          _attack(player, m, events);
        } else if (chest != null) {
          _openChest(chest, events);
        } else if (level.walkable(target)) {
          events.add(MoveEvent(player.id, player.pos, target));
          player.pos = target;
          _collect(events);
          _checkTrap(events);
        } else {
          return const [];
        }
      case WaitAction():
        break;
      case DescendAction():
        if (!onStairs) return [const MessageEvent("Il n'y a pas d'escalier ici.")];
        if (bossAlive) {
          final blocked = <GameEvent>[];
          _announceBoss(blocked);
          blocked.add(MessageEvent(
              "La sortie est verrouillée par la production tant que ${boss!.monster!.theName} est debout.",
              MessageKind.danger));
          return blocked;
        }
        if (_floorKills == 0) _unlock('pacifist', events);
        if (turnsOnFloor < 40) _unlock('express', events);
        if (turnsLeft <= 10) _unlock('just_in_time', events);
        show.onDescend(turnsOnFloor);
        show.onEvents(events, turn);
        _checkAchievements(events);
        _enterBackstage(events);
        return events;
      case QuaffAction():
        if (healPotions <= 0) return [const MessageEvent('Plus de potion de soin. Il fallait y penser avant.')];
        _useItem(healPotion, events);
      case UseItemAction(:final itemId):
        final inv = _inv(itemId);
        if (inv == null || inv.def.kind != ItemKind.consumable) return const [];
        _useItem(inv.def, events);
      case EquipAction(:final itemId):
        final inv = _inv(itemId);
        if (inv == null || !inv.def.equippable) return const [];
        _equip(inv.def, events);
      case UnequipAction(:final slot):
        final current = slot == ItemKind.weapon ? weapon : trinket;
        if (current == null) return const [];
        if (bagFull && _inv(current.id) == null) return [const MessageEvent('Sac plein : impossible de retirer.')];
        if (slot == ItemKind.weapon) {
          weapon = null;
        } else {
          trinket = null;
        }
        _addToBag(current);
        _recalcStats();
        events.add(MessageEvent('Vous retirez ${current.name}.'));
      case DropAction(:final itemId):
        final inv = _inv(itemId);
        if (inv == null) return const [];
        _removeOne(inv.def);
        floorItems.add(FloorItem.item(inv.def, player.pos));
        events.add(MessageEvent('Vous posez ${nameOf(inv.def)}.'));
    }

    _monstersTurn(events);
    _tickStatuses(events);
    turn++;
    if (_fallPending && !gameOver) {
      _fallPending = false;
      _fall(events);
      return events;
    }
    _spotTraps(events);
    if (rageTurns > 0) {
      rageTurns--;
      if (rageTurns == 0) events.add(const MessageEvent('Votre rage retombe.'));
    }
    final regenEvery = has('regen') ? 4 : 7;
    if (!gameOver && turn % regenEvery == 0 && player.hp < player.maxHp) player.hp++;
    _tickTimer(events);
    _updateFov();
    _announceBoss(events);
    _checkLowHp(events);
    _checkAchievements(events);
    if (!gameOver && turn - _lastMaestroTurn >= 40 && rng.chance(0.08)) {
      // Commentaire spontané ou fausse coupure pub.
      if (rng.chance(0.5)) {
        _say(MaestroLines.ambient, events);
      } else {
        final s = rng.pick(show.sponsors).def;
        _say(MaestroLines.ads, events, extra: {'sponsor': s.name, 'slogan': s.slogan});
      }
    }
    if (!gameOver) {
      _minHpRatioFloor = player.hpRatio < _minHpRatioFloor ? player.hpRatio : _minHpRatioFloor;
      _showTurn(events, waited: action is WaitAction, newTiles: explored.length - exploredBefore);
    }
    return events;
  }

  void _announceBoss(List<GameEvent> events) {
    final b = boss;
    if (b == null || _bossAnnounced || !b.alive || !visible.contains(b.pos)) return;
    _bossAnnounced = true;
    b.awake = true;
    b.lastSeenTarget = player.pos;
    events.add(BossEvent(b.name));
    _say(MaestroLines.bossIntro, events, extra: {'boss': b.monster!.theName});
  }

  // ================================================================ lieux, pièges, modificateurs

  void _spawnFeatures() {
    if (level.rooms.length < 3) return;
    final n = rng.range(1, 2) + (floor >= 6 ? 1 : 0);
    for (var i = 0; i < n; i++) {
      final p = _randomFreeCell();
      if (p == null || p.manhattan(level.stairs) < 2) continue;
      final kind = rng.pick(FeatureKind.values);
      features.add(Feature(p, kind, sponsorIndex: rng.nextInt(show.sponsors.length)));
    }
    final nTraps = 1 + floor ~/ 3 + rng.range(0, 1);
    for (var i = 0; i < nTraps; i++) {
      final p = _randomFreeCell();
      if (p == null || trapAt(p) != null) continue;
      final canFall = !isBossFloor(floor) && floor < finalFloor - 1;
      final kinds = [TrapKind.spikes, TrapKind.confetti, TrapKind.spotlight, if (canFall) TrapKind.trapdoor];
      traps.add(Trap(p, rng.pick(kinds)));
    }
  }

  void _applyFloorMod() {
    switch (floorMod) {
      case FloorMod.happyHour:
        for (final m in monsters) {
          if (!m.isBoss) m.statuses[Status.embarrassed] = 30;
        }
      case FloorMod.goldRain:
        for (var i = 0; i < 6; i++) {
          _place(FloorItem.gold(rng.range(4, 9) + floor * 2, const Pos(0, 0)));
        }
      case FloorMod.starMonster:
        final pool = monsters.where((m) => !m.isBoss && !m.disguised).toList();
        if (pool.isNotEmpty) {
          final m = rng.pick(pool)
            ..elite = true
            ..atk += 3
            ..def += 1;
          m.maxHp *= 2;
          m.hp = m.maxHp;
        }
      default:
        break;
    }
  }

  /// Le joueur marche sur un piège caché (ou non).
  void _checkTrap(List<GameEvent> events) {
    final t = trapAt(player.pos);
    if (t == null) return;
    t.revealed = true;
    events.add(TrapEvent(t.pos, t.kind.index));
    switch (t.kind) {
      case TrapKind.spikes:
        final dmg = 3 + floor;
        player.hp -= dmg;
        events.add(StatusDamageEvent(player.id, player.pos, dmg, Status.poison.index));
        events.add(MessageEvent('Des pics jaillissent du sol (-$dmg) ! Le public grimace avec délectation.',
            MessageKind.danger));
        if (player.hp <= 0) _playerDown('des pics rétractables', events);
      case TrapKind.confetti:
        _applyStatus(player, Status.embarrassed, events);
        show.addHype(6);
        events.add(const MessageEvent('BOUM ! Un canon à confettis vous recouvre de paillettes. Très gênant.',
            MessageKind.danger));
      case TrapKind.spotlight:
        _applyStatus(player, Status.burn, events);
        events.add(const MessageEvent('Un projecteur surchauffé vous grille les sourcils !', MessageKind.danger));
      case TrapKind.trapdoor:
        traps.remove(t);
        _fallPending = true;
        events.add(const MessageEvent('Le sol se dérobe sous vos pieds ! AAAAAH !', MessageKind.danger));
    }
  }

  /// Chute par une trappe : étage suivant, sans interview ni coulisses.
  void _fall(List<GameEvent> events) {
    _fellRecently = true;
    _enterFloor(floor + 1, events);
    final dmg = 4 + floor;
    player.hp = (player.hp - dmg).clamp(1, player.maxHp);
    events.add(StatusDamageEvent(player.id, player.pos, dmg, Status.stun.index));
    events.add(MessageEvent('Atterrissage brutal (-$dmg) à l\'étage $floor.', MessageKind.danger));
    _say(MaestroLines.trapFall, events);
    show.addHype(10);
    _checkAchievements(events);
  }

  /// Les pièges voisins peuvent être repérés.
  void _spotTraps(List<GameEvent> events) {
    for (final t in traps) {
      if (t.revealed || t.pos.chebyshev(player.pos) > 1 || !rng.chance(0.3)) continue;
      t.revealed = true;
      events.add(TrapEvent(t.pos, t.kind.index, triggered: false));
      events.add(MessageEvent('Vous repérez un piège : ${t.kind.label}.', MessageKind.good));
      if (rng.chance(0.4)) _say(MaestroLines.trapSpotted, events);
    }
  }

  /// Choix devant un lieu interactif. Le dernier choix (« passer ») ferme sans rien faire.
  FeatureResult chooseFeature(int index) {
    final f = activeFeature;
    if (f == null || index < 0 || index >= f.kind.options.length) {
      return const FeatureResult('', [], closed: false);
    }
    commands.add('f:$index');
    final events = <GameEvent>[];
    String text;
    var close = true;
    var use = true;
    if (index == f.kind.options.length - 1) {
      text = 'Vous passez votre chemin. MAESTRO soupire bruyamment dans les haut-parleurs.';
      use = false;
    } else {
      final roll = rng.nextDouble();
      switch ((f.kind, index)) {
        case (FeatureKind.fountain, 0):
          if (roll < 0.4) {
            final before = player.hp;
            player.hp = (player.hp + player.maxHp ~/ 2).clamp(0, player.maxHp);
            events.add(HealEvent(player.pos, player.hp - before));
            text = "C'est frais, c'est vert, ça soigne (+${player.hp - before} PV). Ne posez pas de questions.";
          } else if (roll < 0.65) {
            baseMaxHp += 3;
            _recalcStats();
            player.hp += 3;
            text = 'Vos cellules frétillent. PV max +3. Vous brillez légèrement dans le noir.';
          } else if (roll < 0.85) {
            _applyStatus(player, Status.poison, events);
            text = "C'était de l'eau d'égout aromatisée. Empoisonné. Le public applaudit.";
          } else {
            text = "Rien ne se passe. C'était de l'eau du robinet. La production est déçue.";
          }
        case (FeatureKind.fountain, _):
          if (gold < 5) {
            text = "Vous n'avez même pas 5 pièces. MAESTRO pouffe.";
            close = false;
            use = false;
          } else {
            gold -= 5;
            if (roll < 0.45) {
              show.addHype(12);
              text = 'Vous faites un vœu. Le public trouve ça mignon (hype +12).';
            } else if (roll < 0.75) {
              _gainBox(BoxTier.bronze, 'Fontaine', events);
              text = 'La fontaine recrache une loot box ! Elle avait faim de monnaie.';
            } else {
              text = 'La fontaine rote. Votre pièce est perdue. Bienvenue dans le capitalisme.';
            }
          }
        case (FeatureKind.shrine, 0):
          final cost = (player.maxHp * 0.1).ceil();
          player.hp = (player.hp - cost).clamp(1, player.maxHp);
          show.adjustSponsor(f.sponsorIndex, 70);
          show.addHype(5);
          _prayedThisFloor = true;
          text = '${show.sponsors[f.sponsorIndex].def.name} accepte votre sacrifice (-$cost PV). '
              'Ils vous aiment un peu plus. Un tout petit peu.';
        case (FeatureKind.shrine, _):
          final loot = 20 + floor * 5;
          gold += loot;
          show.adjustSponsor(f.sponsorIndex, -50);
          if (roll < 0.35) {
            _applyStatus(player, Status.embarrassed, events);
            text = "Vous empochez $loot pièces... et le sponsor vous maudit. Vous vous sentez soudain très gêné.";
          } else {
            text = 'Vous empochez $loot pièces. ${show.sponsors[f.sponsorIndex].def.name} prend note. Ils notent tout.';
          }
        case (FeatureKind.vending, 0):
          if (gold < 15) {
            text = "Monnaie insuffisante. Le distributeur affiche « PAUVRE » en lettres rouges.";
            close = false;
            use = false;
          } else {
            gold -= 15;
            if (!_addToBag(healPotion)) floorItems.add(FloorItem.item(healPotion, player.pos));
            text = 'Clonk. Une potion de soin tombe. Elle est tiède. Elle a un goût de pièce.';
            use = false;
          }
        case (FeatureKind.vending, _):
          if (roll < 0.45) {
            final it = rollItem(rng, rollRarity(rng, const [60, 35, 5, 0]), floor);
            floorItems.add(FloorItem.item(it, player.pos));
            text = 'Vous secouez la machine. Un objet tombe à vos pieds : ${nameOf(it)} !';
          } else if (roll < 0.75) {
            text = 'Vous secouez, secouez... rien. Le distributeur vous regarde avec mépris.';
            use = false;
          } else {
            final dmg = 6 + floor;
            player.hp -= dmg;
            events.add(StatusDamageEvent(player.id, player.pos, dmg, Status.stun.index));
            text = 'La machine bascule et vous tombe dessus (-$dmg) ! Elle est cassée. Vous aussi, un peu.';
            if (player.hp <= 0) _playerDown('un distributeur automatique', events);
          }
        default: // bouche de la vérité
          if (roll < 0.55) {
            _gainBox(BoxTier.argent, 'Bouche de la vérité', events);
            text = 'Vous retirez votre main... avec une loot box ! Vous êtes donc honnête. Personne ne le croyait.';
          } else {
            final dmg = (player.maxHp * 0.25).ceil();
            player.hp = (player.hp - dmg).clamp(1, player.maxHp);
            _applyStatus(player, Status.embarrassed, events);
            text = 'CLAC ! Elle a mordu (-$dmg). Le public conclut que vous êtes un menteur.';
          }
      }
    }
    if (use) f.used = true;
    if (close) activeFeature = null;
    show.onEvents(events, turn);
    _checkAchievements(events);
    return FeatureResult(text, events, closed: close);
  }

  // ================================================================ le show

  /// Compte à rebours de l'étage : avertissements puis démolition.
  void _tickTimer(List<GameEvent> events) {
    if (gameOver) return;
    final left = turnsLeft;
    if (left == 30 || left == 10) {
      _say(MaestroLines.timerWarning, events, extra: {'left': '$left'});
    } else if (left == 0) {
      _say(MaestroLines.demolition, events);
    } else if (left < 0) {
      final dmg = 1 + (-left) ~/ 4;
      player.hp -= dmg;
      events.add(DemolitionEvent(dmg));
      events.add(MessageEvent('Des gravats vous tombent dessus (-$dmg).', MessageKind.danger));
      if (player.hp <= 0) _playerDown("la démolition de l'étage", events);
    }
  }

  void _showTurn(List<GameEvent> events, {required bool waited, required int newTiles}) {
    show.onEvents(events, turn);
    show.endTurn(
      waited: waited,
      lowHp: player.hpRatio < 0.3,
      timerLow: turnsLeft <= 20,
      newTiles: newTiles,
    );
    final extra = <GameEvent>[];
    if (show.takeTwist()) _twist(extra);
    for (final i in show.takeGifts()) {
      final s = show.sponsors[i];
      final tier = switch (s.gifts) {
        1 => BoxTier.bronze,
        2 => BoxTier.argent,
        _ => show.tier == HypeTier.viral ? BoxTier.legendaire : BoxTier.or,
      };
      _gainBox(tier, s.def.name, extra);
      extra.add(SponsorGiftEvent(i, tier.index));
      _say(MaestroLines.sponsorGift, extra, extra: {'sponsor': s.def.name});
      _unlock('sponsored', extra);
    }
    if (show.tier == HypeTier.viral && !_viralAnnounced) {
      _viralAnnounced = true;
      _say(MaestroLines.viral, extra);
      _unlock('viral', extra);
    } else if (show.hype < 60) {
      _viralAnnounced = false;
    }
    // Les récompenses du show font elles-mêmes un peu de hype (succès, boîtes).
    show.onEvents(extra, turn);
    events.addAll(extra);
  }

  /// Rebondissement : la régie lâche deux monstres réveillés hors de vue.
  void _twist(List<GameEvent> events) {
    final pool = _themePool().where((d) => d.disguise == null).toList();
    var spawned = 0;
    for (var tries = 0; tries < 80 && spawned < 2; tries++) {
      final p = Pos(rng.range(1, level.width - 2), rng.range(1, level.height - 2));
      if (!isFree(p) || visible.contains(p) || p.manhattan(player.pos) < 5) continue;
      final m = _makeMonster(rng.weighted(pool, (d) => d.weight), p)
        ..awake = true
        ..lastSeenTarget = player.pos;
      monsters.add(m);
      spawned++;
    }
    events.add(const TwistEvent());
    _say(MaestroLines.twist, events);
  }

  // ================================================================ coulisses

  void _enterBackstage(List<GameEvent> events) {
    // Questions : une en rapport avec l'étage s'il y en a, puis des génériques.
    final ctx = <When>{
      if (_poisonedThisFloor) When.poisoned,
      if (_minHpRatioFloor < 0.25) When.lowHp,
      if (_floorKills >= 5) When.killer,
      if (_floorKills == 0) When.pacifist,
      if (gold >= 120) When.rich,
      if (gold < 15) When.broke,
      if (_mimicThisFloor) When.mimic,
      if (floor >= 4) When.deep,
      if (player.hpRatio < 0.6) When.wounded,
      if (_fellRecently) When.fell,
      if (_prayedThisFloor) When.prayed,
    };
    _fellRecently = false;
    final count = floor < 3 ? 2 : 3;
    final picked = <int>[];
    // Les événements marquants de l'étage passent avant les états généraux.
    const priority = [
      When.fell, When.prayed, When.poisoned, When.mimic, When.lowHp, When.killer, When.pacifist, //
      When.rich, When.broke, When.wounded, When.deep,
    ];
    for (final w in priority) {
      if (!ctx.contains(w)) continue;
      final options = [
        for (var i = 0; i < questions.length; i++)
          if (questions[i].when == w && !_usedQuestions.contains(i)) i,
      ];
      if (options.isNotEmpty) {
        picked.add(rng.pick(options));
        break;
      }
    }
    var generic = [
      for (var i = 0; i < questions.length; i++)
        if (questions[i].when == When.always && !_usedQuestions.contains(i)) i,
    ];
    if (generic.length < count) {
      _usedQuestions.removeWhere((i) => questions[i].when == When.always);
      generic = [for (var i = 0; i < questions.length; i++) if (questions[i].when == When.always) i];
    }
    rng.shuffle(generic);
    picked.addAll(generic.take(count - picked.length));
    _usedQuestions.addAll(picked);

    // Boutique
    final weights = [(60 - floor * 4).clamp(15, 60), 30 + floor * 2, 8 + floor * 2, floor >= 3 ? 2 + floor : 0];
    final shop = <ShopOffer>[ShopOffer(healPotion, _price(healPotion))];
    for (var i = 0; i < 4; i++) {
      final it = rollItem(rng, rollRarity(rng, weights), floor);
      shop.add(ShopOffer(it, _price(it)));
    }

    // Talents
    final available = talentDefs.where((t) => !talents.contains(t.id)).toList();
    rng.shuffle(available);

    backstage = Backstage(
      intro: rng.pick(MaestroLines.interviewIntro).replaceAll('{floor}', '$floor'),
      questions: [for (final i in picked) questions[i]],
      shop: shop,
      talents: available.take(3).toList(),
      healPrice: 10 + floor * 4,
    );
    events.add(const BackstageEvent());
  }

  int _price(ItemDef d) {
    const base = [22, 55, 120, 240];
    final p = d.id == healPotion.id ? 18 : base[d.rarity.index];
    return (p * (1 + floor * 0.08) * (has('haggler') ? 0.75 : 1)).round();
  }

  /// Répond à la question en cours de l'interview.
  AnswerResult? answer(int index) {
    final r = _answer(index);
    if (r != null) commands.add('a:$index');
    return r;
  }

  bool buy(int index) => _rec(_buy(index), 'b:$index');
  bool healAtInfirmary() => _rec(_healAtInfirmary(), 'h');
  bool pickTalent(int index) => _rec(_pickTalent(index), 't:$index');

  List<GameEvent> leaveBackstage() {
    final e = _leaveBackstage();
    if (e.isNotEmpty) commands.add('l');
    return e;
  }

  BoxResult? openBox() {
    final r = _openBox();
    if (r != null) commands.add('o');
    return r;
  }

  bool _rec(bool ok, String cmd) {
    if (ok) commands.add(cmd);
    return ok;
  }

  AnswerResult? _answer(int index) {
    final b = backstage;
    final q = b?.question;
    if (b == null || q == null || index < 0 || index >= q.answers.length) return null;
    final a = q.answers[index];
    show.addHype(a.hype * 0.6);
    show.viewers *= 1 + a.viewersPct;
    gold = (gold + a.gold).clamp(0, 1 << 30);
    if (a.healPct > 0) {
      player.hp = (player.hp + (player.maxHp * a.healPct).round()).clamp(0, player.maxHp);
    }
    if (a.sponsor != null) show.adjustSponsor(a.sponsor!, a.sponsorDelta);
    _nextTimerDelta += a.timerDelta;
    _nextExtraMonsters += a.extraMonsters;
    if (a.box != null) pendingBoxes.add(a.box!);
    if (a.crowd == Crowd.applause) {
      applause++;
      if (applause >= 3) _unlock('talk_show', []);
    }
    final r = AnswerResult(withSponsors(a.text), withSponsors(a.reaction), a.crowd, a.effects);
    b.results.add(r);
    return r;
  }

  bool _buy(int index) {
    final b = backstage;
    if (b == null || index < 0 || index >= b.shop.length) return false;
    final o = b.shop[index];
    if (o.sold || gold < o.price || (bagFull && _inv(o.item.id) == null)) return false;
    gold -= o.price;
    o.sold = true;
    _addToBag(o.item);
    if (has('nose') && o.item.mystery) identified.add(o.item.effect!);
    show.please(Taste.loot, 15);
    return true;
  }

  bool _healAtInfirmary() {
    final b = backstage;
    if (b == null || b.healed || gold < b.healPrice || player.hp >= player.maxHp) return false;
    gold -= b.healPrice;
    b.healed = true;
    player.hp = player.maxHp;
    return true;
  }

  bool _pickTalent(int index) {
    final b = backstage;
    if (b == null || b.talentPicked || index < 0 || index >= b.talents.length) return false;
    final t = b.talents[index];
    b.talentPicked = true;
    _applyTalent(t.id);
    return true;
  }

  /// Acquiert un talent et applique ses effets immédiats.
  void _applyTalent(String id) {
    if (!talents.add(id)) return;
    switch (id) {
      case 'thick_skin':
        baseDef += 1;
      case 'big_arms':
        baseAtk += 2;
      case 'cardio':
        baseMaxHp += 10;
        player.hp += 10;
      case 'crowd_fav':
        show.crowdFav = true;
      case 'showman':
        show.showman = true;
      case 'sponsor_friend':
        show.sponsorFriend = true;
      case 'nose':
        for (final i in inventory) {
          if (i.def.mystery) identified.add(i.def.effect!);
        }
    }
    _recalcStats();
  }

  /// Retour en scène : étage suivant.
  List<GameEvent> _leaveBackstage() {
    if (backstage == null) return const [];
    backstage = null;
    final events = <GameEvent>[];
    _enterFloor(floor + 1, events);
    _checkAchievements(events);
    return events;
  }

  // ================================================================ loot boxes

  /// Ouvre la prochaine loot box en attente (ne consomme pas de tour).
  BoxResult? _openBox() {
    if (pendingBoxes.isEmpty || gameOver) return null;
    final tier = pendingBoxes.removeAt(0);
    final items = <ItemDef>[];
    for (var i = 0; i < tier.items; i++) {
      items.add(rollItem(rng, rollRarity(rng, tier.rarityWeights), floor));
    }
    final goldGain = (tier.gold * (1 + floor * 0.3) * (0.8 + rng.nextDouble() * 0.4)).round();
    gold += goldGain;
    var overflow = false;
    for (final it in items) {
      if (!_addToBag(it)) {
        floorItems.add(FloorItem.item(it, player.pos));
        overflow = true;
      }
    }
    show.onBoxOpened();
    _checkAchievements([]);
    return BoxResult(tier, items, goldGain, overflow: overflow);
  }

  /// Le candidat quitte l'émission en cours de run.
  void abandon() {
    if (gameOver) return;
    commands.add('X');
    gameOver = true;
    killedBy = "l'abandon (le public n'oubliera pas)";
  }

  /// Outil de développement : donne une loot box sans condition.
  void debugGrantBox(BoxTier tier) {
    commands.add('G:${tier.index}');
    pendingBoxes.add(tier);
  }

  /// Outil de développement : place le joueur sur l'escalier.
  void debugToStairs() {
    commands.add('S');
    monsters.removeWhere((m) => m.pos == level.stairs);
    player.pos = level.stairs;
    _updateFov();
  }

  void _gainBox(BoxTier tier, String reason, List<GameEvent> events) {
    pendingBoxes.add(tier);
    events.add(BoxGainedEvent(tier.index, reason));
  }

  void _openChest(Chest chest, List<GameEvent> events) {
    chests.remove(chest);
    _gainBox(chest.tier, 'Coffre', events);
    events.add(MessageEvent('Vous ouvrez le coffre : loot box ${chest.tier.label} !', MessageKind.good));
  }

  // ================================================================ sac et équipement

  InvItem? _inv(String id) {
    for (final i in inventory) {
      if (i.def.id == id) return i;
    }
    return null;
  }

  /// Ajoute au sac (empile les objets identiques). Faux si le sac est plein.
  bool _addToBag(ItemDef d) {
    final existing = _inv(d.id);
    if (existing != null) {
      existing.count++;
      return true;
    }
    if (bagFull) return false;
    inventory.add(InvItem(d));
    return true;
  }

  void _removeOne(ItemDef d) {
    final inv = _inv(d.id);
    if (inv == null) return;
    inv.count--;
    if (inv.count <= 0) inventory.remove(inv);
  }

  void _equip(ItemDef d, List<GameEvent> events) {
    _removeOne(d);
    final previous = d.kind == ItemKind.weapon ? weapon : trinket;
    if (d.kind == ItemKind.weapon) {
      weapon = d;
    } else {
      trinket = d;
    }
    if (previous != null && !_addToBag(previous)) {
      floorItems.add(FloorItem.item(previous, player.pos));
    }
    _recalcStats();
    events.add(MessageEvent('Vous équipez ${d.name}.', MessageKind.good));
  }

  void _recalcStats() {
    final w = weapon, t = trinket;
    player.atk = baseAtk + (w?.atk ?? 0) + (t?.atk ?? 0);
    player.def = baseDef + (w?.def ?? 0) + (t?.def ?? 0);
    player.maxHp = baseMaxHp + (w?.maxHp ?? 0) + (t?.maxHp ?? 0);
    if (player.hp > player.maxHp) player.hp = player.maxHp;
  }

  void _useItem(ItemDef d, List<GameEvent> events) {
    _removeOne(d);
    potionsDrunk++;
    final wasKnown = !d.mystery || identified.contains(d.effect);
    final before = player.hp;
    switch (d.effect!) {
      case Effect.heal:
        player.hp = (player.hp + (player.maxHp * 0.4).round() + 4).clamp(0, player.maxHp);
        player.statuses
          ..remove(Status.poison)
          ..remove(Status.burn);
        events.add(MessageEvent('Vous buvez une potion de soin (+${player.hp - before} PV).', MessageKind.good));
      case Effect.bigHeal:
        baseMaxHp += 2;
        _recalcStats();
        player.hp = player.maxHp;
        events.add(const MessageEvent('Vous vous sentez comme neuf. Et même un peu plus.', MessageKind.good));
      case Effect.strength:
        baseAtk += 1;
        _recalcStats();
        events.add(const MessageEvent('Vos biceps gonflent. ATQ +1.', MessageKind.good));
      case Effect.toughness:
        baseMaxHp += 5;
        _recalcStats();
        player.hp += 5;
        events.add(const MessageEvent('Votre peau devient cartonnée. PV max +5.', MessageKind.good));
      case Effect.poison:
        final dmg = (player.maxHp / 4).ceil();
        player.hp = (player.hp - dmg).clamp(1, player.maxHp);
        events.add(MessageEvent('Beurk ! Du poison (-${before - player.hp} PV).', MessageKind.danger));
        _unlock('poisoned', events);
      case Effect.teleport:
        final dest = _randomFreeCell(avoidStartRoom: false);
        if (dest != null) {
          events.add(MoveEvent(player.id, player.pos, dest));
          player.pos = dest;
        }
        events.add(const MessageEvent('POUF ! Vous êtes ailleurs.', MessageKind.good));
      case Effect.clairvoyance:
        for (var y = 0; y < level.height; y++) {
          for (var x = 0; x < level.width; x++) {
            explored.add(Pos(x, y));
          }
        }
        events.add(const MessageEvent("Le plan de l'étage s'imprime dans votre cerveau.", MessageKind.good));
      case Effect.cure:
        player.hp = (player.hp + 10).clamp(0, player.maxHp);
        player.statuses.clear();
        events.add(const MessageEvent('Pansement appliqué. Le logo du sponsor vous colle à la peau.', MessageKind.good));
      case Effect.confetti:
        var hit = 0;
        for (final m in List<Actor>.of(monsters)) {
          if (!visible.contains(m.pos) || m.disguised) continue;
          hit++;
          final dmg = 8 + floor;
          m.hp -= dmg;
          events.add(StatusDamageEvent(m.id, m.pos, dmg, Status.embarrassed.index));
          if (m.alive) {
            _applyStatus(m, Status.embarrassed, events);
          } else {
            _kill(m, player, events);
          }
        }
        events.add(MessageEvent("BOUM ! Une pluie de confettis s'abat sur $hit monstre(s).", MessageKind.good));
        show.addHype(6);
      case Effect.remote:
        final spots = [
          for (final p in level.stairs.neighbors4) if (isFree(p)) p,
          if (!bossAlive && isFree(level.stairs)) level.stairs,
        ];
        if (spots.isNotEmpty) {
          final dest = spots.last;
          events.add(MoveEvent(player.id, player.pos, dest));
          player.pos = dest;
        }
        events.add(const MessageEvent('ZAP ! Vous changez de chaîne et atterrissez près de la sortie.',
            MessageKind.good));
      case Effect.whistle:
        var n = 0;
        for (final m in monsters) {
          if (m.pos.isAdjacent4(player.pos) && !m.disguised) {
            _applyStatus(m, Status.stun, events);
            m.statuses[Status.stun] = 3;
            n++;
          }
        }
        events.add(MessageEvent('PRRRRT ! Carton rouge pour $n monstre(s).', MessageKind.good));
      case Effect.rage:
        rageTurns = 12;
        events.add(const MessageEvent('RAAAAH ! Dégâts doublés pendant 12 tours.', MessageKind.good));
    }
    if (d.effect == Effect.poison) _poisonedThisFloor = true;
    events.add(ItemUsedEvent(unknown: !wasKnown));
    if (player.hp > before) events.add(HealEvent(player.pos, player.hp - before));
    if (!wasKnown) {
      identified.add(d.effect!);
      events.add(MessageEvent("C'était : ${d.name} !", MessageKind.good));
    }
    if (rng.chance(0.25)) _say(MaestroLines.potion, events);
  }

  // ================================================================ étages

  void _enterFloor(int newFloor, List<GameEvent> events) {
    floor = newFloor;
    level = DungeonGenerator(rng).generate(floor: floor);
    player.pos = level.start;
    monsters.clear();
    floorItems.clear();
    chests.clear();
    explored.clear();
    _floorArrivalTurn = turn;
    _floorKills = 0;
    floorTimer = 170 + floor * 10 + (has('light_foot') ? 25 : 0) + _airtime + _nextTimerDelta;
    if (floorTimer < 60) floorTimer = 60;
    _nextTimerDelta = 0;
    _secondWindUsed = false;
    _poisonedThisFloor = false;
    _mimicThisFloor = false;
    _prayedThisFloor = false;
    features.clear();
    traps.clear();
    activeFeature = null;
    // Un étage sur trois environ (à partir du 2) a un modificateur.
    floorMod = floor >= 2 && rng.chance(0.35) ? rng.pick(FloorMod.values) : null;
    if (floorMod == FloorMod.shortEpisode) floorTimer = (floorTimer - 40).clamp(60, 9999);
    _minHpRatioFloor = player.hpRatio;
    _floorWalkable = {
      for (var y = 0; y < level.height; y++)
        for (var x = 0; x < level.width; x++)
          if (level.tiles.get(x, y).walkable) Pos(x, y),
    };
    _spawnMonsters();
    _spawnLoot();
    _spawnFeatures();
    _applyFloorMod();
    _updateFov();
    events.add(FloorEvent(floor));
    if (floor > 1 && (floor - 1) % 3 == 0) {
      events.add(MessageEvent(theme.intro, MessageKind.maestro));
    } else if (floor > 1) {
      _say(MaestroLines.newFloor, events);
    }
    final mod = floorMod;
    if (mod != null) {
      events.add(FloorModEvent(mod.index));
      events.add(MessageEvent('${mod.label.toUpperCase()} ! ${mod.announce}', MessageKind.maestro));
    }
  }

  Pos? _randomFreeCell({bool avoidStartRoom = true}) {
    final rooms = level.rooms.skip(avoidStartRoom ? 1 : 0).toList();
    for (var tries = 0; tries < 60; tries++) {
      final room = rng.pick(rooms);
      final p = Pos(rng.range(room.x, room.x2), rng.range(room.y, room.y2));
      if (isFree(p) && p != level.stairs && itemsAt(p).isEmpty) return p;
    }
    return null;
  }

  /// Monstres de la zone courante disponibles à cet étage.
  List<MonsterDef> _themePool() {
    final pool = theme.monsters.map(monsterById).where((d) => d.minFloor <= floor).toList();
    return pool.isEmpty ? [monsterById(theme.monsters.first)] : pool;
  }

  void _spawnBoss() {
    boss = null;
    _bossAnnounced = false;
    if (!isBossFloor(floor)) return;
    // Le boss garde l'escalier.
    final spots = [
      for (final p in level.stairs.neighbors4) if (isFree(p)) p,
      for (var dy = -2; dy <= 2; dy++)
        for (var dx = -2; dx <= 2; dx++)
          if (isFree(level.stairs + Pos(dx, dy)) && level.stairs + Pos(dx, dy) != level.stairs) level.stairs + Pos(dx, dy),
    ];
    if (spots.isEmpty) return;
    final b = _makeMonster(monsterById(theme.boss), spots.first);
    monsters.add(b);
    boss = b;
  }

  void _spawnMonsters() {
    _spawnBoss();
    final pool = _themePool();
    final count = 3 + floor + rng.range(0, 2) + _nextExtraMonsters;
    _nextExtraMonsters = 0;
    for (var i = 0; i < count; i++) {
      final def = rng.weighted(pool, (d) => d.weight);
      final pos = _randomFreeCell();
      if (pos == null) continue;
      monsters.add(_makeMonster(def, pos));
    }
  }

  Actor _makeMonster(MonsterDef def, Pos pos) {
    final depth = floor - def.minFloor;
    return Actor(
      id: _nextId++,
      name: def.name,
      sprite: def.sprite,
      pos: pos,
      // Les monstres ordinaires se renforcent un peu à chaque étage (pas les boss, réglés à la main).
      maxHp: (def.hp * (1 + 0.1 * depth) * (def.boss ? 1 : 1 + 0.04 * floor)).round(),
      atk: def.atk + depth ~/ 3 + (def.boss ? 0 : floor ~/ 6),
      def: def.def + depth ~/ 4,
      monster: def,
    );
  }

  void _spawnLoot() {
    if (rng.chance(0.5)) _place(FloorItem.item(healPotion, const Pos(0, 0)));
    final weights = [
      (70 - floor * 5).clamp(20, 70),
      25 + floor * 3,
      5 + floor * 2,
      floor >= 3 ? floor : 0,
    ];
    final nItems = rng.range(1, 2);
    for (var i = 0; i < nItems; i++) {
      _place(FloorItem.item(rollItem(rng, rollRarity(rng, weights), floor), const Pos(0, 0)));
    }
    final nGold = rng.range(2, 4);
    for (var i = 0; i < nGold; i++) {
      _place(FloorItem.gold(rng.range(3, 8) + floor * 2, const Pos(0, 0)));
    }
    if (rng.chance(0.55)) {
      final p = _randomFreeCell();
      if (p != null) chests.add(Chest(p, rng.chance(0.25) ? BoxTier.argent : BoxTier.bronze));
    }
  }

  void _place(FloorItem template) {
    final p = _randomFreeCell(avoidStartRoom: false);
    if (p == null) return;
    floorItems.add(template.item != null ? FloorItem.item(template.item!, p) : FloorItem.gold(template.gold, p));
  }

  void _collect(List<GameEvent> events) {
    for (final it in itemsAt(player.pos).toList()) {
      if (it.item == null) {
        floorItems.remove(it);
        var amount = has('pickpocket') ? (it.gold * 1.5).round() : it.gold;
        if (floorMod == FloorMod.shortEpisode) amount = (amount * 1.5).round();
        gold += amount;
        events.add(PickupEvent(it.pos, '+$amount or'));
        events.add(GoldEvent(amount));
        events.add(MessageEvent('Vous ramassez $amount pièces.', MessageKind.good));
      } else if (_addToBag(it.item!)) {
        floorItems.remove(it);
        if (has('nose') && it.item!.mystery) identified.add(it.item!.effect!);
        events.add(const ItemPickedEvent());
        final name = nameOf(it.item!);
        events.add(PickupEvent(it.pos, '+1'));
        events.add(MessageEvent('Vous ramassez : $name.', MessageKind.good));
      } else {
        events.add(MessageEvent('Sac plein ! ${nameOf(it.item!)} reste par terre.', MessageKind.danger));
      }
    }
  }

  // ================================================================ combat

  void _reveal(Actor m, List<GameEvent> events) {
    m.disguised = false;
    m.awake = true;
    m.lastSeenTarget = player.pos;
    _mimicThisFloor = true;
    events.add(RevealEvent(m.pos));
    events.add(const MessageEvent('Le coffre ouvre un œil. Puis une bouche. C\'est une MIMIQUE !', MessageKind.danger));
  }

  void _attack(Actor attacker, Actor target, List<GameEvent> events) {
    final byPlayer = attacker.isPlayer;
    final r = resolveAttack(
      attacker,
      target,
      rng,
      critChance: byPlayer ? critChance : 0.10,
      multiplier: byPlayer && rageTurns > 0 ? 2 : 1,
    );
    // Gêné : les coups font moitié moins mal.
    var damage = r.damage;
    if (!r.miss && attacker.hasStatus(Status.embarrassed)) damage = (damage / 2).ceil();
    events.add(AttackEvent(
      attackerId: attacker.id,
      targetId: target.id,
      from: attacker.pos,
      to: target.pos,
      damage: damage,
      crit: r.crit,
      miss: r.miss,
    ));
    if (r.miss) {
      events.add(MessageEvent(byPlayer ? 'Vous ratez ${_the(target)}.' : '${_cap(_the(attacker))} vous rate.'));
      return;
    }
    target.hp -= damage;
    _onHitEffects(attacker, target, events);
    if (target.monster?.enrage == true && !target.enraged && target.alive && target.hp < target.maxHp / 2) {
      target.enraged = true;
      target.atk = (target.atk * 1.5).round();
      _say(MaestroLines.enrage, events, extra: {'boss': target.monster!.theName});
    }
    final critTxt = r.crit ? ' CRITIQUE !' : '';
    if (byPlayer) {
      if (r.crit) crits++;
      events.add(MessageEvent('Vous frappez ${_the(target)} ($damage).$critTxt'));
      if (lifesteal > 0 && player.hp < player.maxHp) {
        final before = player.hp;
        player.hp = (player.hp + lifesteal).clamp(0, player.maxHp);
        events.add(HealEvent(player.pos, player.hp - before));
      }
    } else {
      events.add(MessageEvent('${_cap(_the(attacker))} vous frappe ($damage).$critTxt', MessageKind.danger));
    }
    if (target.isPlayer && !target.alive) {
      _playerDown(_the(attacker), events, killerName: attacker.name);
    } else if (!target.alive) {
      _kill(target, attacker, events);
    }
  }

  /// Effets « au toucher » : altérations, vol d'or.
  void _onHitEffects(Actor attacker, Actor target, List<GameEvent> events) {
    if (!target.alive) return;
    final OnHit? effect;
    final double chance;
    if (attacker.isPlayer) {
      effect = weapon?.onHit;
      chance = weapon?.onHitChance ?? 0;
    } else {
      effect = attacker.monster!.onHit;
      chance = attacker.monster!.onHitChance;
    }
    if (effect == null || !rng.chance(chance)) return;
    if (effect == OnHit.steal) {
      if (!target.isPlayer || gold <= 0) return;
      final stolen = (5 + floor * 2).clamp(0, gold);
      gold -= stolen;
      events.add(PickupEvent(target.pos, '-$stolen or'));
      events.add(MessageEvent('${_cap(_the(attacker))} vous vole $stolen pièces !', MessageKind.danger));
      return;
    }
    _applyStatus(target, effect.status!, events);
  }

  /// Applique une altération (sauf immunité). Les boss ne sont jamais étourdis.
  void _applyStatus(Actor a, Status s, List<GameEvent> events) {
    if (a.isPlayer && trinket?.immune == s) return;
    if (a.isBoss && s == Status.stun) return;
    // +1 : le tour en cours compte, l'effet doit durer jusqu'aux prochains.
    a.statuses[s] = s.turns + 1;
    events.add(StatusEvent(a.id, a.pos, s.index));
    if (a.isPlayer) {
      events.add(MessageEvent('Vous êtes ${s.label.toLowerCase()} !', MessageKind.danger));
      if (player.statuses.length >= 3) _unlock('sick', events);
    } else {
      events.add(MessageEvent('${_cap(_the(a))} : ${s.label.toLowerCase()}.'));
    }
  }

  /// Fin de tour : dégâts du poison et du feu, durées qui s'écoulent.
  void _tickStatuses(List<GameEvent> events) {
    for (final a in [player, ...monsters]) {
      if (gameOver || !a.alive || a.statuses.isEmpty) continue;
      var dmg = 0;
      Status? cause;
      if (a.hasStatus(Status.poison)) {
        dmg += 1 + floor ~/ 4;
        cause = Status.poison;
      }
      if (a.hasStatus(Status.burn)) {
        dmg += 2 + floor ~/ 3;
        cause = Status.burn;
      }
      if (dmg > 0) {
        a.hp -= dmg;
        events.add(StatusDamageEvent(a.id, a.pos, dmg, cause!.index));
        if (!a.alive) {
          if (a.isPlayer) {
            _playerDown(cause == Status.burn ? 'les flammes' : 'le poison', events);
          } else {
            _kill(a, player, events);
          }
          continue;
        }
      }
      for (final s in a.statuses.keys.toList()) {
        final left = a.statuses[s]! - 1;
        if (left <= 0) {
          a.statuses.remove(s);
        } else {
          a.statuses[s] = left;
        }
      }
    }
  }

  /// Le joueur tombe à 0 PV : second souffle éventuel, sinon fin de la run.
  void _playerDown(String cause, List<GameEvent> events, {String? killerName}) {
    if (has('second_wind') && !_secondWindUsed) {
      _secondWindUsed = true;
      player.hp = 1;
      show.addHype(15);
      events.add(const MessageEvent('SECOND SOUFFLE ! Vous refusez de mourir.', MessageKind.good));
      _say(MaestroLines.secondWind, events);
      return;
    }
    player.hp = 0;
    events.add(DeathEvent(player.id, player.pos, player.sprite, isPlayer: true));
    gameOver = true;
    killedBy = killerName ?? cause;
    events.add(MessageEvent('Vous avez été vaincu par $cause.', MessageKind.danger));
    _say(MaestroLines.death, events);
  }

  void _kill(Actor victim, Actor killer, List<GameEvent> events) {
    events.add(DeathEvent(victim.id, victim.pos, victim.sprite, isPlayer: victim.isPlayer));
    monsters.remove(victim);
    kills++;
    _floorKills++;
    _killTurns.add(turn);
    final id = victim.monster!.id;
    _killsById[id] = (_killsById[id] ?? 0) + 1;
    if (id == 'mimic') _mimicKills++;
    if (weapon?.id == 'butter_knife') _butterKills++;
    final e = victim.monster!.feminine ? 'e' : '';
    events.add(MessageEvent('${_cap(_the(victim))} est éliminé$e.', MessageKind.good));
    if (!_firstKillDone) {
      _firstKillDone = true;
      _say(MaestroLines.firstKill, events, monster: victim.name.toLowerCase());
    }
    if (victim.isBoss) {
      _bossDefeated(victim, events);
    } else if (id == 'mimic') {
      _gainBox(BoxTier.argent, 'Butin de la mimique', events);
    } else if (rng.chance(0.25)) {
      floorItems.add(FloorItem.gold(rng.range(2, 6) + floor, victim.pos));
    }
    if (victim.elite) {
      _gainBox(BoxTier.or, 'Monstre vedette', events);
      floorItems.add(FloorItem.gold(15 + floor * 4, victim.pos));
      events.add(const MessageEvent('La vedette est tombée ! Son agent est inconsolable.', MessageKind.good));
    } else if (!victim.isBoss && kills > 1 && rng.chance(0.12)) {
      _say(MaestroLines.killQuips, events);
    }
    var gained = victim.monster!.xp + floor - 1;
    if (victim.elite) gained *= 3;
    if (floorMod == FloorMod.doubleXp) gained *= 2;
    _gainXp(gained, events);
  }

  void _bossDefeated(Actor b, List<GameEvent> events) {
    final name = b.monster!.theName;
    events.add(BossEvent(b.name, defeated: true));
    show.addHype(25);
    floorItems.add(FloorItem.gold(30 + floor * 8, b.pos));
    _say(MaestroLines.bossDown, events, extra: {'boss': _cap(name)});
    _unlock('boss_slayer', events);
    if (floor >= finalFloor) {
      victory = true;
      gameOver = true;
      killedBy = null;
      _unlock('season_win', events);
      events.add(const VictoryEvent());
      _say(MaestroLines.victory, events);
    } else {
      _gainBox(BoxTier.or, 'Butin de boss', events);
    }
  }

  void _gainXp(int amount, List<GameEvent> events) {
    xp += amount;
    while (xp >= xpToNext) {
      xp -= xpToNext;
      playerLevel++;
      baseMaxHp += 6;
      baseAtk += 1;
      if (playerLevel % 3 == 0) baseDef += 1;
      _recalcStats();
      player.hp = (player.hp + 6 + player.maxHp ~/ 5).clamp(0, player.maxHp);
      events.add(LevelUpEvent(playerLevel));
      events.add(MessageEvent('Niveau $playerLevel ! PV max ${player.maxHp}, attaque ${player.atk}.', MessageKind.good));
      _say(MaestroLines.levelUp, events);
      _gainBox(BoxTier.bronze, 'Montée de niveau', events);
    }
  }

  // ================================================================ succès

  void _unlock(String id, List<GameEvent> events) {
    if (!unlocked.add(id)) return;
    final a = achievementById(id);
    events.add(AchievementEvent(id));
    events.add(MessageEvent('SUCCÈS : ${a.name} !', MessageKind.good));
    _gainBox(a.reward, a.name, events);
  }

  void _checkAchievements(List<GameEvent> events) {
    if (kills >= 1) _unlock('first_blood', events);
    if ((_killsById['rat'] ?? 0) >= 5) _unlock('rat_catcher', events);
    if ((_killsById['slime'] ?? 0) >= 3) _unlock('food_critic', events);
    if (potionsDrunk >= 4) _unlock('thirsty', events);
    if (identified.length >= 3) _unlock('taster', events);
    if (crits >= 5) _unlock('genius', events);
    if (!gameOver && player.hp <= 3) _unlock('miracle', events);
    if (gold >= 150) _unlock('tax_exile', events);
    if (_butterKills >= 5) _unlock('butter', events);
    if (_mimicKills >= 1) _unlock('mimic', events);
    if (floor >= 5) _unlock('deep', events);
    if (_killTurns.length >= 3 && _killTurns.last - _killTurns[_killTurns.length - 3] <= 6) {
      _unlock('carnage', events);
    }
    if (!unlocked.contains('tourist') && explored.containsAll(_floorWalkable)) _unlock('tourist', events);
  }

  // ================================================================ IA

  void _monstersTurn(List<GameEvent> events) {
    for (final m in List<Actor>.of(monsters)) {
      if (gameOver) return;
      if (!m.alive || m.disguised) continue;
      if (m.hasStatus(Status.stun)) continue;
      if (m.isBoss && m.awake) _bossSummon(m, events);
      final sees = visible.contains(m.pos);
      if (sees) {
        m.awake = true;
        m.lastSeenTarget = player.pos;
      }
      if (!m.awake) continue;

      final behavior = m.monster!.behavior;
      if (behavior == Behavior.slow && turn.isOdd) continue;
      if (behavior == Behavior.erratic && rng.chance(0.5)) {
        _randomStep(m, events);
        continue;
      }

      if (m.pos.isAdjacent4(player.pos)) {
        _attack(m, player, events);
        continue;
      }

      final goal = m.lastSeenTarget;
      if (goal == null) {
        m.awake = false;
        continue;
      }
      final path = findPath(level.tiles, m.pos, goal, (p) => isFree(p), allowBlockedGoal: true);
      if (path == null || path.isEmpty) {
        m.lastSeenTarget = null;
        continue;
      }
      final next = path.first;
      if (isFree(next)) {
        events.add(MoveEvent(m.id, m.pos, next));
        m.pos = next;
      }
      if (m.pos == goal && !sees) m.lastSeenTarget = null;
    }
  }

  /// Les boss appellent régulièrement des renforts.
  void _bossSummon(Actor b, List<GameEvent> events) {
    final def = b.monster!;
    if (def.summon == null || def.summonEvery <= 0) return;
    b.summonTimer++;
    if (b.summonTimer % def.summonEvery != 0 || monsters.length >= 20) return;
    final spot = b.pos.neighbors4.where(isFree).toList();
    if (spot.isEmpty) return;
    final minion = _makeMonster(monsterById(def.summon!), rng.pick(spot))
      ..awake = true
      ..lastSeenTarget = player.pos;
    monsters.add(minion);
    events.add(MessageEvent('${_cap(_the(b))} appelle des renforts !', MessageKind.danger));
  }

  void _randomStep(Actor m, List<GameEvent> events) {
    final options = m.pos.neighbors4.where(isFree).toList();
    if (options.isEmpty) return;
    final next = rng.pick(options);
    events.add(MoveEvent(m.id, m.pos, next));
    m.pos = next;
  }

  // ================================================================ utilitaires

  void _updateFov() {
    visible = computeFov(
      player.pos,
      sightRadius,
      (p) => level.tiles[p].blocksSight,
      level.tiles.inBounds,
    );
    explored.addAll(visible);
  }

  void _checkLowHp(List<GameEvent> events) {
    if (gameOver) return;
    if (!_lowHpWarned && player.hpRatio < 0.3) {
      _lowHpWarned = true;
      _say(MaestroLines.lowHp, events);
    } else if (_lowHpWarned && player.hpRatio > 0.6) {
      _lowHpWarned = false;
    }
  }

  void _say(List<String> lines, List<GameEvent> events, {String? monster, Map<String, String> extra = const {}}) {
    var text = rng
        .pick(lines)
        .replaceAll('{floor}', '$floor')
        .replaceAll('{monster}', monster ?? 'monstre');
    extra.forEach((k, v) => text = text.replaceAll('{$k}', v));
    _lastMaestroTurn = turn;
    events.add(MessageEvent(text, MessageKind.maestro));
  }

  String _the(Actor a) => a.isPlayer ? 'vous' : a.monster!.theName;

  String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  // ================================================================ sauvegarde

  /// Version du format de sauvegarde. À incrémenter dès que le moteur change de façon
  /// à rendre un ancien journal impossible à rejouer à l'identique.
  static const saveVersion = 2;

  static String _encode(PlayerAction a) => switch (a) {
        MoveAction(:final dir) => 'm${dir.index}',
        WaitAction() => 'w',
        DescendAction() => 'd',
        QuaffAction() => 'q',
        UseItemAction(:final itemId) => 'u:$itemId',
        EquipAction(:final itemId) => 'e:$itemId',
        UnequipAction(:final slot) => 'x:${slot.index}',
        DropAction(:final itemId) => 'r:$itemId',
      };

  Map<String, Object?> toSave() => {
        'v': saveVersion,
        'seed': seed,
        'role': setup.roleId,
        'upgrades': setup.upgrades,
        'daily': setup.daily,
        'cmds': commands.join(';'),
        // Pour l'écran titre, sans avoir à rejouer.
        'floor': floor,
        'turn': turn,
      };

  /// Reconstruit une run en rejouant son journal. Null si la sauvegarde est illisible ou
  /// date d'une version incompatible du moteur.
  static Game? fromSave(Map<String, Object?> j) {
    try {
      if (j['v'] != saveVersion) return null;
      final ups = <String, int>{};
      (j['upgrades'] as Map?)?.forEach((k, v) => ups[k as String] = (v as num).toInt());
      final g = Game.newRun(
        (j['seed'] as num).toInt(),
        setup: RunSetup(roleId: j['role'] as String? ?? 'lambda', upgrades: ups, daily: j['daily'] as bool? ?? false),
      );
      final raw = j['cmds'] as String? ?? '';
      for (final c in raw.isEmpty ? const <String>[] : raw.split(';')) {
        g._replay(c);
      }
      return g;
    } catch (_) {
      return null;
    }
  }

  void _replay(String c) {
    final arg = c.length > 2 && c[1] == ':' ? c.substring(2) : '';
    switch (c[0]) {
      case 'm':
        act(MoveAction(Dir.values[int.parse(c.substring(1))]));
      case 'w':
        act(const WaitAction());
      case 'd':
        act(const DescendAction());
      case 'q':
        act(const QuaffAction());
      case 'u':
        act(UseItemAction(arg));
      case 'e':
        act(EquipAction(arg));
      case 'x':
        act(UnequipAction(ItemKind.values[int.parse(arg)]));
      case 'r':
        act(DropAction(arg));
      case 'a':
        answer(int.parse(arg));
      case 'b':
        buy(int.parse(arg));
      case 'h':
        healAtInfirmary();
      case 't':
        pickTalent(int.parse(arg));
      case 'l':
        leaveBackstage();
      case 'o':
        openBox();
      case 'f':
        chooseFeature(int.parse(arg));
      case 'X':
        abandon();
      case 'G':
        debugGrantBox(BoxTier.values[int.parse(arg)]);
      case 'S':
        debugToStairs();
      default:
        throw FormatException('Commande inconnue : $c');
    }
  }
}
