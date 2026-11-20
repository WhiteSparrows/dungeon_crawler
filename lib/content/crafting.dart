import 'items.dart';

/// Composant d'artisanat (matériau). Rangé dans la bourse : il ne prend pas de place dans le sac.
enum Component {
  scrap('Ferraille', 74, 0xFFB0B0B8),
  wood('Bois', 63, 0xFFC08040),
  cloth('Tissu', 66, 0xFFE0C0A0),
  bone('Os', 64, 0xFFF0F0E0),
  goo('Gelée', 108, 0xFF80F080),
  powder('Poudre', 82, 0xFF707070),
  crystal('Cristal', 101, 0xFF80D0FF),
  circuit('Circuit imprimé', 60, 0xFF60E0A0);

  const Component(this.label, this.sprite, this.tint);
  final String label;
  final int sprite;
  final int tint;
}

/// Ce que donne le démontage d'un objet (quantités de base, avant la rareté).
Map<Component, int> baseYield(ItemDef d) {
  final r = d.rarity.index + 1; // commun x1 … légendaire x4
  switch (d.kind) {
    case ItemKind.weapon:
      final wooden = d.sprite == 129 || d.sprite == 130 || d.sprite == 131;
      return {
        Component.scrap: wooden ? (r + 1) ~/ 2 : r,
        if (wooden) Component.wood: r,
        if (d.rarity.index >= 2) Component.crystal: d.rarity.index - 1,
      };
    case ItemKind.ranged:
      return {
        if (d.magic) Component.crystal: r else Component.wood: r,
        Component.scrap: 1,
        if (d.magic && d.rarity.index >= 2) Component.circuit: 1,
      };
    case ItemKind.trinket:
      return {Component.crystal: r, Component.scrap: 1};
    case ItemKind.throwable:
      return {if (d.aoe > 0) Component.powder: 2 else Component.scrap: 1};
    case ItemKind.consumable:
      if (d.id == 'bandage') return {Component.cloth: 1, Component.goo: 1};
      if (d.id == 'remote') return {Component.circuit: 2};
      if (d.id == 'whistle') return {Component.scrap: 1};
      if (d.bagSlots > 0) return {Component.cloth: d.bagSlots ~/ 2 + 1};
      if (d.id == 'confetti_barrel') return {Component.powder: 2, Component.cloth: 1};
      return {Component.goo: 1};
    case ItemKind.ammo:
      return const {};
  }
}

/// Matériau que lâchent parfois les monstres.
Component dropOf(String monsterId) => switch (monsterId) {
      'rat' || 'gasbag' || 'croc' || 'boss_ratking' => Component.bone,
      'slime' || 'spitter' || 'medic' || 'makeup' => Component.goo,
      'bat' || 'firebat' || 'spider' || 'clown' || 'mascot' || 'fan' => Component.cloth,
      'bandit' || 'carny' || 'shopper' || 'juggler' || 'paparazzi' => Component.wood,
      'drone' || 'printer' || 'cameraman' || 'promoter' => Component.circuit,
      'ghost' || 'lightghost' || 'stamp' => Component.crystal,
      'intern' || 'archivist' || 'clerk' => Component.powder,
      _ => Component.scrap,
    };

/// Amélioration d'un équipement porté.
enum UpgradeSlot { weapon, trinket, ranged }

/// Recette d'atelier : produit un objet, ou améliore un équipement porté.
class Recipe {
  const Recipe(this.id, this.name, this.inputs, {this.output, this.qty = 1, this.upgrade, this.desc = ''});
  final String id;
  final String name;
  final Map<Component, int> inputs;

  /// Objet produit (id), ou null pour une amélioration.
  final String? output;
  final int qty;
  final UpgradeSlot? upgrade;
  final String desc;
}

/// Niveau d'amélioration maximal d'un équipement.
const maxUpgrade = 5;

const recipes = <Recipe>[
  Recipe('r_stones', 'Cailloux x8', {Component.scrap: 1}, output: 'stones'),
  Recipe('r_arrows', 'Flèches x5', {Component.wood: 1, Component.bone: 1}, output: 'arrows'),
  Recipe('r_potion', 'Potion de soin', {Component.goo: 3, Component.crystal: 1}, output: 'heal_potion'),
  Recipe('r_bandage', 'Pansement sponsorisé', {Component.cloth: 2, Component.goo: 1}, output: 'bandage'),
  Recipe('r_knife', 'Couteau de lancer', {Component.scrap: 2}, output: 'throw_knife'),
  Recipe('r_brick', 'Brique', {Component.scrap: 1, Component.bone: 1}, output: 'brick'),
  Recipe('r_jar', 'Bocal de cornichons', {Component.goo: 1, Component.cloth: 1}, output: 'pickle_jar'),
  Recipe('r_bomb', 'Bombe artisanale', {Component.powder: 2, Component.scrap: 1}, output: 'bomb'),
  Recipe('r_sauce', 'Sauce piquante explosive', {Component.goo: 1, Component.powder: 1}, output: 'hot_sauce'),
  Recipe('r_whistle', "Sifflet d'arbitre", {Component.scrap: 1, Component.bone: 1}, output: 'whistle'),
  Recipe('r_barrel', 'Baril de confettis explosifs', {Component.powder: 2, Component.cloth: 2}, output: 'confetti_barrel'),
  Recipe('r_remote', 'Télécommande de la régie', {Component.circuit: 2, Component.crystal: 1}, output: 'remote'),
  Recipe('r_pouch', 'Banane de touriste', {Component.cloth: 4, Component.scrap: 1}, output: 'tourist_pouch'),
  Recipe('r_hiking', 'Sac de randonnée', {Component.cloth: 6, Component.wood: 2, Component.scrap: 2},
      output: 'hiking_bag'),
  Recipe('u_weapon', "Affûter l'arme", {Component.scrap: 4, Component.crystal: 1},
      upgrade: UpgradeSlot.weapon, desc: 'ATQ +1 sur l\'arme portée (cumulable).'),
  Recipe('u_trinket', "Renforcer l'accessoire", {Component.crystal: 3, Component.scrap: 2},
      upgrade: UpgradeSlot.trinket, desc: 'DEF +1 sur l\'accessoire porté (cumulable).'),
  Recipe('u_ranged', "Calibrer l'arme à distance", {Component.wood: 3, Component.scrap: 2},
      upgrade: UpgradeSlot.ranged, desc: 'Dégâts +1 sur l\'arme à distance portée (cumulable).'),
];

Recipe recipeById(String id) => recipes.firstWhere((r) => r.id == id);
