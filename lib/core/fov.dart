import 'grid.dart';

/// Champ de vision par « shadowcasting » récursif (8 octants).
Set<Pos> computeFov(Pos origin, int radius, bool Function(Pos) blocksSight, bool Function(Pos) inBounds) {
  final visible = <Pos>{origin};
  const mult = [
    [1, 0, 0, -1, -1, 0, 0, 1],
    [0, 1, -1, 0, 0, -1, 1, 0],
    [0, 1, 1, 0, 0, -1, -1, 0],
    [1, 0, 0, 1, -1, 0, 0, -1],
  ];
  for (var oct = 0; oct < 8; oct++) {
    _castLight(origin, radius, 1, 1.0, 0.0, mult[0][oct], mult[1][oct], mult[2][oct], mult[3][oct],
        blocksSight, inBounds, visible);
  }
  return visible;
}

void _castLight(
  Pos o,
  int radius,
  int row,
  double start,
  double end,
  int xx,
  int xy,
  int yx,
  int yy,
  bool Function(Pos) blocks,
  bool Function(Pos) inBounds,
  Set<Pos> visible,
) {
  if (start < end) return;
  final r2 = radius * radius;
  var newStart = 0.0;
  for (var j = row; j <= radius; j++) {
    var dx = -j - 1;
    final dy = -j;
    var blocked = false;
    while (dx <= 0) {
      dx++;
      final p = Pos(o.x + dx * xx + dy * xy, o.y + dx * yx + dy * yy);
      final lSlope = (dx - 0.5) / (dy + 0.5);
      final rSlope = (dx + 0.5) / (dy - 0.5);
      if (start < rSlope) continue;
      if (end > lSlope) break;
      if (!inBounds(p)) continue;
      if (dx * dx + dy * dy <= r2) visible.add(p);
      if (blocked) {
        if (blocks(p)) {
          newStart = rSlope;
        } else {
          blocked = false;
          start = newStart;
        }
      } else if (blocks(p) && j < radius) {
        blocked = true;
        _castLight(o, radius, j + 1, start, lSlope, xx, xy, yx, yy, blocks, inBounds, visible);
        newStart = rSlope;
      }
    }
    if (blocked) break;
  }
}
