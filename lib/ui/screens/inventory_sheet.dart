import 'package:flutter/material.dart';

import '../../content/items.dart';
import '../../core/game.dart';
import '../game_controller.dart';
import '../render/sprite_atlas.dart';
import '../theme.dart';

/// Sac : équipement porté, objets, actions (utiliser / équiper / jeter).
class InventorySheet extends StatefulWidget {
  const InventorySheet({super.key, required this.c, required this.atlas});

  final GameController c;
  final SpriteAtlas atlas;

  static Future<void> show(BuildContext context, GameController c, SpriteAtlas atlas) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Palette.panel,
      shape: const RoundedRectangleBorder(),
      builder: (_) => InventorySheet(c: c, atlas: atlas),
    );
  }

  @override
  State<InventorySheet> createState() => _InventorySheetState();
}

class _InventorySheetState extends State<InventorySheet> {
  /// Objet sélectionné : id d'un objet du sac, ou 'weapon' / 'trinket' pour l'équipement.
  String? selected;

  Game get g => widget.c.game;

  void _do(PlayerAction a) {
    widget.c.inventoryAction(a);
    setState(() => selected = null);
    if (g.gameOver) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.c,
      builder: (context, _) {
        final sel = _selectedDef();
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text('SAC', style: pixel(14, color: Palette.gold)),
                    const Spacer(),
                    Text('ATQ ${g.player.atk}  DEF ${g.player.def}  CRIT ${(g.critChance * 100).round()}%',
                        style: pixel(8, color: Palette.muted)),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: _slot('ARME', 'weapon', g.weapon)),
                    const SizedBox(width: 10),
                    Expanded(child: _slot('ACCESSOIRE', 'trinket', g.trinket)),
                  ],
                ),
                const SizedBox(height: 14),
                Text('OBJETS ${g.inventory.length}/${Game.maxSlots}', style: pixel(8, color: Palette.muted)),
                const SizedBox(height: 8),
                GridView.count(
                  crossAxisCount: 5,
                  shrinkWrap: true,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    for (var i = 0; i < Game.maxSlots; i++)
                      i < g.inventory.length ? _cell(g.inventory[i].def, g.inventory[i].count) : _emptyCell(),
                  ],
                ),
                const SizedBox(height: 14),
                if (sel != null) _details(sel) else _hint(),
              ],
            ),
          ),
        );
      },
    );
  }

  ItemDef? _selectedDef() {
    switch (selected) {
      case null:
        return null;
      case 'weapon':
        return g.weapon;
      case 'trinket':
        return g.trinket;
      default:
        for (final i in g.inventory) {
          if (i.def.id == selected) return i.def;
        }
        return null;
    }
  }

  Widget _slot(String label, String key, ItemDef? d) {
    final active = selected == key;
    return GestureDetector(
      onTap: d == null ? null : () => setState(() => selected = key),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF2E2540),
          border: Border.all(color: active ? Palette.gold : Palette.panelBorder, width: 2),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 36,
              height: 36,
              child: d == null ? null : SpriteIcon(widget.atlas, g.spriteOf(d), size: 36),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: pixel(6, color: Palette.muted)),
                  const SizedBox(height: 4),
                  Text(
                    d?.name ?? '—',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: d == null ? Palette.muted : Color(d.rarity.color), fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cell(ItemDef d, int count) {
    final active = selected == d.id;
    return GestureDetector(
      key: ValueKey('inv-${d.id}'),
      onTap: () => setState(() => selected = d.id),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF2E2540),
          border: Border.all(color: active ? Palette.gold : Color(d.rarity.color).withValues(alpha: 0.6), width: 2),
        ),
        child: Stack(
          children: [
            Center(child: SpriteIcon(widget.atlas, g.spriteOf(d), size: 40)),
            if (count > 1)
              Positioned(right: 3, bottom: 2, child: Text('x$count', style: pixel(7, color: Palette.text))),
          ],
        ),
      ),
    );
  }

  Widget _emptyCell() => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1424),
          border: Border.all(color: Palette.panelBorder),
        ),
      );

  Widget _hint() => const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Text(
          'Touchez un objet pour le voir. Utiliser, équiper ou jeter prend un tour.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Palette.muted, fontSize: 12),
        ),
      );

  Widget _details(ItemDef d) {
    final equipped = selected == 'weapon' || selected == 'trinket';
    final known = !d.mystery || g.identified.contains(d.effect);
    final buttons = <Widget>[
      if (equipped)
        _btn('RETIRER', () => _do(UnequipAction(d.kind)))
      else if (d.equippable)
        _btn('EQUIPER', () => _do(EquipAction(d.id)), primary: true)
      else
        _btn(known ? 'UTILISER' : 'GOUTER', () => _do(UseItemAction(d.id)), primary: true),
      if (!equipped) _btn('JETER', () => _do(DropAction(d.id))),
    ];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1424),
        border: Border.all(color: Color(d.rarity.color), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SpriteIcon(widget.atlas, g.spriteOf(d), size: 40),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(g.nameOf(d), style: TextStyle(color: Color(d.rarity.color), fontSize: 15)),
                    Text(known ? d.rarity.label : 'Non identifiée', style: pixel(7, color: Palette.muted)),
                  ],
                ),
              ),
            ],
          ),
          if (d.statLine.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(d.statLine, style: pixel(8, color: Palette.gold)),
          ],
          const SizedBox(height: 6),
          Text(g.descOf(d), style: const TextStyle(color: Palette.text, fontSize: 13, height: 1.35)),
          if (d.equippable && !equipped) ...[
            const SizedBox(height: 6),
            Text(_compare(d), style: const TextStyle(color: Palette.muted, fontSize: 12)),
          ],
          const SizedBox(height: 10),
          Row(children: [for (final b in buttons) Expanded(child: b)]),
        ],
      ),
    );
  }

  String _compare(ItemDef d) {
    final cur = d.kind == ItemKind.weapon ? g.weapon : g.trinket;
    if (cur == null) return 'Emplacement libre.';
    String diff(String label, num a, num b) {
      final delta = a - b;
      if (delta == 0) return '';
      return '$label ${delta > 0 ? '+' : ''}${delta is double ? '${(delta * 100).round()}%' : delta}';
    }

    final parts = [
      diff('ATQ', d.atk, cur.atk),
      diff('DEF', d.def, cur.def),
      diff('PV', d.maxHp, cur.maxHp),
      diff('CRIT', d.crit, cur.crit),
      diff('VOL', d.lifesteal, cur.lifesteal),
    ].where((s) => s.isNotEmpty);
    return parts.isEmpty ? 'Équivalent à ${cur.name}.' : 'Par rapport à ${cur.name} : ${parts.join(', ')}';
  }

  Widget _btn(String label, VoidCallback onTap, {bool primary = false}) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: primary
            ? FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Palette.gold, shape: const RoundedRectangleBorder()),
                onPressed: onTap,
                child: Text(label, style: pixel(9, color: Palette.bg)),
              )
            : OutlinedButton(
                style: OutlinedButton.styleFrom(shape: const RoundedRectangleBorder()),
                onPressed: onTap,
                child: Text(label, style: pixel(9)),
              ),
      );
}
