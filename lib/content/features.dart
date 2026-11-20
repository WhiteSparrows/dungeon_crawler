/// Lieux interactifs posés dans les salles : on les « frappe » pour ouvrir un choix.
enum FeatureKind {
  fountain(
    'Fontaine douteuse',
    32,
    "Une fontaine glougloute un liquide verdâtre. Une pancarte indique : « Eau potable (probablement) ». "
        'Des pièces brillent au fond.',
    ['Boire une gorgée', 'Jeter une pièce (5 or)', 'Passer son chemin'],
  ),
  shrine(
    'Autel de sponsor',
    64,
    "Un autel à la gloire de {sponsor}. Des offrandes s'y entassent : de l'or, des coupons de réduction, "
        "et ce qui ressemble à un ancien candidat.",
    ['Prier (coûte 10 % des PV max)', "Voler l'offrande", 'Passer son chemin'],
  ),
  vending(
    'Distributeur automatique',
    63,
    "Un distributeur de la production. Il ronronne. Il sent le caramel et l'électricité statique.",
    ['Acheter une potion de soin (15 or)', 'Secouer la machine', 'Passer son chemin'],
  ),
  mouth(
    'Bouche de la vérité',
    20,
    "Une tête de pierre grimaçante. Une plaque dorée : « Les menteurs y perdent la main. "
        "Les autres y gagnent un cadeau. Statistiquement. »",
    ['Mettre la main dedans', 'Passer son chemin'],
  ),

  /// Personnage non joueur : titre, texte et choix dépendent de sa quête (voir `Game`).
  npc('Personnage', 84, '', []);

  const FeatureKind(this.title, this.sprite, this.text, this.options);
  final String title;
  final int sprite;
  final String text;
  final List<String> options;
}

/// Pièges cachés : invisibles jusqu'à ce qu'on marche dessus ou qu'on les repère.
enum TrapKind {
  spikes('Pics rétractables', 0xFFB0B0C0),
  confetti('Canon à confettis', 0xFFFF7AD0),
  spotlight('Projecteur surchauffé', 0xFFFF9F40),
  trapdoor('Trappe de la régie', 0xFF8B5A2B);

  const TrapKind(this.label, this.color);
  final String label;
  final int color;
}

/// Modificateurs d'étage, annoncés par MAESTRO à l'arrivée.
enum FloorMod {
  blackout('Panne de courant', 'Vision réduite à 3 cases.',
      "Oups. Quelqu'un a marché sur le câble. Vous jouerez cet étage dans le noir. On vous entend paniquer, c'est l'essentiel."),
  happyHour('Happy hour', 'Les monstres commencent gênés.',
      "C'est l'happy hour ! Les monstres ont un peu trop bu. Ils sont gênés, vous en profitez. Personne ne juge."),
  goldRain('Pluie de pièces', "L'étage déborde d'or.",
      "Notre sponsor bancaire a eu un accident de camion blindé dans cet étage. Servez-vous, ils sont assurés."),
  doubleXp('Double XP', "L'expérience gagnée est doublée.",
      "Semaine spéciale : expérience doublée ! Les monstres valent deux fois plus. Leurs familles, toujours rien."),
  starMonster('Monstre vedette', 'Un monstre doré rôde : coriace, mais il porte une loot box.',
      "Ce soir, une star invitée : un monstre doré, plus fort, plus riche, plus arrogant. Abattez-le, il a une loot box sur lui."),
  shortEpisode('Épisode écourté', 'Moins de temps, mais l\'or ramassé vaut 50 % de plus.',
      "Le match de foot déborde : cet épisode sera plus court. En compensation, chaque pièce vaut plus. Courez.");

  const FloorMod(this.label, this.desc, this.announce);
  final String label;
  final String desc;
  final String announce;
}
