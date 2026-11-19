import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'meta/profile_store.dart';
import 'ui/audio.dart';
import 'ui/render/sprite_atlas.dart';
import 'ui/screens/title_screen.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final atlas = await SpriteAtlas.load();
  final store = await ProfileStore.load();
  // L'audio se prépare en arrière-plan : le jeu s'affiche sans attendre.
  GameAudio.instance
    ..sfxOn = store.profile.soundFx
    ..musicOn = store.profile.music
    ..init();
  runApp(DonjonApp(atlas: atlas, store: store));
}

class DonjonApp extends StatelessWidget {
  const DonjonApp({super.key, required this.atlas, required this.store});

  final SpriteAtlas atlas;
  final ProfileStore store;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Donjon en Direct',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: TitleScreen(atlas: atlas, store: store),
      );
}
