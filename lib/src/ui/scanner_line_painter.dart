import 'package:flutter/widgets.dart';

/// Draws the soft line that sweeps up and down inside the scan window.
class ScanningLinePainter extends CustomPainter {
  /// Creates a scan-line painter.
  ScanningLinePainter({
    required this.animationValue,
    required this.scanWindow,
    this.animationColor = const Color(0xFF32D74B),
    this.lineThickness = 4.0,
    this.borderRadius = 16.0,
  });

  /// Position of the line, from `0` (top of the window) to `1` (bottom).
  final double animationValue;

  /// The rectangle the line sweeps within.
  final Rect scanWindow;

  /// Colour of the line's glow.
  final Color animationColor;

  /// Thickness of the line's core.
  final double lineThickness;

  /// Corner radius used to clip the line to the scan window.
  final double borderRadius;

  @override
  void paint(Canvas canvas, Size size) {
    if (scanWindow.isEmpty) return;

    canvas
      ..save()
      ..clipRRect(
        RRect.fromRectAndRadius(scanWindow, Radius.circular(borderRadius)),
      );

    // The glow is several times taller than the line itself, so the gradient
    // has somewhere to fall off.
    final glowHeight = lineThickness * 8;
    final centreY = scanWindow.top + animationValue * scanWindow.height;
    final glowRect = Rect.fromLTWH(
      scanWindow.left,
      centreY - glowHeight / 2,
      scanWindow.width,
      glowHeight,
    );

    final glowPaint =
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              animationColor.withValues(alpha: 0),
              animationColor.withValues(alpha: 0.55),
              animationColor.withValues(alpha: 0),
            ],
            stops: const <double>[0, 0.5, 1],
          ).createShader(glowRect);

    canvas
      ..drawRect(glowRect, glowPaint)
      ..drawRect(
        Rect.fromLTWH(
          scanWindow.left,
          centreY - lineThickness / 2,
          scanWindow.width,
          lineThickness,
        ),
        Paint()..color = animationColor,
      )
      ..restore();
  }

  @override
  bool shouldRepaint(covariant ScanningLinePainter oldDelegate) {
    return animationValue != oldDelegate.animationValue ||
        scanWindow != oldDelegate.scanWindow ||
        animationColor != oldDelegate.animationColor ||
        lineThickness != oldDelegate.lineThickness ||
        borderRadius != oldDelegate.borderRadius;
  }
}
