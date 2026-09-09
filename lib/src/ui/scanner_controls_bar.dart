import 'package:flutter/widgets.dart';

import '../config/scanner_theme.dart';

/// Lays the scanner's controls out along an axis with consistent spacing.
///
/// The scanner picks the axis from the available space: a row under the scan
/// window when the preview is taller than it is wide, and a column pinned to
/// the trailing edge when it is not. That keeps the controls clear of the scan
/// window in landscape, where a bottom row would sit on top of it.
class ScannerControlsBar extends StatelessWidget {
  /// Creates a controls bar.
  const ScannerControlsBar({
    required this.children,
    super.key,
    this.axis = Axis.horizontal,
    this.theme,
  });

  /// The controls to lay out. Empty children are filtered out by the caller.
  final List<Widget> children;

  /// Direction to lay the controls out in.
  final Axis axis;

  /// Palette override; defaults to the [ScannerTheme] in scope.
  final ScannerTheme? theme;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    final palette = (theme ?? ScannerTheme.of(context)).resolve();
    final gap = palette.controlSpacing!;

    final spaced = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        spaced.add(
          axis == Axis.horizontal
              ? SizedBox(width: gap)
              : SizedBox(height: gap),
        );
      }
      spaced.add(children[i]);
    }

    if (axis == Axis.horizontal) {
      // Scrollable so an unusually long control set, or a large text scale,
      // degrades to a scrollable strip instead of overflowing.
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(mainAxisSize: MainAxisSize.min, children: spaced),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(mainAxisSize: MainAxisSize.min, children: spaced),
    );
  }
}
