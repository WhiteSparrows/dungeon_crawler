import 'package:donjon_en_direct/content/monsters.dart';
import 'package:donjon_en_direct/core/combat.dart';
import 'package:donjon_en_direct/core/dungeon_gen.dart';
import 'package:donjon_en_direct/core/entities.dart';
import 'package:donjon_en_direct/core/events.dart';
import 'package:donjon_en_direct/core/fov.dart';
import 'package:donjon_en_direct/core/game.dart';
import 'package:donjon_en_direct/core/grid.dart';
import 'package:donjon_en_direct/core/pathfinding.dart';
import 'package:donjon_en_direct/core/rng.dart';
import 'package:flutter_test/flutter_test.dart';

String _dump(Level l) {
  final b = StringBuffer();
  for (var y = 0; y < l.height; y++) {
    for (var x = 0; x < l.width; x++) {
      b.write(l.tiles.get(x, y).index);
    }
  }
  return b.toString();
}

void main() {
  group('Génération', () {
    test('même graine => même étage', () {
      final a = DungeonGenerator(Rng(42)).generate();
      final b = DungeonGenerator(Rng(42)).generate();
      expect(_dump(a), _dump(b));
      expect(a.stairs, b.stairs);
    });

    test('graines différentes => étages différents', () {
      final a = DungeonGenerator(Rng(1)).generate();
      final b = DungeonGenerator(Rng(2)).generate();
      expect(_dump(a), isNot(_dump(b)));
    });

    test('étage connexe et escalier atteignable (200 graines)', () {
      for (var seed = 0; seed < 200; seed++) {
        final l = DungeonGenerator(Rng(seed)).generate(floor: 1 + seed % 10);
        expect(l.rooms.length, greaterThanOrEqualTo(4), reason: 'seed $seed');
        expect(l.tiles[l.stairs], Tile.stairsDown);
        final dist = distanceMap(l.tiles, l.start, (p) => l.tiles[p].walkable);
        var walkable = 0;
        for (var y = 0; y < l.height; y++) {
          for (var x = 0; x < l.width; x++) {
            if (l.tiles.get(x, y).walkable) walkable++;
          }
        }
        expect(dist.length, walkable, reason: 'zones isolées, seed $seed');
        expect(dist.containsKey(l.stairs), isTrue);
        expect(l.start, isNot(l.stairs));
      }
    });
  });

  group('Pathfinding', () {
    test('contourne un mur', () {
      final g = Grid<Tile>(5, 5, Tile.floor);
      for (var y = 0; y < 4; y++) {
        g.set(2, y, Tile.wall);
      }
      final path = findPath(g, const Pos(0, 0), const Pos(4, 0), (p) => g[p].walkable)!;
      expect(path.last, const Pos(4, 0));
      expect(path.length, 12);
      expect(path.every((p) => g[p].walkable), isTrue);
    });

    test('renvoie null sans chemin', () {
      final g = Grid<Tile>(5, 5, Tile.floor);
      for (var y = 0; y < 5; y++) {
        g.set(2, y, Tile.wall);
      }
      expect(findPath(g, const Pos(0, 0), const Pos(4, 0), (p) => g[p].walkable), isNull);
    });
  });

  group('Champ de vision', () {
    test('les murs bloquent la vue', () {
      final g = Grid<Tile>(11, 11, Tile.floor);
      for (var y = 0; y < 11; y++) {
        g.set(6, y, Tile.wall);
      }
      final v = computeFov(const Pos(5, 5), 8, (p) => g[p].blocksSight, g.inBounds);
      expect(v.contains(const Pos(5, 5)), isTrue);
      expect(v.contains(const Pos(1, 5)), isTrue);
      expect(v.contains(const Pos(6, 5)), isTrue, reason: 'le mur lui-même est visible');
      expect(v.contains(const Pos(8, 5)), isFalse, reason: 'derrière le mur');
    });

    test('rayon respecté', () {
      final g = Grid<Tile>(30, 30, Tile.floor);
      final v = computeFov(const Pos(15, 15), 5, (p) => g[p].blocksSight, g.inBounds);
      expect(v.contains(const Pos(20, 15)), isTrue);
      expect(v.contains(const Pos(22, 15)), isFalse);
    });
  });

  group('Combat', () {
    test('dégâts toujours >= 1 quand ça touche', () {
      final rng = Rng(7);
      final weak = Actor(id: 1, name: 'a', sprite: 0, pos: const Pos(0, 0), maxHp: 10, atk: 1, def: 0);
      final tank = Actor(id: 2, name: 'b', sprite: 0, pos: const Pos(1, 0), maxHp: 10, atk: 1, def: 50);
      var hits = 0;
      for (var i = 0; i < 500; i++) {
        final r = resolveAttack(weak, tank, rng);
        if (!r.miss) {
          hits++;
          expect(r.damage, greaterThanOrEqualTo(1));
        }
      }
      expect(hits, inInclusiveRange(380, 470));
    });
  });

  group('Partie', () {
    test('une run démarre proprement', () {
      final g = Game.newRun(123);
      expect(g.floor, 1);
      expect(g.player.alive, isTrue);
      expect(g.monsters, isNotEmpty);
      expect(g.visible.contains(g.player.pos), isTrue);
      expect(g.initialEvents.whereType<MessageEvent>().any((m) => m.kind == MessageKind.maestro), isTrue);
      expect(g.monsters.every((m) => !g.level.rooms.first.contains(m.pos)), isTrue);
    });

    test('foncer dans un mur ne consomme pas de tour', () {
      final g = Game.newRun(5);
      for (final d in Dir.all) {
        if (!g.level.walkable(g.player.pos + d.delta)) {
          final t = g.turn;
          expect(g.act(MoveAction(d)), isEmpty);
          expect(g.turn, t);
          return;
        }
      }
    });

    test('descendre change d\'étage et replace le joueur', () {
      final g = Game.newRun(9);
      g.player.pos = g.level.stairs;
      final ev = g.act(const DescendAction());
      expect(ev.whereType<BackstageEvent>(), isNotEmpty);
      expect(g.backstage, isNotNull);
      final ev2 = g.leaveBackstage();
      expect(ev2.whereType<FloorEvent>().single.floor, 2);
      expect(g.player.pos, g.level.start);
    });

    test('deux runs de même graine jouées pareil restent identiques', () {
      String play(int seed) {
        final g = Game.newRun(seed);
        final r = Rng(seed + 1);
        for (var i = 0; i < 300 && !g.gameOver; i++) {
          if (g.onStairs) {
            g.act(const DescendAction());
            g.answer(0);
            g.answer(1);
            g.leaveBackstage();
          } else {
            g.act(MoveAction(r.pick(Dir.all)));
          }
        }
        return '${g.floor}|${g.turn}|${g.player.hp}|${g.player.pos}|${g.kills}|${g.gold}|${g.gameOver}';
      }

      expect(play(77), play(77));
    });

    test('simulation : un bot qui fonce vers l\'escalier finit par mourir ou descendre', () {
      var maxFloor = 1;
      for (var seed = 0; seed < 30; seed++) {
        final g = Game.newRun(seed);
        for (var i = 0; i < 3000 && !g.gameOver; i++) {
          if (g.onStairs) {
            g.act(const DescendAction());
            g.leaveBackstage();
            continue;
          }
          if (g.player.hpRatio < 0.4 && g.healPotions > 0) {
            g.act(const QuaffAction());
            continue;
          }
          final adj = g.monsters.where((m) => m.pos.isAdjacent4(g.player.pos)).toList();
          if (adj.isNotEmpty) {
            g.act(MoveAction(Dir.fromDelta(adj.first.pos - g.player.pos)!));
            continue;
          }
          final path = findPath(g.level.tiles, g.player.pos, g.level.stairs, (p) => g.level.walkable(p),
              allowBlockedGoal: true);
          final step = path!.first;
          final res = g.act(MoveAction(Dir.fromDelta(step - g.player.pos)!));
          if (res.isEmpty) g.act(const WaitAction());
        }
        if (g.floor > maxFloor) maxFloor = g.floor;
        expect(g.player.hp <= g.player.maxHp, isTrue);
      }
      // Le jeu doit être jouable : un bot naïf descend au moins de quelques étages.
      expect(maxFloor, greaterThanOrEqualTo(3));
    });
  });

  test('articles des monstres', () {
    expect(monsterDefs.firstWhere((m) => m.id == 'spider').theName, startsWith("l'araignée"));
    expect(monsterDefs.firstWhere((m) => m.id == 'slime').theName, startsWith('la gelée'));
    expect(monsterDefs.firstWhere((m) => m.id == 'rat').theName, startsWith('le rat'));
    expect(monsterDefs.firstWhere((m) => m.id == 'bat').feminine, isTrue);
    expect(monsterDefs.firstWhere((m) => m.id == 'rat').feminine, isFalse);
  });
}
