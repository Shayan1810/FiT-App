import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Layered shadow recipes that give FiT its "3D" depth.
///
/// Every elevated surface uses 3–4 stacked shadows: a tight contact shadow,
/// a wide ambient shadow, and a white top-left highlight (neumorphic rim
/// light). Tinting the ambient shadow with the card colour makes coloured
/// cards look like they glow onto the canvas.
class AppShadows {
  AppShadows._();

  /// Shadow for a coloured card; [color] tints the glow.
  static List<BoxShadow> colored(Color color, {double depth = 1}) => [
    BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 22 * depth, offset: Offset(0, 10 * depth)),
    BoxShadow(color: color.withValues(alpha: 0.22), blurRadius: 40 * depth, offset: Offset(0, 22 * depth)),
    BoxShadow(color: AppColors.palette.rim, blurRadius: 8, offset: const Offset(-3, -3)),
  ];

  /// Shadow for a white / light card.
  static List<BoxShadow> soft({double depth = 1}) => [
    BoxShadow(
      color: Colors.black.withValues(alpha: AppColors.isDark ? 0.5 : 0.07),
      blurRadius: 24 * depth,
      offset: Offset(0, 12 * depth),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 50 * depth,
      offset: Offset(0, 26 * depth),
    ),
    BoxShadow(color: AppColors.palette.rim, blurRadius: 10, spreadRadius: 1, offset: const Offset(-5, -5)),
  ];

  /// Shadow for dark slate cards.
  static List<BoxShadow> dark({double depth = 1}) => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.35),
      blurRadius: 20 * depth,
      offset: Offset(0, 10 * depth),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.18),
      blurRadius: 40 * depth,
      offset: Offset(0, 20 * depth),
    ),
    BoxShadow(color: AppColors.palette.rim, blurRadius: 6, offset: const Offset(-2, -2)),
  ];

  /// Small raised chip / icon-badge shadow.
  static List<BoxShadow> chip(Color color) => [
    BoxShadow(color: color.withValues(alpha: 0.30), blurRadius: 10, offset: const Offset(2, 4)),
  ];

  /// Inset-looking shadow used by "pressed" or track surfaces.
  static List<BoxShadow> inset() => [
    BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 6, offset: const Offset(0, 2)),
  ];

  /// Glow behind the primary FAB / selected nav item.
  static List<BoxShadow> glow([Color? color]) => [
    BoxShadow(
      color: (color ?? AppColors.primary).withValues(alpha: 0.45),
      blurRadius: 18,
      spreadRadius: 1,
      offset: const Offset(0, 6),
    ),
  ];
}
