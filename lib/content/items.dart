import '../core/rng.dart';
import 'status.dart';

enum ItemKind { weapon, trinket, consumable }

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
  });

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

  bool get equippable => kind != ItemKind.consumable;

  /// Résumé des bonus, ex. « ATQ +3 · CRIT +10% ».
  String get statLine {
    final parts = <String>[
      if (atk != 0) 'ATQ ${atk > 0 ? '+' : ''}$atk',
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

const allItems = <ItemDef>[...weapons, ...trinkets, healPotion, bandage, confettiBarrel, ...mysteryPotions];

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
