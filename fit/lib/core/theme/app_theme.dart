import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';

/// Builds the light and dark [ThemeData] of the app.
class AppTheme {
  AppTheme._();

  /// Light theme — original lavender-purple design.
  static ThemeData light() => _build(AppPalette.light);

  /// Dark theme — black + lime, matching the FiT logo.
  static ThemeData dark() => _build(AppPalette.dark);

  static ThemeData _build(AppPalette p) {
    final dark = p.brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: p.primary,
      primary: p.primary,
      onPrimary: p.onPrimary,
      secondary: p.primaryLight,
      surface: p.surface,
      onSurface: p.textPrimary,
      brightness: p.brightness,
    );
    final base = ThemeData(
      useMaterial3: true,
      brightness: p.brightness,
      colorScheme: scheme,
      fontFamily: 'Poppins',
      scaffoldBackgroundColor: p.background,
      canvasColor: p.background,
      dividerColor: p.divider,
      splashFactory: InkSparkle.splashFactory,
    );
    final overlay = dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark;
    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: p.textPrimary,
        systemOverlayStyle: overlay.copyWith(statusBarColor: Colors.transparent),
        titleTextStyle: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: p.textPrimary,
        ),
      ),
      textTheme: base.textTheme.apply(bodyColor: p.textPrimary, displayColor: p.textPrimary),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surfaceAlt,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: p.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: p.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: p.primary, width: 1.6),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.primary,
          foregroundColor: p.onPrimary,
          minimumSize: const Size(64, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: dark ? p.surfaceAlt : p.slate900,
        contentTextStyle: const TextStyle(fontFamily: 'Poppins', color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        modalBackgroundColor: p.surface,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      ),
      dialogTheme: DialogThemeData(backgroundColor: p.surface),
      sliderTheme: SliderThemeData(
        activeTrackColor: p.primary,
        thumbColor: p.primary,
        inactiveTrackColor: p.primarySoft,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {TargetPlatform.android: ZoomPageTransitionsBuilder()},
      ),
    );
  }
}

/// Text styles shared across pages (keeps typography consistent).
/// Getters, because their colours follow the active palette.
class AppText {
  AppText._();

  static TextStyle get display =>
      TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: AppColors.textPrimary, height: 1.15);
  static TextStyle get title =>
      TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary);
  static TextStyle get subtitle =>
      TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary);
  static TextStyle get body =>
      TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.textPrimary, height: 1.45);
  static TextStyle get caption =>
      TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textSecondary);
  static const TextStyle metric = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w700,
    color: Colors.white,
    shadows: [Shadow(blurRadius: 8, color: Color(0x4D000000), offset: Offset(2, 2))],
  );
}
