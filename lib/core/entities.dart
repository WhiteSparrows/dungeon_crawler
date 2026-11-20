import '../content/crafting.dart';
import '../content/features.dart';
import '../content/items.dart';
import '../content/monsters.dart';
import '../content/quests.dart';
import '../content/status.dart';
import 'grid.dart';

/// Un être vivant sur la grille : le joueur ou un monstre.
class Actor {
  Actor({
    required this.id,
    required this.name,
    required this.sprite,
    required this.pos,
    required this.maxHp,
    required this.atk,
    required this.def,
    this.monster,
  })  : hp = maxHp,
        disguised = monster?.disguise != null;

  final int id;
  final String name;
  final int sprite;
  Pos pos;
  int hp;
  int maxHp;
  int atk;
  int def;

  /// Définition du monstre (null pour le joueur).
  final MonsterDef? monster;

  /// Le monstre a repéré le joueur.
  bool awake = false;

  /// Monstre déguisé (mimique) : immobile et affiché comme un coffre.
  bool disguised;

  /// Dernière position connue du joueur.
  Pos? lastSeenTarget;

  /// Altérations en cours et tours restants.
  final statuses = <Status, int>{};

  /// Boss enragé (sous la moitié de ses PV).
  bool enraged = false;

  /// Compteur d'invocation des boss.
  int summonTimer = 0;

  /// Monstre vedette (modificateur d'étage) : doré, plus fort, mieux payé.
  bool elite = false;

  /// Kamikaze sur le point d'exploser.
  bool primed = false;

  /// Compteur de soins (soigneurs).
  int healTimer = 0;

  /// Coup lourd en préparation (frappe double au tour suivant si le joueur reste au contact).
  bool windup = false;

  /// Tireur en train de recharger après un tir.
  bool reloading = false;

  /// Dernier tour où ce monstre a reculé (un tireur ne recule pas deux tours de suite).
  int lastRetreatTurn = -10;

  bool hasStatus(Status s) => statuses.containsKey(s);
  bool get isBoss => monster?.boss ?? false;

  bool get isPlayer => monster == null;
  bool get alive => hp > 0;
  double get hpRatio => hp / maxHp;

  /// Sprite à afficher (le déguisement s'il y en a un).
  int get displaySprite => disguised ? (monster?.disguise ?? sprite) : sprite;
}

/// Objet ou tas d'or posé au sol.
class FloorItem {
  FloorItem.item(this.item, this.pos) : gold = 0;
  FloorItem.gold(this.gold, this.pos) : item = null;

  final ItemDef? item;
  final int gold;
  final Pos pos;
}

/// Coffre au trésor : on le frappe pour l'ouvrir et il donne une loot box.
class Chest {
  Chest(this.pos, this.tier);
  final Pos pos;
  final BoxTier tier;
}

/// Lieu interactif (fontaine, autel, distributeur…).
class Feature {
  Feature(this.pos, this.kind, {this.sponsorIndex = 0});
  final Pos pos;
  final FeatureKind kind;

  /// Sponsor honoré par un autel.
  final int sponsorIndex;
  bool used = false;
}

/// Quête d'un PNJ, valable pour l'étage en cours.
class Quest {
  Quest(this.npc, this.feature);
  final NpcDef npc;

  /// Le PNJ sur la carte.
  final Feature feature;
  int goal = 1;
  int progress = 0;
  bool accepted = false;
  bool rewarded = false;

  /// Type de monstre visé (chasse, ménage), ou null pour « n'importe lesquels ».
  String? monsterId;

  /// Identifiant du monstre vedette à abattre.
  int? targetId;

  /// Objet perdu : position sur la carte (null une fois ramassé) et nom.
  Pos? itemPos;
  String itemName = '';
  Component? component;
  Stunt? stunt;

  bool get done => progress >= goal;

  /// Prénom du PNJ (« Raymond »).
  String get shortName => npc.name.split(',').first;
}

/// Piège caché.
class Trap {
  Trap(this.pos, this.kind);
  final Pos pos;
  final TrapKind kind;
  bool revealed = false;
}

/// Pile d'objets dans le sac.
class InvItem {
  InvItem(this.def, [this.count = 1]);
  final ItemDef def;
  int count;
}
