import 'package:flutter/widgets.dart';

import '../config/overlay_config.dart';

/// Draws the scan window's border: either four corner brackets or a complete
/// rounded rectangle.
class ScannerCornerPainter extends CustomPainter {
  /// Creates a border painter for [scanWindow].
  ScannerCornerPainter({
    required this.scanWindow,
    this.borderColor = const Color(0xFFFFFFFF),
    this.cornerRadius = 16.0,
    this.borderRadius = 16.0,
    this.borderType = ScannerBorder.corner,
    this.cornerLength = 44.0,
    this.strokeWidth = 5.0,
  });

  /// The rectangle to outline.
  final Rect scanWindow;

  /// Colour of the stroke.
  final Color borderColor;

  /// Radius of the arc at the tip of each bracket.
  final double cornerRadius;

  /// Corner radius of the scan window itself.
  final double borderRadius;

  /// Whether to draw brackets, a full outline, or nothing.
  final ScannerBorder borderType;

  /// How far each bracket extends along the edges.
  final double cornerLength;

  /// Width of the stroke.
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (borderType == ScannerBorder.none || scanWindow.isEmpty) return;

    final borderPaint =
        Paint()
          ..color = borderColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round
          ..isAntiAlias = true;

    final rrect = RRect.fromRectAndRadius(
      scanWindow,
      Radius.circular(borderRadius),
    );

    switch (borderType) {
      case ScannerBorder.full:
        canvas.drawRRect(rrect, borderPaint);
      case ScannerBorder.corner:
        // Never let the brackets overlap: on a small window each one can only
        // take up to half the shorter side.
        final maxLength = (scanWindow.shortestSide / 2).clamp(
          0.0,
          double.infinity,
        );
        final length = cornerLength.clamp(0.0, maxLength);
        final radius = cornerRadius.clamp(0.0, length);

        final path =
            Path()
              // Top-left
              ..moveTo(rrect.left, rrect.top + length)
              ..lineTo(rrect.left, rrect.top + radius)
              ..arcToPoint(
                Offset(rrect.left + radius, rrect.top),
                radius: Radius.circular(radius),
              )
              ..lineTo(rrect.left + length, rrect.top)
              // Top-right
              ..moveTo(rrect.right - length, rrect.top)
              ..lineTo(rrect.right - radius, rrect.top)
              ..arcToPoint(
                Offset(rrect.right, rrect.top + radius),
                radius: Radius.circular(radius),
              )
              ..lineTo(rrect.right, rrect.top + length)
              // Bottom-left
              ..moveTo(rrect.left, rrect.bottom - length)
              ..lineTo(rrect.left, rrect.bottom - radius)
              ..arcToPoint(
                Offset(rrect.left + radius, rrect.bottom),
                radius: Radius.circular(radius),
                clockwise: false,
              )
              ..lineTo(rrect.left + length, rrect.bottom)
              // Bottom-right
              ..moveTo(rrect.right - length, rrect.bottom)
              ..lineTo(rrect.right - radius, rrect.bottom)
              ..arcToPoint(
                Offset(rrect.right, rrect.bottom - radius),
                radius: Radius.circular(radius),
                clockwise: false,
              )
              ..lineTo(rrect.right, rrect.bottom - length);

        canvas.drawPath(path, borderPaint);
      case ScannerBorder.none:
        break;
    }
  }

  @override
  bool shouldRepaint(covariant ScannerCornerPainter oldDelegate) {
    return scanWindow != oldDelegate.scanWindow ||
        borderColor != oldDelegate.borderColor ||
        borderType != oldDelegate.borderType ||
        cornerRadius != oldDelegate.cornerRadius ||
        borderRadius != oldDelegate.borderRadius ||
        cornerLength != oldDelegate.cornerLength ||
        strokeWidth != oldDelegate.strokeWidth;
  }
}
