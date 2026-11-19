import 'dart:ui' as ui;

import 'package:donjon_en_direct/content/items.dart';
import 'package:donjon_en_direct/core/entities.dart';
import 'package:donjon_en_direct/ui/game_controller.dart';
import 'package:donjon_en_direct/ui/render/sprite_atlas.dart';
import 'package:donjon_en_direct/core/game.dart';
import 'package:donjon_en_direct/content/achievements.dart';
import 'package:donjon_en_direct/meta/profile.dart';
import 'package:donjon_en_direct/meta/profile_store.dart';
import 'package:donjon_en_direct/ui/screens/achievements_screen.dart';
import 'package:donjon_en_direct/content/features.dart';
import 'package:donjon_en_direct/core/grid.dart';
import 'package:donjon_en_direct/ui/screens/feature_dialog.dart';
import 'package:donjon_en_direct/ui/screens/hub_screen.dart';
import 'package:donjon_en_direct/ui/screens/backstage_screen.dart';
import 'package:donjon_en_direct/ui/screens/inventory_sheet.dart';
import 'package:donjon_en_direct/ui/screens/loot_box_dialog.dart';
import 'package:donjon_en_direct/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Atlas factice (image vide) : on teste la mise en page, pas les pixels.
Future<SpriteAtlas> _fakeAtlas() async {
  final rec = ui.PictureRecorder();
  Canvas(rec).drawRect(const Rect.fromLTWH(0, 0, 192, 176), Paint());
  return SpriteAtlas(await rec.endRecording().toImage(192, 176));
}

class _Host extends StatefulWidget {
  const _Host(this.builder);
  final Widget Function(BuildContext, GameController) builder;
  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> with TickerProviderStateMixin {
  late final c = GameController(this, 42);
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, c);
}

void main() {
  testWidgets('ouvrir une loot box affiche le butin', (tester) async {
    tester.view.physicalSize = const Size(1080, 2220);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    final atlas = (await tester.runAsync(_fakeAtlas))!;
    late GameController ctrl;
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(),
      home: _Host((context, c) {
        ctrl = c;
        return Scaffold(
          body: Builder(
            builder: (ctx) => TextButton(onPressed: () => LootBoxDialog.show(ctx, c, atlas), child: const Text('go')),
          ),
        );
      }),
    ));
    ctrl.game.debugGrantBox(BoxTier.or);
    ctrl.game.debugGrantBox(BoxTier.bronze);
    await tester.tap(find.text('go'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('OR'), findsOneWidget);
    expect(find.text('Touchez la boîte !'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('closed-box')));
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text('FERMER'), findsOneWidget);
    expect(find.textContaining('SUIVANTE'), findsOneWidget);
    expect(ctrl.game.pendingBoxes.length, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets("plateau d'interview puis coulisses puis retour en scène", (tester) async {
    tester.view.physicalSize = const Size(1080, 2220);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    final atlas = (await tester.runAsync(_fakeAtlas))!;
    late GameController ctrl;
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(),
      home: _Host((context, c) {
        ctrl = c;
        return Scaffold(
          body: Builder(
            builder: (ctx) => TextButton(
              onPressed: () => Navigator.of(ctx).push(MaterialPageRoute<void>(
                builder: (_) => BackstageScreen(c: c, atlas: atlas),
              )),
              child: const Text('go'),
            ),
          ),
        );
      }),
    ));
    final g = ctrl.game;
    g.monsters.clear();
    g.player.pos = g.level.stairs;
    g.act(const DescendAction());
    expect(g.backstage, isNotNull);
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text('EN DIRECT DU PLATEAU'), findsOneWidget);

    // Deux questions : on répond à chacune.
    for (var q = 0; q < g.backstage!.questions.length; q++) {
      final answer = g.withSponsors(g.backstage!.question!.answers.first.text);
      await tester.tap(find.text('« $answer »').last);
      await tester.pumpAndSettle();
    }
    expect(find.textContaining('LE PUBLIC'), findsWidgets);
    await tester.tap(find.text('PASSER EN COULISSES'));
    await tester.pumpAndSettle();
    expect(find.text('COULISSES'), findsOneWidget);
    await tester.tap(find.text('PRENDRE').first);
    await tester.pumpAndSettle();
    expect(g.talents, hasLength(1));
    await tester.tap(find.text('RETOUR EN SCENE'));
    await tester.pumpAndSettle();
    expect(g.backstage, isNull);
    expect(g.floor, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets("tableau d'honneur : commentaire visible si obtenu, secret caché sinon", (tester) async {
    tester.view.physicalSize = const Size(1080, 2220);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    final atlas = (await tester.runAsync(_fakeAtlas))!;
    final first = achievementById('first_blood');
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(),
      home: AchievementsScreen(unlocked: {'first_blood'}, atlas: atlas),
    ));
    expect(find.text('1/${achievementDefs.length}'), findsOneWidget);
    expect(find.text(first.flavor), findsOneWidget);
    expect(find.text(achievementById('poisoned').name), findsNothing, reason: 'succès secret non obtenu');
    expect(find.text('???'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Loge des stars : signer un rôle puis acheter un contrat', (tester) async {
    tester.view.physicalSize = const Size(1080, 2220);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    final atlas = (await tester.runAsync(_fakeAtlas))!;
    final store = ProfileStore.memory(Profile()..royalties = 100);
    await tester.pumpWidget(MaterialApp(theme: buildTheme(), home: HubScreen(store: store, atlas: atlas)));
    expect(find.text('LOGE DES STARS'), findsOneWidget);
    await tester.tap(find.text('SIGNER : 60'));
    await tester.pump();
    expect(store.profile.roles, contains('concierge'));
    expect(store.profile.selectedRole, 'concierge');
    expect(store.profile.royalties, 40);
    await tester.tap(find.text('CONTRATS'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '40').first);
    await tester.pump();
    expect(store.profile.level('health'), 1);
    expect(store.profile.royalties, 0);
    await tester.tap(find.text('REDIFFUSIONS'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Aucune rediffusion'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('lieu interactif : choisir une option puis continuer', (tester) async {
    tester.view.physicalSize = const Size(1080, 2220);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    final atlas = (await tester.runAsync(_fakeAtlas))!;
    late GameController ctrl;
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(),
      home: _Host((context, c) {
        ctrl = c;
        return Scaffold(
          body: Builder(
            builder: (ctx) => TextButton(
              onPressed: () => FeatureDialog.show(ctx, c, atlas, c.game.activeFeature!),
              child: const Text('go'),
            ),
          ),
        );
      }),
    ));
    final g = ctrl.game;
    g.monsters.clear();
    g.features.clear();
    final d = Dir.all.firstWhere((d) => g.isFree(g.player.pos + d.delta));
    g.features.add(Feature(g.player.pos + d.delta, FeatureKind.fountain));
    g.act(MoveAction(d));
    expect(g.activeFeature, isNotNull);
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text('Fontaine douteuse'), findsOneWidget);
    await tester.tap(find.text('Boire une gorgée'));
    await tester.pumpAndSettle();
    expect(find.text('CONTINUER'), findsOneWidget);
    await tester.tap(find.text('CONTINUER'));
    await tester.pumpAndSettle();
    expect(g.activeFeature, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets("le sac s'affiche et permet d'équiper", (tester) async {
    tester.view.physicalSize = const Size(1080, 2220);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    final atlas = (await tester.runAsync(_fakeAtlas))!;
    late GameController ctrl;
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(),
      home: _Host((context, c) {
        ctrl = c;
        return Scaffold(
          body: Builder(
            builder: (ctx) => TextButton(onPressed: () => InventorySheet.show(ctx, c, atlas), child: const Text('go')),
          ),
        );
      }),
    ));
    ctrl.game.monsters.clear();
    ctrl.game.inventory.add(InvItem(itemById('guard_sword')));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text('SAC'), findsOneWidget);
    expect(find.text('Couteau à beurre'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('inv-guard_sword')));
    await tester.pump();
    expect(find.text('EQUIPER'), findsOneWidget);
    await tester.tap(find.text('EQUIPER'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(ctrl.game.weapon?.id, 'guard_sword');
    expect(tester.takeException(), isNull);
  });
}
