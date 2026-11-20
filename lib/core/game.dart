import '../content/achievements.dart';
import '../content/crafting.dart';
import '../content/features.dart';
import '../content/mastery.dart';
import '../content/quests.dart';
import '../content/interviews.dart';
import '../content/items.dart';
import '../content/lines_fr.dart';
import '../content/monsters.dart';
import '../content/roles.dart';
import '../content/skills.dart';
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

/// Compétence active du rôle.
class SkillAction extends PlayerAction {
  const SkillAction();
}

/// Coup lourd (2 endurance) sur le monstre au contact dans la direction [dir].
class HeavyAction extends PlayerAction {
  const HeavyAction(this.dir);
  final Dir dir;
}

/// Repousse le monstre au contact de 2 cases (1 endurance).
class ShoveAction extends PlayerAction {
  const ShoveAction(this.dir);
  final Dir dir;
}

/// Garde (1 endurance) : annule le prochain coup au contact ce tour et riposte.
class ParryAction extends PlayerAction {
  const ParryAction();
}

/// Tir avec l'arme à distance sur le monstre [targetId].
class ShootAction extends PlayerAction {
  const ShootAction(this.targetId);
  final int targetId;
}

/// Lance l'objet [itemId] sur le monstre [targetId].
/// Fabrique la recette [recipeId] à l'atelier (1 tour).
class CraftAction extends PlayerAction {
  const CraftAction(this.recipeId);
  final String recipeId;
}

class ThrowAction extends PlayerAction {
  const ThrowAction(this.itemId, this.targetId);
  final String itemId;
  final int targetId;
}

/// Ce qu'un monstre s'apprête à faire si le joueur ne bouge pas (affiché au-dessus de lui).
enum MonsterIntent { none, melee, prepare, heavy, shoot, reload, explode, heal, flee, sleep, erratic }

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
    // Tout le monde part avec un lance-pierre : on n'est jamais démuni face à un tireur.
    ranged = itemById('slingshot');
    inventory.add(InvItem(stones, 10));
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
  /// Taille de base du sac.
  static const baseSlots = 12;

  /// Places gagnées pendant la run (banane, sac de rando).
  int bagBonus = 0;

  /// Taille du sac : base + 2 places tous les 3 niveaux + objets + contrat « poches ».
  int get maxSlots => baseSlots + (playerLevel ~/ 3) * 2 + bagBonus + 2 * setup.level('pockets');

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

  // Quêtes des PNJ
  /// Quête de l'étage (null s'il n'y a pas de PNJ).
  Quest? quest;
  int questsDone = 0;
  String? _lastNpc;

  // Compétences qui progressent à l'usage
  final masteryXp = <Mastery, int>{};
  int masteryXpOf(Mastery m) => masteryXp[m] ?? 0;
  int masteryLevel(Mastery m) => masteryLevelFor(masteryXpOf(m));
  bool hasPerk(Mastery m, int level) => masteryLevel(m) >= level;

  /// Événements produits hors tour (démontage) : l'interface les récupère.
  final freeEvents = <GameEvent>[];

  int get heavyCost => hasPerk(Mastery.brawl, 5) ? 1 : 2;
  int get parryCost => hasPerk(Mastery.guard, 3) ? 1 : 2;
  int get spellCost => hasPerk(Mastery.magic, 4) ? 1 : 2;

  /// Portée de l'arme à distance équipée (avec les paliers de compétence).
  int get shootRange {
    final w = ranged;
    if (w == null) return 0;
    return w.range + (w.magic ? (hasPerk(Mastery.magic, 7) ? 1 : 0) : (hasPerk(Mastery.shooting, 3) ? 1 : 0));
  }

  int throwRange(ItemDef d) => d.range + (hasPerk(Mastery.shooting, 3) ? 1 : 0);

  /// Recharge réelle du pouvoir (le charisme la raccourcit).
  int get skillCooldownMax => (skill.cooldown * (1 - 0.04 * masteryLevel(Mastery.charisma))).round();

  // Artisanat
  /// Bourse de composants (ne prend pas de place dans le sac).
  final materials = <Component, int>{};

  /// Niveau d'amélioration de chaque équipement (par identifiant d'objet).
  final itemUpgrades = <String, int>{};
  int crafted = 0;
  int dismantled = 0;

  int plusOf(ItemDef d) => itemUpgrades[d.id] ?? 0;
  int materialCount(Component c) => materials[c] ?? 0;

  // Combat tactique
  ItemDef? ranged;
  static const maxStamina = 5;
  int stamina = maxStamina;
  bool _spentStamina = false;
  bool _parrying = false;

  void _spend(int n) {
    stamina -= n;
    _spentStamina = true;
  }

  /// Monstre visible et vivant d'identifiant [id], ou null.
  Actor? visibleMonster(int id) {
    for (final m in monsters) {
      if (m.id == id && m.alive && !m.disguised && visible.contains(m.pos)) return m;
    }
    return null;
  }

  /// Munitions disponibles pour l'arme à distance (illimité pour la magie).
  int get ammoCount {
    final w = ranged;
    if (w == null) return 0;
    if (w.magic) return 999;
    return _inv(w.ammo!)?.count ?? 0;
  }

  // Compétence active
  int skillCooldown = 0;
  int skillUses = 0;
  SkillDef get skill => skillById(setup.role.skill);
  bool get skillReady => skillCooldown == 0;

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
  String nameOf(ItemDef d) {
    if (d.mystery && !identified.contains(d.effect)) return _looks[d.effect]!.$1;
    final plus = plusOf(d);
    return plus > 0 ? '${d.name} +$plus' : d.name;
  }

  /// Description affichée (inconnue tant que non identifiée).
  String descOf(ItemDef d) =>
      d.mystery && !identified.contains(d.effect) ? 'Effet inconnu. Il faut goûter pour savoir.' : d.desc;

  int spriteOf(ItemDef d) => d.mystery ? _looks[d.effect]!.$2 : d.sprite;

  /// Teinte d'un objet (aucune pour les fioles mystère).
  int? tintOf(ItemDef d) => d.mystery ? null : d.tint;

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
          if (feature.used) {
            if (feature.kind == FeatureKind.npc) {
              return [MessageEvent('${quest?.shortName ?? 'Le personnage'} vous fait un petit signe. Rien de plus.')];
            }
            return [MessageEvent('${feature.kind.title} : déjà utilisé. Il boude.')];
          }
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
          _collectQuestItem(events);
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
        if (inv != null && inv.def.kind == ItemKind.throwable) {
          return [const MessageEvent('Ça se lance : utilisez LANCER puis touchez une cible.')];
        }
        if (inv == null || inv.def.kind != ItemKind.consumable) return const [];
        _useItem(inv.def, events);
      case EquipAction(:final itemId):
        final inv = _inv(itemId);
        if (inv == null || !inv.def.equippable) return const [];
        _equip(inv.def, events);
      case UnequipAction(:final slot):
        final current = switch (slot) {
          ItemKind.weapon => weapon,
          ItemKind.ranged => ranged,
          _ => trinket,
        };
        if (current == null) return const [];
        if (bagFull && _inv(current.id) == null) return [const MessageEvent('Sac plein : impossible de retirer.')];
        switch (slot) {
          case ItemKind.weapon:
            weapon = null;
          case ItemKind.ranged:
            ranged = null;
          default:
            trinket = null;
        }
        _addToBag(current);
        _recalcStats();
        events.add(MessageEvent('Vous retirez ${current.name}.'));
      case HeavyAction(:final dir):
        final m = monsterAt(player.pos + dir.delta);
        if (m == null || m.disguised) return [const MessageEvent('Rien à frapper par là.')];
        if (stamina < heavyCost) {
          return [MessageEvent("Pas assez d'endurance pour un coup lourd ($heavyCost point(s)).")];
        }
        _spend(heavyCost);
        events.add(const MessageEvent('COUP LOURD !', MessageKind.good));
        final hpBefore = m.hp;
        _attack(player, m, events, power: 1.6);
        if (m.hp < hpBefore) _questStunt(Stunt.heavy, events);
        if (m.alive && rng.chance(hasPerk(Mastery.brawl, 8) ? 0.5 : 0.2)) _applyStatus(m, Status.stun, events);
      case ShoveAction(:final dir):
        final m = monsterAt(player.pos + dir.delta);
        if (m == null || m.disguised) return [const MessageEvent('Personne à repousser par là.')];
        if (stamina < 1) return [const MessageEvent("Pas assez d'endurance pour repousser (1 point).")];
        _spend(1);
        _shove(m, dir, events);
        _train(Mastery.guard, 1, events);
      case ParryAction():
        if (stamina < parryCost) return [MessageEvent("Pas assez d'endurance pour parer ($parryCost point(s)).")];
        _spend(parryCost);
        _parrying = true;
        events.add(const MessageEvent('Vous vous mettez en garde.', MessageKind.good));
      case ShootAction(:final targetId):
        final w = ranged;
        if (w == null) return [const MessageEvent('Aucune arme à distance équipée.')];
        final m = visibleMonster(targetId);
        if (m == null || m.pos.chebyshev(player.pos) > shootRange) {
          return [const MessageEvent('Cible hors de portée ou hors de vue.')];
        }
        final track = w.magic ? Mastery.magic : Mastery.shooting;
        if (w.magic) {
          if (stamina < spellCost) {
            return [MessageEvent("Pas assez d'endurance pour lancer un sort ($spellCost point(s)).")];
          }
          _spend(spellCost);
        } else {
          if (ammoCount <= 0) return [MessageEvent('Plus de munitions (${itemById(w.ammo!).name}).')];
          if (hasPerk(Mastery.shooting, 6) && rng.chance(1 / 3)) {
            events.add(PickupEvent(player.pos, 'munition récupérée'));
          } else {
            _removeOne(itemById(w.ammo!));
          }
        }
        _rangedHit(w.atk + plusOf(w) + playerLevel ~/ 2 + masteryLevel(track) ~/ 3, m, events,
            onHit: w.onHit, chance: w.onHitChance, crit: w.crit);
        _train(track, 1, events);
      case CraftAction(:final recipeId):
        final r = recipeById(recipeId);
        final why = whyNotCraft(r);
        if (why != null) return [MessageEvent(why)];
        _craft(r, events);
      case ThrowAction(:final itemId, :final targetId):
        final inv = _inv(itemId);
        if (inv == null || inv.def.kind != ItemKind.throwable) return const [];
        final d = inv.def;
        final m = visibleMonster(targetId);
        if (m == null || m.pos.chebyshev(player.pos) > throwRange(d)) {
          return [const MessageEvent('Cible hors de portée ou hors de vue.')];
        }
        _removeOne(d);
        final throwBonus = masteryLevel(Mastery.shooting) ~/ 3;
        events.add(MessageEvent('Vous lancez : ${d.name} !'));
        if (d.aoe > 0) {
          final center = m.pos;
          for (final v in List<Actor>.of(monsters)) {
            if (!v.alive || v.disguised || v.pos.chebyshev(center) > d.aoe) continue;
            _rangedHit(d.atk + floor + throwBonus, v, events, onHit: d.onHit, chance: d.onHitChance, sure: true);
          }
          events.add(KamikazeEvent(-1, center, exploded: true));
        } else {
          _rangedHit(d.atk + floor ~/ 2 + throwBonus, m, events, onHit: d.onHit, chance: d.onHitChance);
        }
        _train(Mastery.shooting, 1, events);
      case SkillAction():
        if (!skillReady) return [MessageEvent('${skill.name} : encore $skillCooldown tour(s) de recharge.')];
        final why = _useSkill(events);
        if (why != null) return [MessageEvent(why)];
        skillCooldown = skillCooldownMax;
        skillUses++;
        if (hasPerk(Mastery.charisma, 5)) show.addHype(8);
        _train(Mastery.charisma, 3, events);
        events.add(SkillEvent(skill.id));
        if (skillUses >= 10) _unlock('showstopper', events);
        if (rng.chance(0.3)) _say(MaestroLines.skillUsed, events);
      case DropAction(:final itemId):
        final inv = _inv(itemId);
        if (inv == null) return const [];
        _removeOne(inv.def);
        floorItems.add(FloorItem.item(inv.def, player.pos));
        events.add(MessageEvent('Vous posez ${nameOf(inv.def)}.'));
    }

    _monstersTurn(events);
    _parrying = false;
    _tickStatuses(events);
    turn++;
    if (!_spentStamina && stamina < maxStamina) {
      stamina = (stamina + (action is WaitAction ? 2 : 1)).clamp(0, maxStamina);
    }
    _spentStamina = false;
    if (_fallPending && !gameOver) {
      _fallPending = false;
      _fall(events);
      return events;
    }
    _spotTraps(events);
    if (skillCooldown > 0) skillCooldown--;
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
      final kind = rng.pick(FeatureKind.values.where((k) => k != FeatureKind.npc).toList());
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

  // ================================================================ quêtes

  /// Place éventuellement un PNJ et prépare sa quête.
  void _spawnNpc() {
    if (floor >= finalFloor) return;
    if (floor > 1 && !rng.chance(0.6)) return;
    final p = _randomFreeCell();
    if (p == null || p.manhattan(level.stairs) < 2) return;
    final npc = rng.pick(npcs.where((n) => n.id != _lastNpc).toList());
    final f = Feature(p, FeatureKind.npc);
    final q = Quest(npc, f);
    switch (npc.kind) {
      case QuestKind.cull:
        final counts = <String, int>{};
        for (final m in monsters) {
          if (m.isBoss || m.disguised) continue;
          counts[m.monster!.id] = (counts[m.monster!.id] ?? 0) + 1;
        }
        if (counts.isEmpty) return;
        final best = counts.entries.reduce((a, b) => b.value > a.value ? b : a);
        if (best.value >= 2) {
          q.monsterId = best.key;
          q.goal = best.value.clamp(2, 3 + floor ~/ 5);
        } else {
          q.goal = counts.values.fold(0, (a, b) => a + b).clamp(1, 4);
        }
      case QuestKind.hunt:
        final pool = _themePool().where((d) => !d.boss && d.id != 'mimic').toList();
        final pos = _randomFreeCell();
        if (pool.isEmpty || pos == null) return;
        final def = rng.pick(pool);
        final m = _makeMonster(def, pos)
          ..elite = true
          ..atk += 2
          ..def += 1;
        m.maxHp = (m.maxHp * 1.8).round();
        m.hp = m.maxHp;
        monsters.add(m);
        q
          ..monsterId = def.id
          ..targetId = m.id;
      case QuestKind.fetch:
        Pos? best;
        for (var i = 0; i < 8; i++) {
          final c = _randomFreeCell();
          if (c == null) continue;
          if (best == null || c.manhattan(p) > best.manhattan(p)) best = c;
        }
        if (best == null) return;
        q
          ..itemPos = best
          ..itemName = rng.pick(lostItems);
      case QuestKind.donate:
        q
          ..component = rng.pick(const [Component.scrap, Component.bone, Component.cloth, Component.goo, Component.wood])
          ..goal = 3 + floor ~/ 4;
      case QuestKind.stunt:
        final s = rng.pick(Stunt.values);
        q
          ..stunt = s
          ..goal = switch (s) {
            Stunt.parry => 2 + floor ~/ 6,
            Stunt.heavy => 3 + floor ~/ 5,
            Stunt.rangedKill => 2,
          };
    }
    _lastNpc = npc.id;
    features.add(f);
    quest = q;
  }

  /// Or offert à la fin d'une quête.
  int get questGold => 15 + floor * 5;

  String _questSub(Quest q, String s) {
    final monster = q.monsterId == null ? 'monstres' : '« ${monsterById(q.monsterId!).name} »';
    return s
        .replaceAll('{n}', '${q.goal}')
        .replaceAll('{left}', '${q.goal - q.progress}')
        .replaceAll('{monster}', monster)
        .replaceAll('{item}', q.itemName)
        .replaceAll('{component}', q.component?.label.toLowerCase() ?? '')
        .replaceAll('{stunt}', q.stunt?.label ?? '');
  }

  /// Ligne de suivi de la quête acceptée (null sinon).
  String? get questLine {
    final q = quest;
    if (q == null || !q.accepted || q.rewarded) return null;
    if (q.done) return 'Retournez voir ${q.shortName} pour la récompense.';
    final monster = q.monsterId == null ? 'monstres' : monsterById(q.monsterId!).name;
    return switch (q.npc.kind) {
      QuestKind.cull => 'Éliminer : $monster (${q.progress}/${q.goal})',
      QuestKind.hunt => 'Abattre le $monster étoilé',
      QuestKind.fetch => 'Retrouver ${q.itemName}',
      QuestKind.donate =>
        'Apporter ${q.goal} ${q.component!.label.toLowerCase()} à ${q.shortName} (${materialCount(q.component!)}/${q.goal})',
      QuestKind.stunt => '${_cap(q.stunt!.label)} (${q.progress}/${q.goal})',
    };
  }

  /// Titre, image, texte et choix d'un lieu interactif (dynamiques pour un PNJ).
  String featureTitle(Feature f) => f.kind == FeatureKind.npc ? (quest?.npc.name ?? f.kind.title) : f.kind.title;
  int featureSprite(Feature f) => f.kind == FeatureKind.npc ? (quest?.npc.sprite ?? f.kind.sprite) : f.kind.sprite;
  int? featureTint(Feature f) => f.kind == FeatureKind.npc ? quest?.npc.tint : null;

  String featureText(Feature f) {
    final q = quest;
    if (f.kind != FeatureKind.npc || q == null) return f.kind.text;
    if (!q.accepted) {
      return '${q.npc.intro}\n\n${_questSub(q, q.npc.ask)}\n\nRécompense : $questGold or et ${q.npc.reward.label}.';
    }
    if (q.done) return '${q.shortName} vous attend, les yeux brillants. Mission accomplie : réclamez votre dû.';
    return _questSub(q, q.npc.waiting);
  }

  List<String> featureOptions(Feature f) {
    final q = quest;
    if (f.kind != FeatureKind.npc || q == null) return f.kind.options;
    if (!q.accepted) return const ['Accepter la quête', 'Refuser poliment'];
    if (q.done) return const ['Réclamer la récompense', 'Plus tard'];
    if (q.npc.kind == QuestKind.donate) {
      return ['Donner ${q.goal} ${q.component!.label.toLowerCase()} (vous en avez ${materialCount(q.component!)})', 'Plus tard'];
    }
    return const ["Je m'en occupe"];
  }

  FeatureResult _chooseNpc(Feature f, int index, List<GameEvent> events) {
    final q = quest!;
    var text = '';
    var close = true;
    if (!q.accepted) {
      if (index == 0) {
        q.accepted = true;
        if (q.done) {
          text = 'Vous annoncez que c\'est déjà fait. ${q.shortName} n\'en revient pas.\n\n${_rewardQuest(q, events)}';
        } else {
          text = 'Marché conclu. ${q.shortName} compte sur vous. Le public aussi, mais pour d\'autres raisons.';
          events.add(MessageEvent('Nouvelle quête : ${questLine ?? ''}', MessageKind.good));
        }
      } else {
        text = 'Vous déclinez poliment. ${q.shortName} soupire. Vous pouvez encore changer d\'avis.';
      }
    } else if (q.done) {
      if (index == 0) {
        text = _rewardQuest(q, events);
      } else {
        text = '${q.shortName} patiente. Ne tardez pas trop, l\'étage a une date de démolition.';
      }
    } else if (q.npc.kind == QuestKind.donate && index == 0) {
      final c = q.component!;
      if (materialCount(c) < q.goal) {
        text = 'Il vous manque ${q.goal - materialCount(c)} ${c.label.toLowerCase()}. Démontez des objets ou fouillez.';
        close = false;
      } else {
        materials[c] = materialCount(c) - q.goal;
        q.progress = q.goal;
        text = _rewardQuest(q, events);
      }
    } else {
      text = 'Vous repartez. ${q.shortName} vous fait un signe d\'encouragement.';
    }
    if (close) activeFeature = null;
    show.onEvents(events, turn);
    _checkAchievements(events);
    return FeatureResult(text, events, closed: close);
  }

  /// Remet la récompense ; renvoie le texte de remerciement.
  String _rewardQuest(Quest q, List<GameEvent> events) {
    q.rewarded = true;
    q.feature.used = true;
    questsDone++;
    gold += questGold;
    events.add(PickupEvent(q.feature.pos, '+$questGold or'));
    events.add(GoldEvent(questGold));
    String extra;
    switch (q.npc.reward) {
      case QuestReward.box:
        _gainBox(BoxTier.argent, 'Quête de ${q.shortName}', events);
        extra = 'loot box en argent';
      case QuestReward.bag:
        bagBonus += 2;
        extra = 'sac +2 places';
      case QuestReward.knit:
        baseMaxHp += 4;
        _recalcStats();
        final before = player.hp;
        player.hp = player.maxHp;
        events.add(HealEvent(player.pos, player.hp - before));
        extra = 'PV max +4, soin complet';
      case QuestReward.fame:
        show.addHype(25);
        final it = rollItem(rng, Rarity.rare, floor, allowPotions: false);
        if (!_addToBag(it)) floorItems.add(FloorItem.item(it, player.pos));
        extra = '${nameOf(it)}, hype +25';
      case QuestReward.forge:
        final w = weapon;
        if (w != null && plusOf(w) < maxUpgrade) {
          itemUpgrades[w.id] = plusOf(w) + 1;
          _recalcStats();
          extra = nameOf(w);
        } else {
          materials[Component.crystal] = materialCount(Component.crystal) + 3;
          extra = '3 cristaux';
        }
    }
    show.addHype(10);
    events.add(MessageEvent('QUÊTE ACCOMPLIE : +$questGold or, $extra.', MessageKind.good));
    if (rng.chance(0.5)) {
      events.add(MessageEvent(
          rng.pick(const [
            "Une bonne action ! Le public est perplexe. Ce n'est pas le concept de l'émission.",
            "Aider son prochain. Comme c'est touchant. Et comme c'est mauvais pour l'audimat.",
            "Bravo. Notre service juridique vérifie que les PNJ ont bien signé leur décharge.",
          ]),
          MessageKind.maestro));
    }
    return '${q.npc.thanks}\n\n(+$questGold or, $extra)';
  }

  void _questAdvance(Quest q, List<GameEvent> events) {
    if (q.rewarded || q.done) return;
    q.progress++;
    if (!q.accepted) return;
    if (q.done) {
      events.add(MessageEvent('Objectif de quête atteint ! Retournez voir ${q.shortName}.', MessageKind.good));
      events.add(PickupEvent(player.pos, 'QUÊTE OK'));
      show.addHype(4);
    } else {
      events.add(PickupEvent(player.pos, '${q.progress}/${q.goal}'));
    }
  }

  void _questKill(Actor victim, List<GameEvent> events) {
    final q = quest;
    if (q == null) return;
    switch (q.npc.kind) {
      case QuestKind.cull when q.monsterId == null || q.monsterId == victim.monster!.id:
        _questAdvance(q, events);
      case QuestKind.hunt when victim.id == q.targetId:
        _questAdvance(q, events);
      default:
        break;
    }
  }

  void _questStunt(Stunt s, List<GameEvent> events) {
    final q = quest;
    if (q != null && q.accepted && q.npc.kind == QuestKind.stunt && q.stunt == s) _questAdvance(q, events);
  }

  void _collectQuestItem(List<GameEvent> events) {
    final q = quest;
    if (q == null || q.itemPos != player.pos) return;
    q.itemPos = null;
    events.add(const ItemPickedEvent());
    events.add(MessageEvent(
        q.accepted
            ? 'Vous retrouvez ${q.itemName} ! ${q.shortName} va être ravie.'
            : 'Vous ramassez ${q.itemName}. Ça appartient sûrement à quelqu\'un.',
        MessageKind.good));
    _questAdvance(q, events);
  }

  /// Choix devant un lieu interactif. Le dernier choix (« passer ») ferme sans rien faire.
  FeatureResult chooseFeature(int index) {
    final f = activeFeature;
    if (f == null || index < 0 || index >= featureOptions(f).length) {
      return const FeatureResult('', [], closed: false);
    }
    commands.add('f:$index');
    final events = <GameEvent>[];
    if (f.kind == FeatureKind.npc) return _chooseNpc(f, index, events);
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
    // Les munitions arrivent par paquets.
    final n = d.kind == ItemKind.ammo ? d.stack : 1;
    final existing = _inv(d.id);
    if (existing != null) {
      existing.count += n;
      return true;
    }
    if (bagFull) return false;
    inventory.add(InvItem(d, n));
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
    final previous = switch (d.kind) {
      ItemKind.weapon => weapon,
      ItemKind.ranged => ranged,
      _ => trinket,
    };
    switch (d.kind) {
      case ItemKind.weapon:
        weapon = d;
      case ItemKind.ranged:
        ranged = d;
      default:
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
    player.atk = baseAtk + (w?.atk ?? 0) + (t?.atk ?? 0) + (w == null ? 0 : plusOf(w));
    player.def = baseDef +
        (w?.def ?? 0) +
        (t?.def ?? 0) +
        (t == null ? 0 : plusOf(t)) +
        masteryLevel(Mastery.guard) ~/ 4;
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
      case Effect.bagUp:
        bagBonus += d.bagSlots;
        events.add(MessageEvent('Vous vous équipez : ${d.name}. Le sac fait maintenant $maxSlots places.',
            MessageKind.good));
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
    final old = quest;
    if (old != null && old.accepted && !old.rewarded) {
      events.add(MessageEvent('Quête abandonnée : ${old.shortName} ne vous reverra jamais. Tant pis.'));
    }
    quest = null;
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
    _spawnNpc();
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
    final count = 4 + (floor * 1.3).round() + rng.range(0, 2) + _nextExtraMonsters;
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
      maxHp: (def.hp * (1 + 0.1 * depth) * (def.boss ? 1.2 + 0.02 * floor : 1 + 0.11 * floor)).round(),
      atk: def.atk + depth ~/ 3 + (def.boss ? 2 + floor ~/ 6 : floor ~/ 2 + floor ~/ 7),
      def: def.def + depth ~/ 4,
      monster: def,
    );
  }

  void _spawnLoot() {
    if (rng.chance(0.35)) _place(FloorItem.item(healPotion, const Pos(0, 0)));
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
    _place(FloorItem.item(stones, const Pos(0, 0)));
    if (floor >= 2 && rng.chance(0.45)) _place(FloorItem.item(arrows, const Pos(0, 0)));
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

  void _attack(Actor attacker, Actor target, List<GameEvent> events,
      {double power = 1, bool ranged = false, bool sure = false}) {
    final byPlayer = attacker.isPlayer;
    final r = resolveAttack(
      attacker,
      target,
      rng,
      critChance: byPlayer ? critChance : 0.10,
      multiplier: byPlayer && rageTurns > 0 ? 2 : 1,
      sure: sure,
    );
    // Gêné : les coups font moitié moins mal.
    var damage = (r.damage * power).round();
    if (byPlayer && !ranged && !r.miss) {
      damage += masteryLevel(Mastery.brawl) ~/ 3;
      if (weapon == null && hasPerk(Mastery.brawl, 3)) damage += 2;
    }
    if (!r.miss && attacker.hasStatus(Status.embarrassed)) damage = (damage / 2).ceil();
    events.add(AttackEvent(
      attackerId: attacker.id,
      targetId: target.id,
      from: attacker.pos,
      to: target.pos,
      damage: damage,
      crit: r.crit,
      miss: r.miss,
      ranged: ranged,
    ));
    if (r.miss) {
      events.add(MessageEvent(byPlayer ? 'Vous ratez ${_the(target)}.' : '${_cap(_the(attacker))} vous rate.'));
      return;
    }
    target.hp -= damage;
    if (byPlayer && !ranged) _train(Mastery.brawl, weapon == null ? 2 : 1, events);
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
    _questKill(victim, events);
    if (weapon?.id == 'butter_knife') _butterKills++;
    final e = victim.monster!.feminine ? 'e' : '';
    events.add(MessageEvent('${_cap(_the(victim))} est éliminé$e.', MessageKind.good));
    if (!_firstKillDone) {
      _firstKillDone = true;
      _say(MaestroLines.firstKill, events, monster: victim.name.toLowerCase());
    }
    if (victim.isBoss) {
      _gainMaterial(Component.crystal, 3, victim.pos, events);
    } else if (rng.chance(0.2)) {
      _gainMaterial(dropOf(id), 1, victim.pos, events);
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
    if (crafted >= 5) _unlock('crafter', events);
    if (questsDone >= 1) _unlock('good_deed', events);
    if (questsDone >= 5) _unlock('social_worker', events);
    if (dismantled >= 10) _unlock('recycler', events);
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
      if (_tacticalTurn(m, behavior, sees, events)) continue;

      if (m.pos.isAdjacent4(player.pos)) {
        _monsterMelee(m, events);
        continue;
      }
      m.windup = false;

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

  /// Comportements spéciaux. Vrai si le monstre a agi (sinon : comportement normal).
  bool _tacticalTurn(Actor m, Behavior behavior, bool sees, List<GameEvent> events) {
    final dist = m.pos.chebyshev(player.pos);
    switch (behavior) {
      case Behavior.kamikaze:
        if (m.primed) {
          _explode(m, events);
          return true;
        }
        if (dist <= 1) {
          m.primed = true;
          events.add(KamikazeEvent(m.id, m.pos));
          events.add(MessageEvent('${_cap(_the(m))} gonfle dangereusement !', MessageKind.danger));
          if (rng.chance(0.5)) _say(MaestroLines.kamikaze, events, monster: _the(m));
          return true;
        }
        return false;
      case Behavior.coward:
        return m.hpRatio < 0.4 && _stepAway(m, events);
      case Behavior.ranged:
        if (m.reloading) {
          // Après chaque tir, un tour pour recharger : c'est le moment de foncer.
          m.reloading = false;
          return true;
        }
        if (dist <= 1) return _retreat(m, events);
        if (sees && dist <= m.monster!.range) {
          // Un tir fait un peu moins mal qu'un coup au contact, et la garde le divise encore.
          _attack(m, player, events, ranged: true, power: _parrying ? 0.35 : 0.75);
          m.reloading = true;
          return true;
        }
        return false;
      case Behavior.healer:
        if (_tryHeal(m, events)) return true;
        if (dist <= 1) return _retreat(m, events);
        // Reste en retrait derrière ses alliés.
        return sees && dist <= 3;
      default:
        return false;
    }
  }

  // ================================================================ compétences

  /// Fait progresser la compétence [m] ; annonce les niveaux et les paliers.
  void _train(Mastery m, int amount, List<GameEvent> events) {
    final before = masteryLevel(m);
    if (before >= masteryMax) return;
    masteryXp[m] = masteryXpOf(m) + amount;
    final after = masteryLevel(m);
    if (after == before) return;
    events.add(MasteryUpEvent(m.index, after, m.label));
    events.add(MessageEvent('${m.label} niveau $after ! ${masteryBonusText(m, after)}.', MessageKind.good));
    for (final p in masteryPerks) {
      if (p.mastery == m && p.level > before && p.level <= after) {
        events.add(MessageEvent('Nouveau palier : ${p.text}', MessageKind.good));
      }
    }
    final lines = masteryLines[m]!;
    if (after % 2 == 0 || masteryPerks.any((p) => p.mastery == m && p.level == after)) {
      events.add(MessageEvent(
          lines[after % lines.length].replaceAll('{n}', '$after'), MessageKind.maestro));
    }
    show.addHype(2);
    if (m == Mastery.guard) _recalcStats();
    if (after >= 6) _unlock('specialist', events);
    if (Mastery.values.every((x) => masteryLevel(x) >= 2)) _unlock('jack_of_all', events);
  }

  // ================================================================ artisanat

  void _gainMaterial(Component c, int n, Pos pos, List<GameEvent> events) {
    materials[c] = materialCount(c) + n;
    events.add(PickupEvent(pos, '+$n ${c.label.toLowerCase()}'));
  }

  /// Ce que rapporterait le démontage de [d].
  Map<Component, int> dismantleYield(ItemDef d) => baseYield(d);

  /// Démonte un objet du sac (gratuit, sans tour). Faux si impossible.
  bool dismantle(String itemId) {
    final inv = _inv(itemId);
    if (inv == null || gameOver) return false;
    final yields = dismantleYield(inv.def);
    if (yields.isEmpty) return false;
    commands.add('D:$itemId');
    freeEvents.clear();
    _removeOne(inv.def);
    // Plus aucun exemplaire (ni porté) : l'amélioration disparaît avec l'objet.
    final id = inv.def.id;
    if (_inv(id) == null && weapon?.id != id && trinket?.id != id && ranged?.id != id) itemUpgrades.remove(id);
    final bonusChance = masteryLevel(Mastery.crafting) * 0.08;
    yields.forEach((c, n) {
      final extra = bonusChance > 0 && rng.chance(bonusChance) ? 1 : 0;
      materials[c] = materialCount(c) + n + extra;
      if (extra > 0) freeEvents.add(PickupEvent(player.pos, '+1 ${c.label.toLowerCase()} (bonus)'));
    });
    dismantled++;
    _train(Mastery.crafting, 1, freeEvents);
    _checkAchievements(freeEvents);
    return true;
  }

  /// Équipement visé par une amélioration.
  ItemDef? upgradeTarget(UpgradeSlot slot) => switch (slot) {
        UpgradeSlot.weapon => weapon,
        UpgradeSlot.trinket => trinket,
        UpgradeSlot.ranged => ranged,
      };

  /// Coût réel d'une recette (les améliorations coûtent plus cher à chaque niveau).
  Map<Component, int> recipeCost(Recipe r) {
    final slot = r.upgrade;
    if (slot == null) {
      if (!hasPerk(Mastery.crafting, 7)) return r.inputs;
      return {for (final e in r.inputs.entries) e.key: e.value >= 2 ? e.value - 1 : e.value};
    }
    final target = upgradeTarget(slot);
    final level = target == null ? 0 : plusOf(target);
    final discount = hasPerk(Mastery.crafting, 4) ? 0.75 : 1.0;
    return {for (final e in r.inputs.entries) e.key: (e.value * (level + 1) * discount).ceil()};
  }

  /// Raison pour laquelle on ne peut pas fabriquer [r], ou null si c'est possible.
  String? whyNotCraft(Recipe r) {
    final slot = r.upgrade;
    if (slot != null) {
      final target = upgradeTarget(slot);
      if (target == null) return "Il faut d'abord équiper un objet à améliorer.";
      if (plusOf(target) >= maxUpgrade) return '${target.name} est déjà au maximum (+$maxUpgrade).';
    } else {
      final out = itemById(r.output!);
      if (bagFull && _inv(out.id) == null) return 'Sac plein : faites de la place.';
    }
    for (final e in recipeCost(r).entries) {
      if (materialCount(e.key) < e.value) return 'Il manque : ${e.key.label} (${materialCount(e.key)}/${e.value}).';
    }
    return null;
  }

  void _craft(Recipe r, List<GameEvent> events) {
    recipeCost(r).forEach((c, n) => materials[c] = materialCount(c) - n);
    crafted++;
    _train(Mastery.crafting, 2, events);
    final slot = r.upgrade;
    if (slot != null) {
      final target = upgradeTarget(slot)!;
      itemUpgrades[target.id] = plusOf(target) + 1;
      _recalcStats();
      events.add(PickupEvent(player.pos, '+1'));
      events.add(MessageEvent('Atelier : ${nameOf(target)} !', MessageKind.good));
    } else {
      final out = itemById(r.output!);
      _addToBag(out);
      events.add(PickupEvent(player.pos, '+1'));
      events.add(MessageEvent('Atelier : vous fabriquez ${r.name}.', MessageKind.good));
    }
    if (rng.chance(0.15)) {
      events.add(const MessageEvent("Du fait main ! Le public adore l'artisanat. Moi, je m'endors.",
          MessageKind.maestro));
    }
  }

  /// Recul limité : pas deux tours de suite (sinon on ne peut jamais rattraper un tireur).
  bool _retreat(Actor m, List<GameEvent> events) {
    if (turn - m.lastRetreatTurn < 2) return false;
    if (!_stepAway(m, events)) return false;
    m.lastRetreatTurn = turn;
    return true;
  }

  /// Corps à corps d'un monstre : coup lourd préparé, parade du joueur.
  void _monsterMelee(Actor m, List<GameEvent> events) {
    if (m.monster!.heavy && !m.windup) {
      m.windup = true;
      events.add(MessageEvent('${_cap(_the(m))} prépare un coup lourd ! Écartez-vous ou parez.', MessageKind.danger));
      return;
    }
    final power = m.windup ? 2.5 : 1.0;
    m.windup = false;
    if (_parrying) {
      events.add(AttackEvent(attackerId: m.id, targetId: player.id, from: m.pos, to: player.pos, damage: 0, miss: true));
      events.add(MessageEvent('PARADE ! Vous bloquez ${_the(m)} et ripostez.', MessageKind.good));
      show.addHype(power > 1 ? 6 : 3);
      _train(Mastery.guard, 2, events);
      _questStunt(Stunt.parry, events);
      final strong = hasPerk(Mastery.guard, 6);
      _attack(player, m, events, power: (power > 1 ? 1.0 : 0.6) + (strong ? 0.4 : 0), sure: true);
      if (power > 1 && m.alive) _applyStatus(m, Status.stun, events);
      return;
    }
    _attack(m, player, events, power: power);
  }

  /// Repousse [m] de 2 cases : choc contre un mur ou un autre monstre.
  void _shove(Actor m, Dir dir, List<GameEvent> events) {
    if (m.isBoss) {
      events.add(MessageEvent('${_cap(_the(m))} ne bouge pas d\'un pouce. Inébranlable.'));
      return;
    }
    final start = m.pos;
    for (var i = 0; i < 2; i++) {
      final next = m.pos + dir.delta;
      final other = monsterAt(next);
      if (other != null || !level.walkable(next) || chestAt(next) != null || featureAt(next) != null) {
        final dmg = 3 + floor ~/ 2;
        m.hp -= dmg;
        events.add(StatusDamageEvent(m.id, m.pos, dmg, Status.stun.index));
        if (other != null) {
          other.hp -= dmg;
          events.add(StatusDamageEvent(other.id, other.pos, dmg, Status.stun.index));
          events.add(MessageEvent('${_cap(_the(m))} percute ${_the(other)} !', MessageKind.good));
          if (!other.alive) _kill(other, player, events);
        } else {
          events.add(MessageEvent('${_cap(_the(m))} s\'écrase contre le décor !', MessageKind.good));
        }
        break;
      }
      m.pos = next;
    }
    // Repoussé = déséquilibré : il perd son prochain tour.
    if (m.alive) _applyStatus(m, Status.stun, events);
    if (m.pos != start) events.add(MoveEvent(m.id, start, m.pos));
    m.windup = false;
    show.addHype(3);
    if (!m.alive && monsters.contains(m)) _kill(m, player, events);
  }

  /// Tir ou lancer du joueur sur [target].
  void _rangedHit(int atk, Actor target, List<GameEvent> events,
      {OnHit? onHit, double chance = 0, double crit = 0, bool sure = false}) {
    final hit = sure || rng.chance(0.85);
    var dmg = 0;
    var isCrit = false;
    if (hit) {
      dmg = atk + rng.range(0, (atk / 2).ceil()) - target.def;
      if (dmg < 1) dmg = 1;
      isCrit = rng.chance(critChance + crit);
      if (isCrit) dmg *= 2;
      if (rageTurns > 0) dmg *= 2;
      if (player.hasStatus(Status.embarrassed)) dmg = (dmg / 2).ceil();
    }
    events.add(AttackEvent(
        attackerId: player.id,
        targetId: target.id,
        from: player.pos,
        to: target.pos,
        damage: dmg,
        crit: isCrit,
        miss: !hit,
        ranged: true));
    if (!hit) {
      events.add(MessageEvent('Raté ! ${_cap(_the(target))} esquive.'));
      return;
    }
    target.hp -= dmg;
    if (isCrit) crits++;
    events.add(MessageEvent('Touché : ${_the(target)} ($dmg).${isCrit ? ' CRITIQUE !' : ''}'));
    if (!target.alive) {
      _questStunt(Stunt.rangedKill, events);
      _kill(target, player, events);
      return;
    }
    if (onHit != null && rng.chance(chance)) {
      if (onHit.status != null) _applyStatus(target, onHit.status!, events);
    }
  }

  /// Intention affichée au-dessus d'un monstre (ce qu'il fera si le joueur ne bouge pas).
  MonsterIntent intentOf(Actor m) {
    if (!m.alive || m.disguised || !m.awake) return MonsterIntent.none;
    if (m.hasStatus(Status.stun)) return MonsterIntent.sleep;
    final def = m.monster!;
    final dist = m.pos.chebyshev(player.pos);
    final adjacent = m.pos.isAdjacent4(player.pos);
    if (def.behavior == Behavior.slow && turn.isOdd) return MonsterIntent.sleep;
    switch (def.behavior) {
      case Behavior.kamikaze:
        return m.primed || dist <= 1 ? MonsterIntent.explode : MonsterIntent.none;
      case Behavior.ranged:
        if (m.reloading) return MonsterIntent.reload;
        if (dist <= 1) return turn - m.lastRetreatTurn >= 2 ? MonsterIntent.flee : MonsterIntent.melee;
        return visible.contains(m.pos) && dist <= def.range ? MonsterIntent.shoot : MonsterIntent.none;
      case Behavior.healer:
        final wounded = monsters.any((a) => a.alive && a.hp < a.maxHp && a.pos.chebyshev(m.pos) <= 4);
        if ((m.healTimer + 1) % 3 == 0 && wounded) return MonsterIntent.heal;
        if (dist <= 1) return turn - m.lastRetreatTurn >= 2 ? MonsterIntent.flee : MonsterIntent.melee;
        return MonsterIntent.none;
      case Behavior.coward:
        if (m.hpRatio < 0.4) return MonsterIntent.flee;
      case Behavior.erratic:
        return adjacent ? MonsterIntent.erratic : MonsterIntent.none;
      default:
        break;
    }
    if (!adjacent) return MonsterIntent.none;
    if (m.windup) return MonsterIntent.heavy;
    return def.heavy ? MonsterIntent.prepare : MonsterIntent.melee;
  }

  /// S'éloigne d'une case du joueur si possible.
  bool _stepAway(Actor m, List<GameEvent> events) {
    final now = m.pos.manhattan(player.pos);
    Pos? best;
    var bestD = now;
    for (final p in m.pos.neighbors4) {
      if (!isFree(p)) continue;
      final d = p.manhattan(player.pos);
      if (d > bestD) {
        bestD = d;
        best = p;
      }
    }
    if (best == null) return false;
    events.add(MoveEvent(m.id, m.pos, best));
    m.pos = best;
    return true;
  }

  /// Un soigneur soigne l'allié le plus abîmé à portée, tous les 3 tours.
  bool _tryHeal(Actor healer, List<GameEvent> events) {
    healer.healTimer++;
    if (healer.healTimer % 3 != 0) return false;
    Actor? target;
    for (final a in monsters) {
      if (!a.alive || a.disguised || a.hp >= a.maxHp || a.pos.chebyshev(healer.pos) > 4) continue;
      if (target == null || a.hpRatio < target.hpRatio) target = a;
    }
    if (target == null) return false;
    final amount = (target.maxHp * 0.3).round().clamp(1, target.maxHp - target.hp);
    target.hp += amount;
    events.add(HealEvent(target.pos, amount));
    events.add(MessageEvent('${_cap(_the(healer))} soigne ${_the(target)} (+$amount).'));
    return true;
  }

  /// Explosion d'un kamikaze : blesse tout ce qui est autour, lui compris.
  void _explode(Actor k, List<GameEvent> events) {
    final dmg = k.atk + floor ~/ 2;
    events.add(KamikazeEvent(k.id, k.pos, exploded: true));
    events.add(MessageEvent('BOUM ! ${_cap(_the(k))} explose !', MessageKind.danger));
    final victims = [player, ...monsters].where((a) => a != k && a.alive && a.pos.chebyshev(k.pos) <= 1).toList();
    if (!victims.contains(player)) _unlock('defused', events);
    for (final v in victims) {
      v.hp -= dmg;
      events.add(StatusDamageEvent(v.id, v.pos, dmg, Status.burn.index));
      if (v.alive) continue;
      if (v.isPlayer) {
        _playerDown(_the(k), events, killerName: k.name);
      } else {
        _kill(v, player, events);
      }
    }
    if (k.alive && monsters.contains(k)) {
      k.hp = 0;
      _kill(k, player, events);
    }
  }

  // ================================================================ compétences

  /// Applique la compétence. Renvoie un message d'échec (rien ne se passe) ou null.
  String? _useSkill(List<GameEvent> events) {
    final adjacent = monsters.where((m) => m.pos.isAdjacent4(player.pos) && !m.disguised && m.alive).toList();
    switch (skill.id) {
      case 'haymaker':
        if (adjacent.isEmpty) return 'Personne au contact à frapper. Vous moulinez dans le vide.';
        events.add(const MessageEvent('COUP DE POING DÉSESPÉRÉ !', MessageKind.good));
        for (final m in adjacent) {
          if (m.alive) _attack(player, m, events, power: 1.5);
        }
      case 'night_round':
        for (var y = 0; y < level.height; y++) {
          for (var x = 0; x < level.width; x++) {
            explored.add(Pos(x, y));
          }
        }
        for (final t in traps) {
          t.revealed = true;
        }
        var mimics = 0;
        for (final m in monsters) {
          if (m.disguised) {
            m.disguised = false;
            mimics++;
          }
        }
        events.add(MessageEvent(
            'Ronde de nuit : plan, pièges${mimics > 0 ? ' et $mimics mimique(s)' : ''} repérés.', MessageKind.good));
      case 'live':
        var n = 0;
        for (final m in monsters) {
          if (visible.contains(m.pos) && !m.disguised) {
            _applyStatus(m, Status.embarrassed, events);
            n++;
          }
        }
        show.addHype(15);
        events.add(MessageEvent('LIVE ! $n monstre(s) découvrent qu\'ils sont filmés. Malaise général.',
            MessageKind.good));
      case 'warmup':
        final before = player.hp;
        player.hp = (player.hp + (player.maxHp * 0.2).round()).clamp(0, player.maxHp);
        if (player.hp > before) events.add(HealEvent(player.pos, player.hp - before));
        rageTurns = rageTurns < 4 ? 4 : rageTurns;
        events.add(const MessageEvent('Dix pompes, trois jumping jacks : dégâts doublés 4 tours !', MessageKind.good));
      case 'bribe':
        final cost = 15 + 3 * floor;
        Actor? target;
        for (final m in monsters) {
          if (!visible.contains(m.pos) || m.disguised || m.isBoss) continue;
          if (target == null || m.pos.manhattan(player.pos) < target.pos.manhattan(player.pos)) target = m;
        }
        if (target == null) return 'Aucun monstre en vue à soudoyer.';
        if (gold < cost) return 'Il faut $cost pièces pour soudoyer quelqu\'un. Vous êtes trop pauvre pour être corrompu.';
        gold -= cost;
        monsters.remove(target);
        events.add(PickupEvent(target.pos, '-$cost or'));
        events.add(MessageEvent('${_cap(_the(target))} empoche $cost pièces et quitte le plateau en sifflotant.',
            MessageKind.good));
        _unlock('corruption', events);
      case 'daily_special':
        for (final m in adjacent) {
          _applyStatus(m, Status.poison, events);
        }
        final before = player.hp;
        player.hp = (player.hp + 10).clamp(0, player.maxHp);
        if (player.hp > before) events.add(HealEvent(player.pos, player.hp - before));
        events.add(MessageEvent('Plat du jour servi à ${adjacent.length} convive(s). Personne ne finit son assiette.',
            MessageKind.good));
      case 'roll':
        // Cases accessibles en 3 pas au plus, la plus éloignée des monstres.
        final dist = distanceMap(level.tiles, player.pos, isFree);
        final threats = monsters.where((m) => !m.disguised && m.pos.chebyshev(player.pos) <= 6).toList();
        Pos? best;
        var bestScore = -1;
        for (final e in dist.entries) {
          if (e.value == 0 || e.value > 3) continue;
          final score = threats.isEmpty ? e.value : threats.map((m) => m.pos.manhattan(e.key)).reduce((a, b) => a < b ? a : b);
          if (score > bestScore) {
            bestScore = score;
            best = e.key;
          }
        }
        if (best == null) return 'Pas la place de faire une roulade. Vous faites une petite flexion à la place.';
        events.add(MoveEvent(player.id, player.pos, best));
        player.pos = best;
        _collect(events);
        _checkTrap(events);
        events.add(const MessageEvent('ROULADE ! Le public applaudit la réception. Les monstres, moins.',
            MessageKind.good));
    }
    return null;
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
  static const saveVersion = 7;

  static String _encode(PlayerAction a) => switch (a) {
        MoveAction(:final dir) => 'm${dir.index}',
        WaitAction() => 'w',
        DescendAction() => 'd',
        QuaffAction() => 'q',
        UseItemAction(:final itemId) => 'u:$itemId',
        EquipAction(:final itemId) => 'e:$itemId',
        UnequipAction(:final slot) => 'x:${slot.index}',
        DropAction(:final itemId) => 'r:$itemId',
        SkillAction() => 'k',
        HeavyAction(:final dir) => 'L${dir.index}',
        ShoveAction(:final dir) => 'P${dir.index}',
        ParryAction() => 'y',
        ShootAction(:final targetId) => 's:$targetId',
        ThrowAction(:final itemId, :final targetId) => 'T:$itemId|$targetId',
        CraftAction(:final recipeId) => 'C:$recipeId',
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
      case 'k':
        act(const SkillAction());
      case 'L':
        act(HeavyAction(Dir.values[int.parse(c.substring(1))]));
      case 'P':
        act(ShoveAction(Dir.values[int.parse(c.substring(1))]));
      case 'y':
        act(const ParryAction());
      case 's':
        act(ShootAction(int.parse(arg)));
      case 'T':
        final parts = arg.split('|');
        act(ThrowAction(parts[0], int.parse(parts[1])));
      case 'C':
        act(CraftAction(arg));
      case 'D':
        dismantle(arg);
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
