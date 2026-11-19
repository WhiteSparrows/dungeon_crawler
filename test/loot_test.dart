import 'package:donjon_en_direct/content/items.dart';
import 'package:donjon_en_direct/content/monsters.dart';
import 'package:donjon_en_direct/core/entities.dart';
import 'package:donjon_en_direct/core/events.dart';
import 'package:donjon_en_direct/core/game.dart';
import 'package:donjon_en_direct/core/grid.dart';
import 'package:flutter_test/flutter_test.dart';

/// Une direction libre autour du joueur (sans monstre, coffre ni mur).
Dir _freeDir(Game g) => Dir.all.firstWhere((d) => g.isFree(g.player.pos + d.delta));

Game _calmGame(int seed) {
  final g = Game.newRun(seed);
  g.monsters.clear();
  g.chests.clear();
  g.floorItems.clear();
  return g;
}

void main() {
  test('départ : couteau à beurre équipé et une potion de soin', () {
    final g = Game.newRun(1);
    expect(g.weapon?.id, 'butter_knife');
    expect(g.player.atk, g.baseAtk + 1);
    expect(g.healPotions, 1);
  });

  test("équiper une arme change l'attaque et remet l'ancienne dans le sac", () {
    final g = _calmGame(2);
    g.inventory.add(InvItem(itemById('guard_sword')));
    g.act(const EquipAction('guard_sword'));
    expect(g.weapon?.id, 'guard_sword');
    expect(g.player.atk, g.baseAtk + 4);
    expect(g.inventory.any((i) => i.def.id == 'butter_knife'), isTrue);
    expect(g.inventory.any((i) => i.def.id == 'guard_sword'), isFalse);
  });

  test('un accessoire augmente les PV max, le retirer les réduit', () {
    final g = _calmGame(3);
    final base = g.player.maxHp;
    g.inventory.add(InvItem(itemById('gym_ring')));
    g.act(const EquipAction('gym_ring'));
    expect(g.player.maxHp, base + 8);
    g.act(const UnequipAction(ItemKind.trinket));
    expect(g.player.maxHp, base);
    expect(g.trinket, isNull);
  });

  test('une fiole mystère est identifiée en la buvant', () {
    final g = _calmGame(4);
    final potion = mysteryPotions.firstWhere((p) => p.effect == Effect.strength);
    g.inventory.add(InvItem(potion));
    expect(g.nameOf(potion), isNot(potion.name));
    final atk = g.player.atk;
    final ev = g.act(UseItemAction(potion.id));
    expect(g.identified, contains(Effect.strength));
    expect(g.nameOf(potion), potion.name);
    expect(g.player.atk, atk + 1);
    expect(ev.whereType<MessageEvent>().any((m) => m.text.contains("C'était")), isTrue);
  });

  test('les aspects des fioles changent selon la graine', () {
    final p = mysteryPotions.first;
    final names = {for (var s = 0; s < 20; s++) Game.newRun(s).nameOf(p)};
    expect(names.length, greaterThan(1));
  });

  test('le poison ne tue jamais', () {
    final g = _calmGame(5);
    final poison = mysteryPotions.firstWhere((p) => p.effect == Effect.poison);
    g.player.hp = 2;
    g.inventory.add(InvItem(poison));
    g.act(UseItemAction(poison.id));
    expect(g.player.hp, 1);
    expect(g.unlocked, contains('poisoned'));
  });

  test('ouvrir une loot box or donne 2 objets et de l\'or', () {
    final g = _calmGame(6);
    g.pendingBoxes.add(BoxTier.or);
    final gold = g.gold;
    final r = g.openBox()!;
    expect(r.items.length, 2);
    expect(r.gold, greaterThan(0));
    expect(g.gold, gold + r.gold);
    expect(g.pendingBoxes, isEmpty);
    expect(g.openBox(), isNull);
  });

  test('frapper un coffre donne une loot box', () {
    final g = _calmGame(7);
    final d = _freeDir(g);
    g.chests.add(Chest(g.player.pos + d.delta, BoxTier.bronze));
    final pos = g.player.pos;
    final ev = g.act(MoveAction(d));
    expect(g.player.pos, pos);
    expect(g.chests, isEmpty);
    expect(g.pendingBoxes, [BoxTier.bronze]);
    expect(ev.whereType<BoxGainedEvent>(), isNotEmpty);
  });

  test('un faux coffre est une mimique qui se révèle', () {
    final g = _calmGame(8);
    final d = _freeDir(g);
    final def = monsterDefs.firstWhere((m) => m.id == 'mimic');
    final mimic = Actor(
        id: 99, name: def.name, sprite: def.sprite, pos: g.player.pos + d.delta, maxHp: 20, atk: 1, def: 0, monster: def);
    g.monsters.add(mimic);
    expect(mimic.disguised, isTrue);
    expect(mimic.displaySprite, def.disguise);
    g.act(MoveAction(d));
    expect(mimic.disguised, isFalse);
    expect(mimic.hp, 20, reason: 'la révélation ne la blesse pas');
  });

  test('premier kill => succès et loot box', () {
    final g = _calmGame(9);
    final d = _freeDir(g);
    final def = monsterDefs.firstWhere((m) => m.id == 'rat');
    final rat = Actor(id: 98, name: def.name, sprite: def.sprite, pos: g.player.pos + d.delta, maxHp: 1, atk: 0, def: 0, monster: def);
    g.monsters.add(rat);
    final events = <GameEvent>[];
    for (var i = 0; i < 20 && rat.alive; i++) {
      events.addAll(g.act(MoveAction(d)));
    }
    expect(rat.alive, isFalse);
    expect(g.unlocked, contains('first_blood'));
    expect(events.whereType<AchievementEvent>().map((e) => e.id), contains('first_blood'));
    expect(g.pendingBoxes, isNotEmpty);
  });

  test('sac plein : les objets restent au sol', () {
    final g = _calmGame(10);
    for (final w in weapons.skip(1).take(Game.maxSlots - g.inventory.length)) {
      g.inventory.add(InvItem(w));
    }
    expect(g.bagFull, isTrue);
    final d = _freeDir(g);
    g.floorItems.add(FloorItem.item(trinkets.first, g.player.pos + d.delta));
    g.act(MoveAction(d));
    expect(g.floorItems.length, 1);
  });
}
