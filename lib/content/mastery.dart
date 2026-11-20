/// Compétences qui progressent à l'usage, le temps d'une run.
///
/// Chaque branche gagne de l'expérience quand on s'en sert, monte jusqu'au niveau
/// [masteryMax] et débloque des paliers annoncés par MAESTRO.
enum Mastery {
  brawl('Bagarre', 'Frapper au contact. Deux fois plus vite à mains nues.', 117, 0xFFFF9A6A),
  shooting('Tir', 'Toucher avec une arme à distance ou un objet lancé.', 131, 0xFFE0C080),
  magic('Magie', 'Lancer des sorts avec une baguette ou un grimoire.', 129, 0xFFC890FF),
  guard('Garde', 'Réussir une parade, repousser un monstre.', 102, 0xFF90C0FF),
  crafting('Bricolage', "Démonter des objets, fabriquer à l'atelier.", 74, 0xFFB0B0B8),
  charisma('Charisme', 'Utiliser son pouvoir (bouton POUVOIR).', 130, 0xFFFFD84D);

  const Mastery(this.label, this.howTo, this.sprite, this.tint);
  final String label;

  /// Comment la faire progresser.
  final String howTo;
  final int sprite;
  final int tint;
}

/// Niveau maximal d'une compétence.
const masteryMax = 10;

/// Expérience cumulée nécessaire pour atteindre chaque niveau (index = niveau).
const masteryThresholds = [0, 5, 13, 24, 38, 55, 75, 100, 130, 165, 205];

/// Niveau correspondant à une quantité d'expérience.
int masteryLevelFor(int xp) {
  var lvl = 0;
  while (lvl < masteryMax && xp >= masteryThresholds[lvl + 1]) {
    lvl++;
  }
  return lvl;
}

/// Palier spécial débloqué à un niveau précis.
class MasteryPerk {
  const MasteryPerk(this.mastery, this.level, this.text);
  final Mastery mastery;
  final int level;
  final String text;
}

const masteryPerks = <MasteryPerk>[
  MasteryPerk(Mastery.brawl, 3, 'Coups de poing : +2 dégâts à mains nues.'),
  MasteryPerk(Mastery.brawl, 5, 'Coup lourd à 1 point d\'endurance.'),
  MasteryPerk(Mastery.brawl, 8, 'Le coup lourd étourdit une fois sur deux.'),
  MasteryPerk(Mastery.shooting, 3, 'Portée +1.'),
  MasteryPerk(Mastery.shooting, 6, 'Une munition sur trois est récupérée.'),
  MasteryPerk(Mastery.magic, 4, 'Les sorts ne coûtent plus que 1 point d\'endurance.'),
  MasteryPerk(Mastery.magic, 7, 'Portée des sorts +1.'),
  MasteryPerk(Mastery.guard, 3, 'Parer ne coûte plus que 1 point d\'endurance.'),
  MasteryPerk(Mastery.guard, 6, 'Riposte de parade renforcée.'),
  MasteryPerk(Mastery.crafting, 4, 'Améliorations 25 % moins chères.'),
  MasteryPerk(Mastery.crafting, 7, 'Recettes : 1 composant de moins sur les gros postes.'),
  MasteryPerk(Mastery.charisma, 5, 'Le public adore : +audience à chaque pouvoir.'),
];

/// Bonus permanent (par niveau) de chaque branche, en texte.
String masteryBonusText(Mastery m, int level) => switch (m) {
      Mastery.brawl => 'Dégâts au contact +${level ~/ 3}',
      Mastery.shooting => 'Dégâts à distance +${level ~/ 3}',
      Mastery.magic => 'Dégâts des sorts +${level ~/ 3}',
      Mastery.guard => 'DEF +${level ~/ 4}',
      Mastery.crafting => 'Démontage : +${level * 8} % de chance de bonus',
      Mastery.charisma => 'Recharge du pouvoir -${level * 4} %',
    };

/// Réactions de MAESTRO à une montée de compétence.
const masteryLines = <Mastery, List<String>>{
  Mastery.brawl: [
    "Bagarre niveau {n} ! Votre maman serait fière. Enfin, inquiète. Surtout inquiète.",
    "Bagarre {n} ! Nos assureurs viennent de résilier votre contrat. Par courrier recommandé.",
  ],
  Mastery.shooting: [
    "Tir niveau {n} ! Vous visez enfin ce que vous regardez. Révolutionnaire.",
    "Tir {n} ! Les caméramans demandent une prime de risque.",
  ],
  Mastery.magic: [
    "Magie niveau {n} ! Des étincelles, des flammes, une odeur de sourcils brûlés. Magnifique.",
    "Magie {n} ! Notre département des effets spéciaux est au chômage technique. Merci.",
  ],
  Mastery.guard: [
    "Garde niveau {n} ! Vous bloquez les coups. Le public, lui, voulait voir du sang. Équilibre délicat.",
    "Garde {n} ! Un vrai mur. Un mur qui transpire, mais un mur.",
  ],
  Mastery.crafting: [
    "Bricolage niveau {n} ! Notre émission de déco vous propose un contrat. Posthume, sans doute.",
    "Bricolage {n} ! Vous démontez tout. Ne touchez pas aux caméras, s'il vous plaît.",
  ],
  Mastery.charisma: [
    "Charisme niveau {n} ! Le public scande votre nom. Enfin, un nom. Il ne sait pas lequel.",
    "Charisme {n} ! Votre courbe d'audience a la forme d'un ego. Le vôtre.",
  ],
};
