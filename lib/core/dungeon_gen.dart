import 'grid.dart';
import 'pathfinding.dart';
import 'rng.dart';

/// Un étage généré : tuiles, salles, départ et escalier.
class Level {
  Level({
    required this.tiles,
    required this.rooms,
    required this.start,
    required this.stairs,
  });

  final Grid<Tile> tiles;
  final List<Room> rooms;
  final Pos start;
  final Pos stairs;

  int get width => tiles.width;
  int get height => tiles.height;

  bool walkable(Pos p) => tiles.inBounds(p) && tiles[p].walkable;
}

/// Génère un étage « salles + couloirs », garanti connexe.
class DungeonGenerator {
  DungeonGenerator(this.rng, {this.width = 36, this.height = 36});

  final Rng rng;
  final int width;
  final int height;

  Level generate({int floor = 1}) {
    final tiles = Grid<Tile>(width, height, Tile.wall);
    final rooms = <Room>[];
    final targetRooms = 7 + rng.range(0, 3) + (floor ~/ 3);

    for (var attempt = 0; attempt < 200 && rooms.length < targetRooms; attempt++) {
      final w = rng.range(4, 8);
      final h = rng.range(4, 7);
      final x = rng.range(1, width - w - 2);
      final y = rng.range(1, height - h - 2);
      final room = Room(x, y, w, h);
      if (rooms.any((r) => r.intersects(room))) continue;
      _carveRoom(tiles, room);
      if (rooms.isNotEmpty) _carveCorridor(tiles, rooms.last.center, room.center);
      rooms.add(room);
    }

    // Quelques boucles pour éviter les culs-de-sac et permettre de fuir.
    final extraLinks = rng.range(1, 3);
    for (var i = 0; i < extraLinks && rooms.length > 3; i++) {
      final a = rng.pick(rooms);
      final b = rng.pick(rooms);
      if (a != b) _carveCorridor(tiles, a.center, b.center);
    }

    final startRoom = rooms.first;
    final start = startRoom.center;

    // L'escalier va dans la salle la plus éloignée (en chemin réel) du départ.
    final dist = distanceMap(tiles, start, (p) => tiles[p].walkable);
    var stairsRoom = rooms.last;
    var best = -1;
    for (final r in rooms.skip(1)) {
      final d = dist[r.center] ?? -1;
      if (d > best) {
        best = d;
        stairsRoom = r;
      }
    }
    final stairs = stairsRoom.center;
    tiles[stairs] = Tile.stairsDown;

    return Level(tiles: tiles, rooms: rooms, start: start, stairs: stairs);
  }

  void _carveRoom(Grid<Tile> tiles, Room r) {
    for (final p in r.cells) {
      tiles[p] = Tile.floor;
    }
  }

  void _carveCorridor(Grid<Tile> tiles, Pos a, Pos b) {
    final horizontalFirst = rng.chance(0.5);
    if (horizontalFirst) {
      _hLine(tiles, a.x, b.x, a.y);
      _vLine(tiles, a.y, b.y, b.x);
    } else {
      _vLine(tiles, a.y, b.y, a.x);
      _hLine(tiles, a.x, b.x, b.y);
    }
  }

  void _hLine(Grid<Tile> tiles, int x1, int x2, int y) {
    for (var x = x1 < x2 ? x1 : x2; x <= (x1 < x2 ? x2 : x1); x++) {
      if (tiles.get(x, y) == Tile.wall) tiles.set(x, y, Tile.floor);
    }
  }

  void _vLine(Grid<Tile> tiles, int y1, int y2, int x) {
    for (var y = y1 < y2 ? y1 : y2; y <= (y1 < y2 ? y2 : y1); y++) {
      if (tiles.get(x, y) == Tile.wall) tiles.set(x, y, Tile.floor);
    }
  }
}
