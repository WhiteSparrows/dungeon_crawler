import 'package:flutter/material.dart';

import '../../content/interviews.dart';
import '../../content/sprites.dart';
import '../../core/backstage.dart';
import '../../core/game.dart';
import '../../core/show.dart';
import '../../meta/profile_store.dart';
import '../game_controller.dart';
import '../tutorial.dart';
import '../render/sprite_atlas.dart';
import '../theme.dart';

/// Entre deux étages : le plateau d'interview de MAESTRO, puis les coulisses.
class BackstageScreen extends StatefulWidget {
  const BackstageScreen({super.key, required this.c, required this.atlas, this.store});

  final GameController c;
  final SpriteAtlas atlas;

  /// Pour les conseils de MAESTRO (absent dans certains tests).
  final ProfileStore? store;

  @override
  State<BackstageScreen> createState() => _BackstageScreenState();
}

class _BackstageScreenState extends State<BackstageScreen> {
  final _scroll = ScrollController();
  bool _coulisses = false;

  Game get g => widget.c.game;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _tip('interview'));
  }

  Future<void> _tip(String id) async {
    final store = widget.store;
    if (store == null || !mounted || !store.takeTip(id)) return;
    if (await showTip(context, widget.atlas, id)) store.setTips(false);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _answer(int i) {
    widget.c.answer(i);
    // Fait défiler jusqu'à la réaction.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
      }
    });
  }

  void _leave() {
    widget.c.leaveBackstage();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF0E0A14),
        body: SafeArea(
          child: ListenableBuilder(
            listenable: widget.c,
            builder: (context, _) {
              final b = g.backstage;
              if (b == null) return const SizedBox.shrink();
              return Column(
                children: [
                  _header(),
                  Expanded(child: _coulisses ? _backstage(b) : _interview(b)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      color: Palette.panel,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Row(
        children: [
          Container(width: 10, height: 10, decoration: const BoxDecoration(color: Palette.hp, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(_coulisses ? 'COULISSES' : 'EN DIRECT DU PLATEAU', style: pixel(9, color: Palette.text)),
          const Spacer(),
          const Icon(Icons.visibility, color: Palette.muted, size: 16),
          const SizedBox(width: 4),
          Text(formatViewers(g.show.viewers), style: pixel(8, color: Palette.text)),
          const SizedBox(width: 12),
          SpriteIcon(widget.atlas, Sprites.coin, size: 18),
          Text('${g.gold}', style: pixel(9, color: Palette.gold)),
        ],
      ),
    );
  }

  // ================================================================ interview

  Widget _interview(Backstage b) {
    final items = <Widget>[
      const SizedBox(height: 8),
      _studio(),
      _maestro(b.intro),
    ];
    for (var i = 0; i < b.results.length; i++) {
      final r = b.results[i];
      items
        ..add(_maestro(g.withSponsors(b.questions[i].text)))
        ..add(_player(r.answerText))
        ..add(_crowd(r.crowd))
        ..add(_maestro(r.reaction))
        ..add(_effects(r.effects));
    }
    final q = b.question;
    if (q != null) items.add(_maestro(g.withSponsors(q.text), highlight: true));
    items.add(const SizedBox(height: 12));

    return Column(
      children: [
        Expanded(
          child: ListView(controller: _scroll, padding: const EdgeInsets.symmetric(horizontal: 14), children: items),
        ),
        Container(
          color: Palette.panel,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: q != null
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('QUESTION ${b.current + 1}/${b.questions.length} - VOTRE REPONSE :',
                        style: pixel(7, color: Palette.muted)),
                    const SizedBox(height: 8),
                    for (var i = 0; i < q.answers.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            side: const BorderSide(color: Palette.gold),
                            shape: const RoundedRectangleBorder(),
                          ),
                          onPressed: () => _answer(i),
                          child: Text('« ${g.withSponsors(q.answers[i].text)} »',
                              style: const TextStyle(color: Palette.text, fontSize: 14)),
                        ),
                      ),
                  ],
                )
              : _bigButton('PASSER EN COULISSES', () {
                  setState(() => _coulisses = true);
                  WidgetsBinding.instance.addPostFrameCallback((_) => _tip('backstage'));
                }),
        ),
      ],
    );
  }

  Widget _studio() => Container(
        margin: const EdgeInsets.only(bottom: 12),
        height: 80,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF3A1450), Color(0xFF14101C), Color(0xFF3A1450)]),
          border: Border.all(color: Palette.maestro.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              SpriteIcon(widget.atlas, Sprites.maestro, size: 48),
              Text('MAESTRO', style: pixel(6, color: Palette.maestro)),
            ]),
            Text('ETAGE ${g.floor} TERMINE', style: pixel(9, color: Palette.gold)),
            Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              SpriteIcon(widget.atlas, Sprites.hero, size: 48),
              Text('VOUS', style: pixel(6, color: Palette.text)),
            ]),
          ],
        ),
      );

  Widget _maestro(String text, {bool highlight = false}) => Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8, right: 40),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF1F1230),
            border: Border.all(color: highlight ? Palette.maestro : Palette.maestro.withValues(alpha: 0.4), width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('MAESTRO', style: pixel(7, color: Palette.maestro)),
              const SizedBox(height: 4),
              Text(text, style: const TextStyle(color: Palette.text, fontSize: 14, height: 1.35)),
            ],
          ),
        ),
      );

  Widget _player(String text) => Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8, left: 40),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF2A2410),
            border: Border.all(color: Palette.gold.withValues(alpha: 0.6), width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('VOUS', style: pixel(7, color: Palette.gold)),
              const SizedBox(height: 4),
              Text('« $text »', style: const TextStyle(color: Palette.text, fontSize: 14, height: 1.35)),
            ],
          ),
        ),
      );

  Widget _crowd(Crowd c) {
    final color = switch (c) {
      Crowd.applause => const Color(0xFF8BE58B),
      Crowd.laughs => Palette.gold,
      Crowd.boos => const Color(0xFFFF7A7A),
      Crowd.gasps => const Color(0xFF5EC8FF),
      Crowd.silence => Palette.muted,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Center(
        child: Text('~ LE PUBLIC : ${c.label.replaceAll('É', 'E')} ~', style: pixel(8, color: color)),
      ),
    );
  }

  Widget _effects(List<String> effects) {
    if (effects.isEmpty) return const SizedBox(height: 4);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        alignment: WrapAlignment.center,
        children: [
          for (final e in effects)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(border: Border.all(color: Palette.panelBorder), color: Palette.panel),
              child: Text(e, style: const TextStyle(color: Palette.text, fontSize: 11)),
            ),
        ],
      ),
    );
  }

  // ================================================================ coulisses

  Widget _backstage(Backstage b) {
    final p = g.player;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(14),
            children: [
              _section('TALENT', b.talentPicked ? 'Choisi.' : 'Choisissez-en un (gratuit).'),
              for (var i = 0; i < b.talents.length; i++)
                _card(
                  title: b.talents[i].name,
                  subtitle: b.talents[i].desc,
                  color: Palette.xp,
                  picked: b.talentPicked && g.talents.contains(b.talents[i].id),
                  action: b.talentPicked ? null : ('PRENDRE', () => widget.c.pickTalent(i)),
                ),
              const SizedBox(height: 14),
              _section('INFIRMERIE', 'PV ${p.hp}/${p.maxHp}'),
              _card(
                title: 'Soins complets',
                subtitle: "Un infirmier à tentacules recoud ce qui dépasse.",
                color: const Color(0xFF8BE58B),
                picked: b.healed,
                action: b.healed || p.hp >= p.maxHp
                    ? null
                    : ('${b.healPrice} OR', g.gold >= b.healPrice ? () => widget.c.heal() : null),
              ),
              const SizedBox(height: 14),
              _section('BOUTIQUE', 'Sac ${g.inventory.length}/${Game.maxSlots}'),
              for (var i = 0; i < b.shop.length; i++) _offer(b.shop[i], i),
            ],
          ),
        ),
        Container(
          color: Palette.panel,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text("Prochain étage : ${g.floor + 1}", textAlign: TextAlign.center, style: pixel(8, color: Palette.muted)),
              const SizedBox(height: 8),
              _bigButton('RETOUR EN SCENE', _leave),
            ],
          ),
        ),
      ],
    );
  }

  Widget _section(String title, String hint) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Text(title, style: pixel(11, color: Palette.gold)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(hint,
                  textAlign: TextAlign.right, style: const TextStyle(color: Palette.muted, fontSize: 12)),
            ),
          ],
        ),
      );

  Widget _offer(ShopOffer o, int i) {
    final canBuy = !o.sold && g.gold >= o.price;
    return _card(
      icon: SpriteIcon(widget.atlas, g.spriteOf(o.item), size: 36),
      title: g.nameOf(o.item),
      subtitle: [o.item.statLine, g.descOf(o.item)].where((s) => s.isNotEmpty).join('\n'),
      color: Color(o.item.rarity.color),
      picked: o.sold,
      action: o.sold ? null : ('${o.price} OR', canBuy ? () => widget.c.buy(i) : null),
    );
  }

  Widget _card({
    Widget? icon,
    required String title,
    required String subtitle,
    required Color color,
    required bool picked,
    (String, VoidCallback?)? action,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: picked ? const Color(0xFF1C2A1C) : Palette.panel,
        border: Border.all(color: picked ? const Color(0xFF8BE58B) : color.withValues(alpha: 0.6), width: 2),
      ),
      child: Row(
        children: [
          if (icon != null) ...[icon, const SizedBox(width: 10)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: color, fontSize: 14)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(color: Palette.muted, fontSize: 12, height: 1.3)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (picked)
            const Icon(Icons.check, color: Color(0xFF8BE58B))
          else if (action != null)
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Palette.gold,
                disabledBackgroundColor: const Color(0xFF3D3150),
                shape: const RoundedRectangleBorder(),
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              onPressed: action.$2,
              child: Text(action.$1, style: pixel(8, color: action.$2 == null ? Palette.muted : Palette.bg)),
            ),
        ],
      ),
    );
  }

  Widget _bigButton(String label, VoidCallback onTap) => SizedBox(
        width: double.infinity,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Palette.gold,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: const RoundedRectangleBorder(),
          ),
          onPressed: onTap,
          child: Text(label, style: pixel(11, color: Palette.bg)),
        ),
      );
}
