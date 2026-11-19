import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/game.dart';
import 'profile.dart';

/// Charge et sauvegarde le profil sur l'appareil.
class ProfileStore extends ChangeNotifier {
  ProfileStore._(this._prefs, this.profile, this._savedRun);

  /// Magasin en mémoire seulement (tests).
  ProfileStore.memory([Profile? p])
      : _prefs = null,
        profile = p ?? Profile();

  static const _key = 'profile_v1';
  static const _runKey = 'run_v1';

  /// Partie en cours sauvegardée (JSON du journal), ou null.
  String? _savedRun;

  final SharedPreferences? _prefs;
  Profile profile;

  static Future<ProfileStore> load() async {
    final prefs = await SharedPreferences.getInstance();
    Profile p;
    try {
      final raw = prefs.getString(_key);
      p = raw == null ? Profile() : Profile.fromJson((jsonDecode(raw) as Map).cast<String, Object?>());
    } catch (_) {
      // Profil illisible : on repart de zéro plutôt que de planter.
      p = Profile();
    }
    return ProfileStore._(prefs, p, prefs.getString(_runKey));
  }

  Future<void> _save() async {
    notifyListeners();
    await _prefs?.setString(_key, jsonEncode(profile.toJson()));
  }

  // ---------------------------------------------------------------- partie en cours

  bool get hasSavedRun => _savedRun != null;

  /// Résumé de la partie sauvegardée (étage, rôle, défi) sans la rejouer.
  Map<String, Object?>? get savedRunInfo {
    final raw = _savedRun;
    if (raw == null) return null;
    try {
      return (jsonDecode(raw) as Map).cast<String, Object?>();
    } catch (_) {
      return null;
    }
  }

  /// Sauvegarde la partie (ou l'efface si elle est terminée).
  Future<void> saveRun(Game g) async {
    if (g.gameOver) return clearRun();
    _savedRun = jsonEncode(g.toSave());
    await _prefs?.setString(_runKey, _savedRun!);
  }

  /// Reconstruit la partie sauvegardée (null si absente ou incompatible).
  Game? loadRun() {
    final info = savedRunInfo;
    return info == null ? null : Game.fromSave(info);
  }

  Future<void> clearRun() async {
    _savedRun = null;
    notifyListeners();
    await _prefs?.remove(_runKey);
  }

  /// Une nouvelle run remplace la sauvegarde : l'ancienne compte comme abandonnée
  /// (droits d'auteur versés, pas de triche possible en relançant).
  Future<void> abandonSavedRun() async {
    final g = loadRun();
    if (g != null && !g.gameOver) {
      g.abandon();
      profile.recordRun(g);
      await _save();
    }
    await clearRun();
  }

  RunSummary recordRun(Game g) {
    final s = profile.recordRun(g);
    _save();
    return s;
  }

  void setVibrations(bool on) {
    profile.vibrations = on;
    _save();
  }

  void setSoundFx(bool on) {
    profile.soundFx = on;
    _save();
  }

  void setMusic(bool on) {
    profile.music = on;
    _save();
  }

  void setDpad(bool on) {
    profile.dpad = on;
    _save();
  }

  /// Efface toute la progression (droits d'auteur, rôles, succès, historique).
  void reset() {
    final keep = profile;
    profile = Profile()
      ..vibrations = keep.vibrations
      ..dpad = keep.dpad
      ..soundFx = keep.soundFx
      ..music = keep.music;
    _save();
  }

  bool buyRole(String id) => _apply(profile.buyRole(id));
  bool selectRole(String id) => _apply(profile.selectRole(id));
  bool buyUpgrade(String id) => _apply(profile.buyUpgrade(id));

  bool _apply(bool ok) {
    if (ok) _save();
    return ok;
  }
}
