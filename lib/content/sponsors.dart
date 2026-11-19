/// Ce qui fait plaisir à un sponsor.
enum Taste {
  kills('Aime le sang'),
  potions('Aime quand vous buvez'),
  lowHp('Aime quand vous êtes à l\'agonie'),
  exploration('Aime l\'exploration'),
  gold('Aime l\'argent'),
  speed('Aime la vitesse'),
  loot('Aime le shopping'),
  achievements('Aime les exploits');

  const Taste(this.label);
  final String label;
}

class SponsorDef {
  const SponsorDef(this.id, this.name, this.slogan, this.taste, this.color);
  final String id;
  final String name;
  final String slogan;
  final Taste taste;
  final int color;
}

const sponsorDefs = <SponsorDef>[
  SponsorDef('kraak', 'Boissons KRAAK', 'Le goût du risque. Et du caramel.', Taste.potions, 0xFF60E060),
  SponsorDef('mortsubite', 'Assurances Mort-Subite', 'On couvre tout. Sauf vous.', Taste.lowHp, 0xFF8090FF),
  SponsorDef('zorg', 'Boucherie Galactique Zorg', 'Viande de toutes origines. Vraiment toutes.', Taste.kills, 0xFFFF6060),
  SponsorDef('taudis', 'Immobilier Taudis & Fils', 'Chaque recoin est une opportunité.', Taste.exploration, 0xFFE0B060),
  SponsorDef('lunaire', 'Crédit Lunaire', 'Votre argent, notre gravité.', Taste.gold, 0xFFFFD84D),
  SponsorDef('chronos', 'Chronos Express', 'Livré avant même votre mort.', Taste.speed, 0xFF5EC8FF),
  SponsorDef('collec', 'Club des Collectionneurs', 'Tout. Il nous faut TOUT.', Taste.loot, 0xFFC77DFF),
  SponsorDef('ouieouie', 'Plateforme Ouïe-Ouïe', 'Le streaming qui vous écoute.', Taste.achievements, 0xFFFF9F40),
];

SponsorDef sponsorById(String id) => sponsorDefs.firstWhere((s) => s.id == id);
