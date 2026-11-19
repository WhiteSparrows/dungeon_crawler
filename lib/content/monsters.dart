import 'sprites.dart';
import 'status.dart';

/// Comportement de déplacement d'un monstre.
enum Behavior {
  /// Fonce sur le joueur dès qu'il l'a repéré.
  chaser,

  /// Se déplace au hasard une fois sur deux.
  erratic,

  /// N'agit qu'un tour sur deux.
  slow,
}

class MonsterDef {
  const MonsterDef({
    required this.id,
    required this.name,
    required this.sprite,
    required this.hp,
    required this.atk,
    this.def = 0,
    required this.xp,
    this.behavior = Behavior.chaser,
    required this.minFloor,
    this.weight = 10,
    this.disguise,
    this.tint,
    this.feminine = false,
    this.onHit,
    this.onHitChance = 0,
    this.boss = false,
    this.summon,
    this.summonEvery = 0,
    this.enrage = false,
  });

  final String id;
  final String name;
  final int sprite;
  final int hp;
  final int atk;
  final int def;
  final int xp;
  final Behavior behavior;
  final int minFloor;
  final int weight;

  /// Sprite affiché tant que le monstre est déguisé (mimique = coffre).
  final int? disguise;

  /// Teinte appliquée au sprite (variantes de couleur).
  final int? tint;

  /// Pour accorder les messages (« éliminée », « la »).
  final bool feminine;

  /// Effet de ses coups, et sa probabilité.
  final OnHit? onHit;
  final double onHitChance;

  /// Boss de fin de zone : plus gros, verrouille l'escalier.
  final bool boss;

  /// Monstre invoqué régulièrement (boss).
  final String? summon;
  final int summonEvery;

  /// Devient enragé (ATQ +50 %) sous la moitié de ses PV.
  final bool enrage;

  /// Nom précédé de l'article défini : « le rat… », « la gelée… », « l'araignée… ».
  String get theName {
    final lower = name[0].toLowerCase() + name.substring(1);
    if ('aeiouyéèêh'.contains(lower[0])) return "l'$lower";
    return '${feminine ? 'la' : 'le'} $lower';
  }
}

const monsterDefs = <MonsterDef>[
  // ---------------------------------------------------------------- Égouts (1-3)
  MonsterDef(id: 'rat', name: "Rat d'égout syndiqué", sprite: Sprites.rat, hp: 6, atk: 2, xp: 2, minFloor: 1, weight: 14),
  MonsterDef(
      id: 'bat',
      name: 'Chauve-souris sous caféine',
      sprite: Sprites.bat,
      hp: 5,
      atk: 2,
      xp: 2,
      behavior: Behavior.erratic,
      minFloor: 1,
      feminine: true),
  MonsterDef(
      id: 'slime',
      name: 'Gelée de cantine',
      sprite: Sprites.slime,
      hp: 13,
      atk: 4,
      xp: 4,
      behavior: Behavior.slow,
      minFloor: 1,
      weight: 8,
      feminine: true),
  MonsterDef(
      id: 'spider',
      name: 'Araignée influenceuse',
      sprite: Sprites.spider,
      hp: 9,
      atk: 4,
      def: 1,
      xp: 5,
      minFloor: 2,
      feminine: true,
      onHit: OnHit.poison,
      onHitChance: 0.25),
  MonsterDef(
      id: 'croc',
      name: "Alligator de chasse d'eau",
      sprite: 124,
      hp: 16,
      atk: 5,
      def: 1,
      xp: 7,
      minFloor: 2,
      weight: 6),
  MonsterDef(id: 'bandit', name: 'Pillard en tongs', sprite: Sprites.bandit, hp: 15, atk: 5, def: 1, xp: 7, minFloor: 3),
  MonsterDef(
      id: 'mimic',
      name: 'Mimique',
      sprite: Sprites.mimic,
      hp: 20,
      atk: 6,
      def: 1,
      xp: 12,
      minFloor: 2,
      weight: 4,
      disguise: Sprites.chest,
      feminine: true),

  // ---------------------------------------------------------------- Parc d'attractions (4-6)
  MonsterDef(
      id: 'clown',
      name: 'Clown dépressif',
      sprite: 88,
      tint: 0xFFFFB0B0,
      hp: 18,
      atk: 6,
      def: 1,
      xp: 9,
      minFloor: 4,
      onHit: OnHit.embarrass,
      onHitChance: 0.3),
  MonsterDef(
      id: 'mascot',
      name: 'Mascotte enragée',
      sprite: 87,
      tint: 0xFFFFE080,
      hp: 26,
      atk: 7,
      def: 2,
      xp: 11,
      minFloor: 4,
      feminine: true),
  MonsterDef(
      id: 'carny',
      name: 'Forain arnaqueur',
      sprite: Sprites.bandit,
      tint: 0xFFFFA060,
      hp: 16,
      atk: 6,
      def: 1,
      xp: 9,
      minFloor: 4,
      onHit: OnHit.steal,
      onHitChance: 0.4),
  MonsterDef(
      id: 'firebat',
      name: 'Chauve-souris pyrotechnique',
      sprite: Sprites.bat,
      tint: 0xFFFF7050,
      hp: 12,
      atk: 6,
      xp: 8,
      behavior: Behavior.erratic,
      minFloor: 4,
      feminine: true,
      onHit: OnHit.burn,
      onHitChance: 0.3),
  MonsterDef(
      id: 'ghost',
      name: "Fantôme d'un stagiaire",
      sprite: Sprites.ghost,
      hp: 14,
      atk: 8,
      xp: 10,
      behavior: Behavior.erratic,
      minFloor: 5),

  // ---------------------------------------------------------------- Centre commercial (7-9)
  MonsterDef(
      id: 'guard',
      name: 'Vigile de galerie',
      sprite: 97,
      hp: 30,
      atk: 9,
      def: 3,
      xp: 14,
      minFloor: 7,
      onHit: OnHit.stun,
      onHitChance: 0.2),
  MonsterDef(
      id: 'crab', name: 'Crabe agent de sécurité', sprite: Sprites.crab, hp: 28, atk: 8, def: 5, xp: 13, minFloor: 7, weight: 8),
  MonsterDef(
      id: 'shopper',
      name: 'Acheteur compulsif',
      sprite: 98,
      tint: 0xFFB0FFB0,
      hp: 22,
      atk: 9,
      def: 1,
      xp: 12,
      behavior: Behavior.erratic,
      minFloor: 7,
      onHit: OnHit.steal,
      onHitChance: 0.3),
  MonsterDef(
      id: 'mannequin',
      name: 'Mannequin de vitrine',
      sprite: 86,
      tint: 0xFFE0E0FF,
      hp: 40,
      atk: 11,
      def: 4,
      xp: 15,
      behavior: Behavior.slow,
      minFloor: 7),
  MonsterDef(
      id: 'cyclops', name: 'Cyclope videur', sprite: Sprites.cyclops, hp: 44, atk: 12, def: 3, xp: 18, minFloor: 8, weight: 6),

  // ---------------------------------------------------------------- Plateau télé (10-12)
  MonsterDef(
      id: 'cameraman',
      name: 'Cameraman zombie',
      sprite: 86,
      tint: 0xFF90FF90,
      hp: 38,
      atk: 12,
      def: 3,
      xp: 18,
      minFloor: 10,
      onHit: OnHit.embarrass,
      onHitChance: 0.3),
  MonsterDef(
      id: 'fan',
      name: 'Fan hystérique',
      sprite: 99,
      tint: 0xFFFF90D0,
      hp: 30,
      atk: 13,
      def: 2,
      xp: 18,
      behavior: Behavior.erratic,
      minFloor: 10,
      onHit: OnHit.embarrass,
      onHitChance: 0.35),
  MonsterDef(
      id: 'stuntdouble',
      name: 'Doublure cascade',
      sprite: 96,
      tint: 0xFFFFC080,
      hp: 46,
      atk: 15,
      def: 4,
      xp: 22,
      minFloor: 10,
      feminine: true),
  MonsterDef(
      id: 'lightghost',
      name: 'Spectre du projecteur',
      sprite: Sprites.ghost,
      tint: 0xFFFFFF80,
      hp: 34,
      atk: 14,
      def: 2,
      xp: 20,
      behavior: Behavior.erratic,
      minFloor: 11,
      onHit: OnHit.burn,
      onHitChance: 0.35),

  // ---------------------------------------------------------------- Administration infernale (13-15)
  MonsterDef(
      id: 'clerk',
      name: 'Fonctionnaire infernal',
      sprite: 100,
      hp: 55,
      atk: 16,
      def: 5,
      xp: 26,
      behavior: Behavior.slow,
      minFloor: 13,
      onHit: OnHit.stun,
      onHitChance: 0.3),
  MonsterDef(
      id: 'stamp',
      name: 'Démon tamponneur',
      sprite: 111,
      hp: 50,
      atk: 18,
      def: 4,
      xp: 26,
      minFloor: 13,
      onHit: OnHit.poison,
      onHitChance: 0.3),
  MonsterDef(
      id: 'printer',
      name: 'Photocopieuse possédée',
      sprite: Sprites.crab,
      tint: 0xFFB0B0B0,
      hp: 60,
      atk: 17,
      def: 7,
      xp: 28,
      behavior: Behavior.slow,
      minFloor: 13,
      feminine: true,
      onHit: OnHit.burn,
      onHitChance: 0.3),
  MonsterDef(
      id: 'auditor',
      name: 'Contrôleur fiscal',
      sprite: Sprites.cyclops,
      tint: 0xFFC090FF,
      hp: 66,
      atk: 19,
      def: 5,
      xp: 30,
      minFloor: 14,
      onHit: OnHit.steal,
      onHitChance: 0.4),

  // ---------------------------------------------------------------- Boss (un par zone)
  MonsterDef(
      id: 'boss_ratking',
      name: 'Roi Rat Syndical',
      sprite: Sprites.rat,
      tint: 0xFFFFD84D,
      hp: 55,
      atk: 6,
      def: 2,
      xp: 40,
      minFloor: 3,
      weight: 0,
      boss: true,
      summon: 'rat',
      summonEvery: 5),
  MonsterDef(
      id: 'boss_clown',
      name: 'Bobo, clown pyromane',
      sprite: 88,
      tint: 0xFFFF6060,
      hp: 95,
      atk: 10,
      def: 3,
      xp: 70,
      minFloor: 6,
      weight: 0,
      boss: true,
      onHit: OnHit.burn,
      onHitChance: 0.35,
      enrage: true),
  MonsterDef(
      id: 'boss_guard',
      name: 'Vigile Suprême',
      sprite: 97,
      tint: 0xFFFFD84D,
      hp: 150,
      atk: 14,
      def: 5,
      xp: 100,
      minFloor: 9,
      weight: 0,
      boss: true,
      onHit: OnHit.stun,
      onHitChance: 0.25,
      summon: 'guard',
      summonEvery: 7),
  MonsterDef(
      id: 'boss_host',
      name: 'Présentatrice rivale',
      sprite: 99,
      tint: 0xFFC77DFF,
      hp: 220,
      atk: 17,
      def: 5,
      xp: 140,
      minFloor: 12,
      weight: 0,
      boss: true,
      feminine: true,
      onHit: OnHit.embarrass,
      onHitChance: 0.5,
      summon: 'cameraman',
      summonEvery: 5),
  MonsterDef(
      id: 'boss_director',
      name: 'Directeur des Programmes',
      sprite: 111,
      tint: 0xFFFF4040,
      hp: 300,
      atk: 21,
      def: 7,
      xp: 200,
      minFloor: 15,
      weight: 0,
      boss: true,
      onHit: OnHit.poison,
      onHitChance: 0.35,
      summon: 'clerk',
      summonEvery: 4,
      enrage: true),
];

MonsterDef monsterById(String id) => monsterDefs.firstWhere((m) => m.id == id);
