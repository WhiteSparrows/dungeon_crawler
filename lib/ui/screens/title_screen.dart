import 'package:flutter/material.dart';

import '../../content/roles.dart';
import '../../content/sprites.dart';
import '../../meta/profile_store.dart';
import '../audio.dart';
import '../render/sprite_atlas.dart';
import '../theme.dart';
import 'achievements_screen.dart';
import 'game_screen.dart';
import 'hub_screen.dart';
import 'settings_screen.dart';

class TitleScreen extends StatelessWidget {
  const TitleScreen({super.key, required this.atlas, required this.store});

  final SpriteAtlas atlas;
  final ProfileStore store;

  static const _cast = [Sprites.rat, Sprites.bat, Sprites.maestro, Sprites.slime, Sprites.spider];

  /// Nouvelle partie. S'il y en a une en cours, elle est d'abord abandonnée (après confirmation).
  Future<void> _play(BuildContext context, {bool daily = false}) async {
    if (store.hasSavedRun) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Palette.panel,
          shape: const RoundedRectangleBorder(side: BorderSide(color: Palette.hp, width: 2)),
          title: Text('PARTIE EN COURS', style: pixel(11, color: Palette.hp)),
          content: const Text(
            "Une partie est en pause. En lancer une nouvelle l'abandonne (vous touchez ses droits d'auteur).\n\n"
            "MAESTRO : « Zapper sa propre émission. Audacieux. »",
            style: TextStyle(color: Palette.text, height: 1.4),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text('ANNULER', style: pixel(8))),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Palette.hp, shape: const RoundedRectangleBorder()),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text('ABANDONNER', style: pixel(8, color: Palette.text)),
            ),
          ],
        ),
      );
      if (ok != true) return;
      await store.abandonSavedRun();
    }
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => GameScreen(atlas: atlas, store: store, daily: daily)),
    );
  }

  /// Reprend la partie en pause (le journal est rejoué, ce qui peut prendre un instant).
  Future<void> _resume(BuildContext context) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(child: Text('RETOUR EN DIRECT...', style: pixel(10, color: Palette.gold))),
    );
    await Future<void>.delayed(const Duration(milliseconds: 80));
    final game = store.loadRun();
    if (!context.mounted) return;
    Navigator.of(context).pop();
    if (game == null) {
      await store.clearRun();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Cette sauvegarde date d'une ancienne version du jeu et ne peut pas être reprise."),
      ));
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => GameScreen(atlas: atlas, store: store, resume: game)),
    );
  }

  @override
  Widget build(BuildContext context) {
    GameAudio.instance.music(Music.show);
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: store,
          builder: (context, _) {
            final p = store.profile;
            final role = roleById(p.selectedRole);
            final now = DateTime.now();
            final dailyBest = p.dailyBestFor(now);
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        tooltip: 'Réglages',
                        icon: const Icon(Icons.settings, color: Palette.muted),
                        onPressed: () => SettingsScreen.show(context, store),
                      ),
                    ),
                    Center(child: Text('EN DIRECT', style: pixel(12, color: Palette.hp))),
                    const SizedBox(height: 12),
                    Center(child: Text('DONJON', style: pixel(36, color: Palette.gold))),
                    const SizedBox(height: 4),
                    Center(child: Text('EN DIRECT', style: pixel(18, color: Palette.text))),
                    const SizedBox(height: 22),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [for (final s in _cast) SpriteIcon(atlas, s, size: 46)],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      p.runs == 0
                          ? "La Terre a été rachetée par un conglomérat galactique du divertissement.\n"
                              "Vous êtes le candidat du jour. Descendez le plus bas possible."
                          : "Saison ${p.runs + 1}. Record : étage ${p.bestFloor}. "
                              "MAESTRO a déjà oublié votre nom.",
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Palette.muted, height: 1.5),
                    ),
                    const SizedBox(height: 22),
                    if (store.hasSavedRun) ...[
                      _MenuButton(
                        primary: true,
                        onTap: () => _resume(context),
                        child: Row(
                          children: [
                            const Icon(Icons.play_arrow, color: Palette.bg, size: 36),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('REPRENDRE', style: pixel(12, color: Palette.bg)),
                                  const SizedBox(height: 4),
                                  Text(_savedLabel(), style: const TextStyle(color: Palette.bg, fontSize: 13)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    // Jouer avec le rôle choisi
                    _MenuButton(
                      primary: !store.hasSavedRun,
                      onTap: () => _play(context),
                      child: Row(
                        children: [
                          SpriteIcon(atlas, role.sprite, size: 40),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(store.hasSavedRun ? 'NOUVELLE PARTIE' : 'ENTRER EN SCENE',
                                    style: pixel(12, color: store.hasSavedRun ? Palette.text : Palette.bg)),
                                const SizedBox(height: 4),
                                Text(role.name,
                                    style: TextStyle(color: store.hasSavedRun ? Palette.muted : Palette.bg, fontSize: 13)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    _MenuButton(
                      onTap: () => _play(context, daily: true),
                      child: Row(
                        children: [
                          const Icon(Icons.today, color: Palette.xp, size: 30),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('DEFI DU JOUR', style: pixel(10, color: Palette.xp)),
                                const SizedBox(height: 4),
                                Text(
                                  dailyBest == 0
                                      ? 'Même donjon pour tout le monde. Droits d\'auteur +50 %.'
                                      : 'Meilleur aujourd\'hui : étage $dailyBest (${p.dailyAttemptsFor(now)} essai(s))',
                                  style: const TextStyle(color: Palette.muted, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _MenuButton(
                            onTap: () => HubScreen.show(context, store, atlas),
                            child: Column(
                              children: [
                                const Icon(Icons.star, color: Palette.gold, size: 26),
                                const SizedBox(height: 4),
                                Text('LOGE DES STARS', style: pixel(7, color: Palette.text)),
                                const SizedBox(height: 4),
                                Text("${p.royalties} droits d'auteur",
                                    style: const TextStyle(color: Palette.gold, fontSize: 11)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _MenuButton(
                            onTap: () => AchievementsScreen.show(context, p.achievements, atlas),
                            child: Column(
                              children: [
                                const Icon(Icons.emoji_events, color: Palette.gold, size: 26),
                                const SizedBox(height: 4),
                                Text('SUCCES', style: pixel(7, color: Palette.text)),
                                const SizedBox(height: 4),
                                Text('${p.achievements.length} obtenus',
                                    style: const TextStyle(color: Palette.gold, fontSize: 11)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 26),
                    Center(child: Text('Sprites : Kenney.nl (CC0)', style: pixel(7, color: Palette.muted))),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

extension on TitleScreen {
  String _savedLabel() {
    final info = store.savedRunInfo;
    if (info == null) return '';
    final role = roleById(info['role'] as String? ?? 'lambda').name;
    final daily = info['daily'] == true ? ' · défi du jour' : '';
    return 'Étage ${info['floor']} · $role$daily';
  }
}

class _MenuButton extends StatelessWidget {
  const _MenuButton({required this.child, required this.onTap, this.primary = false});

  final Widget child;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: primary ? Palette.gold : Palette.panel,
      shape: Border.all(color: primary ? Palette.gold : Palette.panelBorder, width: 2),
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.all(12), child: child),
      ),
    );
  }
}
