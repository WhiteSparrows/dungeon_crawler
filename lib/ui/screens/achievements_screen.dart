import 'package:flutter/material.dart';

import '../../content/achievements.dart';
import '../../content/sprites.dart';
import '../render/sprite_atlas.dart';
import '../theme.dart';

/// Le tableau d'honneur : tous les succès, commentés (méchamment) par MAESTRO.
class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key, required this.unlocked, required this.atlas});

  final Set<String> unlocked;
  final SpriteAtlas atlas;

  static Future<void> show(BuildContext context, Set<String> unlocked, SpriteAtlas atlas) =>
      Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => AchievementsScreen(unlocked: unlocked, atlas: atlas),
      ));

  @override
  Widget build(BuildContext context) {
    final got = achievementDefs.where((a) => unlocked.contains(a.id)).toList();
    final locked = achievementDefs.where((a) => !unlocked.contains(a.id)).toList();
    final ratio = got.length / achievementDefs.length;
    return Scaffold(
      backgroundColor: const Color(0xFF0E0A14),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              color: Palette.panel,
              padding: const EdgeInsets.fromLTRB(4, 6, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Palette.text),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      Expanded(child: Text("TABLEAU D'HONNEUR", style: pixel(12, color: Palette.gold))),
                      Text('${got.length}/${achievementDefs.length}', style: pixel(11, color: Palette.text)),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 12, top: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          height: 10,
                          color: Colors.black,
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: ratio,
                            child: const ColoredBox(color: Palette.gold),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SpriteIcon(atlas, Sprites.maestro, size: 36),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _intro(got.length),
                                style: const TextStyle(
                                    color: Palette.maestro, fontSize: 12, height: 1.35, fontStyle: FontStyle.italic),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  for (final a in got) _card(a, true),
                  if (got.isNotEmpty && locked.isNotEmpty) const SizedBox(height: 8),
                  if (locked.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8, top: 4),
                      child: Text('A DEBLOQUER', style: pixel(9, color: Palette.muted)),
                    ),
                  for (final a in locked) _card(a, false),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _intro(int n) {
    if (n == 0) {
      return "« Zéro succès. Zéro. Même le rat syndiqué a un palmarès plus fourni. "
          "Allez donc tuer quelque chose, ça vous détendra. »";
    }
    if (n < 5) return "« Quelques babioles en vitrine. C'est mignon. Comme un enfant qui montre ses dessins. »";
    if (n < 12) return "« Pas mal, pas mal. Le public commence à retenir votre visage. Pas votre nom, hein. »";
    return "« Impressionnant. Vraiment. J'en ai presque une larme. C'est de la sueur. C'est le projecteur. »";
  }

  Widget _card(AchievementDef a, bool got) {
    final tierColor = Color(a.reward.color);
    final hidden = a.secret && !got;
    return Opacity(
      opacity: got ? 1 : 0.6,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: got ? const Color(0xFF221B2E) : const Color(0xFF16111E),
          border: Border.all(color: got ? tierColor : Palette.panelBorder, width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: got ? tierColor.withValues(alpha: 0.18) : Colors.black,
                      border: Border.all(color: got ? tierColor : Palette.panelBorder),
                    ),
                    child: Icon(
                      got ? Icons.emoji_events : (hidden ? Icons.help_outline : Icons.lock_outline),
                      color: got ? tierColor : Palette.muted,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(hidden ? '???' : a.name,
                            style: TextStyle(color: got ? Palette.text : Palette.muted, fontSize: 15)),
                        const SizedBox(height: 2),
                        Text(
                          hidden ? 'Succès secret. MAESTRO refuse de dire comment.' : a.desc,
                          style: const TextStyle(color: Palette.muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      SpriteIcon(atlas, Sprites.chest, size: 22),
                      Text(a.reward.label.toUpperCase().replaceAll('É', 'E'), style: pixel(6, color: tierColor)),
                    ],
                  ),
                ],
              ),
            ),
            if (got)
              Container(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                decoration: const BoxDecoration(
                  color: Color(0xFF1F1230),
                  border: Border(top: BorderSide(color: Color(0x55E07BFF))),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('MAESTRO COMMENTE :', style: pixel(6, color: Palette.maestro)),
                    const SizedBox(height: 4),
                    Text(a.flavor, style: const TextStyle(color: Palette.text, fontSize: 13, height: 1.4)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
