import 'package:flutter/material.dart';

import '../../content/talents.dart';
import '../../core/show.dart';
import '../game_controller.dart';
import '../theme.dart';

/// La régie : audience, sponsors (et ce qu'ils aiment), talents acquis.
class RegieSheet extends StatelessWidget {
  const RegieSheet({super.key, required this.c});

  final GameController c;

  static Future<void> show(BuildContext context, GameController c) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Palette.panel,
        shape: const RoundedRectangleBorder(),
        builder: (_) => RegieSheet(c: c),
      );

  @override
  Widget build(BuildContext context) {
    final g = c.game;
    final s = g.show;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('LA REGIE', style: pixel(14, color: Palette.gold)),
            const SizedBox(height: 10),
            Text(
              'Spectateurs : ${formatViewers(s.viewers)} (record ${formatViewers(s.peakViewers)})\n'
              'Hype : ${s.hype.round()} / 100 - ${s.tier.label}',
              style: const TextStyle(color: Palette.text, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 4),
            const Text(
              "Les combats, les risques et les exploits font monter la hype. L'ennui la fait chuter, "
              'et la régie déteste s\'ennuyer.',
              style: TextStyle(color: Palette.muted, fontSize: 12, height: 1.35),
            ),
            const SizedBox(height: 16),
            Text('SPONSORS', style: pixel(10, color: Palette.gold)),
            const SizedBox(height: 8),
            for (final sp in s.sponsors) _sponsor(sp),
            const SizedBox(height: 8),
            Text('TALENTS', style: pixel(10, color: Palette.gold)),
            const SizedBox(height: 6),
            if (g.talents.isEmpty)
              const Text('Aucun pour le moment. On en gagne en coulisses.',
                  style: TextStyle(color: Palette.muted, fontSize: 12))
            else
              for (final id in g.talents)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('• ${talentById(id).name} : ${talentById(id).desc}',
                      style: const TextStyle(color: Palette.text, fontSize: 12)),
                ),
          ],
        ),
      ),
    );
  }

  Widget _sponsor(SponsorState sp) {
    final color = Color(sp.def.color);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: const Color(0xFF1A1424), border: Border.all(color: color.withValues(alpha: 0.6))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(sp.def.name, style: TextStyle(color: color, fontSize: 14))),
              Text('${sp.gifts} colis', style: pixel(7, color: Palette.muted)),
            ],
          ),
          Text('« ${sp.def.slogan} »', style: const TextStyle(color: Palette.muted, fontSize: 11, fontStyle: FontStyle.italic)),
          const SizedBox(height: 4),
          Text(sp.def.taste.label, style: const TextStyle(color: Palette.text, fontSize: 12)),
          const SizedBox(height: 6),
          Container(
            height: 8,
            color: Colors.black,
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: sp.ratio,
              child: ColoredBox(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
