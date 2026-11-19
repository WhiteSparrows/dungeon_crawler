import 'package:donjon_en_direct/content/monsters.dart';
import 'package:donjon_en_direct/content/roles.dart';
import 'package:donjon_en_direct/content/skills.dart';
import 'package:donjon_en_direct/content/status.dart';
import 'package:donjon_en_direct/content/themes.dart';
import 'package:donjon_en_direct/core/entities.dart';
import 'package:donjon_en_direct/core/events.dart';
import 'package:donjon_en_direct/core/game.dart';
import 'package:donjon_en_direct/core/grid.dart';
import 'package:flutter_test/flutter_test.dart';

Game _calm(int seed, {String role = 'lambda'}) {
  final g = Game.newRun(seed, setup: RunSetup(roleId: role));
  g.monsters.clear();
  g.chests.clear();
  g.floorItems.clear();
  g.features.clear();
  g.traps.clear();
  g.boss = null;
  return g;
}

Actor _spawn(Game g, String id, Pos p, {int? hp}) {
  final def = monsterById(id);
  final a = Actor(
      id: 700 + g.monsters.length,
      name: def.name,
      sprite: def.sprite,
      pos: p,
      maxHp: hp ?? def.hp,
      atk: def.atk,
      def: def.def,
      monster: def)
    ..awake = true
    ..lastSeenTarget = g.player.pos;
  g.monsters.add(a);
  return a;
}

Dir _freeDir(Game g) => Dir.all.firstWhere((d) => g.isFree(g.player.pos + d.delta));

/// Une case libre à [n] pas en ligne droite du joueur (couloir ou salle), ou null.
Pos? _lineSpot(Game g, int n) {
  for (final d in Dir.all) {
    var ok = true;
    for (var i = 1; i <= n; i++) {
      if (!g.isFree(g.player.pos + Pos(d.delta.x * i, d.delta.y * i))) ok = false;
    }
    if (ok) return g.player.pos + Pos(d.delta.x * n, d.delta.y * n);
  }
  return null;
}

void main() {
  test('chaque rôle a une compétence existante', () {
    for (final r in roleDefs) {
      expect(skillDefs.map((s) => s.id), contains(r.skill));
    }
    expect(monsterDefs.where((m) => !m.boss).length, 35);
    for (final t in themeDefs) {
      for (final id in t.monsters) {
        monsterById(id);
      }
    }
  });

  group('Compétences', () {
    test('recharge : utilisable puis bloquée pendant le temps de recharge', () {
      final g = _calm(1, role: 'gym');
      g.player.hp = 5;
      g.act(const SkillAction());
      expect(g.player.hp, greaterThan(5));
      expect(g.rageTurns, greaterThan(0));
      expect(g.skillReady, isFalse);
      final t = g.turn;
      final ev = g.act(const SkillAction());
      expect(g.turn, t, reason: 'en recharge : pas de tour');
      expect(ev.whereType<MessageEvent>().single.text, contains('recharge'));
      for (var i = 0; i < g.skill.cooldown; i++) {
        g.act(const WaitAction());
      }
      expect(g.skillReady, isTrue);
    });

    test('coup de poing désespéré : sans cible, rien ne se passe', () {
      final g = _calm(2);
      final t = g.turn;
      g.act(const SkillAction());
      expect(g.turn, t);
      expect(g.skillReady, isTrue);
    });

    test('pot-de-vin : le monstre part contre de l\'or', () {
      final g = _calm(3, role: 'accountant');
      final d = _freeDir(g);
      _spawn(g, 'rat', g.player.pos + d.delta);
      final gold = g.gold;
      g.act(const SkillAction());
      expect(g.monsters, isEmpty);
      expect(g.gold, gold - (15 + 3 * g.floor));
      expect(g.unlocked, contains('corruption'));
    });

    test('roulade : le cascadeur s\'éloigne des monstres', () {
      final g = _calm(4, role: 'stuntman');
      final d = _freeDir(g);
      final rat = _spawn(g, 'rat', g.player.pos + d.delta, hp: 999);
      g.act(const SkillAction());
      expect(g.player.pos.manhattan(rat.pos), greaterThan(1));
    });

    test('live : les monstres en vue sont gênés', () {
      final g = _calm(5, role: 'influencer');
      final d = _freeDir(g);
      final rat = _spawn(g, 'rat', g.player.pos + d.delta, hp: 999);
      final hype = g.show.hype;
      g.act(const SkillAction());
      expect(rat.hasStatus(Status.embarrassed), isTrue);
      expect(g.show.hype, greaterThan(hype));
    });

    test('ronde de nuit : révèle pièges et mimiques', () {
      final g = _calm(6, role: 'concierge');
      final mimic = _spawn(g, 'mimic', g.level.stairs);
      expect(mimic.disguised, isTrue);
      g.act(const SkillAction());
      expect(mimic.disguised, isFalse);
      expect(g.explored.length, g.level.width * g.level.height);
    });
  });

  group('Monstres tactiques', () {
    test('le tireur attaque à distance sans venir au contact', () {
      for (var seed = 0; seed < 30; seed++) {
        final g = _calm(seed);
        final spot = _lineSpot(g, 3);
        if (spot == null) continue;
        _spawn(g, 'juggler', spot, hp: 999);
        g.player.hp = g.player.maxHp = 9999;
        final events = <GameEvent>[];
        for (var i = 0; i < 4; i++) {
          events.addAll(g.act(const WaitAction()));
        }
        expect(events.whereType<AttackEvent>().where((e) => e.ranged), isNotEmpty, reason: 'seed $seed');
        return;
      }
      fail('aucune graine avec un couloir de 3 cases');
    });

    test('le kamikaze prévient puis explose ; on peut l\'esquiver', () {
      final g = _calm(7);
      final d = _freeDir(g);
      final k = _spawn(g, 'gasbag', g.player.pos + d.delta);
      g.act(const WaitAction());
      expect(k.primed, isTrue);
      // On s'éloigne d'au moins 2 cases avant l'explosion.
      final away = Dir.all.firstWhere((x) =>
          g.isFree(g.player.pos + x.delta) && (g.player.pos + x.delta).chebyshev(k.pos) >= 2,
          orElse: () => d);
      final hp = g.player.hp;
      final ev = g.act(MoveAction(away));
      expect(ev.whereType<KamikazeEvent>().where((e) => e.exploded), isNotEmpty);
      expect(k.alive, isFalse);
      if (g.player.pos.chebyshev(k.pos) >= 2) {
        expect(g.player.hp, hp);
        expect(g.unlocked, contains('defused'));
      }
    });

    test('le soigneur soigne ses alliés', () {
      final g = _calm(8);
      final spot = _lineSpot(g, 3);
      expect(spot, isNotNull);
      final medic = _spawn(g, 'medic', spot!);
      final hurt = _spawn(g, 'rat', g.level.stairs, hp: 100)..hp = 10;
      hurt.pos = medic.pos;
      // Place le blessé à côté du soigneur.
      final near = medic.pos.neighbors4.firstWhere((p) => g.isFree(p));
      hurt.pos = near;
      g.player.hp = g.player.maxHp = 9999;
      for (var i = 0; i < 4; i++) {
        g.act(const WaitAction());
      }
      expect(hurt.hp, greaterThan(10));
    });

    test('le forain blessé s\'enfuit', () {
      final g = _calm(9);
      final d = _freeDir(g);
      final carny = _spawn(g, 'carny', g.player.pos + d.delta, hp: 100)..hp = 10;
      g.act(const WaitAction());
      expect(carny.pos.manhattan(g.player.pos), greaterThanOrEqualTo(1));
      expect(carny.pos, isNot(g.player.pos + d.delta), reason: 'il a reculé');
    });
  });
}
