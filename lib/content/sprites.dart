/// Index des tuiles dans assets/sprites/tiny_dungeon.png (Kenney Tiny Dungeon, CC0).
/// Planche de 12 colonnes x 11 lignes, tuiles 16x16 : index = ligne * 12 + colonne.
abstract final class Sprites {
  // Décor : un jeu de sols par « zone » (change tous les 3 étages).
  static const floorSets = [
    [48, 48, 48, 48, 48, 48, 48, 48, 48, 49], // sable
    [0, 0, 0, 0, 1, 12, 24], // terre battue
  ];
  static const wallVariants = [40, 40, 40, 40, 40, 40, 40, 28];
  static const stairsDown = 39;

  // Héros
  static const hero = 85;

  /// L'animateur MAESTRO (mage en robe violette, très cabotin).
  static const maestro = 84;

  // Monstres
  static const rat = 123;
  static const bat = 120;
  static const slime = 108;
  static const spider = 122;
  static const bandit = 112;
  static const crab = 110;
  static const ghost = 121;
  static const cyclops = 109;
  static const mimic = 92;

  // Coffres
  static const chest = 89;
  static const chestOpen = 91;

  // Objets
  static const potionRed = 115;
  static const coin = 102;
  static const tomb = 65;
}
