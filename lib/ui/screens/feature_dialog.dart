import 'package:flutter/material.dart';

import '../../core/entities.dart';
import '../../core/game.dart';
import '../game_controller.dart';
import '../render/sprite_atlas.dart';
import '../theme.dart';

/// Choix devant un lieu interactif (fontaine, autel, distributeur, bouche de la vérité).
class FeatureDialog extends StatefulWidget {
  const FeatureDialog({super.key, required this.c, required this.atlas, required this.feature});

  final GameController c;
  final SpriteAtlas atlas;
  final Feature feature;

  static Future<void> show(BuildContext context, GameController c, SpriteAtlas atlas, Feature f) => showDialog<void>(
        context: context,
        barrierDismissible: false,
        barrierColor: const Color(0xCC000000),
        builder: (_) => FeatureDialog(c: c, atlas: atlas, feature: f),
      );

  @override
  State<FeatureDialog> createState() => _FeatureDialogState();
}

class _FeatureDialogState extends State<FeatureDialog> {
  FeatureResult? _result;

  Game get g => widget.c.game;

  String _sub(String s) => s.replaceAll('{sponsor}', g.show.sponsors[widget.feature.sponsorIndex].def.name);

  void _choose(int i) => setState(() => _result = widget.c.chooseFeature(i));

  @override
  Widget build(BuildContext context) {
    final k = widget.feature.kind;
    final r = _result;
    final done = r != null && r.closed;
    return PopScope(
      canPop: done,
      onPopInvokedWithResult: (didPop, _) {
        // Retour = « passer son chemin ».
        if (!didPop && !done) {
          _choose(k.options.length - 1);
          Navigator.of(context).pop();
        }
      },
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: Palette.panel, border: Border.all(color: Palette.gold, width: 3)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  SpriteIcon(widget.atlas, k.sprite, size: 56),
                  const SizedBox(width: 12),
                  Expanded(child: Text(k.title, style: const TextStyle(color: Palette.gold, fontSize: 18))),
                ],
              ),
              const SizedBox(height: 12),
              Text(_sub(k.text), style: const TextStyle(color: Palette.text, fontSize: 14, height: 1.4)),
              const SizedBox(height: 14),
              if (r != null && r.text.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1F1230),
                    border: Border.all(color: Palette.maestro.withValues(alpha: 0.6), width: 2),
                  ),
                  child: Text(r.text, style: const TextStyle(color: Palette.text, fontSize: 14, height: 1.4)),
                ),
              if (done)
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: Palette.gold, shape: const RoundedRectangleBorder()),
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('CONTINUER', style: pixel(10, color: Palette.bg)),
                )
              else
                for (var i = 0; i < k.options.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        side: BorderSide(color: i == k.options.length - 1 ? Palette.panelBorder : Palette.gold),
                        shape: const RoundedRectangleBorder(),
                      ),
                      onPressed: () => _choose(i),
                      child: Text(_sub(k.options[i]), style: const TextStyle(color: Palette.text, fontSize: 14)),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
