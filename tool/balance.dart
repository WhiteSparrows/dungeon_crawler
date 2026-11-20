// ignore_for_file: avoid_print
// Simulateur d'équilibrage : un bot « raisonnable » joue des centaines de runs.
// Usage : dart run tool/balance.dart [runs] [roleId]
import 'package:donjon_en_direct/content/crafting.dart';
import 'package:donjon_en_direct/content/items.dart';
import 'package:donjon_en_direct/content/mastery.dart';
import 'package:donjon_en_direct/content/monsters.dart';
import 'package:donjon_en_direct/core/entities.dart';
import 'package:donjon_en_direct/core/game.dart';
import 'package:donjon_en_direct/core/grid.dart';
import 'package:donjon_en_direct/core/pathfinding.dart';
import 'package:donjon_en_direct/core/rng.dart';

/// Score grossier d'un objet équipable pour le bot.
double _value(ItemDef d) => d.atk * 1.0 + d.def * 1.2 + d.maxHp * 0.25 + d.crit * 20 + d.lifesteal * 1.5;

class Result {
  Result(this.floor, this.level, this.turns, this.cause, this.victory, this.viralTurns, this.totalTurns);
  final int floor;
  final int level;
  final int turns;
  final String cause;
  final bool victory;
  final int viralTurns;
  final int totalTurns;
}

Result playOne(int seed, RunSetup setup) {
  final g = Game.newRun(seed, setup: setup);
  final r = Rng(seed ^ 0x5bd1e995);
  var viral = 0;
  var lastTurn = -1;
  for (var i = 0; i < 6000 && !g.gameOver; i++) {
    if (g.show.hype >= 80 && g.turn != lastTurn) viral++;
    lastTurn = g.turn;
    final f = g.activeFeature;
    if (f != null) {
      final res = g.chooseFeature(r.nextInt(f.kind.options.length));
      if (!res.closed) g.chooseFeature(f.kind.options.length - 1);
      continue;
    }
    // Coulisses : répondre, prendre un talent, se soigner, acheter une potion.
    if (g.backstage != null) {
      while (g.backstage!.question != null) {
        g.answer(r.nextInt(3));
      }
      g.pickTalent(0);
      if (g.player.hpRatio < 0.7) g.healAtInfirmary();
      g.buy(0);
      g.leaveBackstage();
      continue;
    }
    // Loot boxes + meilleur équipement.
    while (g.openBox() != null) {}
    for (final inv in List<InvItem>.of(g.inventory)) {
      final d = inv.def;
      if (!d.equippable) continue;
      final cur = d.kind == ItemKind.weapon ? g.weapon : g.trinket;
      if (cur == null || _value(d) > _value(cur)) {
        g.act(EquipAction(d.id));
      }
    }
    // Artisanat : démonter l'équipement en trop, puis fabriquer l'utile.
    for (final inv in List<InvItem>.of(g.inventory)) {
      if (inv.def.equippable) g.dismantle(inv.def.id);
    }
    for (final id in ['u_weapon', 'r_potion', if (g.ammoCount < 6) 'r_stones', 'u_trinket', 'u_ranged']) {
      if (g.whyNotCraft(recipeById(id)) == null) {
        g.act(CraftAction(id));
        break;
      }
    }
    if (g.player.hpRatio < 0.35 && g.healPotions > 0) {
      g.act(const QuaffAction());
      continue;
    }
    if (g.player.hpRatio < 0.35) {
      final mystery = g.inventory.where((i) => i.def.mystery || i.def.id == 'bandage').toList();
      if (mystery.isNotEmpty) {
        g.act(UseItemAction(mystery.first.def.id));
        continue;
      }
    }
    final adj = g.monsters.where((m) => m.pos.isAdjacent4(g.player.pos) && !m.disguised).toList();
    // Parer un coup lourd annoncé.
    if (adj.any((m) => g.intentOf(m) == MonsterIntent.heavy) && g.stamina >= g.parryCost) {
      g.act(const ParryAction());
      continue;
    }
    // Abattre les tireurs et soigneurs à distance.
    final shooters = g.monsters
        .where((m) =>
            !m.disguised &&
            g.visible.contains(m.pos) &&
            !m.pos.isAdjacent4(g.player.pos) &&
            (m.monster!.behavior == Behavior.ranged || m.monster!.behavior == Behavior.healer) &&
            g.ranged != null &&
            m.pos.chebyshev(g.player.pos) <= g.shootRange)
        .toList();
    if (shooters.isNotEmpty && g.ammoCount > 0 && (!g.ranged!.magic || g.stamina >= g.spellCost)) {
      final t = g.turn;
      g.act(ShootAction(shooters.first.id));
      if (g.turn != t) continue;
    }
    if (adj.isNotEmpty && g.stamina >= g.heavyCost + 2) {
      final t = g.turn;
      g.act(HeavyAction(Dir.fromDelta(adj.first.pos - g.player.pos)!));
      if (g.turn != t) continue;
    }
    final wantsSkill = switch (g.skill.id) {
      'roll' || 'bribe' => g.player.hpRatio < 0.4 && adj.isNotEmpty,
      _ => adj.isNotEmpty || g.player.hpRatio < 0.5,
    };
    if (g.skillReady && wantsSkill) {
      final t = g.turn;
      g.act(const SkillAction());
      if (g.turn != t) continue;
    }
    if (adj.isNotEmpty) {
      g.act(MoveAction(Dir.fromDelta(adj.first.pos - g.player.pos)!));
      continue;
    }
    if (g.onStairs) {
      final ev = g.act(const DescendAction());
      if (g.backstage == null && ev.isNotEmpty) {
        // Escalier verrouillé : aller chercher le boss.
        final b = g.boss;
        if (b != null) {
          final path = findPath(g.level.tiles, g.player.pos, b.pos, (p) => g.level.walkable(p), allowBlockedGoal: true);
          if (path != null && path.isNotEmpty) g.act(MoveAction(Dir.fromDelta(path.first - g.player.pos)!));
        } else {
          g.act(const WaitAction());
        }
      }
      continue;
    }
    final path = findPath(g.level.tiles, g.player.pos, g.level.stairs,
        (p) => g.level.walkable(p) && g.chestAt(p) == null && g.featureAt(p) == null && !(g.trapAt(p)?.revealed ?? false),
        allowBlockedGoal: true);
    if (path == null || path.isEmpty) {
      g.act(MoveAction(r.pick(Dir.all)));
      continue;
    }
    final res = g.act(MoveAction(Dir.fromDelta(path.first - g.player.pos)!));
    if (res.isEmpty) g.act(const WaitAction());
  }
  for (final m in Mastery.values) {
    masterySum[m] = (masterySum[m] ?? 0) + g.masteryLevel(m);
  }
  return Result(g.floor, g.playerLevel, g.turn, g.killedBy ?? (g.victory ? 'VICTOIRE' : 'timeout'), g.victory, viral,
      g.turn);
}

/// Somme des niveaux de compétence en fin de run (pour la moyenne).
final masterySum = <Mastery, int>{};

void main(List<String> args) {
  final runs = args.isNotEmpty ? int.parse(args[0]) : 200;
  final role = args.length > 1 ? args[1] : 'lambda';
  final setup = RunSetup(roleId: role);
  final results = [for (var s = 0; s < runs; s++) playOne(1000 + s, setup)];
  final floors = <int, int>{};
  final causes = <String, int>{};
  for (final r in results) {
    floors[r.floor] = (floors[r.floor] ?? 0) + 1;
    causes[r.cause] = (causes[r.cause] ?? 0) + 1;
  }
  final avg = results.fold<int>(0, (s, r) => s + r.floor) / runs;
  final viral = results.fold<int>(0, (s, r) => s + r.viralTurns) / results.fold<int>(1, (s, r) => s + r.totalTurns);
  print('Runs: $runs  rôle: $role  étage moyen: ${avg.toStringAsFixed(2)}  victoires: '
      '${results.where((r) => r.victory).length}  temps en VIRAL: ${(viral * 100).toStringAsFixed(1)}%');
  print('Compétences moyennes en fin de run : '
      '${[for (final m in Mastery.values) '${m.label} ${((masterySum[m] ?? 0) / runs).toStringAsFixed(1)}'].join(', ')}');
  print('Répartition des étages atteints :');
  for (final f in floors.keys.toList()..sort()) {
    print('  étage ${f.toString().padLeft(2)} : ${'#' * (floors[f]! * 60 ~/ runs)} ${floors[f]}');
  }
  final demo = <int, int>{};
  for (final r in results.where((r) => r.cause.contains('démolition'))) {
    demo[r.floor] = (demo[r.floor] ?? 0) + 1;
  }
  print('Démolitions par étage : $demo');
  print('Causes de mort (top 10) :');
  final sorted = causes.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  for (final e in sorted.take(10)) {
    print('  ${e.value.toString().padLeft(4)}  ${e.key}');
  }
}
