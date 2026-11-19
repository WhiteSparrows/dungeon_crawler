import 'package:donjon_en_direct/content/interviews.dart';
import 'package:donjon_en_direct/content/items.dart';
import 'package:donjon_en_direct/content/monsters.dart';
import 'package:donjon_en_direct/core/entities.dart';
import 'package:donjon_en_direct/core/events.dart';
import 'package:donjon_en_direct/core/game.dart';
import 'package:donjon_en_direct/core/grid.dart';
import 'package:donjon_en_direct/core/show.dart';
import 'package:flutter_test/flutter_test.dart';

Game _calm(int seed) {
  final g = Game.newRun(seed);
  g.monsters.clear();
  g.chests.clear();
  g.floorItems.clear();
  return g;
}

Dir _freeDir(Game g) => Dir.all.firstWhere((d) => g.isFree(g.player.pos + d.delta));

void main() {
  test('trois sponsors différents par run', () {
    final g = Game.newRun(1);
    expect(g.show.sponsors.length, 3);
    expect(g.show.sponsors.map((s) => s.def.id).toSet().length, 3);
  });

  group('Interview et coulisses', () {
    test("descendre ouvre l'interview ; le jeu est en pause", () {
      final g = _calm(2);
      g.player.pos = g.level.stairs;
      g.act(const DescendAction());
      final b = g.backstage!;
      expect(b.questions.length, 2);
      expect(b.intro, isNotEmpty);
      final t = g.turn;
      expect(g.act(const WaitAction()), isEmpty);
      expect(g.turn, t);
      expect(g.floor, 1);
    });

    test('répondre applique les effets et passe à la question suivante', () {
      final g = _calm(3);
      g.player.pos = g.level.stairs;
      g.act(const DescendAction());
      final b = g.backstage!;
      final q = b.question!;
      final a = q.answers[0];
      final gold = g.gold;
      final r = g.answer(0)!;
      expect(r.reaction, isNot(contains('{s')));
      expect(r.crowd, a.crowd);
      expect(g.gold, (gold + a.gold).clamp(0, 1 << 30));
      expect(b.current, 1);
      g.answer(2);
      expect(b.interviewDone, isTrue);
      expect(g.answer(0), isNull);
    });

    test("une question en rapport avec l'étage passe en premier (poison)", () {
      final g = _calm(4);
      final poison = mysteryPotions.firstWhere((p) => p.effect == Effect.poison);
      g.inventory.add(InvItem(poison));
      g.act(UseItemAction(poison.id));
      g.player.pos = g.level.stairs;
      g.act(const DescendAction());
      expect(g.backstage!.questions.first.when, When.poisoned);
    });

    test('les conséquences de l\'interview s\'appliquent à l\'étage suivant', () {
      final g = _calm(5);
      g.player.pos = g.level.stairs;
      g.act(const DescendAction());
      // Injecte une question connue pour contrôler l'effet.
      final q = questions.firstWhere((q) => q.answers.any((a) => a.timerDelta == 30));
      g.backstage!.questions
        ..clear()
        ..add(q);
      g.answer(q.answers.indexWhere((a) => a.timerDelta == 30));
      g.leaveBackstage();
      expect(g.floor, 2);
      expect(g.floorTimer, 170 + 20 + 30);
      expect(g.turnsLeft, g.floorTimer);
    });

    test('boutique, infirmerie et talents', () {
      final g = _calm(6);
      g.player.pos = g.level.stairs;
      g.act(const DescendAction());
      final b = g.backstage!;
      expect(b.shop.first.item.id, 'heal_potion');
      expect(b.talents.length, 3);
      g.gold = 0;
      expect(g.buy(0), isFalse);
      g.gold = 1000;
      expect(g.buy(0), isTrue);
      expect(g.buy(0), isFalse, reason: 'déjà vendu');
      expect(g.healPotions, 2);
      g.player.hp = 1;
      expect(g.healAtInfirmary(), isTrue);
      expect(g.player.hp, g.player.maxHp);
      final t = b.talents.first;
      expect(g.pickTalent(0), isTrue);
      expect(g.talents, contains(t.id));
      expect(g.pickTalent(1), isFalse, reason: 'un seul talent par coulisses');
    });
  });

  group('Compte à rebours', () {
    test("la démolition blesse puis tue", () {
      final g = _calm(7);
      g.floorTimer = 1;
      final events = <GameEvent>[];
      for (var i = 0; i < 200 && !g.gameOver; i++) {
        events.addAll(g.act(const WaitAction()));
      }
      expect(events.whereType<DemolitionEvent>(), isNotEmpty);
      expect(g.gameOver, isTrue);
      expect(g.killedBy, contains('démolition'));
    });

    test('second souffle : survit une fois', () {
      final g = _calm(8);
      g.talents.add('second_wind');
      g.floorTimer = 0;
      g.player.hp = 1;
      g.act(const WaitAction());
      expect(g.gameOver, isFalse);
      expect(g.player.hp, 1);
    });
  });

  group('Audience et sponsors', () {
    test('éliminer un monstre fait monter la hype', () {
      final g = _calm(9);
      final d = _freeDir(g);
      final def = monsterDefs.firstWhere((m) => m.id == 'rat');
      final rat = Actor(id: 77, name: def.name, sprite: def.sprite, pos: g.player.pos + d.delta, maxHp: 1, atk: 0, def: 0, monster: def);
      g.monsters.add(rat);
      final before = g.show.hype;
      for (var i = 0; i < 20 && rat.alive; i++) {
        g.act(MoveAction(d));
      }
      expect(g.show.hype, greaterThan(before));
    });

    test("l'ennui déclenche un rebondissement", () {
      final g = _calm(10);
      g.show.hype = 0;
      final events = <GameEvent>[];
      for (var i = 0; i < 40; i++) {
        g.show.hype = 0;
        events.addAll(g.act(const WaitAction()));
      }
      expect(events.whereType<TwistEvent>(), isNotEmpty);
      expect(g.monsters, isNotEmpty);
    });

    test('un sponsor satisfait envoie un colis', () {
      final g = _calm(11);
      g.show.sponsors[1].satisfaction = 500;
      final ev = g.act(const WaitAction());
      expect(ev.whereType<SponsorGiftEvent>().single.sponsorIndex, 1);
      expect(g.pendingBoxes, isNotEmpty);
      expect(g.unlocked, contains('sponsored'));
    });

    test("l'audience suit la hype", () {
      final hot = Show([]), cold = Show([]);
      for (var i = 0; i < 50; i++) {
        hot.hype = 90;
        cold.hype = 5;
        hot.endTurn(waited: false, lowHp: false, timerLow: false, newTiles: 0);
        cold.endTurn(waited: false, lowHp: false, timerLow: false, newTiles: 0);
      }
      expect(hot.viewers, greaterThan(1200));
      expect(cold.viewers, lessThan(1200));
      expect(formatViewers(12400), '12,4k');
    });
  });
}
