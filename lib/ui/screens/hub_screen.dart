import 'package:flutter/material.dart';

import '../../content/roles.dart';
import '../../content/skills.dart';
import '../../content/sprites.dart';
import '../../content/upgrades.dart';
import '../../core/show.dart';
import '../../meta/profile.dart';
import '../../meta/profile_store.dart';
import '../render/sprite_atlas.dart';
import '../theme.dart';

/// La Loge des stars : rôles, contrats permanents et rediffusions des runs passées.
class HubScreen extends StatelessWidget {
  const HubScreen({super.key, required this.store, required this.atlas});

  final ProfileStore store;
  final SpriteAtlas atlas;

  static Future<void> show(BuildContext context, ProfileStore store, SpriteAtlas atlas) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => HubScreen(store: store, atlas: atlas)));

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFF0E0A14),
        body: SafeArea(
          child: ListenableBuilder(
            listenable: store,
            builder: (context, _) {
              final p = store.profile;
              return Column(
                children: [
                  Container(
                    color: Palette.panel,
                    padding: const EdgeInsets.fromLTRB(4, 6, 14, 0),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back, color: Palette.text),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                            Expanded(child: Text('LOGE DES STARS', style: pixel(12, color: Palette.gold))),
                            const Icon(Icons.copyright, color: Palette.gold, size: 18),
                            const SizedBox(width: 4),
                            Text('${p.royalties}', style: pixel(11, color: Palette.gold)),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 2, 0, 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SpriteIcon(atlas, Sprites.maestro, size: 32),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  "« Bienvenue dans ma loge. Ne touchez à rien, sauf à votre portefeuille. "
                                  "Les droits d'auteur, c'est vous qui les gagnez ; les dépenser, c'est moi qui décide où. »",
                                  style: TextStyle(
                                      color: Palette.maestro, fontSize: 12, height: 1.35, fontStyle: FontStyle.italic),
                                ),
                              ),
                            ],
                          ),
                        ),
                        TabBar(
                          indicatorColor: Palette.gold,
                          labelStyle: pixel(7),
                          labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                          labelColor: Palette.gold,
                          unselectedLabelColor: Palette.muted,
                          tabs: const [Tab(text: 'ROLES'), Tab(text: 'CONTRATS'), Tab(text: 'REDIFFUSIONS')],
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [_roles(p), _upgrades(p), _history(p)],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- rôles

  Widget _roles(Profile p) => ListView(
        padding: const EdgeInsets.all(12),
        children: [
          for (final r in roleDefs) _roleCard(p, r),
        ],
      );

  Widget _roleCard(Profile p, RoleDef r) {
    final owned = p.roles.contains(r.id);
    final selected = p.selectedRole == r.id;
    final canBuy = p.royalties >= r.cost;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFF2A2410) : Palette.panel,
        border: Border.all(color: selected ? Palette.gold : Palette.panelBorder, width: 2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Opacity(opacity: owned ? 1 : 0.45, child: SpriteIcon(atlas, r.sprite, size: 52)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.name, style: TextStyle(color: owned ? Palette.text : Palette.muted, fontSize: 15)),
                const SizedBox(height: 3),
                Text(r.perks, style: const TextStyle(color: Palette.xp, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Pouvoir : ${skillById(r.skill).name} — ${skillById(r.skill).desc}',
                    style: const TextStyle(color: Color(0xFF5EC8FF), fontSize: 12)),
                const SizedBox(height: 4),
                Text('« ${r.pitch} »',
                    style: const TextStyle(color: Palette.muted, fontSize: 12, height: 1.3, fontStyle: FontStyle.italic)),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: selected
                      ? Text('CHOISI', style: pixel(8, color: Palette.gold))
                      : owned
                          ? OutlinedButton(
                              style: OutlinedButton.styleFrom(shape: const RoundedRectangleBorder()),
                              onPressed: () => store.selectRole(r.id),
                              child: Text('CHOISIR', style: pixel(8)),
                            )
                          : FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: Palette.gold,
                                disabledBackgroundColor: const Color(0xFF3D3150),
                                shape: const RoundedRectangleBorder(),
                              ),
                              onPressed: canBuy ? () => store.buyRole(r.id) : null,
                              child: Text('SIGNER : ${r.cost}',
                                  style: pixel(8, color: canBuy ? Palette.bg : Palette.muted)),
                            ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- contrats

  Widget _upgrades(Profile p) => ListView(
        padding: const EdgeInsets.all(12),
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Text(
              "Bonus permanents pour toutes vos runs (sauf le défi du jour, où tout le monde part à égalité).",
              style: TextStyle(color: Palette.muted, fontSize: 12),
            ),
          ),
          for (final u in upgradeDefs) _upgradeCard(p, u),
        ],
      );

  Widget _upgradeCard(Profile p, UpgradeDef u) {
    final lvl = p.level(u.id);
    final cost = p.nextUpgradeCost(u.id);
    final canBuy = cost != null && p.royalties >= cost;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Palette.panel, border: Border.all(color: Palette.panelBorder, width: 2)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(u.name, style: const TextStyle(color: Palette.text, fontSize: 15)),
                const SizedBox(height: 3),
                Text(u.desc, style: const TextStyle(color: Palette.muted, fontSize: 12)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    for (var i = 0; i < u.maxLevel; i++)
                      Container(
                        width: 18,
                        height: 8,
                        margin: const EdgeInsets.only(right: 4),
                        color: i < lvl ? Palette.gold : Colors.black,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (cost == null)
            Text('MAX', style: pixel(9, color: Palette.gold))
          else
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Palette.gold,
                disabledBackgroundColor: const Color(0xFF3D3150),
                shape: const RoundedRectangleBorder(),
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              onPressed: canBuy ? () => store.buyUpgrade(u.id) : null,
              child: Text('$cost', style: pixel(9, color: canBuy ? Palette.bg : Palette.muted)),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- rediffusions

  Widget _history(Profile p) {
    Widget stat(String k, String v) => Expanded(
          child: Column(
            children: [
              Text(v, style: pixel(11, color: Palette.gold)),
              const SizedBox(height: 4),
              Text(k, textAlign: TextAlign.center, style: const TextStyle(color: Palette.muted, fontSize: 11)),
            ],
          ),
        );
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(color: Palette.panel, border: Border.all(color: Palette.panelBorder)),
          child: Row(
            children: [
              stat('Saisons', '${p.runs}'),
              stat('Record étage', '${p.bestFloor}'),
              stat('Record audience', formatViewers(p.bestViewers)),
              stat('Monstres', '${p.totalKills}'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (p.history.isEmpty)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              "Aucune rediffusion. MAESTRO attend votre premier échec avec impatience.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Palette.muted),
            ),
          ),
        for (final r in p.history) _record(r),
      ],
    );
  }

  Widget _record(RunRecord r) {
    final date = DateTime.tryParse(r.date);
    final when = date == null
        ? ''
        : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')} '
            '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    final role = roleById(r.roleId);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Palette.panel,
        border: Border.all(color: r.daily ? Palette.xp : Palette.panelBorder),
      ),
      child: Row(
        children: [
          SpriteIcon(atlas, role.sprite, size: 36),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('ETAGE ${r.floor}', style: pixel(9, color: Palette.text)),
                    if (r.daily) ...[
                      const SizedBox(width: 6),
                      Text('DEFI', style: pixel(7, color: Palette.xp)),
                    ],
                    const Spacer(),
                    Text(when, style: const TextStyle(color: Palette.muted, fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${role.name} · niv. ${r.level} · ${r.kills} monstres · ${formatViewers(r.viewers)} spectateurs',
                  style: const TextStyle(color: Palette.muted, fontSize: 12),
                ),
                Text('Tué par : ${r.killedBy}', style: const TextStyle(color: Palette.muted, fontSize: 12)),
                Text("+${r.royalties} droits d'auteur", style: const TextStyle(color: Palette.gold, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
