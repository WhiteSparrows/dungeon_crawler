import 'dart:convert';
import 'dart:ui' as ui;

import 'package:donjon_en_direct/content/monsters.dart';
import 'package:donjon_en_direct/content/tips.dart';
import 'package:donjon_en_direct/core/entities.dart';
import 'package:donjon_en_direct/core/game.dart';
import 'package:donjon_en_direct/core/grid.dart';
import 'package:donjon_en_direct/meta/profile.dart';
import 'package:donjon_en_direct/meta/profile_store.dart';
import 'package:donjon_en_direct/ui/render/sprite_atlas.dart';
import 'package:donjon_en_direct/ui/theme.dart';
import 'package:donjon_en_direct/ui/tutorial.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Game _calm(int seed) {
  final g = Game.newRun(seed);
  g.monsters.clear();
  g.chests.clear();
  g.floorItems.clear();
  g.features.clear();
  g.traps.clear();
  g.boss = null;
  g.floorMod = null;
  return g;
}

void main() {
  test('chaque conseil déclenché en jeu existe', () {
    final ids = tipDefs.map((t) => t.id).toSet();
    expect(ids.length, tipDefs.length, reason: 'identifiants uniques');
    final g = _calm(1);
    final seen = <String>{};
    // On épuise tous les conseils possibles dans cette situation : chacun doit exister.
    for (var i = 0; i < 30; i++) {
      final id = nextInGameTip(g, seen);
      if (id == null) break;
      expect(ids, contains(id));
      seen.add(id);
    }
  });

  test("ordre : bienvenue, puis déplacements, puis rien tant qu'il ne se passe rien", () {
    final g = _calm(2);
    expect(nextInGameTip(g, {}), 'welcome');
    expect(nextInGameTip(g, {'welcome'}), 'move');
    final seen = {'welcome', 'move'};
    final next = nextInGameTip(g, seen);
    expect(next, anyOf(isNull, 'stairs', 'bag', 'lootbox'), reason: 'situation calme : $next');
  });

  test('un monstre en vue déclenche son conseil', () {
    final g = _calm(3);
    final d = Dir.all.firstWhere((d) => g.isFree(g.player.pos + d.delta));
    final def = monsterById('rat');
    g.monsters.add(Actor(
        id: 900, name: def.name, sprite: def.sprite, pos: g.player.pos + d.delta, maxHp: 5, atk: 1, def: 0, monster: def));
    expect(nextInGameTip(g, {'welcome', 'move'}), 'monster');
    expect(nextInGameTip(g, {'welcome', 'move', 'monster'}), 'skill', reason: 'monstre au contact, pouvoir prêt');
  });

  test('fin de partie : seul le conseil de fin', () {
    final g = _calm(4)..abandon();
    expect(nextInGameTip(g, {}), 'gameover');
    expect(nextInGameTip(g, {'gameover'}), isNull);
  });

  test('profil : conseils vus et réglage conservés', () {
    final store = ProfileStore.memory();
    expect(store.takeTip('welcome'), isTrue);
    expect(store.takeTip('welcome'), isFalse, reason: 'une seule fois');
    store.setTips(false);
    expect(store.takeTip('move'), isFalse, reason: 'conseils coupés');
    final p = Profile.fromJson((jsonDecode(jsonEncode(store.profile.toJson())) as Map).cast<String, Object?>());
    expect(p.seenTips, contains('welcome'));
    expect(p.tipsOn, isFalse);
    store.resetTips();
    expect(store.profile.seenTips, isEmpty);
    expect(store.profile.tipsOn, isTrue);
  });

  testWidgets('fiche de conseil : COMPRIS ferme, « couper » coupe', (tester) async {
    tester.view.physicalSize = const Size(1080, 2220);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    final atlas = (await tester.runAsync(() async {
      final rec = ui.PictureRecorder();
      Canvas(rec).drawRect(const Rect.fromLTWH(0, 0, 192, 176), Paint());
      return SpriteAtlas(await rec.endRecording().toImage(192, 176));
    }))!;
    bool? result;
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(),
      home: Scaffold(
        body: Builder(
          builder: (ctx) => TextButton(
            onPressed: () async => result = await showTip(ctx, atlas, 'welcome'),
            child: const Text('go'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text('CONSEIL DE MAESTRO'), findsOneWidget);
    expect(find.text(tipById('welcome').title), findsOneWidget);
    await tester.tap(find.text('COMPRIS'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Couper les conseils'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
    expect(tester.takeException(), isNull);
  });
}
