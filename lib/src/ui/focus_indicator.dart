import 'package:flutter/material.dart';

import '../config/scanner_theme.dart';

/// The ring that briefly appears where the user tapped to focus.
///
/// It animates in, shrinks slightly like a camera app's focus reticle, then
/// fades out. Rendering nothing when [position] is null keeps it out of the
/// tree while idle.
class FocusIndicator extends StatelessWidget {
  /// Creates a focus indicator.
  const FocusIndicator({
    required this.position,
    super.key,
    this.theme,
    this.size = 72,
  });

  /// Where the user tapped, in this widget's coordinate space, or `null`.
  final Offset? position;

  /// Palette override; defaults to the [ScannerTheme] in scope.
  final ScannerTheme? theme;

  /// Diameter of the ring at rest.
  final double size;

  @override
  Widget build(BuildContext context) {
    final point = position;
    if (point == null) return const SizedBox.shrink();

    final palette = (theme ?? ScannerTheme.of(context)).resolve();

    return Positioned(
      left: point.dx - size / 2,
      top: point.dy - size / 2,
      width: size,
      height: size,
      child: IgnorePointer(
        child: TweenAnimationBuilder<double>(
          key: ValueKey<Offset>(point),
          tween: Tween<double>(begin: 1.35, end: 1),
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutBack,
          builder:
              (context, scale, child) =>
                  Transform.scale(scale: scale, child: child),
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: palette.focusRingColor!, width: 2),
            ),
          ),
        ),
      ),
    );
  }
}
