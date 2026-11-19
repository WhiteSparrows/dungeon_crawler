/// Rôle de départ du candidat (débloqué dans la Loge des stars).
class RoleDef {
  const RoleDef({
    required this.id,
    required this.name,
    required this.pitch,
    required this.perks,
    required this.sprite,
    required this.cost,
    this.atk = 0,
    this.def = 0,
    this.maxHp = 0,
    this.gold = 0,
    this.hype = 0,
    this.potions = 0,
    this.talents = const [],
    this.mysteryPotions = 0,
    required this.skill,
  });

  /// Compétence active (voir skills.dart).
  final String skill;

  final String id;
  final String name;

  /// Présentation par MAESTRO.
  final String pitch;

  /// Résumé des effets.
  final String perks;
  final int sprite;

  /// Prix en droits d'auteur.
  final int cost;
  final int atk;
  final int def;
  final int maxHp;
  final int gold;
  final double hype;

  /// Potions de soin en plus (ou en moins) au départ.
  final int potions;

  /// Talents acquis dès le départ.
  final List<String> talents;

  /// Fioles mystère aléatoires au départ.
  final int mysteryPotions;
}

const roleDefs = <RoleDef>[
  RoleDef(
    id: 'lambda',
    skill: 'haymaker',
    name: 'Candidat lambda',
    pitch: "Aucun talent, aucune expérience, aucune chance. Le public adore les outsiders. Brièvement.",
    perks: 'Équilibré. Rien de spécial.',
    sprite: 85,
    cost: 0,
  ),
  RoleDef(
    id: 'concierge',
    skill: 'night_round',
    name: 'Concierge',
    pitch: "Trente ans à surveiller les boîtes aux lettres. Aucun coffre ne lui ment.",
    perks: 'DEF +1 · Flair à mimiques · +1 potion de soin',
    sprite: 86,
    cost: 60,
    def: 1,
    potions: 1,
    talents: ['mimic_sense'],
  ),
  RoleDef(
    id: 'influencer',
    skill: 'live',
    name: 'Influenceuse',
    pitch: "Elle a 4 millions d'abonnés et zéro instinct de survie. Les sponsors se l'arrachent.",
    perks: 'Hype de départ +30 · Ami des sponsors · PV max -5',
    sprite: 99,
    cost: 80,
    maxHp: -5,
    hype: 30,
    talents: ['sponsor_friend'],
  ),
  RoleDef(
    id: 'gym',
    skill: 'warmup',
    name: 'Prof de gym',
    pitch: "Siffle, crie, fait des pompes entre deux meurtres. Allergique aux potions.",
    perks: 'PV max +12 · ATQ +1 · aucune potion de départ',
    sprite: 87,
    cost: 100,
    maxHp: 12,
    atk: 1,
    potions: -1,
  ),
  RoleDef(
    id: 'accountant',
    skill: 'bribe',
    name: 'Comptable',
    pitch: "Il a négocié son contrat de candidat. Il a perdu, mais il a négocié.",
    perks: '+80 or · Négociateur · Pickpocket',
    sprite: 98,
    cost: 120,
    gold: 80,
    talents: ['haggler', 'pickpocket'],
  ),
  RoleDef(
    id: 'chef',
    skill: 'daily_special',
    name: 'Chef de cantine',
    pitch: "Il reconnaît une fiole à l'odeur. Ses gelées l'ont reconnu aussi : elles veulent se venger.",
    perks: 'Nez fin · 2 fioles mystère au départ',
    sprite: 100,
    cost: 120,
    talents: ['nose'],
    mysteryPotions: 2,
  ),
  RoleDef(
    id: 'stuntman',
    skill: 'roll',
    name: 'Cascadeur',
    pitch: "Il est déjà mort onze fois. Il trouve ça surfait.",
    perks: 'Second souffle · Œil de lynx · PV max -5',
    sprite: 96,
    cost: 150,
    maxHp: -5,
    talents: ['second_wind', 'lynx'],
  ),
];

RoleDef roleById(String id) => roleDefs.firstWhere((r) => r.id == id, orElse: () => roleDefs.first);
