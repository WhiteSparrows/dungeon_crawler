/// Position sur la grille.
class Pos {
  const Pos(this.x, this.y);

  final int x;
  final int y;

  Pos operator +(Pos o) => Pos(x + o.x, y + o.y);
  Pos operator -(Pos o) => Pos(x - o.x, y - o.y);

  /// Distance de Manhattan.
  int manhattan(Pos o) => (x - o.x).abs() + (y - o.y).abs();

  /// Distance de Tchebychev (déplacement 8 directions).
  int chebyshev(Pos o) {
    final dx = (x - o.x).abs();
    final dy = (y - o.y).abs();
    return dx > dy ? dx : dy;
  }

  bool isAdjacent4(Pos o) => manhattan(o) == 1;

  Iterable<Pos> get neighbors4 => Dir.all.map((d) => this + d.delta);

  @override
  bool operator ==(Object other) => other is Pos && other.x == x && other.y == y;

  @override
  int get hashCode => x * 73856093 ^ y * 19349663;

  @override
  String toString() => '($x,$y)';
}

/// Les 4 directions de déplacement (jeu pensé pour le tactile).
enum Dir {
  up(Pos(0, -1)),
  down(Pos(0, 1)),
  left(Pos(-1, 0)),
  right(Pos(1, 0));

  const Dir(this.delta);
  final Pos delta;

  static const all = [Dir.up, Dir.down, Dir.left, Dir.right];

  static Dir? fromDelta(Pos d) {
    for (final dir in all) {
      if (dir.delta == d) return dir;
    }
    return null;
  }
}

enum Tile { wall, floor, stairsDown }

extension TileProps on Tile {
  bool get walkable => this != Tile.wall;
  bool get blocksSight => this == Tile.wall;
}

/// Grille 2D générique.
class Grid<T> {
  Grid(this.width, this.height, T fill) : _cells = List<T>.filled(width * height, fill);

  final int width;
  final int height;
  final List<T> _cells;

  bool inBounds(Pos p) => p.x >= 0 && p.y >= 0 && p.x < width && p.y < height;

  T operator [](Pos p) => _cells[p.y * width + p.x];
  void operator []=(Pos p, T v) => _cells[p.y * width + p.x] = v;

  T get(int x, int y) => _cells[y * width + x];
  void set(int x, int y, T v) => _cells[y * width + x] = v;
}

/// Rectangle (salle) sur la grille.
class Room {
  const Room(this.x, this.y, this.w, this.h);

  final int x;
  final int y;
  final int w;
  final int h;

  int get x2 => x + w - 1;
  int get y2 => y + h - 1;
  Pos get center => Pos(x + w ~/ 2, y + h ~/ 2);

  bool contains(Pos p) => p.x >= x && p.x <= x2 && p.y >= y && p.y <= y2;

  /// Vrai si les salles se chevauchent en gardant [margin] cases d'écart.
  bool intersects(Room o, {int margin = 1}) =>
      x - margin <= o.x2 && x2 + margin >= o.x && y - margin <= o.y2 && y2 + margin >= o.y;

  Iterable<Pos> get cells sync* {
    for (var j = y; j <= y2; j++) {
      for (var i = x; i <= x2; i++) {
        yield Pos(i, j);
      }
    }
  }
}
