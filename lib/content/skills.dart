/// Compétence active d'un rôle (bouton « POUVOIR »), avec un temps de recharge en tours.
/// Aucune visée : tout est automatique, pensé pour le tactile.
class SkillDef {
  const SkillDef(this.id, this.name, this.desc, this.cooldown);
  final String id;
  final String name;
  final String desc;
  final int cooldown;
}

const skillDefs = <SkillDef>[
  SkillDef('haymaker', 'Coup de poing désespéré',
      'Frappe tous les monstres au contact à 150 % de vos dégâts.', 6),
  SkillDef('night_round', 'Ronde de nuit',
      "Révèle le plan de l'étage, tous les pièges et les mimiques. Le concierge sait tout.", 25),
  SkillDef('live', 'Live sauvage',
      'Tous les monstres en vue sont gênés 5 tours. Hype +15.', 15),
  SkillDef('warmup', 'Échauffement',
      'Soigne 20 % des PV max et dégâts doublés pendant 4 tours.', 40),
  SkillDef('bribe', 'Pot-de-vin',
      "Le monstre en vue le plus proche (hors boss) prend l'argent et quitte l'émission. Coûte 15 + 3 × étage pièces.",
      12),
  SkillDef('daily_special', 'Plat du jour',
      'Empoisonne les monstres au contact et vous rend 10 PV. Recette secrète.', 10),
  SkillDef('roll', 'Roulade',
      "Bondit jusqu'à 3 cases loin des monstres au contact. Les cascadeurs ne fuient pas, ils se repositionnent.", 9),
];

SkillDef skillById(String id) => skillDefs.firstWhere((s) => s.id == id);
