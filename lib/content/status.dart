/// Altérations d'état (joueur et monstres).
enum Status {
  poison('Empoisonné', 'POISON', 0xFF60E060),
  burn('En feu', 'FEU', 0xFFFF9F40),
  stun('Étourdi', 'ETOURDI', 0xFFFFE060),
  embarrassed('Gêné', 'GENE', 0xFFFF7AD0);

  const Status(this.label, this.short, this.color);
  final String label;

  /// Libellé court sans accent majuscule (police pixel).
  final String short;
  final int color;

  /// Durée par défaut.
  int get turns => switch (this) {
        Status.poison => 6,
        Status.burn => 3,
        Status.stun => 1,
        Status.embarrassed => 5,
      };
}

/// Effet d'un coup porté (arme ou monstre).
enum OnHit { poison, burn, stun, embarrass, steal }

extension OnHitStatus on OnHit {
  Status? get status => switch (this) {
        OnHit.poison => Status.poison,
        OnHit.burn => Status.burn,
        OnHit.stun => Status.stun,
        OnHit.embarrass => Status.embarrassed,
        OnHit.steal => null,
      };

  String get label => switch (this) {
        OnHit.poison => 'empoisonne',
        OnHit.burn => 'enflamme',
        OnHit.stun => 'étourdit',
        OnHit.embarrass => 'met mal à l\'aise',
        OnHit.steal => 'vole de l\'or',
      };
}
