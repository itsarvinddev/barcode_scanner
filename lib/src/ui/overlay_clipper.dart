import 'package:flutter/widgets.dart';

/// Clips everything except a rounded rectangle, producing the "cut-out" the
/// scan window is drawn through.
class OverlayClipper extends CustomClipper<Path> {
  /// Creates a clipper that punches [scanWindow] out of the available area.
  OverlayClipper({required this.scanWindow, this.borderRadius = 16.0});

  /// The hole, in the coordinate space of the widget being clipped.
  final Rect scanWindow;

  /// Corner radius of the hole.
  final double borderRadius;

  @override
  Path getClip(Size size) {
    final full = Rect.fromLTWH(0, 0, size.width, size.height);

    // An empty or off-screen window would clip everything away; treat it as
    // "no cut-out" instead of blanking the preview.
    if (scanWindow.isEmpty || !scanWindow.overlaps(full)) {
      return Path()..addRect(full);
    }

    final rounded = RRect.fromRectAndRadius(
      scanWindow,
      Radius.circular(borderRadius),
    );

    return Path()
      ..addRect(full)
      ..addRRect(rounded)
      ..fillType = PathFillType.evenOdd;
  }

  @override
  bool shouldReclip(covariant OverlayClipper oldClipper) {
    return scanWindow != oldClipper.scanWindow ||
        borderRadius != oldClipper.borderRadius;
  }
}
