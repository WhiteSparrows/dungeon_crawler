import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter/foundation.dart';

import '../../content/achievements.dart';
import '../../content/features.dart';
import '../../content/items.dart';
import '../../content/sprites.dart';
import '../../core/events.dart';
import '../../core/game.dart';
import '../../meta/profile.dart';
import '../../meta/profile_store.dart';
import '../../core/grid.dart';
import '../../core/show.dart';
import '../game_controller.dart';
import '../render/dungeon_painter.dart';
import '../render/sprite_atlas.dart';
import '../audio.dart';
import '../theme.dart';
import 'achievements_screen.dart';
import '../tutorial.dart';
import 'backstage_screen.dart';
import 'feature_dialog.dart';
import 'inventory_sheet.dart';
import 'regie_sheet.dart';
import 'loot_box_dialog.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.atlas, required this.store, this.daily = false, this.resume});

  final SpriteAtlas atlas;
  final ProfileStore store;

  /// Défi du jour : graine du jour, rôle de base, aucun contrat.
  final bool daily;

  /// Partie sauvegardée à reprendre (déjà reconstruite).
  final Game? resume;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  late GameController c;
  late DungeonPainter painter;
  final _focus = FocusNode();

  /// Bilan de fin de run (droits d'auteur), calculé une seule fois.
  RunSummary? _summary;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    GameAudio.instance.music(Music.dungeon);
    _newRun(resume: widget.resume);
    // Une partie reprise peut être en pleine interview.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _watchBackstage();
      _watchFeature();
      _watchTips();
    });
  }

  /// L'appli passe en arrière-plan (appel, autre appli, écran éteint) : on sauvegarde.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) widget.store.saveRun(c.game);
  }

  bool _backstageOpen = false;

  void _newRun({Game? resume}) {
    if (resume != null) {
      c = GameController.resume(this, resume);
    } else {
      final seed = widget.daily ? dailySeed(DateTime.now()) : DateTime.now().microsecondsSinceEpoch & 0x7fffffff;
      c = GameController(this, seed, setup: widget.store.profile.setupFor(daily: widget.daily));
    }
    c.vibrations = widget.store.profile.vibrations;
    c.startIdle();
    c.addListener(_watchBackstage);
    c.addListener(_watchFeature);
    c.addListener(_watchTips);
    c.addListener(_watchGameOver);
    painter = DungeonPainter(c, widget.atlas);
    _summary = null;
  }

  /// Fin de run : on encaisse les droits d'auteur et on sauvegarde le profil.
  void _watchGameOver() {
    if (!c.game.gameOver || _summary != null) return;
    _summary = widget.store.recordRun(c.game);
    widget.store.clearRun();
  }

  /// Succès connus : ceux du profil plus ceux de la run en cours.
  Set<String> get _allAchievements => {...widget.store.profile.achievements, ...c.game.unlocked};

  /// Quitter en pleine run : pause (sauvegarde) ou abandon (enregistré).
  Future<void> _confirmQuit() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Palette.panel,
        shape: const RoundedRectangleBorder(side: BorderSide(color: Palette.hp, width: 2)),
        title: Text("QUITTER L'EMISSION ?", style: pixel(11, color: Palette.hp)),
        content: const Text(
          "PAUSE : la partie est sauvegardée, vous la reprendrez depuis le menu.\n\n"
          "ABANDON : MAESTRO : « Abandonner en direct ? Quelle audace. Quelle lâcheté. "
          "Vous toucherez quand même vos droits d'auteur, on n'est pas des monstres. Enfin si, mais pas ceux-là. »",
          style: TextStyle(color: Palette.text, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop('stay'), child: Text('RESTER', style: pixel(8))),
          OutlinedButton(
            style: OutlinedButton.styleFrom(shape: const RoundedRectangleBorder(), side: const BorderSide(color: Palette.gold)),
            onPressed: () => Navigator.of(ctx).pop('pause'),
            child: Text('PAUSE', style: pixel(8, color: Palette.gold)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Palette.hp, shape: const RoundedRectangleBorder()),
            onPressed: () => Navigator.of(ctx).pop('quit'),
            child: Text('ABANDON', style: pixel(8, color: Palette.text)),
          ),
        ],
      ),
    );
    if (!mounted || choice == null || choice == 'stay') return;
    if (choice == 'pause') {
      await widget.store.saveRun(c.game);
    } else {
      c.game.abandon();
      _watchGameOver();
    }
    if (mounted) Navigator.of(context).pop();
  }

  bool _featureOpen = false;
  bool _tipOpen = false;

  /// Conseils de MAESTRO : un à la fois, quand rien d'autre n'est ouvert.
  void _watchTips() {
    final p = widget.store.profile;
    if (!p.tipsOn || _tipOpen || _backstageOpen || _featureOpen || c.animating) return;
    final id = nextInGameTip(c.game, p.seenTips);
    if (id == null) return;
    _tipOpen = true;
    widget.store.markTip(id);
    c.stopAutoWalk();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      // Laisse l'écran de fin s'afficher avant le conseil de fin de partie.
      if (id == 'gameover') await Future<void>.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      final off = await showTip(context, widget.atlas, id);
      if (off) widget.store.setTips(false);
      _tipOpen = false;
      _focus.requestFocus();
      if (mounted) _watchTips();
    });
  }

  /// Le joueur s'approche d'un lieu interactif : dialogue de choix.
  void _watchFeature() {
    final f = c.game.activeFeature;
    if (f == null || _featureOpen) return;
    _featureOpen = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await FeatureDialog.show(context, c, widget.atlas, f);
      _featureOpen = false;
      _focus.requestFocus();
    });
  }

  /// Dès que le joueur quitte l'étage, on ouvre le plateau d'interview.
  void _watchBackstage() {
    if (c.game.backstage == null || _backstageOpen) return;
    _backstageOpen = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      GameAudio.instance
        ..play(Sfx.jingle)
        ..music(Music.show);
      await Navigator.of(context).push(
        PageRouteBuilder<void>(
          pageBuilder: (_, _, _) => BackstageScreen(c: c, atlas: widget.atlas, store: widget.store),
          transitionsBuilder: (_, anim, _, child) => FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
      _backstageOpen = false;
      GameAudio.instance.music(Music.dungeon);
      _focus.requestFocus();
    });
  }

  Future<void> _openRegie() async {
    await RegieSheet.show(context, c);
    _focus.requestFocus();
  }

  void _restart() {
    final old = c;
    setState(_newRun);
    old.dispose();
  }

  @override
  void dispose() {
    GameAudio.instance.music(Music.show);
    WidgetsBinding.instance.removeObserver(this);
    c.dispose();
    _focus.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.arrowUp || k == LogicalKeyboardKey.keyW || k == LogicalKeyboardKey.keyZ) {
      c.move(Dir.up);
    } else if (k == LogicalKeyboardKey.arrowDown || k == LogicalKeyboardKey.keyS) {
      c.move(Dir.down);
    } else if (k == LogicalKeyboardKey.arrowLeft || k == LogicalKeyboardKey.keyA || k == LogicalKeyboardKey.keyQ) {
      c.move(Dir.left);
    } else if (k == LogicalKeyboardKey.arrowRight || k == LogicalKeyboardKey.keyD) {
      c.move(Dir.right);
    } else if (k == LogicalKeyboardKey.space || k == LogicalKeyboardKey.period) {
      c.wait();
    } else if (k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.greater) {
      c.descend();
    } else if (k == LogicalKeyboardKey.keyP) {
      c.quaff();
    } else if (k == LogicalKeyboardKey.keyH) {
      c.setMode(CombatMode.heavy);
    } else if (k == LogicalKeyboardKey.keyG) {
      c.setMode(CombatMode.shove);
    } else if (k == LogicalKeyboardKey.keyF) {
      c.parry();
    } else if (k == LogicalKeyboardKey.keyT) {
      c.toggleShoot();
    } else if (k == LogicalKeyboardKey.keyK) {
      c.skill();
    } else if (k == LogicalKeyboardKey.keyI) {
      _openBag();
    } else if (k == LogicalKeyboardKey.keyB) {
      _openBox();
    } else if (k == LogicalKeyboardKey.keyR && c.game.gameOver) {
      _restart();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  Future<void> _openBag() async {
    if (c.game.gameOver) return;
    await InventorySheet.show(context, c, widget.atlas);
    _focus.requestFocus();
  }

  Future<void> _openBox() async {
    if (c.game.gameOver || c.game.pendingBoxes.isEmpty) return;
    await LootBoxDialog.show(context, c, widget.atlas);
    _focus.requestFocus();
  }

  void _onSwipe(DragEndDetails d) {
    final v = d.velocity.pixelsPerSecond;
    if (v.distance < 250) return;
    if (v.dx.abs() > v.dy.abs()) {
      c.move(v.dx > 0 ? Dir.right : Dir.left);
    } else {
      c.move(v.dy > 0 ? Dir.down : Dir.up);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: c.game.gameOver,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmQuit();
      },
      child: Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Scaffold(
        body: SafeArea(
          child: ListenableBuilder(
            listenable: c,
            builder: (context, _) => Column(
              children: [
                _Hud(c: c, atlas: widget.atlas, known: _allAchievements),
                _ShowBar(c: c, onTap: _openRegie),
                if (c.game.floorMod != null) _ModBanner(mod: c.game.floorMod!),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, box) => Stack(
                      children: [
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapUp: (d) => c.tapTile(painter.cameraFor(box.biggest).toTile(d.localPosition)),
                          onPanEnd: _onSwipe,
                          child: CustomPaint(painter: painter, size: box.biggest),
                        ),
                        if (c.game.bossAlive && c.game.bossAnnounced)
                          Positioned(left: 10, right: 10, top: 6, child: _BossBar(c: c)),
                        if (c.maestroVisible)
                          Positioned(
                            left: 10,
                            right: 10,
                            top: c.game.bossAlive && c.game.bossAnnounced ? 46 : 8,
                            child: _MaestroBubble(text: c.maestro!, onTap: c.dismissMaestro),
                          ),
                        if (c.visibleToasts.isNotEmpty)
                          Positioned(
                            left: 10,
                            right: 10,
                            bottom: 8,
                            child: Column(
                              children: [
                                for (final t in c.visibleToasts)
                                  GestureDetector(
                                    onTap: () => AchievementsScreen.show(context, _allAchievements, widget.atlas),
                                    child: _AchievementToast(name: t),
                                  ),
                              ],
                            ),
                          ),
                        if (c.game.pendingBoxes.isNotEmpty && !c.game.gameOver)
                          Positioned(
                            right: 10,
                            bottom: 8 + c.visibleToasts.length * 48.0,
                            child: _GiftButton(
                              count: c.game.pendingBoxes.length,
                              atlas: widget.atlas,
                              onTap: _openBox,
                            ),
                          ),
                        if (widget.store.profile.dpad && !c.game.gameOver)
                          Positioned(left: 8, bottom: 8, child: _DPad(c: c)),
                        if (c.game.gameOver && !c.animating)
                          Positioned.fill(
                            child: _GameOver(
                                c: c,
                                atlas: widget.atlas,
                                summary: _summary,
                                known: _allAchievements,
                                onRestart: _restart)),
                      ],
                    ),
                  ),
                ),
                _Log(c: c),
                _CombatBar(c: c, atlas: widget.atlas),
                _ActionBar(c: c, atlas: widget.atlas, onBag: _openBag),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}

// ------------------------------------------------------------------ HUD

class _Hud extends StatelessWidget {
  const _Hud({required this.c, required this.atlas, required this.known});

  final GameController c;
  final SpriteAtlas atlas;
  final Set<String> known;

  @override
  Widget build(BuildContext context) {
    final g = c.game;
    final p = g.player;
    return Container(
      color: Palette.panel,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        children: [
          GestureDetector(
            // Raccourci de développement (builds debug uniquement) : une loot box or.
            onLongPress: kDebugMode
                ? () => c.debugGrantBox(BoxTier.or)
                : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ETAGE', style: pixel(7, color: Palette.muted)),
                Text('${g.floor}', style: pixel(16, color: Palette.gold)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Accès au tableau d'honneur (succès).
          GestureDetector(
            onTap: () => AchievementsScreen.show(context, known, atlas),
            child: Container(
              padding: const EdgeInsets.fromLTRB(5, 3, 5, 3),
              decoration: BoxDecoration(border: Border.all(color: Palette.gold.withValues(alpha: 0.6))),
              child: Column(
                children: [
                  const Icon(Icons.emoji_events, color: Palette.gold, size: 18),
                  Text('${known.length}/${achievementDefs.length}', style: pixel(6, color: Palette.gold)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Bar(
                  ratio: p.hpRatio,
                  color: p.hpRatio < 0.3 ? const Color(0xFFFF2020) : Palette.hp,
                  label: 'PV ${p.hp}/${p.maxHp}',
                  height: 16,
                ),
                const SizedBox(height: 5),
                _Bar(
                  ratio: g.xp / g.xpToNext,
                  color: Palette.xp,
                  label: 'NIV ${g.playerLevel}',
                  height: 12,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                children: [
                  SpriteIcon(atlas, Sprites.coin, size: 20),
                  Text('${g.gold}', style: pixel(10, color: Palette.gold)),
                ],
              ),
              const SizedBox(height: 3),
              Text('ATQ ${p.atk} DEF ${p.def}', style: pixel(6, color: Palette.muted)),
              if (g.rageTurns > 0) Text('RAGE ${g.rageTurns}', style: pixel(6, color: Palette.hp)),
              for (final e in p.statuses.entries)
                Text('${e.key.short} ${e.value}', style: pixel(6, color: Color(e.key.color))),
            ],
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ Barre du show

/// Audience, hype et compte à rebours de l'étage. Toucher = ouvrir la régie.
class _ShowBar extends StatelessWidget {
  const _ShowBar({required this.c, required this.onTap});

  final GameController c;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final g = c.game;
    final s = g.show;
    final tier = s.tier;
    final left = g.turnsLeft;
    final timerColor = left < 0
        ? const Color(0xFFFF2020)
        : left <= 20
            ? const Color(0xFFFF7A7A)
            : Palette.text;
    return GestureDetector(
      onTap: onTap,
      // Raccourci de développement (builds debug uniquement) : aller sur l'escalier.
      onLongPress: kDebugMode ? c.debugToStairs : null,
      child: Container(
        color: const Color(0xFF1A1424),
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 7),
        child: Row(
          children: [
            const Icon(Icons.visibility, color: Palette.muted, size: 15),
            const SizedBox(width: 4),
            SizedBox(width: 52, child: Text(formatViewers(s.viewers), style: pixel(8))),
            Expanded(
              child: Container(
                height: 12,
                decoration: BoxDecoration(color: Colors.black, border: Border.all(color: Palette.panelBorder)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: s.hype / 100,
                      child: ColoredBox(color: Color(tier.color)),
                    ),
                    Center(child: Text('HYPE : ${tier.label}', style: pixel(6))),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Icon(Icons.timer, color: timerColor, size: 15),
            const SizedBox(width: 3),
            Text(left < 0 ? 'DEMOLITION' : '$left', style: pixel(8, color: timerColor)),
            const SizedBox(width: 6),
            Row(
              children: [
                for (final sp in s.sponsors)
                  Container(
                    width: 6,
                    height: 14,
                    margin: const EdgeInsets.only(left: 2),
                    alignment: Alignment.bottomCenter,
                    color: Colors.black,
                    child: FractionallySizedBox(
                      heightFactor: sp.ratio,
                      child: ColoredBox(color: Color(sp.def.color)),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ Barre de combat

class _CombatBar extends StatelessWidget {
  const _CombatBar({required this.c, required this.atlas});

  final GameController c;
  final SpriteAtlas atlas;

  @override
  Widget build(BuildContext context) {
    final g = c.game;
    final w = g.ranged;
    final aiming = c.targeting != null;
    final throwing = c.targeting?.isThrow ?? false;
    final shootLabel = w == null ? 'TIRER' : (w.magic ? 'SORT' : 'TIRER ${g.ammoCount}');
    return Container(
      color: const Color(0xFF1A1424),
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      child: Row(
        children: [
          // Endurance
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('ENDU', style: pixel(5, color: Palette.muted)),
              const SizedBox(height: 3),
              Row(
                children: [
                  for (var i = 0; i < Game.maxStamina; i++)
                    Container(
                      width: 7,
                      height: 12,
                      margin: const EdgeInsets.only(right: 2),
                      color: i < g.stamina ? const Color(0xFF5EC8FF) : Colors.black,
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(width: 6),
          _ModeButton(
              label: 'LOURD 2',
              active: c.mode == CombatMode.heavy,
              enabled: g.stamina >= 2,
              onTap: () => c.setMode(CombatMode.heavy)),
          _ModeButton(
              label: 'POUSSER 1',
              active: c.mode == CombatMode.shove,
              enabled: g.stamina >= 1,
              onTap: () => c.setMode(CombatMode.shove)),
          _ModeButton(label: 'PARER 2', active: false, enabled: g.stamina >= 2, onTap: c.parry),
          _ModeButton(
            label: throwing ? 'ANNULER' : shootLabel,
            active: aiming,
            enabled: throwing || (w != null && g.ammoCount > 0 && (!w.magic || g.stamina >= 2)),
            onTap: throwing ? c.toggleShoot : c.toggleShoot,
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({required this.label, required this.active, required this.enabled, required this.onTap});

  final String label;
  final bool active;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFFF9F40);
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Material(
          color: active ? accent.withValues(alpha: 0.25) : const Color(0xFF2E2540),
          shape: Border.all(color: active ? accent : Palette.panelBorder, width: 2),
          child: InkWell(
            onTap: enabled || active ? onTap : null,
            child: Opacity(
              opacity: enabled || active ? 1 : 0.35,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 9),
                child: Center(child: Text(label, style: pixel(6, color: active ? accent : Palette.text))),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ Modificateur d'étage

class _ModBanner extends StatelessWidget {
  const _ModBanner({required this.mod});

  final FloorMod mod;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFF2A2010),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Text.rich(
        TextSpan(children: [
          TextSpan(text: '${mod.label} : ', style: const TextStyle(color: Palette.gold, fontWeight: FontWeight.bold)),
          TextSpan(text: mod.desc, style: const TextStyle(color: Palette.text)),
        ]),
        style: const TextStyle(fontSize: 12),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

// ------------------------------------------------------------------ Croix directionnelle

class _DPad extends StatelessWidget {
  const _DPad({required this.c});

  final GameController c;

  Widget _btn(IconData icon, VoidCallback onTap) => SizedBox(
        width: 46,
        height: 46,
        child: Material(
          color: const Color(0xCC2E2540),
          shape: Border.all(color: Palette.panelBorder, width: 2),
          child: InkWell(onTap: onTap, child: Icon(icon, color: Palette.text, size: 26)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(width: 46, height: 46);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(mainAxisSize: MainAxisSize.min, children: [gap, _btn(Icons.keyboard_arrow_up, () => c.move(Dir.up)), gap]),
        Row(mainAxisSize: MainAxisSize.min, children: [
          _btn(Icons.keyboard_arrow_left, () => c.move(Dir.left)),
          _btn(Icons.hourglass_bottom, c.wait),
          _btn(Icons.keyboard_arrow_right, () => c.move(Dir.right)),
        ]),
        Row(mainAxisSize: MainAxisSize.min, children: [gap, _btn(Icons.keyboard_arrow_down, () => c.move(Dir.down)), gap]),
      ],
    );
  }
}

// ------------------------------------------------------------------ Boss

class _BossBar extends StatelessWidget {
  const _BossBar({required this.c});

  final GameController c;

  @override
  Widget build(BuildContext context) {
    final b = c.game.boss!;
    final color = b.enraged ? const Color(0xFFFF2020) : const Color(0xFFC03030);
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 5, 8, 6),
      decoration: BoxDecoration(color: const Color(0xEE1A0A0A), border: Border.all(color: color, width: 2)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('BOSS', style: pixel(7, color: color)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(b.name + (b.enraged ? ' (ENRAGÉ)' : ''),
                    overflow: TextOverflow.ellipsis, style: const TextStyle(color: Palette.text, fontSize: 12)),
              ),
              Text('${b.hp}/${b.maxHp}', style: pixel(7, color: Palette.text)),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            height: 8,
            color: Colors.black,
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: b.hpRatio.clamp(0.0, 1.0),
              child: ColoredBox(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ Succès et cadeaux

class _AchievementToast extends StatelessWidget {
  const _AchievementToast({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xEE2A2010),
        border: Border.all(color: Palette.gold, width: 2),
      ),
      child: Row(
        children: [
          const Icon(Icons.emoji_events, color: Palette.gold, size: 20),
          const SizedBox(width: 8),
          Text('SUCCES', style: pixel(7, color: Palette.gold)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(name,
                overflow: TextOverflow.ellipsis, style: const TextStyle(color: Palette.text, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _GiftButton extends StatefulWidget {
  const _GiftButton({required this.count, required this.atlas, required this.onTap});

  final int count;
  final SpriteAtlas atlas;
  final VoidCallback onTap;

  @override
  State<_GiftButton> createState() => _GiftButtonState();
}

class _GiftButtonState extends State<_GiftButton> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, child) => Transform.scale(scale: 1 + _pulse.value * 0.08, child: child),
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 6, 10, 6),
          decoration: BoxDecoration(
            color: const Color(0xEE2A2010),
            border: Border.all(color: Palette.gold, width: 2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SpriteIcon(widget.atlas, Sprites.chest, size: 34),
              const SizedBox(width: 6),
              Text('x${widget.count}', style: pixel(11, color: Palette.gold)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.ratio, required this.color, required this.label, required this.height});

  final double ratio;
  final Color color;
  final String label;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(color: Colors.black, border: Border.all(color: Palette.panelBorder)),
      child: Stack(
        fit: StackFit.expand,
        children: [
          FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: ratio.clamp(0.0, 1.0),
            child: ColoredBox(color: color),
          ),
          Center(child: Text(label, style: pixel(height * 0.45))),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ MAESTRO

class _MaestroBubble extends StatelessWidget {
  const _MaestroBubble({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xEE1A0F24),
          border: Border.all(color: Palette.maestro, width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(width: 8, height: 8, color: Palette.hp),
                const SizedBox(width: 6),
                Text('MAESTRO', style: pixel(8, color: Palette.maestro)),
              ],
            ),
            const SizedBox(height: 6),
            Text(text, style: const TextStyle(color: Palette.text, fontSize: 13, height: 1.35)),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ Journal

class _Log extends StatelessWidget {
  const _Log({required this.c});

  final GameController c;

  @override
  Widget build(BuildContext context) {
    final lines = c.log.where((l) => l.kind != MessageKind.maestro).toList();
    final shown = lines.length > 4 ? lines.sublist(lines.length - 4) : lines;
    return Container(
      width: double.infinity,
      height: 84,
      color: const Color(0xFF0F0C15),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < shown.length; i++)
            Opacity(
              opacity: 0.45 + 0.55 * (i + 1) / shown.length,
              child: Text(
                shown[i].text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Palette.forMessage(shown[i].kind), fontSize: 12.5),
              ),
            ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ Actions

class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.c, required this.atlas, required this.onBag});

  final GameController c;
  final SpriteAtlas atlas;
  final VoidCallback onBag;

  @override
  Widget build(BuildContext context) {
    final g = c.game;
    return Container(
      color: Palette.panel,
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
      child: Row(
        children: [
          _ActionButton(
            label: 'ATTENDRE',
            icon: const Icon(Icons.hourglass_bottom, color: Palette.text, size: 26),
            onTap: c.wait,
          ),
          _ActionButton(
            label: 'SAC ${g.inventory.length}/${g.maxSlots}',
            icon: const Icon(Icons.backpack, color: Palette.gold, size: 26),
            onTap: g.gameOver ? null : onBag,
          ),
          _ActionButton(
            label: 'SOIN x${g.healPotions}',
            icon: SpriteIcon(atlas, Sprites.potionRed, size: 30),
            onTap: g.healPotions > 0 ? c.quaff : null,
          ),
          _ActionButton(
            label: g.skillReady ? 'POUVOIR' : 'POUVOIR ${g.skillCooldown}',
            icon: Icon(Icons.flash_on, color: g.skillReady ? const Color(0xFF5EC8FF) : Palette.muted, size: 28),
            onTap: g.gameOver ? null : c.skill,
            onLongPress: () => _showSkill(context, g.skill.name, g.skill.desc, g.skill.cooldown),
            highlight: g.skillReady && !g.gameOver,
            highlightColor: const Color(0xFF5EC8FF),
          ),
          _ActionButton(
            label: 'DESCENDRE',
            icon: SpriteIcon(atlas, Sprites.stairsDown, size: 30),
            onTap: g.onStairs ? c.descend : null,
            highlight: g.onStairs,
          ),
        ],
      ),
    );
  }
}

void _showSkill(BuildContext context, String name, String desc, int cooldown) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Palette.panel,
      shape: const RoundedRectangleBorder(side: BorderSide(color: Color(0xFF5EC8FF), width: 2)),
      title: Text(name, style: const TextStyle(color: Color(0xFF5EC8FF))),
      content: Text('$desc\n\nRecharge : $cooldown tours.', style: const TextStyle(color: Palette.text, height: 1.4)),
      actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text('OK', style: pixel(9)))],
    ),
  );
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.highlight = false,
    this.onLongPress,
    this.highlightColor = Palette.gold,
  });

  final String label;
  final Widget icon;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool highlight;
  final Color highlightColor;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Material(
          color: highlight ? highlightColor.withValues(alpha: 0.22) : const Color(0xFF2E2540),
          shape: Border.all(color: highlight ? highlightColor : Palette.panelBorder, width: 2),
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            child: Opacity(
              opacity: enabled ? 1 : 0.35,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(height: 30, child: Center(child: icon)),
                    const SizedBox(height: 4),
                    Text(label, style: pixel(6, color: highlight ? highlightColor : Palette.text)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ Fin de run

class _GameOver extends StatelessWidget {
  const _GameOver({
    required this.c,
    required this.atlas,
    required this.summary,
    required this.known,
    required this.onRestart,
  });

  final GameController c;
  final SpriteAtlas atlas;
  final RunSummary? summary;
  final Set<String> known;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    final g = c.game;
    final s = summary;
    Widget stat(String k, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              Expanded(child: Text(k, style: pixel(8, color: Palette.muted))),
              Text(v, style: pixel(9, color: Palette.text)),
            ],
          ),
        );
    return ColoredBox(
      color: const Color(0xCC000000),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Container(
            width: 320,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: Palette.panel, border: Border.all(color: Palette.hp, width: 3)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(g.victory ? 'SAISON GAGNEE' : 'ELIMINE',
                    textAlign: TextAlign.center, style: pixel(g.victory ? 18 : 22, color: g.victory ? Palette.gold : Palette.hp)),
                const SizedBox(height: 6),
                Text(g.setup.daily ? 'Fin du defi du jour' : 'Fin de diffusion', style: pixel(8, color: Palette.muted)),
                const SizedBox(height: 14),
                stat('Etage atteint', '${g.floor}${s?.bestFloor == true ? '  RECORD !' : ''}'),
                stat('Niveau', '${g.playerLevel}'),
                stat('Monstres', '${g.kills}'),
                stat('Audience max', '${formatViewers(g.show.peakViewers)}${s?.bestViewers == true ? '  RECORD !' : ''}'),
                stat('Succès (run)', '${g.unlocked.length}'),
                const SizedBox(height: 6),
                Text('Tué par : ${g.killedBy ?? '?'}',
                    textAlign: TextAlign.center, style: const TextStyle(color: Palette.muted, fontSize: 12)),
                if (s != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2010),
                      border: Border.all(color: Palette.gold.withValues(alpha: 0.7)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text("DROITS D'AUTEUR", style: pixel(8, color: Palette.gold)),
                        const SizedBox(height: 6),
                        for (final l in s.lines)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 1),
                            child: Row(
                              children: [
                                Expanded(
                                    child: Text(l.label, style: const TextStyle(color: Palette.text, fontSize: 12))),
                                Text('+${l.amount}', style: pixel(8, color: Palette.gold)),
                              ],
                            ),
                          ),
                        const Divider(color: Palette.panelBorder),
                        Row(
                          children: [
                            Expanded(child: Text('TOTAL', style: pixel(9, color: Palette.text))),
                            Text('+${s.total}', style: pixel(11, color: Palette.gold)),
                          ],
                        ),
                        if (s.newAchievements.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Nouveaux au tableau : ${s.newAchievements.map((id) => achievementById(id).name).join(', ')}',
                            style: const TextStyle(color: Palette.maestro, fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    shape: const RoundedRectangleBorder(),
                    side: const BorderSide(color: Palette.gold),
                  ),
                  onPressed: () => AchievementsScreen.show(context, known, atlas),
                  icon: const Icon(Icons.emoji_events, color: Palette.gold, size: 18),
                  label: Text("TABLEAU D'HONNEUR", style: pixel(8, color: Palette.gold)),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(shape: const RoundedRectangleBorder()),
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text('MENU', style: pixel(9)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: Palette.gold,
                          shape: const RoundedRectangleBorder(),
                        ),
                        onPressed: onRestart,
                        child: Text('REJOUER', style: pixel(9, color: Palette.bg)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
