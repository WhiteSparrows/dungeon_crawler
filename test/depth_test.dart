import 'package:donjon_en_direct/content/items.dart';
import 'package:donjon_en_direct/content/monsters.dart';
import 'package:donjon_en_direct/content/status.dart';
import 'package:donjon_en_direct/content/themes.dart';
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
  g.boss = null;
  return g;
}

Dir _freeDir(Game g) => Dir.all.firstWhere((d) => g.isFree(g.player.pos + d.delta));

Actor _spawn(Game g, String id, Pos p, {int? hp}) {
  final def = monsterById(id);
  final a = Actor(id: 900 + g.monsters.length, name: def.name, sprite: def.sprite, pos: p, maxHp: hp ?? def.hp,
      atk: def.atk, def: def.def, monster: def);
  g.monsters.add(a);
  return a;
}

/// Va à l'étage [floor] en passant par les coulisses.
void _goTo(Game g, int floor) {
  while (g.floor < floor) {
    g.boss = null;
    g.monsters.clear();
    g.player.pos = g.level.stairs;
    g.act(const DescendAction());
    g.leaveBackstage();
  }
}

void main() {
  group('Contenu', () {
    test('35 monstres réguliers et 5 boss, tous utilisés par une zone', () {
      final regular = monsterDefs.where((m) => !m.boss).toList();
      final bosses = monsterDefs.where((m) => m.boss).toList();
      expect(regular.length, 35);
      expect(bosses.length, 5);
      final used = {for (final t in themeDefs) ...t.monsters, for (final t in themeDefs) t.boss};
      for (final m in monsterDefs) {
        expect(used, contains(m.id), reason: '${m.id} jamais utilisé');
      }
    });

    test('au moins 35 objets', () => expect(allItems.length, greaterThanOrEqualTo(35)));

    test('zones : une tous les 3 étages', () {
      expect(themeFor(1).name, contains('Égouts'));
      expect(themeFor(4).name, contains('Parc'));
      expect(themeFor(15).boss, 'boss_director');
      expect(isBossFloor(3), isTrue);
      expect(isBossFloor(4), isFalse);
    });
  });

  group('Altérations', () {
    test('le poison blesse chaque tour puis disparaît', () {
      final g = _calm(1);
      g.player.statuses[Status.poison] = 3;
      final hp = g.player.hp;
      final ev = g.act(const WaitAction());
      expect(ev.whereType<StatusDamageEvent>(), isNotEmpty);
      expect(g.player.hp, lessThan(hp));
      g.act(const WaitAction());
      g.act(const WaitAction());
      expect(g.player.hasStatus(Status.poison), isFalse);
    });

    test('étourdi : le joueur ne peut pas bouger ce tour', () {
      final g = _calm(2);
      g.player.statuses[Status.stun] = 1;
      final pos = g.player.pos;
      g.act(MoveAction(_freeDir(g)));
      expect(g.player.pos, pos);
      expect(g.player.hasStatus(Status.stun), isFalse);
    });

    test('gêné : les coups font moitié moins mal', () {
      var normal = 0, shy = 0;
      for (var seed = 0; seed < 40; seed++) {
        for (final shame in [false, true]) {
          final g = _calm(seed);
          final d = _freeDir(g);
          final dummy = _spawn(g, 'rat', g.player.pos + d.delta, hp: 999);
          if (shame) g.player.statuses[Status.embarrassed] = 99;
          for (var i = 0; i < 5; i++) {
            g.act(MoveAction(d));
          }
          final dealt = 999 - dummy.hp;
          if (shame) {
            shy += dealt;
          } else {
            normal += dealt;
          }
        }
      }
      expect(shy, lessThan(normal * 0.7));
    });

    test('la potion de soin retire poison et feu ; le pansement retire tout', () {
      final g = _calm(3);
      g.player.statuses.addAll({Status.poison: 5, Status.burn: 5, Status.embarrassed: 5});
      g.act(const QuaffAction());
      expect(g.player.hasStatus(Status.poison), isFalse);
      expect(g.player.hasStatus(Status.burn), isFalse);
      expect(g.player.hasStatus(Status.embarrassed), isTrue);
      g.inventory.add(InvItem(bandage));
      g.act(const UseItemAction('bandage'));
      expect(g.player.statuses, isEmpty);
    });

    test("bague d'immunité : pas de poison", () {
      final g = _calm(4);
      g.trinket = itemById('antivenom');
      final d = _freeDir(g);
      final spider = _spawn(g, 'stamp', g.player.pos + d.delta);
      spider.awake = true;
      g.player.hp = g.player.maxHp = 9999;
      for (var i = 0; i < 40; i++) {
        g.act(const WaitAction());
      }
      expect(g.player.hasStatus(Status.poison), isFalse);
    });
  });

  group('Zones et boss', () {
    test("les monstres d'un étage viennent de sa zone", () {
      final g = Game.newRun(5);
      _goTo(g, 4);
      final allowed = {...themeFor(4).monsters};
      expect(g.monsters, isNotEmpty);
      for (final m in g.monsters) {
        expect(allowed, contains(m.monster!.id));
      }
    });

    test("étage 3 : un boss garde l'escalier et le verrouille", () {
      final g = Game.newRun(6);
      _goTo(g, 3);
      expect(g.boss, isNotNull);
      expect(g.boss!.monster!.id, 'boss_ratking');
      expect(g.bossAlive, isTrue);
      g.player.pos = g.level.stairs;
      final ev = g.act(const DescendAction());
      expect(g.backstage, isNull);
      expect(ev.whereType<MessageEvent>().first.text, contains('verrouillée'));
      g.boss!.hp = 0;
      g.monsters.remove(g.boss);
      expect(g.bossAlive, isFalse);
      g.act(const DescendAction());
      expect(g.backstage, isNotNull);
    });

    test('le boss invoque des renforts', () {
      final g = Game.newRun(7);
      _goTo(g, 3);
      g.monsters.removeWhere((m) => !m.isBoss);
      final b = g.boss!
        ..awake = true
        ..lastSeenTarget = g.player.pos;
      g.player.hp = g.player.maxHp = 9999;
      for (var i = 0; i < 12; i++) {
        g.act(const WaitAction());
      }
      expect(g.monsters.where((m) => !m.isBoss).length, greaterThan(0));
      expect(b.alive, isTrue);
    });

    test('vaincre le boss final gagne la saison', () {
      final g = Game.newRun(8);
      _goTo(g, finalFloor);
      final b = g.boss!;
      expect(b.monster!.id, 'boss_director');
      g.monsters.removeWhere((m) => m != b);
      final d = _freeDir(g);
      b.pos = g.player.pos + d.delta;
      b.hp = 1;
      final events = <GameEvent>[];
      for (var i = 0; i < 30 && b.alive; i++) {
        events.addAll(g.act(MoveAction(d)));
      }
      expect(g.victory, isTrue);
      expect(g.gameOver, isTrue);
      expect(events.whereType<VictoryEvent>(), isNotEmpty);
      expect(g.unlocked, containsAll(['boss_slayer', 'season_win']));
    });

    test('un boss enragé tape plus fort', () {
      final g = Game.newRun(9);
      _goTo(g, 6);
      final b = g.boss!;
      final atk = b.atk;
      g.monsters.removeWhere((m) => m != b);
      final d = _freeDir(g);
      b.pos = g.player.pos + d.delta;
      b.hp = b.maxHp ~/ 2 + 1;
      for (var i = 0; i < 20 && !b.enraged && b.alive; i++) {
        g.player.hp = g.player.maxHp;
        g.act(MoveAction(d));
      }
      expect(b.enraged, isTrue);
      expect(b.atk, greaterThan(atk));
    });
  });
}
