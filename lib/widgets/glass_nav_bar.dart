import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

/// Floating glass capsule bottom navigation bar with haptic feedback.
///
/// Uses [GlassTabBar.bottom] from liquid_glass_widgets for the iOS 26-style
/// glass aesthetic, with [HapticFeedback.mediumImpact] on tab taps.
class GlassNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTabSelected;
  final List<String> labels;
  final List<IconData> icons;

  /// Optional icons for the glass variant (filled SF Symbols style).
  final List<IconData>? glassIcons;

  const GlassNavBar({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
    required this.labels,
    required this.icons,
    this.glassIcons,
  });

  /// Default glass icons (filled variants matching liquid_glass_widgets demo).
  static const List<IconData> _defaultGlassIcons = [
    CupertinoIcons.house_fill,
    CupertinoIcons.square_stack_fill,
    CupertinoIcons.waveform_path_ecg,
    CupertinoIcons.chart_bar_fill,
    CupertinoIcons.gear_alt_fill,
  ];

  void _handleTap(int index) {
    if (index != currentIndex) HapticFeedback.mediumImpact();
    onTabSelected(index);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Selected capsule color: 10% of label color for a subtle glass pill.
    final pillColor = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.black.withValues(alpha: 0.10);

    final effectiveGlassIcons = glassIcons ?? icons;

    return SafeArea(
      top: false,
      child: GlassTabBar.bottom(
        tabs: [
          for (var i = 0; i < labels.length; i++)
            GlassTab(icon: Icon(effectiveGlassIcons[i]), label: labels[i]),
        ],
        selectedIndex: currentIndex,
        onTabSelected: _handleTap,
        barHeight: 64,
        verticalPadding: 18,
        horizontalPadding: 20,
        indicatorColor: pillColor,
        selectedIconColor: theme.colorScheme.primary,
        selectedLabelColor: theme.colorScheme.primary,
        selectedLabelStyle:
            const TextStyle(decoration: TextDecoration.none),
        unselectedLabelStyle:
            const TextStyle(decoration: TextDecoration.none),
      ),
    );
  }
}
