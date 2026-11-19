/// Talents passifs choisis en coulisses (un parmi trois, chacun une seule fois).
class TalentDef {
  const TalentDef(this.id, this.name, this.desc);
  final String id;
  final String name;
  final String desc;
}

const talentDefs = <TalentDef>[
  TalentDef('thick_skin', 'Peau de cuir', 'DEF +1.'),
  TalentDef('big_arms', 'Gros bras', 'ATQ +2.'),
  TalentDef('cardio', 'Cardio', 'PV max +10.'),
  TalentDef('lynx', 'Œil de lynx', 'Chance de critique +8 %.'),
  TalentDef('vampire', 'Petit vampire', 'Vol de vie +1 à chaque coup.'),
  TalentDef('regen', 'Régénération', 'Récupère 1 PV tous les 4 tours (au lieu de 7).'),
  TalentDef('pickpocket', 'Pickpocket', 'Or ramassé +50 %.'),
  TalentDef('crowd_fav', 'Chouchou du public', "L'audience s'ennuie deux fois moins vite."),
  TalentDef('showman', 'Bête de scène', 'Les éliminations font 50 % de hype en plus.'),
  TalentDef('nose', 'Nez fin', 'Les fioles mystère sont identifiées dès qu\'on les ramasse.'),
  TalentDef('haggler', 'Négociateur', 'Boutique des coulisses -25 %.'),
  TalentDef('light_foot', 'Pied léger', '+25 tours avant la démolition de chaque étage.'),
  TalentDef('second_wind', 'Second souffle', 'Une fois par étage, survit à un coup fatal avec 1 PV.'),
  TalentDef('sponsor_friend', 'Ami des sponsors', 'Les sponsors sont satisfaits 30 % plus vite.'),
  TalentDef('mimic_sense', 'Flair à mimiques', 'Les mimiques déguisées sont signalées.'),
];

TalentDef talentById(String id) => talentDefs.firstWhere((t) => t.id == id);
