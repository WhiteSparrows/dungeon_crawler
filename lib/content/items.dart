import '../core/rng.dart';
import 'status.dart';

/// [ranged] : arme à distance (fronde, arc, baguette…), dans son propre emplacement.
/// [ammo] : munitions (empilables). [throwable] : objet qu'on lance sur une cible.
enum ItemKind { weapon, trinket, consumable, ranged, ammo, throwable }

enum Rarity {
  commun('Commun', 0xFFD8D8E0),
  rare('Rare', 0xFF5EC8FF),
  epique('Épique', 0xFFC77DFF),
  legendaire('Légendaire', 0xFFFFC94D);

  const Rarity(this.label, this.color);
  final String label;
  final int color;
}

/// Effets des consommables. Les fioles mystère ont un aspect tiré au hasard à chaque run.
enum Effect {
  heal,
  bigHeal,
  strength,
  toughness,
  poison,
  teleport,
  clairvoyance,
  rage,

  /// Soigne 10 PV et retire toutes les altérations.
  cure,

  /// Blesse et gêne tous les monstres en vue.
  confetti,

  /// Téléporte près de l'escalier.
  remote,

  /// Étourdit les monstres au contact.
  whistle,

  /// Agrandit le sac pour le reste de la run.
  bagUp,
}

class ItemDef {
  const ItemDef({
    required this.id,
    required this.name,
    required this.desc,
    required this.sprite,
    required this.kind,
    this.rarity = Rarity.commun,
    this.atk = 0,
    this.def = 0,
    this.maxHp = 0,
    this.crit = 0,
    this.lifesteal = 0,
    this.effect,
    this.mystery = false,
    this.minFloor = 1,
    this.onHit,
    this.onHitChance = 0,
    this.immune,
    this.range = 0,
    this.ammo,
    this.magic = false,
    this.aoe = 0,
    this.tint,
    this.stack = 1,
    this.bagSlots = 0,
  });

  /// Places de sac gagnées (objets [Effect.bagUp]).
  final int bagSlots;

  /// Portée (armes à distance, objets à lancer).
  final int range;

  /// Munition consommée à chaque tir (id d'objet), null pour la magie.
  final String? ammo;

  /// Arme magique : chaque tir coûte de l'endurance au lieu de munitions.
  final bool magic;

  /// Rayon d'explosion (objets à lancer).
  final int aoe;

  /// Teinte du sprite (variantes de couleur).
  final int? tint;

  /// Quantité trouvée d'un coup (munitions).
  final int stack;

  final String id;
  final String name;
  final String desc;
  final int sprite;
  final ItemKind kind;
  final Rarity rarity;
  final int atk;
  final int def;
  final int maxHp;

  /// Bonus de chance de critique (0.05 = +5 %).
  final double crit;

  /// PV rendus à chaque coup porté.
  final int lifesteal;
  final Effect? effect;

  /// Fiole mystère : nom réel caché tant qu'elle n'est pas identifiée.
  final bool mystery;
  final int minFloor;

  /// Arme : effet appliqué à la cible, avec sa probabilité.
  final OnHit? onHit;
  final double onHitChance;

  /// Accessoire : immunité à une altération.
  final Status? immune;

  bool get equippable => kind == ItemKind.weapon || kind == ItemKind.trinket || kind == ItemKind.ranged;

  /// Résumé des bonus, ex. « ATQ +3 · CRIT +10% ».
  String get statLine {
    final parts = <String>[
      if (kind == ItemKind.ranged || kind == ItemKind.throwable) 'DEGATS $atk · PORTEE $range',
      if (kind == ItemKind.ranged && magic) 'MAGIE : 2 ENDURANCE',
      if (aoe > 0) 'EXPLOSION',
      if (atk != 0 && kind != ItemKind.ranged && kind != ItemKind.throwable) 'ATQ ${atk > 0 ? '+' : ''}$atk',
      if (def != 0) 'DEF ${def > 0 ? '+' : ''}$def',
      if (maxHp != 0) 'PV ${maxHp > 0 ? '+' : ''}$maxHp',
      if (crit != 0) 'CRIT +${(crit * 100).round()}%',
      if (lifesteal != 0) 'VOL DE VIE $lifesteal',
      if (onHit != null) '${onHit!.label.toUpperCase()} ${(onHitChance * 100).round()}%',
      if (immune != null) 'IMMUNISE : ${immune!.short}',
    ];
    return parts.join(' · ');
  }
}

// ------------------------------------------------------------------ Armes

const weapons = <ItemDef>[
  ItemDef(
      id: 'butter_knife',
      name: 'Couteau à beurre',
      desc: "Fourni par la production. Tartine aussi les rats.",
      sprite: 103,
      kind: ItemKind.weapon,
      atk: 1),
  ItemDef(
      id: 'cosplay_sword',
      name: 'Épée de cosplay',
      desc: 'En résine. Fait mal quand même, surtout à la fierté.',
      sprite: 104,
      kind: ItemKind.weapon,
      atk: 2),
  ItemDef(
      id: 'garden_machete',
      name: 'Machette de jardinage',
      desc: 'Taille les haies et les gobelins.',
      sprite: 105,
      kind: ItemKind.weapon,
      atk: 3,
      minFloor: 2),
  ItemDef(
      id: 'intern_staff',
      name: 'Bâton du stagiaire',
      desc: 'Personne ne sait ce qu\'il fait. Lui non plus.',
      sprite: 129,
      kind: ItemKind.weapon,
      rarity: Rarity.rare,
      atk: 2,
      crit: 0.15),
  ItemDef(
      id: 'guard_sword',
      name: 'Épée de vigile',
      desc: 'Vérifie les sacs à l\'entrée, puis les tranche.',
      sprite: 106,
      kind: ItemKind.weapon,
      rarity: Rarity.rare,
      atk: 4,
      minFloor: 2),
  ItemDef(
      id: 'meeting_hammer',
      name: 'Marteau de réunion',
      desc: 'Clôt les débats. Définitivement.',
      sprite: 117,
      kind: ItemKind.weapon,
      rarity: Rarity.rare,
      atk: 4,
      crit: 0.05,
      onHit: OnHit.stun,
      onHitChance: 0.12,
      minFloor: 3),
  ItemDef(
      id: 'lumberjack_axe',
      name: 'Hache de bûcheron',
      desc: 'Odeur de sapin incluse.',
      sprite: 118,
      kind: ItemKind.weapon,
      rarity: Rarity.epique,
      atk: 6,
      minFloor: 3),
  ItemDef(
      id: 'teleshop_scepter',
      name: 'Sceptre de télé-achat',
      desc: 'Mais attendez, ce n\'est pas tout ! Il vole aussi la vie.',
      sprite: 130,
      kind: ItemKind.weapon,
      rarity: Rarity.epique,
      atk: 4,
      lifesteal: 2,
      minFloor: 3),
  ItemDef(
      id: 'parade_spear',
      name: 'Lance de parade',
      desc: 'Brillante, pointue, sponsorisée.',
      sprite: 131,
      kind: ItemKind.weapon,
      rarity: Rarity.epique,
      atk: 5,
      crit: 0.1,
      minFloor: 4),
  ItemDef(
      id: 'flaming_blade',
      name: 'Lame flamboyante',
      desc: 'Interdite dans 47 systèmes solaires. Pas ici.',
      sprite: 107,
      kind: ItemKind.weapon,
      rarity: Rarity.legendaire,
      atk: 8,
      crit: 0.1,
      lifesteal: 1,
      onHit: OnHit.burn,
      onHitChance: 0.3,
      minFloor: 4),
  ItemDef(
      id: 'double_axe',
      name: 'Hache double du finale',
      desc: 'Réservée aux candidats qui font de l\'audience.',
      sprite: 119,
      kind: ItemKind.weapon,
      rarity: Rarity.legendaire,
      atk: 10,
      minFloor: 5),
  ItemDef(
      id: 'venom_dagger',
      name: 'Dague du poissonnier',
      desc: "Elle sent le poisson. Les plaies aussi, et elles s'infectent.",
      sprite: 103,
      kind: ItemKind.weapon,
      rarity: Rarity.rare,
      atk: 2,
      onHit: OnHit.poison,
      onHitChance: 0.35,
      minFloor: 2),
  ItemDef(
      id: 'confetti_staff',
      name: 'Bâton à confettis',
      desc: 'Chaque coup déclenche une pluie de paillettes humiliante.',
      sprite: 129,
      kind: ItemKind.weapon,
      rarity: Rarity.rare,
      atk: 3,
      onHit: OnHit.embarrass,
      onHitChance: 0.3,
      minFloor: 4),
  ItemDef(
      id: 'taser',
      name: 'Matraque de vigile',
      desc: 'Saisie au Centre commercial. Le vigile ne la réclamera pas.',
      sprite: 117,
      kind: ItemKind.weapon,
      rarity: Rarity.epique,
      atk: 5,
      onHit: OnHit.stun,
      onHitChance: 0.25,
      minFloor: 6),
  ItemDef(
      id: 'mic',
      name: 'Micro de présentateur',
      desc: 'Larsen inclus. Les ennemis ne savent plus où se mettre.',
      sprite: 130,
      kind: ItemKind.weapon,
      rarity: Rarity.epique,
      atk: 7,
      onHit: OnHit.embarrass,
      onHitChance: 0.4,
      minFloor: 9),
  ItemDef(
      id: 'stapler',
      name: 'Agrafeuse de la mort',
      desc: "Arme réglementaire de l'Administration. Les agrafes sont rouillées. Exprès.",
      sprite: 131,
      kind: ItemKind.weapon,
      rarity: Rarity.legendaire,
      atk: 9,
      crit: 0.05,
      onHit: OnHit.poison,
      onHitChance: 0.3,
      minFloor: 11),
];

// ------------------------------------------------------------------ Armes à distance et magie

const rangedWeapons = <ItemDef>[
  ItemDef(
      id: 'slingshot',
      name: 'Lance-pierre de récré',
      desc: 'Confisqué en 1998. Toujours aussi efficace sur les rats.',
      sprite: 56,
      kind: ItemKind.ranged,
      atk: 3,
      range: 4,
      ammo: 'stones'),
  ItemDef(
      id: 'bow',
      name: 'Arc de kermesse',
      desc: 'Gagné au chamboule-tout. Les flèches ont une ventouse, mais on a limé les ventouses.',
      sprite: 131,
      tint: 0xFFC08040,
      kind: ItemKind.ranged,
      rarity: Rarity.rare,
      atk: 5,
      range: 5,
      ammo: 'arrows',
      minFloor: 2),
  ItemDef(
      id: 'confetti_cannon',
      name: 'Canon à confettis',
      desc: 'Fait peu de dégâts, mais beaucoup de honte.',
      sprite: 82,
      tint: 0xFFFF90D0,
      kind: ItemKind.ranged,
      rarity: Rarity.rare,
      atk: 3,
      range: 3,
      ammo: 'stones',
      onHit: OnHit.embarrass,
      onHitChance: 0.5,
      minFloor: 3),
  ItemDef(
      id: 'crossbow',
      name: 'Arbalète de vigile',
      desc: 'Homologuée pour la sécurité des galeries marchandes. Par personne.',
      sprite: 131,
      tint: 0xFF9090A0,
      kind: ItemKind.ranged,
      rarity: Rarity.epique,
      atk: 8,
      range: 5,
      ammo: 'arrows',
      onHit: OnHit.stun,
      onHitChance: 0.15,
      minFloor: 5),
  ItemDef(
      id: 'nailgun',
      name: 'Cloueuse de chantier',
      desc: 'Le chef de chantier la cherche. Il cherche aussi ses doigts.',
      sprite: 74,
      tint: 0xFFFFD84D,
      kind: ItemKind.ranged,
      rarity: Rarity.legendaire,
      atk: 11,
      range: 4,
      ammo: 'stones',
      crit: 0.1,
      minFloor: 8),
  ItemDef(
      id: 'wand_fire',
      name: 'Baguette du magicien de goûter',
      desc: "Sortait des lapins. Sort maintenant des boules de feu. Le magicien n'a pas survécu à la transition.",
      sprite: 129,
      kind: ItemKind.ranged,
      rarity: Rarity.rare,
      atk: 4,
      range: 4,
      magic: true,
      onHit: OnHit.burn,
      onHitChance: 0.4,
      minFloor: 2),
  ItemDef(
      id: 'wand_frost',
      name: 'Sceptre de climatisation',
      desc: 'Réglé sur « bureau en août ». Gèle sur place.',
      sprite: 130,
      tint: 0xFFA0E0FF,
      kind: ItemKind.ranged,
      rarity: Rarity.rare,
      atk: 4,
      range: 4,
      magic: true,
      onHit: OnHit.stun,
      onHitChance: 0.3,
      minFloor: 3),
  ItemDef(
      id: 'wand_lightning',
      name: 'Télécommande foudroyante',
      desc: 'Change de chaîne. Et de vie.',
      sprite: 74,
      tint: 0xFF5EC8FF,
      kind: ItemKind.ranged,
      rarity: Rarity.epique,
      atk: 9,
      range: 6,
      magic: true,
      minFloor: 5),
  ItemDef(
      id: 'grimoire',
      name: 'Grimoire des impôts',
      desc: 'Chaque page est une malédiction. Certaines en trois exemplaires.',
      sprite: 75,
      tint: 0xFFC77DFF,
      kind: ItemKind.ranged,
      rarity: Rarity.legendaire,
      atk: 12,
      range: 5,
      magic: true,
      onHit: OnHit.poison,
      onHitChance: 0.4,
      minFloor: 8),
];

// ------------------------------------------------------------------ Munitions et objets à lancer

const stones = ItemDef(
  id: 'stones',
  name: 'Cailloux',
  desc: 'Munitions pour lance-pierre, canon à confettis et cloueuse.',
  sprite: 102,
  tint: 0xFF9A9A9A,
  kind: ItemKind.ammo,
  stack: 8,
);

const arrows = ItemDef(
  id: 'arrows',
  name: 'Flèches',
  desc: 'Munitions pour arcs et arbalètes. Ventouses limées.',
  sprite: 103,
  tint: 0xFFC0A060,
  kind: ItemKind.ammo,
  stack: 5,
  minFloor: 2,
);

const throwables = <ItemDef>[
  ItemDef(
      id: 'throw_knife',
      name: 'Couteau de lancer',
      desc: 'Un couteau. Que vous lancez. Le concept est simple.',
      sprite: 103,
      kind: ItemKind.throwable,
      atk: 7,
      range: 4),
  ItemDef(
      id: 'brick',
      name: 'Brique',
      desc: "Matériau de construction et argument définitif. Étourdit souvent.",
      sprite: 74,
      tint: 0xFFB06040,
      kind: ItemKind.throwable,
      atk: 5,
      range: 3,
      onHit: OnHit.stun,
      onHitChance: 0.5),
  ItemDef(
      id: 'pickle_jar',
      name: 'Bocal de cornichons',
      desc: 'Explose en une pluie de saumure humiliante. Gêne à coup sûr.',
      sprite: 113,
      tint: 0xFF90E060,
      kind: ItemKind.throwable,
      atk: 2,
      range: 4,
      onHit: OnHit.embarrass,
      onHitChance: 1),
  ItemDef(
      id: 'bomb',
      name: 'Bombe artisanale',
      desc: 'Un réveil, de la poudre et beaucoup de scotch. Explose autour de la cible.',
      sprite: 82,
      tint: 0xFF606060,
      kind: ItemKind.throwable,
      rarity: Rarity.rare,
      atk: 12,
      range: 4,
      aoe: 1,
      minFloor: 2),
  ItemDef(
      id: 'hot_sauce',
      name: 'Sauce piquante explosive',
      desc: "Interdite dans les cantines depuis l'incident. Enflamme tout autour de la cible.",
      sprite: 114,
      tint: 0xFFFF4040,
      kind: ItemKind.throwable,
      rarity: Rarity.rare,
      atk: 6,
      range: 4,
      aoe: 1,
      onHit: OnHit.burn,
      onHitChance: 1,
      minFloor: 3),
];

// ------------------------------------------------------------------ Accessoires

const trinkets = <ItemDef>[
  ItemDef(
      id: 'broken_ring',
      name: 'Bague de fiançailles rompues',
      desc: 'Elle a dit non. Vous, vous encaissez mieux.',
      sprite: 101,
      kind: ItemKind.trinket,
      def: 1),
  ItemDef(
      id: 'gym_ring',
      name: 'Anneau de la salle de sport',
      desc: 'Abonnement jamais résilié.',
      sprite: 101,
      kind: ItemKind.trinket,
      maxHp: 8),
  ItemDef(
      id: 'smartwatch',
      name: 'Montre connectée',
      desc: 'Compte vos pas et les points faibles ennemis.',
      sprite: 101,
      kind: ItemKind.trinket,
      rarity: Rarity.rare,
      crit: 0.12),
  ItemDef(
      id: 'bouncer_ring',
      name: 'Chevalière de videur',
      desc: 'Pas de baskets, pas de dégâts.',
      sprite: 101,
      kind: ItemKind.trinket,
      rarity: Rarity.rare,
      def: 2,
      maxHp: 4,
      minFloor: 2),
  ItemDef(
      id: 'vampire_ring',
      name: 'Anneau du producteur',
      desc: 'Se nourrit du travail des autres.',
      sprite: 101,
      kind: ItemKind.trinket,
      rarity: Rarity.epique,
      lifesteal: 2,
      atk: 1,
      minFloor: 3),
  ItemDef(
      id: 'star_ring',
      name: 'Anneau de star',
      desc: 'Les projecteurs vous suivent. Les coups aussi, mais moins fort.',
      sprite: 101,
      kind: ItemKind.trinket,
      rarity: Rarity.legendaire,
      def: 3,
      maxHp: 12,
      crit: 0.05,
      minFloor: 4),
  ItemDef(
      id: 'fireproof',
      name: 'Gourmette ignifugée',
      desc: "Testée sur un cascadeur. Le cascadeur, lui, n'était pas ignifugé.",
      sprite: 101,
      kind: ItemKind.trinket,
      rarity: Rarity.rare,
      def: 1,
      immune: Status.burn,
      minFloor: 3),
  ItemDef(
      id: 'antivenom',
      name: 'Bague anti-venin',
      desc: 'Goût menthe. Les araignées détestent la menthe.',
      sprite: 101,
      kind: ItemKind.trinket,
      rarity: Rarity.rare,
      maxHp: 4,
      immune: Status.poison,
      minFloor: 2),
  ItemDef(
      id: 'thick_skull',
      name: 'Chevalière tête dure',
      desc: 'Rien ne vous sonne. Même pas les mauvaises nouvelles.',
      sprite: 101,
      kind: ItemKind.trinket,
      rarity: Rarity.epique,
      def: 2,
      immune: Status.stun,
      minFloor: 6),
  ItemDef(
      id: 'no_shame',
      name: 'Anneau sans-gêne',
      desc: "Ayez l'air ridicule avec assurance.",
      sprite: 101,
      kind: ItemKind.trinket,
      rarity: Rarity.rare,
      crit: 0.05,
      immune: Status.embarrassed,
      minFloor: 4),
];

// ------------------------------------------------------------------ Consommables

const healPotion = ItemDef(
  id: 'heal_potion',
  name: 'Potion de soin',
  desc: 'Rouge, sucrée, réglementaire. Rend 40 % des PV.',
  sprite: 115,
  kind: ItemKind.consumable,
  effect: Effect.heal,
);

const bandage = ItemDef(
  id: 'bandage',
  name: 'Pansement sponsorisé',
  desc: 'Soigne 10 PV et retire poison, feu, étourdissement et gêne. Logo du sponsor imprimé dessus.',
  sprite: 66,
  kind: ItemKind.consumable,
  effect: Effect.cure,
);

const confettiBarrel = ItemDef(
  id: 'confetti_barrel',
  name: 'Baril de confettis explosifs',
  desc: "Blesse tous les monstres en vue et les met très mal à l'aise.",
  sprite: 82,
  kind: ItemKind.consumable,
  rarity: Rarity.rare,
  effect: Effect.confetti,
  minFloor: 2,
);

const remote = ItemDef(
  id: 'remote',
  name: 'Télécommande de la régie',
  desc: "Zappe directement à côté de l'escalier. Volée au réalisateur, qui la cherche encore.",
  sprite: 74,
  kind: ItemKind.consumable,
  rarity: Rarity.rare,
  effect: Effect.remote,
  minFloor: 2,
);

const whistle = ItemDef(
  id: 'whistle',
  name: "Sifflet d'arbitre",
  desc: 'Un coup de sifflet strident : les monstres au contact sont étourdis 2 tours. Carton rouge.',
  sprite: 56,
  kind: ItemKind.consumable,
  effect: Effect.whistle,
);

const touristPouch = ItemDef(
  id: 'tourist_pouch',
  name: 'Banane de touriste',
  desc: "À porter à la taille, avec fierté et sans goût. +3 places dans le sac pour toute la run.",
  sprite: 66,
  tint: 0xFFFFD84D,
  kind: ItemKind.consumable,
  effect: Effect.bagUp,
  bagSlots: 3,
);

const hikingBag = ItemDef(
  id: 'hiking_bag',
  name: 'Sac de randonnée',
  desc: "Quarante litres, douze poches, une odeur de chaussette. +6 places dans le sac pour toute la run.",
  sprite: 66,
  tint: 0xFF8BE58B,
  kind: ItemKind.consumable,
  rarity: Rarity.rare,
  effect: Effect.bagUp,
  bagSlots: 6,
  minFloor: 3,
);

/// Fioles mystère : leur nom réel n'apparaît qu'une fois identifiées.
const mysteryPotions = <ItemDef>[
  ItemDef(
      id: 'p_bigheal',
      name: 'Élixir de régénération',
      desc: 'Soigne entièrement et augmente les PV max de 2.',
      sprite: 0,
      kind: ItemKind.consumable,
      rarity: Rarity.rare,
      effect: Effect.bigHeal,
      mystery: true),
  ItemDef(
      id: 'p_strength',
      name: 'Potion de force',
      desc: 'ATQ +1 de façon permanente.',
      sprite: 0,
      kind: ItemKind.consumable,
      rarity: Rarity.rare,
      effect: Effect.strength,
      mystery: true),
  ItemDef(
      id: 'p_toughness',
      name: 'Potion de robustesse',
      desc: 'PV max +5 de façon permanente.',
      sprite: 0,
      kind: ItemKind.consumable,
      effect: Effect.toughness,
      mystery: true),
  ItemDef(
      id: 'p_poison',
      name: 'Poison',
      desc: 'Fait perdre un quart de vos PV. Ne tue pas. Presque.',
      sprite: 0,
      kind: ItemKind.consumable,
      effect: Effect.poison,
      mystery: true),
  ItemDef(
      id: 'p_teleport',
      name: 'Potion de téléportation',
      desc: "Vous envoie n'importe où sur l'étage.",
      sprite: 0,
      kind: ItemKind.consumable,
      effect: Effect.teleport,
      mystery: true),
  ItemDef(
      id: 'p_clairvoyance',
      name: 'Potion de clairvoyance',
      desc: "Révèle le plan de l'étage.",
      sprite: 0,
      kind: ItemKind.consumable,
      effect: Effect.clairvoyance,
      mystery: true),
  ItemDef(
      id: 'p_rage',
      name: 'Potion de rage',
      desc: 'Dégâts doublés pendant 12 tours.',
      sprite: 0,
      kind: ItemKind.consumable,
      rarity: Rarity.rare,
      effect: Effect.rage,
      mystery: true),
];

/// Aspects possibles des fioles mystère (nom + sprite), mélangés à chaque run.
const potionLooks = <(String, int)>[
  ('Fiole trouble', 113),
  ('Mixture fluo', 114),
  ('Sirop bleu suspect', 116),
  ('Flacon tiède', 125),
  ('Jus de cave', 126),
  ('Boisson énergisante entamée', 127),
  ('Élixir pétillant', 128),
];

const allItems = <ItemDef>[
  ...weapons,
  ...rangedWeapons,
  stones,
  arrows,
  ...throwables,
  ...trinkets,
  healPotion,
  bandage,
  confettiBarrel,
  remote,
  whistle,
  touristPouch,
  hikingBag,
  ...mysteryPotions,
];

ItemDef itemById(String id) => allItems.firstWhere((i) => i.id == id);

// ------------------------------------------------------------------ Loot boxes

enum BoxTier {
  bronze('Bronze', 0xFFCD7F32, 1, [70, 27, 3, 0], 5),
  argent('Argent', 0xFFC8D0DC, 2, [45, 42, 12, 1], 15),
  or('Or', 0xFFFFC94D, 2, [10, 45, 38, 7], 35),
  legendaire('Légendaire', 0xFFC77DFF, 3, [0, 20, 50, 30], 80);

  const BoxTier(this.label, this.color, this.items, this.rarityWeights, this.gold);
  final String label;
  final int color;
  final int items;

  /// Poids de tirage pour commun / rare / épique / légendaire.
  final List<int> rarityWeights;

  /// Or de base contenu dans la boîte (multiplié par l'étage).
  final int gold;
}

/// Tire un objet de rareté [rarity] (ou inférieure si aucun) adapté à l'étage.
ItemDef rollItem(Rng rng, Rarity rarity, int floor, {bool allowPotions = true}) {
  for (var r = rarity.index; r >= 0; r--) {
    final pool = allItems
        .where((i) =>
            i.rarity.index == r &&
            i.minFloor <= floor + 1 &&
            i.id != 'butter_knife' &&
            (allowPotions || i.kind != ItemKind.consumable))
        .toList();
    if (pool.isNotEmpty) return rng.pick(pool);
  }
  return healPotion;
}

Rarity rollRarity(Rng rng, List<int> weights) {
  final idx = rng.weighted([0, 1, 2, 3], (i) => weights[i]);
  return Rarity.values[idx];
}
