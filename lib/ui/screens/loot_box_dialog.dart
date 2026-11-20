import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../content/items.dart';
import '../../content/sprites.dart';
import '../../core/game.dart';
import '../game_controller.dart';
import '../render/sprite_atlas.dart';
import '../audio.dart';
import '../theme.dart';

/// Ouverture d'une loot box : la boîte tremble, on tape, elle explose, le butin apparaît.
class LootBoxDialog extends StatefulWidget {
  const LootBoxDialog({super.key, required this.c, required this.atlas});

  final GameController c;
  final SpriteAtlas atlas;

  static Future<void> show(BuildContext context, GameController c, SpriteAtlas atlas) => showDialog<void>(
        context: context,
        barrierColor: const Color(0xDD000000),
        builder: (_) => LootBoxDialog(c: c, atlas: atlas),
      );

  @override
  State<LootBoxDialog> createState() => _LootBoxDialogState();
}

class _LootBoxDialogState extends State<LootBoxDialog> with TickerProviderStateMixin {
  late final AnimationController _shake =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();
  late final AnimationController _burst =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 700));

  BoxResult? result;
  late BoxTier tier;

  @override
  void initState() {
    super.initState();
    tier = widget.c.game.pendingBoxes.first;
  }

  @override
  void dispose() {
    _shake.dispose();
    _burst.dispose();
    super.dispose();
  }

  void _open() {
    if (result != null) return;
    GameAudio.instance.play(Sfx.lootbox);
    setState(() => result = widget.c.openBox());
    _burst.forward(from: 0);
  }

  void _next() {
    final boxes = widget.c.game.pendingBoxes;
    if (boxes.isEmpty) return;
    setState(() {
      result = null;
      tier = boxes.first;
    });
  }

  @override
  Widget build(BuildContext context) {
    final color = Color(tier.color);
    final remaining = widget.c.game.pendingBoxes.length;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Palette.panel, border: Border.all(color: color, width: 3)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('LOOT BOX', style: pixel(10, color: Palette.muted)),
            const SizedBox(height: 6),
            Text(tier.label.toUpperCase().replaceAll('É', 'E'), style: pixel(20, color: color)),
            const SizedBox(height: 18),
            SizedBox(
              height: 150,
              child: result == null ? _closedBox(color) : _opened(color),
            ),
            const SizedBox(height: 16),
            if (result == null)
              Text('Touchez la boîte !', style: pixel(9, color: Palette.text))
            else ...[
              for (final it in result!.items) _itemRow(it),
              _goldRow(result!.gold),
              if (result!.overflow)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text('Sac plein : le reste est posé à vos pieds.',
                      style: TextStyle(color: Color(0xFFFF7A7A), fontSize: 12)),
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(shape: const RoundedRectangleBorder()),
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text('FERMER', style: pixel(9)),
                    ),
                  ),
                  if (remaining > 0) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: Palette.gold, shape: const RoundedRectangleBorder()),
                        onPressed: _next,
                        child: Text('SUIVANTE ($remaining)', style: pixel(8, color: Palette.bg)),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _closedBox(Color color) {
    return GestureDetector(
      key: const ValueKey('closed-box'),
      onTap: _open,
      child: AnimatedBuilder(
        animation: _shake,
        builder: (context, _) {
          // Tremblement de plus en plus fort, avec pause.
          final t = _shake.value;
          final amp = t < 0.6 ? 0.0 : math.sin((t - 0.6) * 40) * 6;
          return Transform.translate(
            offset: Offset(amp, 0),
            child: Transform.rotate(
              angle: amp / 80,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [color.withValues(alpha: 0.45), Colors.transparent]),
                ),
                child: Center(child: SpriteIcon(widget.atlas, Sprites.chest, size: 112)),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _opened(Color color) {
    return AnimatedBuilder(
      animation: _burst,
      builder: (context, _) {
        final t = Curves.easeOut.transform(_burst.value);
        return Stack(
          alignment: Alignment.center,
          children: [
            // Rayons qui s'étendent.
            for (var i = 0; i < 12; i++)
              Transform.rotate(
                angle: i * math.pi / 6 + t * 0.6,
                child: Container(width: 6, height: 40 + t * 110, color: color.withValues(alpha: (1 - t) * 0.8)),
              ),
            Opacity(
              opacity: 1 - t * 0.4,
              child: SpriteIcon(widget.atlas, Sprites.chestOpen, size: 96 + t * 10),
            ),
          ],
        );
      },
    );
  }

  Widget _itemRow(ItemDef d) {
    final g = widget.c.game;
    return AnimatedBuilder(
      animation: _burst,
      builder: (context, child) => Opacity(opacity: _burst.value, child: child),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1424),
          border: Border.all(color: Color(d.rarity.color), width: 2),
        ),
        child: Row(
          children: [
            SpriteIcon(widget.atlas, g.spriteOf(d), size: 36, tint: g.tintOf(d)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(g.nameOf(d), style: TextStyle(color: Color(d.rarity.color), fontSize: 14)),
                  if (d.statLine.isNotEmpty) Text(d.statLine, style: pixel(7, color: Palette.muted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _goldRow(int gold) => Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SpriteIcon(widget.atlas, Sprites.coin, size: 24),
            const SizedBox(width: 6),
            Text('+$gold', style: pixel(11, color: Palette.gold)),
          ],
        ),
      );
}
