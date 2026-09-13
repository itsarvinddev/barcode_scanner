import 'package:flutter/material.dart';

import '../config/scanner_theme.dart';

/// A compact zoom slider for the camera.
///
/// It reads `0.0` to `1.0`, matching `MobileScannerController.setZoomScale`,
/// and lays out horizontally in portrait and vertically in landscape so it
/// never crowds the scan window.
class ScannerZoomSlider extends StatelessWidget {
  /// Creates a zoom slider.
  const ScannerZoomSlider({
    required this.value,
    required this.onChanged,
    required this.semanticLabel,
    super.key,
    this.vertical = false,
    this.theme,
  });

  /// Current zoom, from `0` (widest) to `1` (most zoomed in).
  final double value;

  /// Called continuously while the user drags.
  final ValueChanged<double>? onChanged;

  /// Accessibility label for the slider.
  final String semanticLabel;

  /// Whether to lay the slider out vertically.
  final bool vertical;

  /// Palette override; defaults to the [ScannerTheme] in scope.
  final ScannerTheme? theme;

  @override
  Widget build(BuildContext context) {
    final palette = (theme ?? ScannerTheme.of(context)).resolve();

    Widget slider = Slider(
      value: value.clamp(0.0, 1.0),
      onChanged: onChanged,
      semanticFormatterCallback: (v) => '${(v * 100).round()}%',
    );

    // [Slider] asserts that a `flutter/material` [Material] is above it and
    // throws "No Material widget found" otherwise. Inside the full-screen
    // scanner the Scaffold provides one, but an embedded scanner — or this
    // slider on its own — can sit in a page with none: a bare WidgetsApp, or
    // an app built on `package:material_ui`, whose Material is a different
    // type since Flutter 3.47. A transparent Material paints nothing, and is
    // only added when no Material is there already, so a classic app's tree
    // is unchanged.
    if (Material.maybeOf(context) == null) {
      slider = Material(type: MaterialType.transparency, child: slider);
    }

    slider = SliderTheme(
      data: SliderThemeData(
        activeTrackColor: palette.reticleColor,
        inactiveTrackColor: palette.controlBackgroundColor,
        thumbColor: palette.reticleColor,
        overlayColor: palette.reticleColor!.withValues(alpha: 0.15),
        trackHeight: 3,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
      ),
      child: slider,
    );

    final labelled = Semantics(
      slider: true,
      label: semanticLabel,
      child: slider,
    );

    if (!vertical) {
      return SizedBox(width: 220, child: labelled);
    }

    return RotatedBox(
      quarterTurns: 3,
      child: SizedBox(width: 180, child: labelled),
    );
  }
}
