import 'package:donjon_en_direct/content/items.dart';
import 'package:donjon_en_direct/content/monsters.dart';
import 'package:donjon_en_direct/content/status.dart';
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
  g.floorMod = null;
  return g;
}

Actor _spawn(Game g, String id, Pos p, {int hp = 999, int? atk}) {
  final def = monsterById(id);
  final a = Actor(
      id: 800 + g.monsters.length,
      name: def.name,
      sprite: def.sprite,
      pos: p,
      maxHp: hp,
      atk: atk ?? def.atk,
      def: 0,
      monster: def)
    ..awake = true
    ..lastSeenTarget = g.player.pos;
  g.monsters.add(a);
  return a;
}

Dir _freeDir(Game g) => Dir.all.firstWhere((d) => g.isFree(g.player.pos + d.delta));

/// Une direction où [n] cases libres s'alignent devant le joueur.
Dir? _lineDir(Game g, int n) {
  for (final d in Dir.all) {
    var ok = true;
    for (var i = 1; i <= n; i++) {
      if (!g.isFree(g.player.pos + Pos(d.delta.x * i, d.delta.y * i))) ok = false;
    }
    if (ok) return d;
  }
  return null;
}

Pos _at(Game g, Dir d, int n) => g.player.pos + Pos(d.delta.x * n, d.delta.y * n);

void main() {
  test('départ : lance-pierre et cailloux, endurance pleine', () {
    final g = Game.newRun(1);
    expect(g.ranged?.id, 'slingshot');
    expect(g.ammoCount, 10);
    expect(g.stamina, Game.maxStamina);
  });

  group('Coups', () {
    test("coup lourd : coûte 2 d'endurance et fait plus mal", () {
      var light = 0, heavy = 0;
      for (var seed = 0; seed < 30; seed++) {
        final g1 = _calm(seed), g2 = _calm(seed);
        final d = _freeDir(g1);
        final a = _spawn(g1, 'rat', g1.player.pos + d.delta, atk: 0);
        final b = _spawn(g2, 'rat', g2.player.pos + d.delta, atk: 0);
        g1.act(MoveAction(d));
        g2.act(HeavyAction(d));
        expect(g2.stamina, lessThanOrEqualTo(Game.maxStamina - 2 + 0));
        light += 999 - a.hp;
        heavy += 999 - b.hp;
      }
      expect(heavy, greaterThan(light * 1.4));
    });

    test("sans endurance : pas de coup lourd, pas de tour perdu", () {
      final g = _calm(2);
      final d = _freeDir(g);
      _spawn(g, 'rat', g.player.pos + d.delta);
      g.stamina = 1;
      final t = g.turn;
      final ev = g.act(HeavyAction(d));
      expect(g.turn, t);
      expect(ev.whereType<MessageEvent>().single.text, contains('endurance'));
    });

    test("l'endurance remonte, plus vite en attendant", () {
      final g = _calm(3);
      g.stamina = 0;
      g.act(const WaitAction());
      expect(g.stamina, 2);
      g.act(MoveAction(_freeDir(g)));
      expect(g.stamina, greaterThanOrEqualTo(2));
    });

    test('repousser contre un mur : dégâts et étourdissement', () {
      for (var seed = 0; seed < 40; seed++) {
        final g = _calm(seed);
        // Cherche un mur juste derrière le monstre.
        for (final d in Dir.all) {
          final m1 = g.player.pos + d.delta;
          final behind = m1 + d.delta;
          if (!g.isFree(m1) || g.level.walkable(behind)) continue;
          final rat = _spawn(g, 'rat', m1, hp: 50);
          g.act(ShoveAction(d));
          expect(rat.hp, lessThan(50), reason: 'seed $seed');
          expect(rat.hasStatus(Status.stun), isTrue);
          return;
        }
      }
      fail('aucune configuration mur trouvée');
    });

    test('repousser en terrain libre : le monstre recule de 2 cases', () {
      for (var seed = 0; seed < 40; seed++) {
        final g = _calm(seed);
        final d = _lineDir(g, 3);
        if (d == null) continue;
        final rat = _spawn(g, 'rat', _at(g, d, 1));
        g.act(ShoveAction(d));
        expect(rat.pos, _at(g, d, 3));
        return;
      }
      fail('pas de ligne libre');
    });

    test('parer : le coup est bloqué et le monstre prend une riposte', () {
      final g = _calm(4);
      final d = _freeDir(g);
      final brute = _spawn(g, 'bandit', g.player.pos + d.delta, hp: 200, atk: 50);
      final hp = g.player.hp;
      g.act(const ParryAction());
      expect(g.player.hp, hp);
      expect(brute.hp, lessThan(200));
    });
  });

  group('Distance', () {
    test('tirer consomme une munition et touche une cible à portée', () {
      for (var seed = 0; seed < 40; seed++) {
        final g = _calm(seed);
        final d = _lineDir(g, 3);
        if (d == null) continue;
        final target = _spawn(g, 'rat', _at(g, d, 3), hp: 999);
        final ammo = g.ammoCount;
        for (var i = 0; i < 4; i++) {
          g.act(ShootAction(target.id));
        }
        expect(g.ammoCount, ammo - 4);
        expect(target.hp, lessThan(999));
        return;
      }
      fail('pas de ligne libre');
    });

    test('hors de portée ou sans munitions : refusé sans perdre de tour', () {
      final g = _calm(5);
      final d = _freeDir(g);
      final rat = _spawn(g, 'rat', g.player.pos + d.delta);
      g.inventory.removeWhere((i) => i.def.id == 'stones');
      final t = g.turn;
      final ev = g.act(ShootAction(rat.id));
      expect(g.turn, t);
      expect(ev.whereType<MessageEvent>().single.text, contains('munitions'));
    });

    test("une baguette coûte de l'endurance au lieu de munitions", () {
      final g = _calm(6);
      g.ranged = itemById('wand_fire');
      final d = _freeDir(g);
      final rat = _spawn(g, 'rat', g.player.pos + d.delta);
      g.act(ShootAction(rat.id));
      expect(g.stamina, lessThanOrEqualTo(Game.maxStamina - 2 + 1));
    });

    test('bombe : touche tous les monstres autour de la cible', () {
      for (var seed = 0; seed < 40; seed++) {
        final g = _calm(seed);
        final d = _lineDir(g, 3);
        if (d == null) continue;
        final a = _spawn(g, 'rat', _at(g, d, 3));
        final near = a.pos.neighbors4.where(g.isFree).toList();
        if (near.isEmpty) continue;
        final b = _spawn(g, 'rat', near.first);
        g.inventory.add(InvItem(itemById('bomb')));
        g.act(ThrowAction('bomb', a.id));
        expect(a.hp, lessThan(999));
        expect(b.hp, lessThan(999));
        return;
      }
      fail('pas de configuration');
    });
  });

  group('Monstres', () {
    test("un monstre lourd prépare son coup un tour à l'avance", () {
      final g = _calm(7);
      final d = _freeDir(g);
      final croc = _spawn(g, 'croc', g.player.pos + d.delta, atk: 10);
      expect(g.intentOf(croc), MonsterIntent.prepare);
      final hp = g.player.hp;
      final ev = g.act(const WaitAction());
      expect(g.player.hp, hp, reason: 'premier tour : préparation');
      expect(ev.whereType<MessageEvent>().any((m) => m.text.contains('coup lourd')), isTrue);
      expect(g.intentOf(croc), MonsterIntent.heavy);
    });

    test('un tireur recharge après chaque tir et ne recule pas deux tours de suite', () {
      for (var seed = 0; seed < 40; seed++) {
        final g = _calm(seed);
        final d = _lineDir(g, 3);
        if (d == null) continue;
        final spitter = _spawn(g, 'spitter', _at(g, d, 3));
        g.player.hp = g.player.maxHp = 9999;
        expect(g.intentOf(spitter), MonsterIntent.shoot);
        g.act(const WaitAction());
        expect(spitter.reloading, isTrue);
        expect(g.intentOf(spitter), MonsterIntent.reload);
        // Au contact, il ne peut reculer qu'un tour sur deux.
        spitter
          ..reloading = false
          ..pos = g.player.pos + d.delta;
        g.act(const WaitAction());
        final afterFirst = spitter.pos;
        spitter.pos = g.player.pos + d.delta;
        g.act(const WaitAction());
        expect(afterFirst != g.player.pos + d.delta && spitter.pos == g.player.pos + d.delta, isTrue,
            reason: 'seed $seed : recul limité');
        return;
      }
      fail('pas de ligne libre');
    });
  });

  test('rejeu : les nouvelles actions sont sauvegardées et rejouées', () {
    final g = _calm(8);
    final d = _freeDir(g);
    final rat = _spawn(g, 'rat', g.player.pos + d.delta, hp: 999, atk: 0);
    g.act(HeavyAction(d));
    g.act(const ParryAction());
    g.act(ShootAction(rat.id));
    expect(g.commands.where((c) => c.startsWith('L') || c == 'y' || c.startsWith('s:')).length, 3);
  });
}
