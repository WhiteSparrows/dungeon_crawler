import 'dart:collection';

import 'grid.dart';

/// Carte des distances (BFS 4 directions) depuis [origin].
Map<Pos, int> distanceMap(Grid<Object?> grid, Pos origin, bool Function(Pos) passable) {
  final dist = <Pos, int>{origin: 0};
  final queue = Queue<Pos>()..add(origin);
  while (queue.isNotEmpty) {
    final cur = queue.removeFirst();
    final d = dist[cur]!;
    for (final n in cur.neighbors4) {
      if (!grid.inBounds(n) || dist.containsKey(n) || !passable(n)) continue;
      dist[n] = d + 1;
      queue.add(n);
    }
  }
  return dist;
}

/// Plus court chemin de [from] vers [to] (exclut [from], inclut [to]).
/// [passable] est testé pour chaque case sauf la destination si [allowBlockedGoal].
/// Renvoie null si aucun chemin.
List<Pos>? findPath(
  Grid<Object?> grid,
  Pos from,
  Pos to,
  bool Function(Pos) passable, {
  bool allowBlockedGoal = false,
  int maxNodes = 4000,
}) {
  if (from == to) return <Pos>[];
  final came = <Pos, Pos>{};
  final queue = Queue<Pos>()..add(from);
  final seen = <Pos>{from};
  while (queue.isNotEmpty && seen.length < maxNodes) {
    final cur = queue.removeFirst();
    for (final n in cur.neighbors4) {
      if (!grid.inBounds(n) || seen.contains(n)) continue;
      final isGoal = n == to;
      if (!passable(n) && !(isGoal && allowBlockedGoal)) continue;
      seen.add(n);
      came[n] = cur;
      if (isGoal) {
        final path = <Pos>[n];
        var p = cur;
        while (p != from) {
          path.add(p);
          p = came[p]!;
        }
        return path.reversed.toList();
      }
      queue.add(n);
    }
  }
  return null;
}
