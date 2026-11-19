import 'dart:convert';

import 'package:donjon_en_direct/core/entities.dart';
import 'package:donjon_en_direct/core/game.dart';
import 'package:donjon_en_direct/core/grid.dart';
import 'package:donjon_en_direct/core/rng.dart';
import 'package:donjon_en_direct/meta/profile_store.dart';
import 'package:flutter_test/flutter_test.dart';

/// Empreinte de l'état complet d'une partie.
String signature(Game g) => [
      g.floor,
      g.turn,
      g.floorMod,
      [for (final f in g.features) '${f.kind.name}${f.used}'].join(','),
      [for (final t in g.traps) '${t.kind.name}${t.revealed}'].join(','),
      g.player.hp,
      g.player.maxHp,
      g.player.pos,
      g.gold,
      g.kills,
      g.xp,
      g.playerLevel,
      g.weapon?.id,
      g.skillCooldown,
      g.trinket?.id,
      [for (final i in g.inventory) '${i.def.id}x${i.count}'].join(','),
      [for (final m in g.monsters) '${m.monster!.id}@${m.pos}:${m.hp}'].join(','),
      g.pendingBoxes.length,
      g.show.hype.toStringAsFixed(3),
      g.show.viewers.toStringAsFixed(1),
      g.unlocked.toList()..sort(),
      g.talents.toList()..sort(),
      g.backstage?.current,
      g.gameOver,
      g.explored.length,
    ].join('|');

/// Joue [steps] actions variées (déplacements, combats, coulisses, loot boxes, équipement).
void play(Game g, Rng r, int steps) {
  for (var i = 0; i < steps && !g.gameOver; i++) {
    final f = g.activeFeature;
    if (f != null) {
      final res = g.chooseFeature(r.nextInt(f.kind.options.length));
      if (!res.closed) g.chooseFeature(f.kind.options.length - 1);
      continue;
    }
    if (g.backstage != null) {
      while (g.backstage!.question != null) {
        g.answer(r.nextInt(3));
      }
      g.pickTalent(r.nextInt(3));
      g.buy(0);
      g.healAtInfirmary();
      g.leaveBackstage();
      continue;
    }
    if (g.pendingBoxes.isNotEmpty && r.chance(0.3)) g.openBox();
    for (final inv in List<InvItem>.of(g.inventory)) {
      if (inv.def.equippable && r.chance(0.5)) g.act(EquipAction(inv.def.id));
    }
    if (g.skillReady && r.chance(0.15)) {
      g.act(const SkillAction());
    } else if (g.player.hpRatio < 0.4 && g.healPotions > 0) {
      g.act(const QuaffAction());
    } else if (g.onStairs && r.chance(0.8)) {
      g.act(const DescendAction());
    } else if (r.chance(0.08)) {
      g.debugToStairs();
    } else {
      g.act(MoveAction(r.pick(Dir.all)));
    }
  }
}

void main() {
  test('une partie rechargée est identique à l\'originale, et le reste ensuite', () {
    for (var seed = 0; seed < 25; seed++) {
      final original = Game.newRun(seed, setup: const RunSetup(roleId: 'chef', upgrades: {'kit': 1, 'welcome': 1}));
      final r = Rng(seed * 7 + 1);
      play(original, r, 400);
      final json = jsonEncode(original.toSave());
      final loaded = Game.fromSave((jsonDecode(json) as Map).cast<String, Object?>());
      expect(loaded, isNotNull, reason: 'seed $seed');
      expect(signature(loaded!), signature(original), reason: 'seed $seed');
      expect(loaded.commands, original.commands);

      // Les deux continuent à l'identique.
      play(original, Rng(seed), 150);
      play(loaded, Rng(seed), 150);
      expect(signature(loaded), signature(original), reason: 'suite, seed $seed');
    }
  });

  test('les actions sans effet ne gonflent pas le journal', () {
    final g = Game.newRun(3);
    g.monsters.clear();
    final wall = Dir.all.where((d) => !g.level.walkable(g.player.pos + d.delta)).toList();
    final before = g.commands.length;
    for (final d in wall) {
      g.act(MoveAction(d));
    }
    expect(g.commands.length, before);
  });

  test('défi du jour et abandon sont conservés', () {
    final g = Game.newRun(dailySeed(DateTime(2026, 11, 19)), setup: RunSetup.dailyChallenge);
    play(g, Rng(1), 50);
    g.abandon();
    final loaded = Game.fromSave(g.toSave())!;
    expect(loaded.setup.daily, isTrue);
    expect(loaded.gameOver, isTrue);
    expect(loaded.killedBy, g.killedBy);
  });

  test('magasin : sauvegarder, reprendre, abandonner pour une nouvelle partie', () async {
    final store = ProfileStore.memory();
    final g = Game.newRun(11);
    play(g, Rng(2), 20);
    expect(g.gameOver, isFalse);
    await store.saveRun(g);
    expect(store.hasSavedRun, isTrue);
    expect(store.savedRunInfo!['floor'], g.floor);
    final back = store.loadRun()!;
    expect(signature(back), signature(g));

    await store.abandonSavedRun();
    expect(store.hasSavedRun, isFalse);
    expect(store.profile.runs, 1);
    expect(store.profile.history.single.killedBy, contains('abandon'));

    // Une partie terminée n'est pas sauvegardée.
    final dead = Game.newRun(12)..abandon();
    await store.saveRun(dead);
    expect(store.hasSavedRun, isFalse);
  });

  test('sauvegarde incompatible ou corrompue : null, pas de plantage', () {
    final g = Game.newRun(4);
    final s = g.toSave()..['v'] = -1;
    expect(Game.fromSave(s), isNull);
    final bad = Game.newRun(4).toSave()..['cmds'] = 'zzz;m9';
    expect(Game.fromSave(bad), isNull);
  });
}
