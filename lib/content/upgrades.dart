/// Contrats permanents négociés avec la production (achetés avec les droits d'auteur).
class UpgradeDef {
  const UpgradeDef(this.id, this.name, this.desc, this.costs);
  final String id;
  final String name;

  /// Effet par niveau.
  final String desc;

  /// Prix de chaque niveau (la longueur donne le niveau max).
  final List<int> costs;

  int get maxLevel => costs.length;
}

const upgradeDefs = <UpgradeDef>[
  UpgradeDef('health', 'Mutuelle « Presque Vivant »', 'PV max +5 par niveau.', [40, 80, 140]),
  UpgradeDef('kit', 'Kit de survie', '+1 potion de soin au départ par niveau.', [50, 110]),
  UpgradeDef('agent', 'Agent artistique', 'Hype de départ +10 par niveau.', [30, 60, 100]),
  UpgradeDef('bonus', 'Prime de signature', '+25 or au départ par niveau.', [30, 60, 90]),
  UpgradeDef('airtime', 'Temps d\'antenne', '+15 tours avant démolition, à chaque étage, par niveau.', [60, 120]),
  UpgradeDef('welcome', 'Cadeau de bienvenue', 'Loot box au départ : Bronze, puis Argent.', [70, 150]),
];

UpgradeDef upgradeById(String id) => upgradeDefs.firstWhere((u) => u.id == id);
