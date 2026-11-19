import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/game.dart';
import 'profile.dart';

/// Charge et sauvegarde le profil sur l'appareil.
class ProfileStore extends ChangeNotifier {
  ProfileStore._(this._prefs, this.profile);

  /// Magasin en mémoire seulement (tests).
  ProfileStore.memory([Profile? p])
      : _prefs = null,
        profile = p ?? Profile();

  static const _key = 'profile_v1';

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
    return ProfileStore._(prefs, p);
  }

  Future<void> _save() async {
    notifyListeners();
    await _prefs?.setString(_key, jsonEncode(profile.toJson()));
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

  void setDpad(bool on) {
    profile.dpad = on;
    _save();
  }

  /// Efface toute la progression (droits d'auteur, rôles, succès, historique).
  void reset() {
    final keep = profile;
    profile = Profile()
      ..vibrations = keep.vibrations
      ..dpad = keep.dpad;
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
