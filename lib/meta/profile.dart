import 'dart:math' as math;

import '../content/roles.dart';
import '../content/upgrades.dart';
import '../core/game.dart';

/// Une run terminée, pour les « rediffusions ».
class RunRecord {
  const RunRecord({
    required this.date,
    required this.roleId,
    required this.floor,
    required this.viewers,
    required this.kills,
    required this.level,
    required this.killedBy,
    required this.achievements,
    required this.royalties,
    required this.daily,
  });

  final String date;
  final String roleId;
  final int floor;
  final double viewers;
  final int kills;
  final int level;
  final String killedBy;
  final int achievements;
  final int royalties;
  final bool daily;

  Map<String, Object?> toJson() => {
        'date': date,
        'role': roleId,
        'floor': floor,
        'viewers': viewers,
        'kills': kills,
        'level': level,
        'killedBy': killedBy,
        'ach': achievements,
        'roy': royalties,
        'daily': daily,
      };

  factory RunRecord.fromJson(Map<String, Object?> j) => RunRecord(
        date: j['date'] as String? ?? '',
        roleId: j['role'] as String? ?? 'lambda',
        floor: (j['floor'] as num?)?.toInt() ?? 0,
        viewers: (j['viewers'] as num?)?.toDouble() ?? 0,
        kills: (j['kills'] as num?)?.toInt() ?? 0,
        level: (j['level'] as num?)?.toInt() ?? 1,
        killedBy: j['killedBy'] as String? ?? '?',
        achievements: (j['ach'] as num?)?.toInt() ?? 0,
        royalties: (j['roy'] as num?)?.toInt() ?? 0,
        daily: j['daily'] as bool? ?? false,
      );
}

class RoyaltyLine {
  const RoyaltyLine(this.label, this.amount);
  final String label;
  final int amount;
}

/// Bilan de fin de run affiché sur l'écran « Fin de diffusion ».
class RunSummary {
  const RunSummary(this.lines, this.total, this.newAchievements, {this.bestFloor = false, this.bestViewers = false});
  final List<RoyaltyLine> lines;
  final int total;
  final List<String> newAchievements;
  final bool bestFloor;
  final bool bestViewers;
}

/// Profil du joueur, conservé entre les runs (méta-progression).
class Profile {
  Profile();

  int royalties = 0;
  int totalRoyalties = 0;
  int runs = 0;
  int bestFloor = 0;
  double bestViewers = 0;
  int totalKills = 0;
  final achievements = <String>{};
  final roles = <String>{'lambda'};
  final upgrades = <String, int>{};
  String selectedRole = 'lambda';
  final history = <RunRecord>[];

  // Réglages
  bool vibrations = true;
  bool dpad = false;
  bool soundFx = true;
  bool music = true;

  // Défi du jour
  String dailyDate = '';
  int dailyBestFloor = 0;
  int dailyAttempts = 0;

  static const maxHistory = 15;

  int level(String upgrade) => upgrades[upgrade] ?? 0;

  /// Configuration de la prochaine run.
  RunSetup setupFor({bool daily = false}) => daily
      ? RunSetup.dailyChallenge
      : RunSetup(roleId: roles.contains(selectedRole) ? selectedRole : 'lambda', upgrades: Map.of(upgrades));

  bool buyRole(String id) {
    final r = roleById(id);
    if (roles.contains(id) || royalties < r.cost) return false;
    royalties -= r.cost;
    roles.add(id);
    selectedRole = id;
    return true;
  }

  bool selectRole(String id) {
    if (!roles.contains(id)) return false;
    selectedRole = id;
    return true;
  }

  /// Prix du prochain niveau, ou null si le contrat est au maximum.
  int? nextUpgradeCost(String id) {
    final u = upgradeById(id);
    final lvl = level(id);
    return lvl >= u.maxLevel ? null : u.costs[lvl];
  }

  bool buyUpgrade(String id) {
    final cost = nextUpgradeCost(id);
    if (cost == null || royalties < cost) return false;
    royalties -= cost;
    upgrades[id] = level(id) + 1;
    return true;
  }

  /// Enregistre une run terminée : droits d'auteur, records, succès, historique.
  RunSummary recordRun(Game g, {DateTime? now}) {
    final when = now ?? DateTime.now();
    final daily = g.setup.daily;
    final newAch = g.unlocked.where((a) => !achievements.contains(a)).toList();

    final lines = <RoyaltyLine>[
      RoyaltyLine('Étages atteints (${g.floor})', g.floor * 12),
      RoyaltyLine('Audience record', (math.sqrt(g.show.peakViewers) / 2).round()),
      RoyaltyLine('Monstres éliminés (${g.kills})', g.kills),
      if (g.unlocked.isNotEmpty) RoyaltyLine('Succès de la run (${g.unlocked.length})', g.unlocked.length * 5),
      if (newAch.isNotEmpty) RoyaltyLine('Nouveaux succès (${newAch.length})', newAch.length * 15),
      if (g.victory) const RoyaltyLine('SAISON GAGNÉE', 250),
    ];
    var total = lines.fold<int>(0, (s, l) => s + l.amount);
    if (daily) {
      final bonus = total ~/ 2;
      lines.add(RoyaltyLine('Bonus défi du jour (+50 %)', bonus));
      total += bonus;
    }

    final isBestFloor = g.floor > bestFloor;
    final isBestViewers = g.show.peakViewers > bestViewers;
    royalties += total;
    totalRoyalties += total;
    runs++;
    totalKills += g.kills;
    if (isBestFloor) bestFloor = g.floor;
    if (isBestViewers) bestViewers = g.show.peakViewers;
    achievements.addAll(g.unlocked);

    if (daily) {
      final today = dayKey(when);
      if (dailyDate != today) {
        dailyDate = today;
        dailyBestFloor = 0;
        dailyAttempts = 0;
      }
      dailyAttempts++;
      if (g.floor > dailyBestFloor) dailyBestFloor = g.floor;
    }

    history.insert(
      0,
      RunRecord(
        date: when.toIso8601String(),
        roleId: g.setup.roleId,
        floor: g.floor,
        viewers: g.show.peakViewers,
        kills: g.kills,
        level: g.playerLevel,
        killedBy: g.killedBy ?? '?',
        achievements: g.unlocked.length,
        royalties: total,
        daily: daily,
      ),
    );
    if (history.length > maxHistory) history.removeRange(maxHistory, history.length);

    return RunSummary(lines, total, newAch, bestFloor: isBestFloor, bestViewers: isBestViewers);
  }

  /// Meilleur étage au défi du jour [d] (0 si pas encore tenté).
  int dailyBestFor(DateTime d) => dailyDate == dayKey(d) ? dailyBestFloor : 0;
  int dailyAttemptsFor(DateTime d) => dailyDate == dayKey(d) ? dailyAttempts : 0;

  static String dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // ---------------------------------------------------------------- JSON

  Map<String, Object?> toJson() => {
        'v': 1,
        'royalties': royalties,
        'totalRoyalties': totalRoyalties,
        'runs': runs,
        'bestFloor': bestFloor,
        'bestViewers': bestViewers,
        'totalKills': totalKills,
        'achievements': achievements.toList(),
        'roles': roles.toList(),
        'upgrades': upgrades,
        'selectedRole': selectedRole,
        'history': [for (final r in history) r.toJson()],
        'dailyDate': dailyDate,
        'dailyBestFloor': dailyBestFloor,
        'dailyAttempts': dailyAttempts,
        'vibrations': vibrations,
        'dpad': dpad,
        'sfx': soundFx,
        'music': music,
      };

  factory Profile.fromJson(Map<String, Object?> j) {
    final p = Profile()
      ..royalties = (j['royalties'] as num?)?.toInt() ?? 0
      ..totalRoyalties = (j['totalRoyalties'] as num?)?.toInt() ?? 0
      ..runs = (j['runs'] as num?)?.toInt() ?? 0
      ..bestFloor = (j['bestFloor'] as num?)?.toInt() ?? 0
      ..bestViewers = (j['bestViewers'] as num?)?.toDouble() ?? 0
      ..totalKills = (j['totalKills'] as num?)?.toInt() ?? 0
      ..selectedRole = j['selectedRole'] as String? ?? 'lambda'
      ..dailyDate = j['dailyDate'] as String? ?? ''
      ..dailyBestFloor = (j['dailyBestFloor'] as num?)?.toInt() ?? 0
      ..dailyAttempts = (j['dailyAttempts'] as num?)?.toInt() ?? 0
      ..vibrations = j['vibrations'] as bool? ?? true
      ..dpad = j['dpad'] as bool? ?? false
      ..soundFx = j['sfx'] as bool? ?? true
      ..music = j['music'] as bool? ?? true;
    p.achievements.addAll((j['achievements'] as List?)?.cast<String>() ?? const []);
    p.roles.addAll((j['roles'] as List?)?.cast<String>() ?? const []);
    final ups = j['upgrades'] as Map?;
    ups?.forEach((k, v) => p.upgrades[k as String] = (v as num).toInt());
    for (final r in (j['history'] as List?) ?? const []) {
      p.history.add(RunRecord.fromJson((r as Map).cast<String, Object?>()));
    }
    return p;
  }
}
