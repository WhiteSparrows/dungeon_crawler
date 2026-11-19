import '../content/items.dart';
import '../content/monsters.dart';
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

/// Pile d'objets dans le sac.
class InvItem {
  InvItem(this.def, [this.count = 1]);
  final ItemDef def;
  int count;
}
