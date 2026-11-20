import 'package:donjon_en_direct/content/crafting.dart';
import 'package:donjon_en_direct/content/items.dart';
import 'package:donjon_en_direct/content/monsters.dart';
import 'package:donjon_en_direct/core/entities.dart';
import 'package:donjon_en_direct/core/events.dart';
import 'package:donjon_en_direct/core/game.dart';
import 'package:donjon_en_direct/core/grid.dart';
import 'package:flutter_test/flutter_test.dart';

Game _calm(int seed) {
  final g = Game.newRun(seed);
  g.monsters.clear();
  g.chests.clear();
  g.floorItems.clear();
  g.features.clear();
  g.traps.clear();
  g.boss = null;
  return g;
}

void main() {
  test('toutes les recettes produisent un objet existant', () {
    for (final r in recipes) {
      if (r.output != null) itemById(r.output!);
      expect(r.inputs, isNotEmpty);
    }
  });

  group('Démontage', () {
    test('donne des composants, gratuit, sans tour', () {
      final g = _calm(1);
      g.inventory.add(InvItem(itemById('guard_sword')));
      final t = g.turn;
      final y = g.dismantleYield(itemById('guard_sword'));
      expect(y, isNotEmpty);
      expect(g.dismantle('guard_sword'), isTrue);
      expect(g.turn, t);
      expect(g.inventory.any((i) => i.def.id == 'guard_sword'), isFalse);
      y.forEach((c, n) => expect(g.materialCount(c), n));
      expect(g.commands.last, 'D:guard_sword');
    });

    test('un objet rare rapporte plus qu\'un commun', () {
      final g = _calm(2);
      int total(ItemDef d) => g.dismantleYield(d).values.fold(0, (a, b) => a + b);
      expect(total(itemById('lumberjack_axe')), greaterThan(total(itemById('cosplay_sword'))));
    });

    test('les munitions et les objets absents ne se démontent pas', () {
      final g = _calm(3);
      expect(g.dismantle('stones'), isFalse);
      expect(g.dismantle('nimporte_quoi'), isFalse);
    });
  });

  group('Fabrication', () {
    test('sans composants : refusé, aucun tour', () {
      final g = _calm(4);
      final t = g.turn;
      final ev = g.act(const CraftAction('r_bomb'));
      expect(g.turn, t);
      expect(ev.whereType<MessageEvent>().single.text, contains('manque'));
    });

    test('cailloux : 1 ferraille donne 8 cailloux, en un tour', () {
      final g = _calm(5);
      g.materials[Component.scrap] = 1;
      final ammo = g.ammoCount;
      g.act(const CraftAction('r_stones'));
      expect(g.ammoCount, ammo + 8);
      expect(g.materialCount(Component.scrap), 0);
      expect(g.crafted, 1);
    });

    test('bombe fabriquée puis lancée', () {
      final g = _calm(6);
      g.materials[Component.powder] = 2;
      g.materials[Component.scrap] = 1;
      g.act(const CraftAction('r_bomb'));
      expect(g.inventory.any((i) => i.def.id == 'bomb'), isTrue);
    });

    test("affûter l'arme : ATQ +1, coût croissant, maximum +5", () {
      final g = _calm(7);
      final r = recipeById('u_weapon');
      final atk = g.player.atk;
      g.materials[Component.scrap] = 1000;
      g.materials[Component.crystal] = 1000;
      expect(g.recipeCost(r)[Component.scrap], 4);
      g.act(const CraftAction('u_weapon'));
      expect(g.player.atk, atk + 1);
      expect(g.nameOf(g.weapon!), endsWith('+1'));
      expect(g.recipeCost(r)[Component.scrap], 8);
      for (var i = 0; i < 10; i++) {
        g.act(const CraftAction('u_weapon'));
      }
      expect(g.plusOf(g.weapon!), maxUpgrade);
      expect(g.whyNotCraft(r), contains('maximum'));
    });

    test("amélioration sans objet équipé : refusée", () {
      final g = _calm(8);
      g.trinket = null;
      g.materials[Component.crystal] = 10;
      g.materials[Component.scrap] = 10;
      expect(g.whyNotCraft(recipeById('u_trinket')), contains('équiper'));
    });
  });

  test('les monstres lâchent parfois des composants', () {
    var got = 0;
    for (var seed = 0; seed < 30; seed++) {
      final g = _calm(seed);
      final d = Dir.all.firstWhere((d) => g.isFree(g.player.pos + d.delta));
      final def = monsterById('slime');
      final slime = Actor(
          id: 900, name: def.name, sprite: def.sprite, pos: g.player.pos + d.delta, maxHp: 1, atk: 0, def: 0, monster: def);
      g.monsters.add(slime);
      for (var i = 0; i < 10 && slime.alive; i++) {
        g.act(MoveAction(d));
      }
      got += g.materialCount(Component.goo);
    }
    expect(got, greaterThan(3));
  });

  test("rejeu : le démontage d'un objet de départ est reconstruit à l'identique", () {
    final g = Game.newRun(9);
    expect(g.dismantle('heal_potion'), isTrue);
    final loaded = Game.fromSave(g.toSave())!;
    expect(loaded.materialCount(Component.goo), g.materialCount(Component.goo));
    expect(loaded.healPotions, 0);
  });
}
