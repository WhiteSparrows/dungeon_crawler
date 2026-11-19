import 'dart:convert';

import 'package:donjon_en_direct/content/items.dart';
import 'package:donjon_en_direct/content/roles.dart';
import 'package:donjon_en_direct/core/game.dart';
import 'package:donjon_en_direct/meta/profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Rôles et contrats', () {
    test('le rôle par défaut garde les stats de base', () {
      final g = Game.newRun(1);
      expect(g.player.maxHp, 30);
      expect(g.healPotions, 1);
      expect(g.setup.roleId, 'lambda');
    });

    test('Prof de gym : plus de PV, plus d\'attaque, pas de potion', () {
      final g = Game.newRun(1, setup: const RunSetup(roleId: 'gym'));
      expect(g.player.maxHp, 42);
      expect(g.player.atk, 3 + 1 + 1);
      expect(g.healPotions, 0);
      expect(g.player.sprite, roleById('gym').sprite);
    });

    test('Cascadeur et Chef : talents et fioles de départ', () {
      final s = Game.newRun(2, setup: const RunSetup(roleId: 'stuntman'));
      expect(s.talents, containsAll(['second_wind', 'lynx']));
      final c = Game.newRun(2, setup: const RunSetup(roleId: 'chef'));
      final mystery = c.inventory.where((i) => i.def.mystery).fold(0, (n, i) => n + i.count);
      expect(mystery, 2);
      for (final i in c.inventory.where((i) => i.def.mystery)) {
        expect(c.nameOf(i.def), i.def.name, reason: 'nez fin : identifiées');
      }
    });

    test('les contrats s\'appliquent au départ', () {
      final g = Game.newRun(3,
          setup: const RunSetup(upgrades: {'health': 2, 'kit': 1, 'bonus': 3, 'airtime': 1, 'welcome': 2, 'agent': 1}));
      expect(g.player.maxHp, 40);
      expect(g.healPotions, 2);
      expect(g.gold, 75);
      expect(g.floorTimer, 170 + 10 + 15);
      expect(g.pendingBoxes, [BoxTier.argent]);
      expect(g.show.hype, 40);
    });

    test('défi du jour : même date, même graine', () {
      expect(dailySeed(DateTime(2026, 11, 19, 8)), dailySeed(DateTime(2026, 11, 19, 23)));
      expect(dailySeed(DateTime(2026, 11, 19)), isNot(dailySeed(DateTime(2026, 11, 20))));
    });
  });

  group('Profil', () {
    test('achat de rôle et de contrat', () {
      final p = Profile()..royalties = 100;
      expect(p.buyRole('concierge'), isTrue);
      expect(p.royalties, 40);
      expect(p.selectedRole, 'concierge');
      expect(p.buyRole('stuntman'), isFalse, reason: 'trop cher');
      expect(p.buyUpgrade('health'), isTrue);
      expect(p.level('health'), 1);
      expect(p.nextUpgradeCost('health'), 80);
      expect(p.setupFor().roleId, 'concierge');
      expect(p.setupFor(daily: true).roleId, 'lambda');
      expect(p.setupFor(daily: true).upgrades, isEmpty);
    });

    test('fin de run : droits d\'auteur, records, succès, historique', () {
      final p = Profile();
      final g = Game.newRun(4);
      g.floor = 3;
      g.kills = 7;
      g.unlocked.addAll(['first_blood', 'pacifist']);
      g.abandon();
      final s = p.recordRun(g, now: DateTime(2026, 11, 19));
      expect(s.total, greaterThan(3 * 12 + 7));
      expect(s.newAchievements, hasLength(2));
      expect(s.bestFloor, isTrue);
      expect(p.royalties, s.total);
      expect(p.achievements, containsAll(['first_blood', 'pacifist']));
      expect(p.history.single.floor, 3);
      expect(p.history.single.killedBy, contains('abandon'));

      // Les succès déjà connus ne rapportent plus le bonus « nouveau ».
      final g2 = Game.newRun(5)..unlocked.add('first_blood');
      g2.abandon();
      expect(p.recordRun(g2).newAchievements, isEmpty);
    });

    test('défi du jour : bonus et meilleur score du jour', () {
      final p = Profile();
      final day = DateTime(2026, 11, 19);
      final g = Game.newRun(dailySeed(day), setup: RunSetup.dailyChallenge)..floor = 4;
      g.abandon();
      final s = p.recordRun(g, now: day);
      expect(s.lines.last.label, contains('défi'));
      expect(p.dailyBestFor(day), 4);
      expect(p.dailyAttemptsFor(day), 1);
      expect(p.dailyBestFor(DateTime(2026, 11, 20)), 0);
    });

    test('aller-retour JSON', () {
      final p = Profile()
        ..royalties = 42
        ..selectedRole = 'chef'
        ..bestViewers = 12345.6;
      p.roles.add('chef');
      p.upgrades['kit'] = 2;
      p.achievements.add('viral');
      final g = Game.newRun(6)..abandon();
      p.recordRun(g);
      final q = Profile.fromJson((jsonDecode(jsonEncode(p.toJson())) as Map).cast<String, Object?>());
      expect(q.royalties, p.royalties);
      expect(q.selectedRole, 'chef');
      expect(q.roles, containsAll(['lambda', 'chef']));
      expect(q.upgrades['kit'], 2);
      expect(q.achievements, contains('viral'));
      expect(q.history.length, 1);
      expect(q.bestViewers, p.bestViewers);
    });
  });
}
