import 'dart:math' as math;

/// Générateur aléatoire à graine : une même graine produit toujours la même run.
class Rng {
  Rng(this.seed) : _r = math.Random(seed);

  final int seed;
  final math.Random _r;

  /// Entier dans [0, max).
  int nextInt(int max) => _r.nextInt(max);

  /// Entier dans [min, max] (bornes incluses).
  int range(int min, int max) => min + _r.nextInt(max - min + 1);

  double nextDouble() => _r.nextDouble();

  /// Vrai avec une probabilité [p] (0..1).
  bool chance(double p) => _r.nextDouble() < p;

  T pick<T>(List<T> items) => items[_r.nextInt(items.length)];

  /// Choix pondéré : [weight] donne le poids de chaque élément.
  T weighted<T>(List<T> items, int Function(T) weight) {
    final total = items.fold<int>(0, (s, e) => s + weight(e));
    var roll = _r.nextInt(total);
    for (final e in items) {
      roll -= weight(e);
      if (roll < 0) return e;
    }
    return items.last;
  }

  void shuffle<T>(List<T> items) => items.shuffle(_r);
}
