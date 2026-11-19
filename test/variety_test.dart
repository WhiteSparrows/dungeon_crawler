import 'package:donjon_en_direct/content/features.dart';
import 'package:donjon_en_direct/content/items.dart';
import 'package:donjon_en_direct/content/monsters.dart';
import 'package:donjon_en_direct/content/status.dart';
import 'package:donjon_en_direct/core/entities.dart';
import 'package:donjon_en_direct/core/events.dart';
import 'package:donjon_en_direct/core/game.dart';
import 'package:donjon_en_direct/core/grid.dart';
import 'package:flutter_test/flutter_test.dart';

Game _calm(int seed) {
  final g = Game.newRun(seed);
  g.monsters.clear();
  g.chests.clear();
  g.floorItems.clear();
  g.features.clear();
  g.traps.clear();
  g.boss = null;
  return g;
}

Dir _freeDir(Game g) => Dir.all.firstWhere((d) => g.isFree(g.player.pos + d.delta));

void main() {
  group('Lieux interactifs', () {
    test("s'approcher ouvre un choix gratuit et bloque le jeu jusqu'au choix", () {
      final g = _calm(1);
      final d = _freeDir(g);
      g.features.add(Feature(g.player.pos + d.delta, FeatureKind.fountain));
      final t = g.turn;
      final ev = g.act(MoveAction(d));
      expect(ev.whereType<FeatureEvent>(), isNotEmpty);
      expect(g.activeFeature, isNotNull);
      expect(g.turn, t, reason: "ouvrir le choix ne coûte pas de tour");
      expect(g.act(const WaitAction()), isEmpty);
      final r = g.chooseFeature(0);
      expect(r.text, isNotEmpty);
      expect(g.activeFeature, isNull);
      expect(g.features.single.used, isTrue);
      // Déjà utilisé : simple message.
      expect(g.act(MoveAction(d)).whereType<MessageEvent>().single.text, contains('déjà utilisé'));
    });

    test('passer son chemin ne consomme pas le lieu', () {
      final g = _calm(2);
      final d = _freeDir(g);
      g.features.add(Feature(g.player.pos + d.delta, FeatureKind.mouth));
      g.act(MoveAction(d));
      g.chooseFeature(FeatureKind.mouth.options.length - 1);
      expect(g.features.single.used, isFalse);
      expect(g.activeFeature, isNull);
    });

    test("pas assez d'or : le dialogue reste ouvert", () {
      final g = _calm(3);
      g.gold = 0;
      final d = _freeDir(g);
      g.features.add(Feature(g.player.pos + d.delta, FeatureKind.vending));
      g.act(MoveAction(d));
      final r = g.chooseFeature(0);
      expect(r.closed, isFalse);
      expect(g.activeFeature, isNotNull);
      g.gold = 100;
      g.chooseFeature(0);
      expect(g.gold, 85);
      expect(g.healPotions, 2);
      expect(g.features.single.used, isFalse, reason: "on peut racheter au distributeur");
    });

    test('prier un sponsor coûte des PV et le satisfait', () {
      final g = _calm(4);
      final d = _freeDir(g);
      g.features.add(Feature(g.player.pos + d.delta, FeatureKind.shrine, sponsorIndex: 1));
      final before = g.show.sponsors[1].satisfaction;
      final hp = g.player.hp;
      g.act(MoveAction(d));
      g.chooseFeature(0);
      expect(g.player.hp, lessThan(hp));
      expect(g.show.sponsors[1].satisfaction, greaterThan(before));
    });
  });

  group('Pièges', () {
    test('les pics blessent et se révèlent', () {
      final g = _calm(5);
      final d = _freeDir(g);
      g.traps.add(Trap(g.player.pos + d.delta, TrapKind.spikes));
      final hp = g.player.hp;
      final ev = g.act(MoveAction(d));
      expect(ev.whereType<TrapEvent>(), isNotEmpty);
      expect(g.player.hp, lessThan(hp));
      expect(g.traps.single.revealed, isTrue);
    });

    test('le canon à confettis gêne', () {
      final g = _calm(6);
      final d = _freeDir(g);
      g.traps.add(Trap(g.player.pos + d.delta, TrapKind.confetti));
      g.act(MoveAction(d));
      expect(g.player.hasStatus(Status.embarrassed), isTrue);
    });

    test("la trappe fait tomber à l'étage suivant sans interview", () {
      final g = _calm(7);
      final d = _freeDir(g);
      g.traps.add(Trap(g.player.pos + d.delta, TrapKind.trapdoor));
      g.act(MoveAction(d));
      expect(g.floor, 2);
      expect(g.backstage, isNull);
      expect(g.player.alive, isTrue);
    });
  });

  group("Modificateurs d'étage", () {
    test('chaque modificateur finit par apparaître', () {
      final seen = <FloorMod>{};
      for (var seed = 0; seed < 60 && seen.length < FloorMod.values.length; seed++) {
        final g = Game.newRun(seed);
        for (var f = 0; f < 4; f++) {
          g.boss = null;
          g.monsters.clear();
          g.player.pos = g.level.stairs;
          g.act(const DescendAction());
          g.leaveBackstage();
          if (g.floorMod != null) seen.add(g.floorMod!);
        }
      }
      expect(seen, containsAll(FloorMod.values));
    });

    test('panne de courant : vision réduite', () {
      final g = _calm(8);
      g.floorMod = FloorMod.blackout;
      expect(g.sightRadius, 3);
    });
  });

  test('sifflet : étourdit les monstres au contact', () {
    final g = _calm(9);
    final d = _freeDir(g);
    final def = monsterById('rat');
    final rat = Actor(
        id: 500, name: def.name, sprite: def.sprite, pos: g.player.pos + d.delta, maxHp: 50, atk: 1, def: 0, monster: def);
    g.monsters.add(rat);
    g.inventory.add(InvItem(whistle));
    final ev = g.act(const UseItemAction('whistle'));
    expect(ev.whereType<MessageEvent>().any((m) => m.text.contains('Carton rouge')), isTrue);
    expect(rat.hasStatus(Status.stun), isTrue);
  });
}
