import 'package:donjon_en_direct/content/crafting.dart';
import 'package:donjon_en_direct/content/features.dart';
import 'package:donjon_en_direct/content/quests.dart';
import 'package:donjon_en_direct/core/entities.dart';
import 'package:donjon_en_direct/core/events.dart';
import 'package:donjon_en_direct/core/game.dart';
import 'package:donjon_en_direct/core/grid.dart';
import 'package:donjon_en_direct/core/pathfinding.dart';
import 'package:flutter_test/flutter_test.dart';

/// Première run (graine >= [from]) dont le PNJ du premier étage propose une quête [k].
Game _withQuest(QuestKind k, {int from = 0}) {
  for (var seed = from; seed < from + 400; seed++) {
    final g = Game.newRun(seed);
    if (g.quest?.npc.kind == k) return g;
  }
  throw StateError('Aucune quête $k trouvée');
}

/// Téléporte le joueur à côté du PNJ et lui parle.
void _talk(Game g) {
  final f = g.quest!.feature;
  final d = Dir.all.firstWhere((d) => g.isFree(f.pos - d.delta));
  g.player.pos = f.pos - d.delta;
  final ev = g.act(MoveAction(d));
  expect(ev.whereType<FeatureEvent>(), isNotEmpty);
  expect(g.activeFeature, same(f));
}

/// Tue [m] au corps à corps (téléportation à côté, PV à 1).
void _slay(Game g, Actor m) {
  final d = Dir.all.firstWhere((d) => g.isFree(m.pos - d.delta) || g.player.pos == m.pos - d.delta);
  g.player.pos = m.pos - d.delta;
  m.hp = 1;
  m.def = 0;
  for (var i = 0; i < 30 && m.alive; i++) {
    g.player.hp = g.player.maxHp;
    g.act(MoveAction(d));
  }
  expect(m.alive, isFalse);
}

void main() {
  test('un PNJ au premier étage, avec une quête cohérente', () {
    final kinds = <QuestKind>{};
    for (var seed = 0; seed < 80; seed++) {
      final g = Game.newRun(seed);
      final q = g.quest;
      if (q == null) continue;
      kinds.add(q.npc.kind);
      expect(g.features, contains(q.feature));
      expect(q.feature.kind, FeatureKind.npc);
      expect(q.goal, greaterThan(0));
      switch (q.npc.kind) {
        case QuestKind.cull:
          final n = g.monsters.where((m) => q.monsterId == null || m.monster!.id == q.monsterId).length;
          expect(n, greaterThanOrEqualTo(q.goal), reason: 'seed $seed');
        case QuestKind.hunt:
          final t = g.monsters.where((m) => m.id == q.targetId).single;
          expect(t.elite, isTrue);
        case QuestKind.fetch:
          expect(g.level.walkable(q.itemPos!), isTrue);
          expect(q.itemName, isNotEmpty);
        case QuestKind.donate:
          expect(q.component, isNotNull);
        case QuestKind.stunt:
          expect(q.stunt, isNotNull);
      }
      expect(g.featureText(q.feature), contains('Récompense'));
      expect(g.featureOptions(q.feature), hasLength(2));
    }
    expect(kinds, containsAll(QuestKind.values));
  });

  test('refuser, accepter, donner sans assez puis avec assez de composants', () {
    final g = _withQuest(QuestKind.donate);
    final q = g.quest!;
    _talk(g);
    expect(g.chooseFeature(1).closed, isTrue);
    expect(q.accepted, isFalse);
    expect(g.activeFeature, isNull);

    _talk(g);
    g.chooseFeature(0);
    expect(q.accepted, isTrue);
    expect(g.questLine, contains(q.component!.label.toLowerCase()));

    _talk(g);
    final refused = g.chooseFeature(0);
    expect(refused.closed, isFalse);
    expect(refused.text, contains('manque'));
    g.chooseFeature(1);

    g.materials[q.component!] = q.goal + 1;
    final gold = g.gold;
    final plus = g.plusOf(g.weapon!);
    _talk(g);
    final r = g.chooseFeature(0);
    expect(r.closed, isTrue);
    expect(q.rewarded, isTrue);
    expect(q.feature.used, isTrue);
    expect(g.gold, gold + g.questGold);
    expect(g.plusOf(g.weapon!), plus + 1);
    expect(g.materialCount(q.component!), 1);
    expect(g.questLine, isNull);
    expect(g.unlocked, contains('good_deed'));
  });

  test('ménage : les éliminations comptent, puis récompense (sac +2)', () {
    final g = _withQuest(QuestKind.cull);
    final q = g.quest!;
    _talk(g);
    g.chooseFeature(0);
    final slots = g.maxSlots;
    for (final m in List.of(g.monsters)) {
      if (q.done) break;
      if (m.isBoss || m.disguised || (q.monsterId != null && m.monster!.id != q.monsterId)) continue;
      _slay(g, m);
    }
    expect(q.done, isTrue);
    expect(g.questLine, contains('Retournez'));
    _talk(g);
    expect(g.featureOptions(q.feature).first, contains('Réclamer'));
    g.chooseFeature(0);
    expect(g.maxSlots, slots + 2);
  });

  test('chasse : abattre la vedette avant d\'accepter compte aussi', () {
    final g = _withQuest(QuestKind.hunt);
    final q = g.quest!;
    _slay(g, g.monsters.firstWhere((m) => m.id == q.targetId));
    expect(q.done, isTrue);
    _talk(g);
    final boxes = g.pendingBoxes.length;
    final r = g.chooseFeature(0);
    expect(r.text, contains('déjà fait'));
    expect(q.rewarded, isTrue);
    expect(g.pendingBoxes.length, greaterThan(boxes));
  });

  test('objet perdu : on le ramasse en marchant dessus', () {
    final g = _withQuest(QuestKind.fetch);
    final q = g.quest!;
    _talk(g);
    g.chooseFeature(0);
    final target = q.itemPos!;
    final d = Dir.all.firstWhere((d) => g.isFree(target - d.delta));
    g.player.pos = target - d.delta;
    g.act(MoveAction(d));
    expect(q.itemPos, isNull);
    expect(q.done, isTrue);
  });

  test('descendre abandonne la quête en cours', () {
    final g = _withQuest(QuestKind.stunt);
    _talk(g);
    g.chooseFeature(0);
    g.boss = null;
    g.monsters.clear();
    g.player.pos = g.level.stairs;
    g.act(const DescendAction());
    final ev = g.leaveBackstage();
    expect(ev.whereType<MessageEvent>().map((e) => e.text), contains(contains('abandonnée')));
    expect(g.quest?.accepted ?? false, isFalse);
  });

  test('rejeu : parler au PNJ en marchant et accepter, à l\'identique', () {
    for (var seed = 0; seed < 40; seed++) {
      final g = Game.newRun(seed);
      final q = g.quest;
      if (q == null) continue;
      for (var i = 0; i < 300 && g.activeFeature == null && !g.gameOver; i++) {
        final path = findPath(g.level.tiles, g.player.pos, q.feature.pos, (p) => g.level.walkable(p),
            allowBlockedGoal: true);
        if (path == null || path.isEmpty) break;
        final ev = g.act(MoveAction(Dir.fromDelta(path.first - g.player.pos)!));
        if (ev.isEmpty) g.act(const WaitAction());
      }
      if (g.activeFeature != q.feature) continue;
      g.chooseFeature(0);
      expect(q.accepted, isTrue);
      final loaded = Game.fromSave(g.toSave())!;
      expect(loaded.quest!.accepted, isTrue);
      expect(loaded.quest!.npc.id, q.npc.id);
      expect(loaded.quest!.progress, q.progress);
      expect(loaded.player.pos, g.player.pos);
      expect(loaded.gold, g.gold);
      return;
    }
    fail('aucune run où le PNJ est joignable');
  });

  test('tous les PNJ ont un texte complet', () {
    for (final n in npcs) {
      expect(n.intro, isNotEmpty);
      expect(n.ask, isNotEmpty);
      expect(n.thanks, isNotEmpty);
    }
    expect(Component.values, isNotEmpty);
  });
}
