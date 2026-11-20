import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../content/sprites.dart';
import '../../core/entities.dart';
import '../../core/events.dart';
import '../../core/game.dart';
import '../../core/grid.dart';
import '../game_controller.dart';
import '../theme.dart';
import 'fx.dart';
import 'sprite_atlas.dart';

/// Nombre de tuiles visibles en largeur : règle le zoom.
const tilesAcross = 11.0;

/// Géométrie caméra partagée entre le dessin et la conversion tap → case.
class Camera {
  Camera(this.size, this.centerX, this.centerY) : tileSize = (size.width / tilesAcross).floorToDouble();

  final Size size;
  final double centerX;
  final double centerY;
  final double tileSize;

  Offset toScreen(double x, double y) => Offset(
        (x - centerX) * tileSize + size.width / 2 - tileSize / 2,
        (y - centerY) * tileSize + size.height / 2 - tileSize / 2,
      );

  Pos toTile(Offset s) => Pos(
        ((s.dx - size.width / 2 + tileSize / 2) / tileSize + centerX).floor(),
        ((s.dy - size.height / 2 + tileSize / 2) / tileSize + centerY).floor(),
      );
}

class DungeonPainter extends CustomPainter {
  DungeonPainter(this.c, this.atlas) : super(repaint: c);

  final GameController c;
  final SpriteAtlas atlas;

  /// Position interpolée d'un acteur pendant l'animation du tour.
  Offset renderPos(Actor a) {
    final prev = c.prevPos[a.id] ?? a.pos;
    final t = easeMove(c.turnT);
    return Offset(prev.x + (a.pos.x - prev.x) * t, prev.y + (a.pos.y - prev.y) * t);
  }

  Camera cameraFor(Size size) {
    final p = renderPos(c.game.player);
    return Camera(size, p.dx, p.dy);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final g = c.game;
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF0B0910));
    canvas.save();
    canvas.clipRect(Offset.zero & size);

    final shake = c.shake;
    if (shake > 0) {
      canvas.translate(math.sin(c.nowMs / 18) * shake, math.cos(c.nowMs / 23) * shake);
    }

    final cam = cameraFor(size);
    final ts = cam.tileSize;
    final halfW = (size.width / ts / 2).ceil() + 1;
    final halfH = (size.height / ts / 2).ceil() + 1;
    final cx = cam.centerX.round(), cy = cam.centerY.round();

    final theme = g.theme;
    final floorSet = theme.floorSet;
    final floorTint = Color(theme.floorTint);
    final wallTint = Color(theme.wallTint);
    final dim = Paint()..color = const Color(0x99000000);

    // --- Décor
    for (var y = cy - halfH; y <= cy + halfH; y++) {
      for (var x = cx - halfW; x <= cx + halfW; x++) {
        final p = Pos(x, y);
        if (!g.level.tiles.inBounds(p) || !g.explored.contains(p)) continue;
        final dst = cam.toScreen(x.toDouble(), y.toDouble()) & Size(ts + 0.5, ts + 0.5);
        final tile = g.level.tiles[p];
        final h = _hash(x, y, g.floor);
        if (tile == Tile.wall) {
          if (!_touchesFloor(p)) continue;
          atlas.draw(canvas, Sprites.wallVariants[h % Sprites.wallVariants.length], dst, tint: wallTint);
        } else {
          atlas.draw(canvas, floorSet[h % floorSet.length], dst, tint: floorTint);
          if (tile == Tile.stairsDown) atlas.draw(canvas, Sprites.stairsDown, dst);
        }
        if (!g.visible.contains(p)) canvas.drawRect(dst, dim);
      }
    }

    // --- Objets au sol
    for (final it in g.floorItems) {
      if (!g.explored.contains(it.pos)) continue;
      final dst = cam.toScreen(it.pos.x.toDouble(), it.pos.y.toDouble()) & Size(ts, ts);
      final sprite = it.item == null ? Sprites.coin : g.spriteOf(it.item!);
      final seen = g.visible.contains(it.pos);
      if (it.item != null && seen) {
        // Halo de la couleur de rareté.
        canvas.drawCircle(dst.center, ts * 0.32,
            Paint()..color = Color(it.item!.rarity.color).withValues(alpha: 0.22));
      }
      final itemTint = it.item == null ? null : g.tintOf(it.item!);
      atlas.draw(canvas, sprite, dst.deflate(ts * 0.12),
          opacity: seen ? 1 : 0.45, tint: itemTint == null ? null : Color(itemTint));
    }

    // --- Coffres (et mimiques déguisées, indiscernables)
    void drawChest(Pos p, int sprite) {
      if (!g.explored.contains(p)) return;
      final dst = cam.toScreen(p.x.toDouble(), p.y.toDouble()) & Size(ts, ts);
      atlas.draw(canvas, sprite, dst, opacity: g.visible.contains(p) ? 1 : 0.45);
    }

    for (final ch in g.chests) {
      drawChest(ch.pos, Sprites.chest);
    }
    // --- Lieux interactifs
    for (final f in g.features) {
      if (!g.explored.contains(f.pos)) continue;
      final dst = cam.toScreen(f.pos.x.toDouble(), f.pos.y.toDouble()) & Size(ts, ts);
      final seen = g.visible.contains(f.pos);
      atlas.draw(canvas, f.kind.sprite, dst, opacity: f.used ? 0.35 : (seen ? 1 : 0.5));
      if (!f.used && seen) _text(canvas, '?', dst.topCenter + Offset(0, -ts * 0.05), Palette.gold, ts * 0.28);
    }

    // --- Pièges repérés
    for (final t in g.traps) {
      if (!t.revealed || !g.explored.contains(t.pos)) continue;
      final r = (cam.toScreen(t.pos.x.toDouble(), t.pos.y.toDouble()) & Size(ts, ts)).deflate(ts * 0.22);
      final color = Color(t.kind.color).withValues(alpha: g.visible.contains(t.pos) ? 0.9 : 0.45);
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = ts * 0.07;
      canvas.drawRect(r, paint);
      canvas.drawLine(r.topLeft, r.bottomRight, paint);
      canvas.drawLine(r.topRight, r.bottomLeft, paint);
    }

    for (final m in g.monsters) {
      if (!m.disguised) continue;
      drawChest(m.pos, m.displaySprite);
      if (g.has('mimic_sense') && g.explored.contains(m.pos)) {
        // Talent « Flair à mimiques » : un point d'exclamation rouge trahit le monstre.
        final o = cam.toScreen(m.pos.x.toDouble(), m.pos.y.toDouble());
        _text(canvas, '!', o + Offset(ts * 0.8, ts * 0.15), const Color(0xFFFF4040), ts * 0.3);
      }
    }

    final t = c.turnT;

    // --- Monstres qui meurent ce tour-ci : flash puis fondu
    for (final e in c.turnEvents) {
      if (e is DeathEvent && !e.isPlayer && t < 1) {
        final dst = cam.toScreen(e.pos.x.toDouble(), e.pos.y.toDouble()) & Size(ts, ts);
        atlas.draw(canvas, e.sprite, dst, opacity: 1 - t, flash: const Color(0xFFFF4040));
      }
    }

    // --- Monstres puis joueur
    for (final m in g.monsters) {
      if (!g.visible.contains(m.pos) || m.disguised) continue;
      _drawActor(canvas, cam, m, t);
      if (t >= 1 && !g.gameOver) _drawIntent(canvas, cam, m);
      if (c.canTarget(m)) _drawReticle(canvas, cam, m.pos);
    }
    if (g.gameOver) {
      final dst = cam.toScreen(g.player.pos.x.toDouble(), g.player.pos.y.toDouble()) & Size(ts, ts);
      atlas.draw(canvas, Sprites.tomb, dst);
    } else {
      _drawActor(canvas, cam, g.player, t);
    }

    // --- Projectiles des tireurs
    if (t < 1) {
      for (final e in c.turnEvents) {
        if (e is! AttackEvent || !e.ranged) continue;
        final k = easeMove(t);
        final x = e.from.x + (e.to.x - e.from.x) * k, y = e.from.y + (e.to.y - e.from.y) * k;
        final center = cam.toScreen(x, y) + Offset(ts / 2, ts / 2);
        canvas.drawCircle(center, ts * 0.12, Paint()..color = const Color(0xFF000000));
        canvas.drawCircle(center, ts * 0.09, Paint()..color = const Color(0xFFFFE070));
      }
    }

    // --- Particules et traits de coups
    final now = c.nowMs;
    for (final p in c.fx.particles) {
      final age = (now - p.bornMs) / 1000;
      final life = (now - p.bornMs) / p.lifeMs;
      if (life >= 1 || life < 0) continue;
      final x = p.x + p.vx * age;
      final y = p.y + p.vy * age + 0.5 * p.gravity * age * age;
      final o = cam.toScreen(x - 0.5, y - 0.5) + Offset(ts / 2, ts / 2);
      final s = p.size * ts;
      canvas.drawRect(Rect.fromCenter(center: o, width: s, height: s),
          Paint()..color = p.color.withValues(alpha: (1 - life).clamp(0.0, 1.0)));
    }
    for (final sl in c.fx.slashes) {
      final k = ((now - sl.bornMs) / Slash.lifeMs).clamp(0.0, 1.0);
      final center = cam.toScreen(sl.x, sl.y) + Offset(ts / 2, ts / 2);
      final len = ts * 0.45 * (0.4 + 0.6 * k);
      final paint = Paint()
        ..color = sl.color.withValues(alpha: 1 - k)
        ..strokeWidth = ts * (sl.crit ? 0.11 : 0.08)
        ..strokeCap = StrokeCap.square;
      canvas.drawLine(center + Offset(-len, -len), center + Offset(len, len), paint);
      if (sl.crit) canvas.drawLine(center + Offset(len, -len), center + Offset(-len, len), paint);
    }

    // --- Textes flottants
    for (final f in c.floaters) {
      final age = (c.nowMs - f.bornMs) / GameController.floaterMs;
      final o = cam.toScreen(f.x, f.y - age * 0.9);
      final pop = 1 + 0.5 * (1 - age * 6).clamp(0.0, 1.0);
      _text(canvas, f.text, o + Offset(ts / 2, ts * 0.1), f.color.withValues(alpha: (1 - age).clamp(0, 1)),
          (f.big ? ts * 0.32 : ts * 0.26) * pop);
    }

    canvas.restore();

    // --- Fondu au noir à l'arrivée sur un étage.
    if (c.floorFade > 0) {
      canvas.drawRect(Offset.zero & size, Paint()..color = Color.fromRGBO(0, 0, 0, c.floorFade));
    }

    // --- Fin d'épisode : bords rouges quand la démolition approche, puis pendant.
    final left = g.turnsLeft;
    if (left <= 20 && !g.gameOver) {
      final strength = left < 0 ? 0.55 : 0.25 * (1 - left / 20);
      final rect = Offset.zero & size;
      canvas.drawRect(
        rect,
        Paint()
          ..shader = RadialGradient(
            radius: 0.9,
            colors: [const Color(0x00FF0000), Color.fromRGBO(200, 0, 0, strength)],
            stops: const [0.6, 1.0],
          ).createShader(rect),
      );
    }
  }

  void _drawActor(Canvas canvas, Camera cam, Actor a, double t) {
    final ts = cam.tileSize;
    var pos = renderPos(a);
    final prev = c.prevPos[a.id];
    if (prev != null && prev != a.pos && t < 1) {
      // Petit saut d'une case à l'autre.
      pos += Offset(0, -math.sin(t * math.pi) * 0.15);
    } else if ((c.idlePhase + a.id).isOdd) {
      // Respiration : un pixel de sprite vers le haut une image sur deux.
      pos += const Offset(0, -1 / 16);
    }
    Color? flash;
    if (a.primed && c.idlePhase.isOdd) flash = const Color(0xFFFF3030);
    for (final e in c.turnEvents) {
      if (e is AttackEvent) {
        if (e.attackerId == a.id && t < 1 && !e.ranged) {
          // Petit « bump » vers la cible.
          final k = math.sin(t * math.pi) * 0.35;
          pos += Offset((e.to.x - e.from.x) * k, (e.to.y - e.from.y) * k);
        }
        if (e.targetId == a.id && !e.miss && t < 0.7) flash = Colors.white;
      }
    }
    var dst = cam.toScreen(pos.dx, pos.dy) & Size(ts, ts);
    if (a.isBoss) {
      // Les boss sont plus gros, posés sur la même case.
      final big = ts * 1.45;
      dst = Rect.fromLTWH(dst.center.dx - big / 2, dst.bottom - big, big, big);
    }

    // Ombre portée.
    canvas.drawOval(
      Rect.fromCenter(center: dst.bottomCenter - Offset(0, ts * 0.1), width: ts * 0.6, height: ts * 0.16),
      Paint()..color = const Color(0x66000000),
    );
    if (a.isPlayer && c.levelUpGlow > 0) {
      final k = c.levelUpGlow;
      canvas.drawCircle(dst.center, ts * (0.5 + (1 - k) * 0.9),
          Paint()
            ..color = Color.fromRGBO(255, 216, 77, 0.6 * k)
            ..style = PaintingStyle.stroke
            ..strokeWidth = ts * 0.12);
    }
    if (a.isPlayer && c.game.rageTurns > 0) {
      // Aura rouge pendant la rage.
      canvas.drawCircle(dst.center, ts * 0.45, Paint()..color = const Color(0x55FF2020));
    }
    final tint = a.elite ? 0xFFFFD84D : a.monster?.tint;
    if (a.elite) {
      canvas.drawCircle(dst.center, ts * 0.5, Paint()..color = const Color(0x44FFD84D));
    }
    atlas.draw(canvas, a.displaySprite, dst, flash: flash, tint: tint == null ? null : Color(tint));
    if (a.elite) _text(canvas, '*', dst.topCenter + Offset(0, -ts * 0.08), const Color(0xFFFFD84D), ts * 0.35);
    if (a.primed) {
      // Kamikaze prêt à exploser : halo rouge et « !! ».
      canvas.drawCircle(dst.center, ts * 0.55, Paint()..color = const Color(0x66FF2020));
      _text(canvas, '!!', dst.topCenter + Offset(0, -ts * 0.05), const Color(0xFFFF4040), ts * 0.3);
    }
    if (a.enraged) {
      canvas.drawRect(dst, Paint()..color = const Color(0x22FF0000));
    }
    // Marqueurs d'altérations (petits carrés colorés).
    var i = 0;
    for (final s in a.statuses.keys) {
      final r = Rect.fromLTWH(dst.left + ts * 0.05 + i * ts * 0.17, dst.top + ts * 0.02, ts * 0.14, ts * 0.14);
      canvas.drawRect(r.inflate(1), Paint()..color = const Color(0xFF000000));
      canvas.drawRect(r, Paint()..color = Color(s.color));
      i++;
    }

    // Barre de vie des monstres blessés.
    if (!a.isPlayer && !a.isBoss && a.hp < a.maxHp) {
      final bar = Rect.fromLTWH(dst.left + ts * 0.15, dst.top - ts * 0.08, ts * 0.7, ts * 0.07);
      canvas.drawRect(bar.inflate(1), Paint()..color = const Color(0xFF000000));
      canvas.drawRect(bar, Paint()..color = const Color(0xFF5A1A1A));
      canvas.drawRect(
        Rect.fromLTWH(bar.left, bar.top, bar.width * a.hpRatio.clamp(0, 1), bar.height),
        Paint()..color = const Color(0xFFE04040),
      );
    }
  }

  /// Icône d'intention au-dessus du monstre (ce qu'il fera si on ne bouge pas).
  void _drawIntent(Canvas canvas, Camera cam, Actor m) {
    final (String glyph, Color color) = switch (c.game.intentOf(m)) {
      MonsterIntent.melee => ('!', const Color(0xFFFF5050)),
      MonsterIntent.prepare => ('...', const Color(0xFFFF9F40)),
      MonsterIntent.heavy => ('!!', const Color(0xFFFF2020)),
      MonsterIntent.shoot => ('>', const Color(0xFFFFE070)),
      MonsterIntent.reload => ('...', const Color(0xFF9A9A9A)),
      MonsterIntent.explode => ('**', const Color(0xFFFF4040)),
      MonsterIntent.heal => ('+', const Color(0xFF60FF80)),
      MonsterIntent.flee => ('<', const Color(0xFFFFFFFF)),
      MonsterIntent.sleep => ('z', const Color(0xFF8090FF)),
      MonsterIntent.erratic => ('?', const Color(0xFFC77DFF)),
      MonsterIntent.none => ('', const Color(0x00000000)),
    };
    if (glyph.isEmpty) return;
    final ts = cam.tileSize;
    final o = cam.toScreen(m.pos.x.toDouble(), m.pos.y.toDouble());
    final r = Rect.fromCenter(center: o + Offset(ts * 0.82, ts * 0.02), width: ts * 0.42, height: ts * 0.3);
    canvas.drawRect(r, Paint()..color = const Color(0xCC000000));
    canvas.drawRect(
        r,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
    _text(canvas, glyph, r.center, color, ts * 0.2);
  }

  /// Cible possible pendant la visée.
  void _drawReticle(Canvas canvas, Camera cam, Pos p) {
    final ts = cam.tileSize;
    final r = (cam.toScreen(p.x.toDouble(), p.y.toDouble()) & Size(ts, ts)).deflate(ts * 0.04);
    final paint = Paint()
      ..color = const Color(0xFFFFE070)
      ..style = PaintingStyle.stroke
      ..strokeWidth = ts * 0.06;
    final k = ts * 0.28;
    for (final (corner, dx, dy) in [
      (r.topLeft, 1.0, 1.0),
      (r.topRight, -1.0, 1.0),
      (r.bottomLeft, 1.0, -1.0),
      (r.bottomRight, -1.0, -1.0),
    ]) {
      canvas.drawLine(corner, corner + Offset(k * dx, 0), paint);
      canvas.drawLine(corner, corner + Offset(0, k * dy), paint);
    }
  }

  bool _touchesFloor(Pos p) {
    final tiles = c.game.level.tiles;
    for (var dy = -1; dy <= 1; dy++) {
      for (var dx = -1; dx <= 1; dx++) {
        final q = Pos(p.x + dx, p.y + dy);
        if (tiles.inBounds(q) && tiles[q].walkable) return true;
      }
    }
    return false;
  }

  /// Hachage 32 bits bien mélangé : variantes de sol réparties sans grappes.
  static int _hash(int x, int y, int f) {
    var h = (x * 73856093) ^ (y * 19349663) ^ (f * 83492791);
    h = ((h ^ (h >> 13)) * 0x5bd1e995) & 0xffffffff;
    h = ((h ^ (h >> 15)) * 0x27d4eb2d) & 0xffffffff;
    return (h ^ (h >> 16)) & 0x7fffffff;
  }

  void _text(Canvas canvas, String s, Offset center, Color color, double size) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          fontFamily: 'PressStart2P',
          fontSize: size,
          color: color,
          shadows: [Shadow(color: Colors.black.withValues(alpha: color.a), offset: const Offset(1.5, 1.5))],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(DungeonPainter old) => true;
}
