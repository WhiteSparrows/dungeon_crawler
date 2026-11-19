import 'package:flutter/material.dart';

import '../../meta/profile_store.dart';
import '../audio.dart';
import '../theme.dart';

/// Réglages : vibrations, croix directionnelle, remise à zéro.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.store});

  final ProfileStore store;

  static Future<void> show(BuildContext context, ProfileStore store) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => SettingsScreen(store: store)));

  Future<void> _confirmReset(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Palette.panel,
        shape: const RoundedRectangleBorder(side: BorderSide(color: Palette.hp, width: 2)),
        title: Text('TOUT EFFACER ?', style: pixel(11, color: Palette.hp)),
        content: const Text(
          "Droits d'auteur, rôles, contrats, succès et rediffusions seront définitivement perdus.\n\n"
          "MAESTRO : « Un reboot de la franchise ? Audacieux. Les fans vont hurler. »",
          style: TextStyle(color: Palette.text, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text('ANNULER', style: pixel(9))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Palette.hp, shape: const RoundedRectangleBorder()),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('EFFACER', style: pixel(9, color: Palette.text)),
          ),
        ],
      ),
    );
    if (ok == true) store.reset();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0A14),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: store,
          builder: (context, _) {
            final p = store.profile;
            return ListView(
              padding: const EdgeInsets.fromLTRB(4, 6, 14, 20),
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Palette.text),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Text('REGLAGES', style: pixel(12, color: Palette.gold)),
                  ],
                ),
                const SizedBox(height: 10),
                _toggle(
                  'Musique',
                  'Boucles chiptune du donjon et du plateau.',
                  p.music,
                  (on) {
                    store.setMusic(on);
                    GameAudio.instance.setMusicOn(on);
                  },
                ),
                _toggle(
                  'Effets sonores',
                  'Coups, loot box, public en délire, trombone triste.',
                  p.soundFx,
                  (on) {
                    store.setSoundFx(on);
                    GameAudio.instance.sfxOn = on;
                  },
                ),
                _toggle(
                  'Vibrations',
                  'Coups reçus, éliminations, boss, montées de niveau.',
                  p.vibrations,
                  store.setVibrations,
                ),
                _toggle(
                  'Croix directionnelle',
                  "Affiche des flèches à l'écran en plus du toucher et du glissé.",
                  p.dpad,
                  store.setDpad,
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      shape: const RoundedRectangleBorder(),
                      side: const BorderSide(color: Palette.hp),
                      padding: const EdgeInsets.all(14),
                    ),
                    onPressed: () => _confirmReset(context),
                    icon: const Icon(Icons.delete_forever, color: Palette.hp),
                    label: Text('EFFACER LA PROGRESSION', style: pixel(8, color: Palette.hp)),
                  ),
                ),
                const SizedBox(height: 30),
                const Padding(
                  padding: EdgeInsets.only(left: 12),
                  child: Text(
                    'Donjon en Direct\nSprites : Tiny Dungeon par Kenney (CC0)\nPolice : Press Start 2P (SIL OFL)\n'
                    'Sons et musiques : synthétisés pour le jeu (tool/make_sounds.py)',
                    style: TextStyle(color: Palette.muted, fontSize: 12, height: 1.5),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _toggle(String title, String desc, bool value, ValueChanged<bool> onChanged) => Container(
        margin: const EdgeInsets.only(left: 12, bottom: 10),
        decoration: BoxDecoration(color: Palette.panel, border: Border.all(color: Palette.panelBorder)),
        child: SwitchListTile(
          value: value,
          onChanged: onChanged,
          activeThumbColor: Palette.gold,
          title: Text(title, style: const TextStyle(color: Palette.text)),
          subtitle: Text(desc, style: const TextStyle(color: Palette.muted, fontSize: 12)),
        ),
      );
}
