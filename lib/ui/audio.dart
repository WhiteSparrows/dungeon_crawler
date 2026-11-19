import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';

/// Bruitages (fichiers assets/audio/*.wav, générés par tool/make_sounds.py).
enum Sfx {
  hit,
  crit,
  hurt,
  kill,
  coin,
  pickup,
  potion,
  levelup,
  lootbox,
  achievement,
  boss,
  trap,
  stairs,
  boxGained('box_gained'),
  click,
  door,
  death,
  victory,
  jingle,
  applause,
  laugh,
  boo;

  const Sfx([this._file]);
  final String? _file;
  String get file => _file ?? name;
}

enum Music {
  dungeon('music_dungeon', 0.32),
  show('music_show', 0.32);

  const Music(this.file, this.volume);
  final String file;
  final double volume;
}

/// Lecteur audio du jeu. Tant que [init] n'a pas réussi (tests, plateforme sans son),
/// tout est silencieux : aucune erreur ne remonte jusqu'au jeu.
class GameAudio with WidgetsBindingObserver {
  GameAudio._();
  static final instance = GameAudio._();

  bool sfxOn = true;
  bool musicOn = true;
  bool _ready = false;
  final _pools = <Sfx, AudioPool>{};
  AudioPlayer? _player;
  Music? _current;
  bool _paused = false;

  Future<void> init() async {
    try {
      final player = AudioPlayer();
      await player.setReleaseMode(ReleaseMode.loop);
      _player = player;
      WidgetsBinding.instance.addObserver(this);
      _ready = true;
      // La musique d'abord (demandée par l'écran titre pendant le chargement), puis les bruitages.
      await _restartMusic();
      for (final s in Sfx.values) {
        _pools[s] = await AudioPool.createFromAsset(path: 'audio/${s.file}.wav', maxPlayers: 3);
      }
    } catch (e) {
      debugPrint('GameAudio init: $e');
      _ready = false;
    }
  }

  void play(Sfx s, {double volume = 0.8}) {
    if (!_ready || !sfxOn || _paused) return;
    _pools[s]?.start(volume: volume).catchError((_) => () async {});
  }

  /// Lance une musique (ne fait rien si c'est déjà celle-ci).
  Future<void> music(Music m) async {
    if (_current == m) return;
    _current = m;
    await _restartMusic();
  }

  Future<void> _restartMusic() async {
    final p = _player;
    if (!_ready || p == null) return;
    try {
      await p.stop();
      final m = _current;
      if (m != null && musicOn && !_paused) await p.play(AssetSource('audio/${m.file}.wav'), volume: m.volume);
    } catch (e) {
      debugPrint('GameAudio musique: $e');
    }
  }

  Future<void> setMusicOn(bool on) async {
    musicOn = on;
    await _restartMusic();
  }

  /// Coupe tout quand l'application passe en arrière-plan.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final p = _player;
    if (p == null) return;
    if (state == AppLifecycleState.resumed) {
      if (!_paused) return;
      _paused = false;
      if (musicOn && _current != null) {
        // Reprise là où on en était ; si le lecteur a été libéré entre-temps, on relance.
        final resume = p.state == PlayerState.paused ? p.resume() : _restartMusic();
        resume.catchError((Object e) => debugPrint('GameAudio reprise: $e'));
      }
    } else if (!_paused) {
      _paused = true;
      p.pause().catchError((Object e) => debugPrint('GameAudio pause: $e'));
    }
  }
}
