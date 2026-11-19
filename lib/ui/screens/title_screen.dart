import 'package:flutter/material.dart';

import '../../content/roles.dart';
import '../../content/sprites.dart';
import '../../meta/profile_store.dart';
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

  void _play(BuildContext context, {bool daily = false}) => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => GameScreen(atlas: atlas, store: store, daily: daily)),
      );

  @override
  Widget build(BuildContext context) {
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
                    // Jouer avec le rôle choisi
                    _MenuButton(
                      primary: true,
                      onTap: () => _play(context),
                      child: Row(
                        children: [
                          SpriteIcon(atlas, role.sprite, size: 40),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('ENTRER EN SCENE', style: pixel(12, color: Palette.bg)),
                                const SizedBox(height: 4),
                                Text(role.name, style: const TextStyle(color: Palette.bg, fontSize: 13)),
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
