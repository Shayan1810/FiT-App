import 'package:flutter/material.dart';

/// One complete set of colours (light or dark).
class AppPalette {
  const AppPalette({
    required this.brightness,
    required this.primary,
    required this.primaryLight,
    required this.primaryDeep,
    required this.primarySoft,
    required this.onPrimary,
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.divider,
    required this.slate900,
    required this.slate700,
    required this.slate600,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.rim,
    required this.cardBorder,
    required this.heroGradient,
    required this.cardGradient,
  });

  final Brightness brightness;
  final Color primary;
  final Color primaryLight;
  final Color primaryDeep;
  final Color primarySoft;

  /// Text/icon colour drawn on top of [primary].
  final Color onPrimary;
  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color divider;
  final Color slate900;
  final Color slate700;
  final Color slate600;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;

  /// Top-left "rim light" used by the 3D shadows.
  final Color rim;
  final Color cardBorder;

  /// Gradient of hero cards (white text on top).
  final List<Color> heroGradient;

  /// Gradient of plain cards.
  final List<Color> cardGradient;

  /// Light theme — the original FiT lavender-purple design.
  static const AppPalette light = AppPalette(
    brightness: Brightness.light,
    primary: Color(0xFF8B7CF6),
    primaryLight: Color(0xFFB794F6),
    primaryDeep: Color(0xFF9F7AEA),
    primarySoft: Color(0xFFEDE9FE),
    onPrimary: Colors.white,
    background: Color(0xFFF5F6FA),
    surface: Colors.white,
    surfaceAlt: Color(0xFFFAFAFC),
    divider: Color(0xFFE5E7EB),
    slate900: Color(0xFF1F2937),
    slate700: Color(0xFF374151),
    slate600: Color(0xFF4B5563),
    textPrimary: Color(0xFF111827),
    textSecondary: Color(0xFF6B7280),
    textMuted: Color(0xFF9CA3AF),
    rim: Color(0xD9FFFFFF),
    cardBorder: Colors.white,
    heroGradient: [Color(0xFF8B7CF6), Color(0xFFB794F6), Color(0xFF9F7AEA)],
    cardGradient: [Colors.white, Color(0xFFF9FAFB)],
  );

  /// Dark theme — matches the FiT logo: deep black with electric lime.
  static const AppPalette dark = AppPalette(
    brightness: Brightness.dark,
    primary: Color(0xFF7ED321),
    primaryLight: Color(0xFFA8F04B),
    primaryDeep: Color(0xFF4E9A12),
    primarySoft: Color(0xFF1B2A10),
    onPrimary: Color(0xFF0A0A0A),
    background: Color(0xFF050505),
    surface: Color(0xFF131314),
    surfaceAlt: Color(0xFF1A1A1C),
    divider: Color(0xFF2A2A2D),
    slate900: Color(0xFF151517),
    slate700: Color(0xFF26262A),
    slate600: Color(0xFF33333A),
    textPrimary: Color(0xFFF4F4F5),
    textSecondary: Color(0xFFA1A1AA),
    textMuted: Color(0xFF71717A),
    rim: Color(0x0FFFFFFF),
    cardBorder: Color(0x14FFFFFF),
    heroGradient: [Color(0xFF3B7A12), Color(0xFF26550B), Color(0xFF122B05)],
    cardGradient: [Color(0xFF18181A), Color(0xFF101011)],
  );
}

/// The FiT colour palette.
///
/// Every widget takes colours from here — never hard-code a hex value in a
/// page. The values switch between [AppPalette.light] and [AppPalette.dark]
/// when the theme changes ([use]); `PaletteScope` then rebuilds the tree.
class AppColors {
  AppColors._();

  static AppPalette _p = AppPalette.light;

  /// Incremented on every palette switch; painters compare it in
  /// `shouldRepaint` so custom drawings re-colour too.
  static int version = 0;

  /// The active palette.
  static AppPalette get palette => _p;

  /// True while the dark palette is active.
  static bool get isDark => _p.brightness == Brightness.dark;

  /// Activates the palette for [b]. Returns true if it changed.
  static bool use(Brightness b) {
    final next = b == Brightness.dark ? AppPalette.dark : AppPalette.light;
    if (identical(next, _p)) return false;
    _p = next;
    version++;
    return true;
  }

  // Brand
  static Color get primary => _p.primary;
  static Color get primaryLight => _p.primaryLight;
  static Color get primaryDeep => _p.primaryDeep;
  static Color get primarySoft => _p.primarySoft;
  static Color get onPrimary => _p.onPrimary;

  // Canvas & surfaces
  static Color get background => _p.background;
  static Color get surface => _p.surface;
  static Color get surfaceAlt => _p.surfaceAlt;
  static Color get divider => _p.divider;

  // Dark "slate" cards
  static Color get slate900 => _p.slate900;
  static Color get slate700 => _p.slate700;
  static Color get slate600 => _p.slate600;

  // Text
  static Color get textPrimary => _p.textPrimary;
  static Color get textSecondary => _p.textSecondary;
  static Color get textMuted => _p.textMuted;

  // Macro colours (same in both themes)
  static const Color protein = Color(0xFF3B82F6);
  static const Color carbs = Color(0xFFF59E0B);
  static const Color fat = Color(0xFFA855F7);
  static const Color fiber = Color(0xFF10B981);

  // Domain accents
  static const Color steps = Color(0xFF10B981);
  static const Color sleep = Color(0xFF6366F1);
  static const Color water = Color(0xFF06B6D4);
  static const Color burn = Color(0xFFF97316);

  // Semantic
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  /// Hero card gradient (white text on top).
  static LinearGradient get primaryGradient =>
      LinearGradient(colors: _p.heroGradient, begin: Alignment.topLeft, end: Alignment.bottomRight);

  /// Dark slate gradient (weight card, diagnostics).
  static LinearGradient get slateGradient => LinearGradient(
    colors: [_p.slate700, _p.slate600, _p.slate900],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Plain card gradient.
  static LinearGradient get lightGradient =>
      LinearGradient(colors: _p.cardGradient, begin: Alignment.topLeft, end: Alignment.bottomRight);

  /// Two-stop gradient built from [color] for accent cards.
  static LinearGradient accentGradient(Color color) => LinearGradient(
    colors: isDark
        ? [Color.lerp(color, Colors.black, 0.35)!, Color.lerp(color, Colors.black, 0.6)!]
        : [color, Color.lerp(color, Colors.white, 0.25)!],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
