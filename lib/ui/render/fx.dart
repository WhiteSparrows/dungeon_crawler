import 'dart:math' as math;

import 'package:flutter/painting.dart';

/// Particule cosmétique (coordonnées en tuiles). N'influence jamais le jeu.
class Particle {
  Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.color,
    required this.bornMs,
    required this.lifeMs,
    required this.size,
    this.gravity = 0,
  });

  final double x, y, vx, vy, gravity;
  final Color color;
  final int bornMs, lifeMs;

  /// Taille en fraction de tuile.
  final double size;

  bool dead(int now) => now - bornMs >= lifeMs;
}

/// Trait de coup (« slash ») dessiné sur la cible.
class Slash {
  Slash(this.x, this.y, this.bornMs, this.color, {this.crit = false});
  final double x, y;
  final int bornMs;
  final Color color;
  final bool crit;
  static const lifeMs = 170;
  bool dead(int now) => now - bornMs >= lifeMs;
}

/// Fabrique de particules. Utilise son propre hasard : le moteur reste déterministe.
class Fx {
  final particles = <Particle>[];
  final slashes = <Slash>[];
  final _r = math.Random();

  bool get isEmpty => particles.isEmpty && slashes.isEmpty;

  void prune(int now) {
    particles.removeWhere((p) => p.dead(now));
    slashes.removeWhere((s) => s.dead(now));
  }

  /// Gerbe de [n] particules autour du centre de la case ([x], [y]).
  void burst(
    double x,
    double y,
    int now, {
    required List<Color> colors,
    int n = 10,
    double speed = 2.5,
    int life = 450,
    double size = 0.09,
    double gravity = 0,
    double upward = 0,
    double spread = 0.15,
  }) {
    for (var i = 0; i < n; i++) {
      final a = _r.nextDouble() * math.pi * 2;
      final v = speed * (0.4 + _r.nextDouble() * 0.6);
      particles.add(Particle(
        x: x + 0.5 + (_r.nextDouble() - 0.5) * spread,
        y: y + 0.5 + (_r.nextDouble() - 0.5) * spread,
        vx: math.cos(a) * v,
        vy: math.sin(a) * v - upward,
        color: colors[_r.nextInt(colors.length)],
        bornMs: now,
        lifeMs: (life * (0.7 + _r.nextDouble() * 0.6)).round(),
        size: size * (0.7 + _r.nextDouble() * 0.6),
        gravity: gravity,
      ));
    }
  }

  void slash(double x, double y, int now, Color color, {bool crit = false}) =>
      slashes.add(Slash(x, y, now, color, crit: crit));

  // ---------------------------------------------------------------- recettes

  void hit(double x, double y, int now, {bool crit = false}) {
    slash(x, y, now, crit ? const Color(0xFFFFA030) : const Color(0xFFFFFFFF), crit: crit);
    burst(x, y, now,
        colors: crit ? const [Color(0xFFFFA030), Color(0xFFFFE070)] : const [Color(0xFFFFFFFF), Color(0xFFFFE070)],
        n: crit ? 12 : 5,
        speed: crit ? 3.5 : 2.2,
        life: 260);
  }

  void hurt(double x, double y, int now) {
    slash(x, y, now, const Color(0xFFFF4040));
    burst(x, y, now, colors: const [Color(0xFFE02020), Color(0xFF901010)], n: 7, speed: 2, life: 500, gravity: 6,
        upward: 1.5);
  }

  void death(double x, double y, int now, Color tint) {
    burst(x, y, now,
        colors: [tint, const Color(0xFFDDDDDD), const Color(0xFF888888)],
        n: 16,
        speed: 3,
        life: 600,
        size: 0.11,
        gravity: 5,
        upward: 1.5,
        spread: 0.5);
  }

  void coins(double x, double y, int now) => burst(x, y, now,
      colors: const [Color(0xFFFFD84D), Color(0xFFFFF0A0)], n: 7, speed: 1.6, life: 500, upward: 2, size: 0.07);

  void sparkle(double x, double y, int now) => burst(x, y, now,
      colors: const [Color(0xFF8FD8FF), Color(0xFFFFFFFF)], n: 7, speed: 1.4, life: 550, upward: 1.5, size: 0.07);

  void heal(double x, double y, int now) => burst(x, y, now,
      colors: const [Color(0xFF60FF80), Color(0xFFB0FFC0)], n: 8, speed: 0.6, life: 800, upward: 1.8, spread: 0.7);

  void confetti(double x, double y, int now) => burst(x, y, now,
      colors: const [
        Color(0xFFFF5050),
        Color(0xFFFFD84D),
        Color(0xFF5EC8FF),
        Color(0xFF8BE58B),
        Color(0xFFC77DFF),
      ],
      n: 22,
      speed: 3.2,
      life: 900,
      gravity: 4,
      upward: 3,
      size: 0.08);

  void levelUp(double x, double y, int now) => burst(x, y, now,
      colors: const [Color(0xFFFFD84D), Color(0xFFFFFFFF)], n: 24, speed: 3.5, life: 700, size: 0.08);

  void explosion(double x, double y, int now) => burst(x, y, now,
      colors: const [Color(0xFFFF5030), Color(0xFFFFA030), Color(0xFFFFE070), Color(0xFF555555)],
      n: 30,
      speed: 4.5,
      life: 650,
      size: 0.13,
      spread: 0.6);

  void dust(double x, double y, int now) => burst(x, y, now,
      colors: const [Color(0xFFB0A090), Color(0xFF807060)], n: 10, speed: 1.6, life: 500, upward: 0.8, size: 0.1);

  /// Petite bulle / fumerolle d'altération (animation de repos).
  void wisp(double x, double y, int now, Color color) => particles.add(Particle(
        x: x + 0.3 + _r.nextDouble() * 0.4,
        y: y + 0.4,
        vx: (_r.nextDouble() - 0.5) * 0.3,
        vy: -0.9,
        color: color,
        bornMs: now,
        lifeMs: 700,
        size: 0.07,
      ));
}
