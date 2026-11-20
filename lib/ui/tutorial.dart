import 'package:flutter/material.dart';

import '../content/sprites.dart';
import '../content/tips.dart';
import '../core/game.dart';
import 'render/sprite_atlas.dart';
import 'theme.dart';

/// Prochain conseil de MAESTRO à afficher en jeu (le premier de la liste dont la
/// condition est vraie et qui n'a jamais été vu), ou null.
String? nextInGameTip(Game g, Set<String> seen) {
  if (g.gameOver) return seen.contains('gameover') ? null : 'gameover';
  if (g.backstage != null || g.activeFeature != null) return null;
  final me = g.player.pos;
  bool shown(dynamic p) => g.visible.contains(p);
  final conditions = <String, bool Function()>{
    'welcome': () => true,
    'move': () => true,
    'boss': () => g.bossAnnounced && g.bossAlive,
    'monster': () => g.monsters.any((m) => !m.disguised && shown(m.pos)),
    'ranged': () => g.monsters.any((m) => !m.disguised && shown(m.pos) && g.intentOf(m) == MonsterIntent.shoot),
    'combat': () => g.monsters.any((m) => !m.disguised && m.pos.isAdjacent4(me)),
    'intent': () => g.monsters.any((m) => shown(m.pos) &&
        const {MonsterIntent.prepare, MonsterIntent.heavy, MonsterIntent.explode}.contains(g.intentOf(m))),
    'skill': () => g.skillReady && g.monsters.any((m) => !m.disguised && m.pos.isAdjacent4(me)),
    'status': () => g.player.statuses.isNotEmpty,
    'potion': () => g.player.hpRatio < 0.5 && g.healPotions > 0,
    'trap': () => g.traps.any((t) => t.revealed),
    'mod': () => g.floorMod != null,
    'lootbox': () => g.pendingBoxes.isNotEmpty,
    'craft': () => g.materials.values.any((n) => n > 0),
    'mastery': () => g.masteryXp.values.any((n) => n >= 4),
    'bag': () => g.inventory.any((i) => i.def.equippable),
    'chest': () => g.chests.any((c) => shown(c.pos)) || g.monsters.any((m) => m.disguised && shown(m.pos)),
    'feature': () => g.features.any((f) => !f.used && shown(f.pos)),
    'stairs': () => shown(g.level.stairs),
    'timer': () => g.turnsLeft <= 40,
    'hud': () => g.turn >= 4,
    'hype': () => g.turn >= 25,
    'sponsor': () => g.show.sponsors.any((s) => s.gifts > 0 || s.ratio >= 0.5),
  };
  for (final e in conditions.entries) {
    if (!seen.contains(e.key) && e.value()) return e.key;
  }
  return null;
}

/// Fiche de conseil. Renvoie vrai si le joueur a demandé de couper les conseils.
Future<bool> showTip(BuildContext context, SpriteAtlas atlas, String id) async {
  final tip = tipById(id);
  final off = await showDialog<bool>(
    context: context,
    // Pas de fermeture par un tap à côté : un conseil n'apparaît qu'une fois, il ne doit pas
    // disparaître parce que le joueur tapotait la carte.
    barrierDismissible: false,
    barrierColor: const Color(0x99000000),
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1F1230),
          border: Border.all(color: Palette.maestro, width: 3),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                SpriteIcon(atlas, Sprites.maestro, size: 48),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('CONSEIL DE MAESTRO', style: pixel(7, color: Palette.maestro)),
                      const SizedBox(height: 4),
                      Text(tip.title, style: const TextStyle(color: Palette.gold, fontSize: 17)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(tip.text, style: const TextStyle(color: Palette.text, fontSize: 14, height: 1.45)),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Palette.gold, shape: const RoundedRectangleBorder()),
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('COMPRIS', style: pixel(10, color: Palette.bg)),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Couper les conseils', style: TextStyle(color: Palette.muted, fontSize: 12)),
            ),
          ],
        ),
      ),
    ),
  );
  return off ?? false;
}
