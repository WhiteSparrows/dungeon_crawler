import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Planche de sprites 16x16 (Kenney Tiny Dungeon, 12 colonnes).
class SpriteAtlas {
  SpriteAtlas(this.image);

  static const tile = 16.0;
  static const columns = 12;

  final ui.Image image;

  static Future<SpriteAtlas> load() async {
    final data = await rootBundle.load('assets/sprites/tiny_dungeon.png');
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    return SpriteAtlas(frame.image);
  }

  Rect src(int index) => Rect.fromLTWH((index % columns) * tile, (index ~/ columns) * tile, tile, tile);

  /// Dessine la tuile [index] dans [dst] en pixels nets.
  void draw(Canvas canvas, int index, Rect dst, {double opacity = 1, Color? flash, Color? tint}) {
    final paint = Paint()
      ..filterQuality = FilterQuality.none
      ..isAntiAlias = false
      ..color = Color.fromRGBO(255, 255, 255, opacity);
    if (flash != null) {
      paint.colorFilter = ColorFilter.mode(flash, BlendMode.srcATop);
    } else if (tint != null) {
      paint.colorFilter = ColorFilter.mode(tint, BlendMode.modulate);
    }
    canvas.drawImageRect(image, src(index), dst, paint);
  }
}

/// Petit widget pour afficher un sprite dans l'interface.
class SpriteIcon extends StatelessWidget {
  const SpriteIcon(this.atlas, this.index, {super.key, this.size = 32});

  final SpriteAtlas atlas;
  final int index;
  final double size;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _SpritePainter(atlas, index));
}

class _SpritePainter extends CustomPainter {
  _SpritePainter(this.atlas, this.index);

  final SpriteAtlas atlas;
  final int index;

  @override
  void paint(Canvas canvas, Size size) => atlas.draw(canvas, index, Offset.zero & size);

  @override
  bool shouldRepaint(_SpritePainter old) => old.index != index;
}
