import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_shadows.dart';

/// One destination in the [NavBar3D].
class NavItem {
  const NavItem(this.icon, this.label);
  final IconData icon;
  final String label;
}

/// Floating dark "pill" navigation bar (evolved from the original circular button
/// bar). The selected destination is a raised purple disc that glides to
/// its new position and pops up with a glow.
class NavBar3D extends StatelessWidget {
  const NavBar3D({super.key, required this.items, required this.index, required this.onChanged});

  final List<NavItem> items;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottom + 12),
      child: Container(
        height: 68,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.isDark ? const Color(0xFF1C1C1F) : const Color(0xFF2B3442),
              AppColors.slate900,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(34),
          boxShadow: AppShadows.dark(depth: 0.9),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: LayoutBuilder(
          builder: (context, box) {
            final slot = box.maxWidth / items.length;
            final disc = (slot - 4).clamp(40.0, 52.0);
            return Stack(
              children: [
                // Gliding selection disc.
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 420),
                  curve: Curves.easeOutBack,
                  left: slot * index + (slot - disc) / 2,
                  top: (68 - disc) / 2,
                  child: Container(
                    width: disc,
                    height: disc,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        center: Alignment(-0.3, -0.4),
                        colors: [AppColors.primaryLight, AppColors.primary, AppColors.primaryDeep],
                      ),
                      boxShadow: AppShadows.glow(),
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (var i = 0; i < items.length; i++)
                      Expanded(
                        child: Semantics(
                          button: true,
                          selected: i == index,
                          label: items[i].label,
                          child: InkResponse(
                            radius: 30,
                            onTap: () {
                              if (i != index) HapticFeedback.selectionClick();
                              onChanged(i);
                            },
                            child: SizedBox(
                              height: 68,
                              child: AnimatedScale(
                                scale: i == index ? 1.12 : 1,
                                duration: const Duration(milliseconds: 250),
                                child: Icon(
                                  items[i].icon,
                                  color: i == index
                                      ? AppColors.onPrimary
                                      : Colors.white.withValues(alpha: 0.55),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
