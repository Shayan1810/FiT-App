import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';

/// Keeps [AppColors] in sync with the active [Theme] brightness.
///
/// Placed in `MaterialApp.builder`. When the brightness flips (Settings →
/// Appearance, or the system dark-mode switch) it activates the matching
/// palette and marks every descendant for rebuild — widget state (scroll
/// positions, current tab, open pages) is preserved.
class PaletteScope extends StatefulWidget {
  const PaletteScope({super.key, required this.child});
  final Widget child;

  @override
  State<PaletteScope> createState() => _PaletteScopeState();
}

class _PaletteScopeState extends State<PaletteScope> {
  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    if (AppColors.use(brightness)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _rebuildAll());
    }
    final dark = brightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AppColors.background,
        systemNavigationBarIconBrightness: dark ? Brightness.light : Brightness.dark,
      ),
      child: widget.child,
    );
  }

  void _rebuildAll() {
    if (!mounted) return;
    void mark(Element e) {
      e.markNeedsBuild();
      e.visitChildren(mark);
    }

    (context as Element).visitChildren(mark);
  }
}
