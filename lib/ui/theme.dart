import 'package:flutter/material.dart';

import '../core/events.dart';

abstract final class Palette {
  static const bg = Color(0xFF14101C);
  static const panel = Color(0xFF221B2E);
  static const panelBorder = Color(0xFF3D3150);
  static const gold = Color(0xFFFFC94D);
  static const hp = Color(0xFFE04848);
  static const xp = Color(0xFF5EC8FF);
  static const maestro = Color(0xFFE07BFF);
  static const text = Color(0xFFEDE6F5);
  static const muted = Color(0xFF9A8FAD);

  static Color forMessage(MessageKind k) => switch (k) {
        MessageKind.info => text,
        MessageKind.good => const Color(0xFF8BE58B),
        MessageKind.danger => const Color(0xFFFF7A7A),
        MessageKind.maestro => maestro,
      };
}

/// Police pixel pour titres et chiffres.
TextStyle pixel(double size, {Color color = Palette.text}) =>
    TextStyle(fontFamily: 'PressStart2P', fontSize: size, color: color, height: 1.4);

ThemeData buildTheme() => ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: Palette.bg,
      colorScheme: const ColorScheme.dark(primary: Palette.gold, surface: Palette.panel),
      useMaterial3: true,
    );
