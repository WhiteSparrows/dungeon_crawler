/// Zone du donjon (3 étages chacune) : décor, monstres et boss.
class ThemeDef {
  const ThemeDef({
    required this.name,
    required this.intro,
    required this.floorSet,
    required this.floorTint,
    required this.wallTint,
    required this.monsters,
    required this.boss,
  });

  final String name;

  /// Annonce de MAESTRO à l'arrivée dans la zone.
  final String intro;
  final List<int> floorSet;
  final int floorTint;
  final int wallTint;
  final List<String> monsters;
  final String boss;
}

const _sand = [48, 48, 48, 48, 48, 48, 48, 48, 48, 49];
const _dirt = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 24];

const themeDefs = <ThemeDef>[
  ThemeDef(
    name: 'Les Égouts',
    intro: "Bienvenue dans les Égouts ! Respirez par la bouche. Ou ne respirez pas, ça nous arrange.",
    floorSet: _dirt,
    floorTint: 0xFFB8D0A8,
    wallTint: 0xFFB0C8B0,
    monsters: ['rat', 'bat', 'slime', 'spider', 'croc', 'bandit', 'spitter', 'gasbag', 'mimic'],
    boss: 'boss_ratking',
  ),
  ThemeDef(
    name: "Le Parc d'attractions abandonné",
    intro: "Zone 2 : le Parc d'attractions ! Fermé depuis l'accident. Les clowns, eux, n'ont jamais quitté leur poste.",
    floorSet: _sand,
    floorTint: 0xFFFFD0E0,
    wallTint: 0xFFE0C8FF,
    monsters: ['clown', 'mascot', 'carny', 'firebat', 'ghost', 'juggler', 'medic', 'mimic'],
    boss: 'boss_clown',
  ),
  ThemeDef(
    name: 'Le Centre commercial',
    intro: "Zone 3 : le Centre commercial ! Soldes monstres, au sens propre. Gardez votre ticket de caisse.",
    floorSet: _sand,
    floorTint: 0xFFE8EEFF,
    wallTint: 0xFFFFFFFF,
    monsters: ['guard', 'crab', 'shopper', 'mannequin', 'cyclops', 'promoter', 'drone', 'mimic'],
    boss: 'boss_guard',
  ),
  ThemeDef(
    name: 'Le Plateau télé',
    intro: "Zone 4 : nos propres studios ! Faites attention au matériel. Il coûte plus cher que vous.",
    floorSet: _dirt,
    floorTint: 0xFFA898D8,
    wallTint: 0xFF9888C0,
    monsters: ['cameraman', 'fan', 'stuntdouble', 'lightghost', 'paparazzi', 'makeup', 'mimic'],
    boss: 'boss_host',
  ),
  ThemeDef(
    name: "L'Administration infernale",
    intro: "Dernière zone : l'Administration. Formulaire B-666 en trois exemplaires. Votre mort sera traitée sous 6 à 8 semaines.",
    floorSet: _dirt,
    floorTint: 0xFFD89080,
    wallTint: 0xFFD0A0A0,
    monsters: ['clerk', 'stamp', 'printer', 'auditor', 'archivist', 'intern', 'mimic'],
    boss: 'boss_director',
  ),
];

/// Dernier étage : la saison se gagne en battant le boss de l'étage 15.
const finalFloor = 15;

ThemeDef themeFor(int floor) => themeDefs[((floor - 1) ~/ 3).clamp(0, themeDefs.length - 1)];

bool isBossFloor(int floor) => floor % 3 == 0;
