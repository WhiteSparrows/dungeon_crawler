import 'package:donjon_en_direct/content/crafting.dart';
import 'package:donjon_en_direct/content/items.dart';
import 'package:donjon_en_direct/content/mastery.dart';
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

/// Place un sac de frappe inoffensif à côté du joueur et renvoie la direction.
(Actor, Dir) _dummy(Game g, {int hp = 999}) {
  final d = Dir.all.firstWhere((d) => g.isFree(g.player.pos + d.delta));
  final def = monsterById('slime');
  final m = Actor(
      id: 900, name: def.name, sprite: def.sprite, pos: g.player.pos + d.delta, maxHp: hp, atk: 0, def: 0, monster: def);
  g.monsters.add(m);
  return (m, d);
}

void main() {
  test('paliers d\'expérience', () {
    expect(masteryLevelFor(0), 0);
    expect(masteryLevelFor(masteryThresholds[1] - 1), 0);
    expect(masteryLevelFor(masteryThresholds[1]), 1);
    expect(masteryLevelFor(masteryThresholds[masteryMax] - 1), masteryMax - 1);
    expect(masteryLevelFor(masteryThresholds[masteryMax]), masteryMax);
    expect(masteryLevelFor(9999), masteryMax);
    expect(masteryThresholds, hasLength(masteryMax + 1));
  });

  test('chaque palier est atteignable', () {
    for (final p in masteryPerks) {
      expect(p.level, inInclusiveRange(1, masteryMax));
    }
  });

  test('les coups de poing entraînent la Bagarre deux fois plus vite', () {
    final g = _calm(1);
    g.act(const UnequipAction(ItemKind.weapon));
    expect(g.weapon, isNull);
    final (m, d) = _dummy(g);
    var hits = 0;
    for (var i = 0; i < 6; i++) {
      final ev = g.act(MoveAction(d));
      hits += ev.whereType<AttackEvent>().where((e) => e.attackerId == g.player.id && !e.miss).length;
    }
    expect(m.alive, isTrue);
    expect(hits, greaterThan(0));
    expect(g.masteryXpOf(Mastery.brawl), 2 * hits);
  });

  test('montée de niveau : événement, message et palier annoncé', () {
    final g = _calm(2);
    g.masteryXp[Mastery.brawl] = masteryThresholds[3] - 1;
    final (_, d) = _dummy(g);
    final events = <GameEvent>[];
    for (var i = 0; i < 10 && g.masteryLevel(Mastery.brawl) < 3; i++) {
      events.addAll(g.act(MoveAction(d)));
    }
    expect(g.masteryLevel(Mastery.brawl), 3);
    expect(events.whereType<MasteryUpEvent>().single.level, 3);
    expect(events.whereType<MessageEvent>().map((e) => e.text), contains(contains('palier')));
  });

  test('paliers : coûts réduits', () {
    final g = _calm(3);
    expect(g.heavyCost, 2);
    expect(g.parryCost, 2);
    expect(g.spellCost, 2);
    g.masteryXp[Mastery.brawl] = masteryThresholds[5];
    g.masteryXp[Mastery.guard] = masteryThresholds[3];
    g.masteryXp[Mastery.magic] = masteryThresholds[4];
    expect(g.heavyCost, 1);
    expect(g.parryCost, 1);
    expect(g.spellCost, 1);

    final r = recipeById('u_weapon');
    expect(g.recipeCost(r)[Component.scrap], 4);
    g.masteryXp[Mastery.crafting] = masteryThresholds[4];
    expect(g.recipeCost(r)[Component.scrap], 3);
    g.masteryXp[Mastery.crafting] = masteryThresholds[7];
    expect(g.recipeCost(recipeById('r_bomb'))[Component.powder], 1);
  });

  test('le charisme raccourcit la recharge du pouvoir', () {
    final g = _calm(4);
    final base = g.skillCooldownMax;
    g.masteryXp[Mastery.charisma] = masteryThresholds[masteryMax];
    expect(g.skillCooldownMax, lessThan(base));
  });

  test('le Bricolage progresse en démontant et en fabriquant', () {
    final g = _calm(5);
    g.inventory.add(InvItem(itemById('guard_sword')));
    expect(g.dismantle('guard_sword'), isTrue);
    expect(g.masteryXpOf(Mastery.crafting), 1);
    g.materials[Component.scrap] = 1;
    g.act(const CraftAction('r_stones'));
    expect(g.masteryXpOf(Mastery.crafting), 3);
  });

  test('rejeu : progression et démontages bonus reconstruits à l\'identique', () {
    final g = Game.newRun(6);
    expect(g.dismantle('heal_potion'), isTrue);
    for (var i = 0; i < 4; i++) {
      g.act(const ParryAction());
      g.act(const WaitAction());
    }
    final loaded = Game.fromSave(g.toSave())!;
    for (final m in Mastery.values) {
      expect(loaded.masteryXpOf(m), g.masteryXpOf(m), reason: m.label);
    }
    expect(loaded.materials, g.materials);
  });
}
