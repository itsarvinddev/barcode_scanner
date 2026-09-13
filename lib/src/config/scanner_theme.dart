import 'package:flutter/material.dart';

/// The palette and metrics used by the scanner chrome.
///
/// The scanner draws on top of a live camera preview, which is unpredictable
/// and usually dark, so the defaults are deliberately *not* derived from the
/// app's [ColorScheme]: they are hand-picked to stay legible over any frame.
/// Use [ScannerTheme.fromColorScheme] — or [ScannerTheme.fromColors] in an app
/// built on `package:material_ui` — when you would rather match your brand, or
/// set individual fields to override just the parts you care about.
///
/// Every colour field is nullable. `null` means "use the built-in default",
/// which is resolved once per build by [resolve].
@immutable
class ScannerTheme {
  /// Creates a scanner theme. Unset fields fall back to the built-in defaults.
  const ScannerTheme({
    this.reticleColor,
    this.reticleSuccessColor,
    this.reticleErrorColor,
    this.reticleStrokeWidth,
    this.scanLineColor,
    this.overlayColor,
    this.overlayBlurSigma,
    this.controlBackgroundColor,
    this.controlForegroundColor,
    this.controlActiveBackgroundColor,
    this.controlActiveForegroundColor,
    this.controlSize,
    this.controlSpacing,
    this.barcodeHighlightColor,
    this.barcodeHighlightStrokeWidth,
    this.focusRingColor,
    this.hintTextStyle,
    this.hintBackgroundColor,
    this.surfaceColor,
    this.onSurfaceColor,
    this.borderRadius,
  });

  /// Derives a scanner theme from a [ColorScheme].
  ///
  /// The reticle picks up [ColorScheme.primary] and the controls pick up
  /// [ColorScheme.surface]/[ColorScheme.onSurface], while the dimmed area
  /// outside the scan window stays neutral so the preview remains readable.
  ///
  /// [ColorScheme] here is `flutter/material`'s. An app built on
  /// `package:material_ui` has a `ColorScheme` of a different type, which this
  /// factory cannot accept; pass its colours to [ScannerTheme.fromColors]
  /// instead, which derives exactly the same theme.
  factory ScannerTheme.fromColorScheme(ColorScheme scheme) {
    return ScannerTheme.fromColors(
      primary: scheme.primary,
      onPrimary: scheme.onPrimary,
      surface: scheme.surface,
      onSurface: scheme.onSurface,
      error: scheme.error,
    );
  }

  /// Derives a scanner theme from individual brand colours.
  ///
  /// This is [ScannerTheme.fromColorScheme] without the `ColorScheme`: given
  /// the same five colours it produces an identical theme. It exists because
  /// Flutter now also publishes Material as the separate
  /// `package:material_ui`, whose `ColorScheme` is a distinct type from the
  /// `flutter/material` one this package's API is written against. Plain [Color]s work with either:
  ///
  /// ```dart
  /// final scheme = Theme.of(context).colorScheme; // material_ui's
  /// AiBarcodeScanner(
  ///   theme: ScannerTheme.fromColors(
  ///     primary: scheme.primary,
  ///     onPrimary: scheme.onPrimary,
  ///     surface: scheme.surface,
  ///     onSurface: scheme.onSurface,
  ///     error: scheme.error,
  ///   ),
  /// )
  /// ```
  ///
  /// Only [primary] is required. [onPrimary] defaults to a dark or light
  /// foreground chosen for contrast against [primary], and [onSurface] to one
  /// chosen against [surface] — so a light [surface] is never paired with the
  /// built-in white text. Leaving [surface] or [error] out keeps the built-in
  /// defaults for the parts they would have coloured.
  factory ScannerTheme.fromColors({
    required Color primary,
    Color? onPrimary,
    Color? surface,
    Color? onSurface,
    Color? error,
  }) {
    final foreground =
        onSurface ?? (surface == null ? null : _contrastingForeground(surface));
    return ScannerTheme(
      reticleColor: primary,
      reticleSuccessColor: primary,
      reticleErrorColor: error,
      scanLineColor: primary,
      controlBackgroundColor: surface?.withValues(alpha: 0.85),
      controlForegroundColor: foreground,
      controlActiveBackgroundColor: primary,
      controlActiveForegroundColor:
          onPrimary ?? _contrastingForeground(primary),
      barcodeHighlightColor: primary,
      focusRingColor: primary,
      surfaceColor: surface,
      onSurfaceColor: foreground,
    );
  }

  /// A dark or light foreground that stays legible on [background].
  ///
  /// Uses the same luminance threshold as
  /// `ThemeData.estimateBrightnessForColor`, so the choice matches what a
  /// Material theme would make for the same colour, but with the scanner's own
  /// near-black and white.
  static Color _contrastingForeground(Color background) {
    final luminance = background.computeLuminance();
    final isLight = (luminance + 0.05) * (luminance + 0.05) > 0.15;
    return isLight ? const Color(0xFF1C1C1E) : const Color(0xFFFFFFFF);
  }

  /// Colour of the scan-window border in its resting state.
  final Color? reticleColor;

  /// Colour of the scan-window border after a barcode passes validation.
  final Color? reticleSuccessColor;

  /// Colour of the scan-window border after a barcode fails validation.
  final Color? reticleErrorColor;

  /// Stroke width of the scan-window border.
  final double? reticleStrokeWidth;

  /// Colour of the animated scanning line.
  final Color? scanLineColor;

  /// Colour laid over the preview outside the scan window.
  final Color? overlayColor;

  /// Gaussian blur sigma applied outside the scan window. `0` disables the
  /// blur, which is worth doing on low-end devices — a [BackdropFilter] is the
  /// single most expensive thing the overlay draws.
  final double? overlayBlurSigma;

  /// Background of the round control buttons.
  final Color? controlBackgroundColor;

  /// Icon colour of the round control buttons.
  final Color? controlForegroundColor;

  /// Background of a control button in its "on" state (torch enabled).
  final Color? controlActiveBackgroundColor;

  /// Icon colour of a control button in its "on" state.
  final Color? controlActiveForegroundColor;

  /// Diameter of the round control buttons.
  final double? controlSize;

  /// Gap between adjacent control buttons.
  final double? controlSpacing;

  /// Colour of the box drawn around each detected barcode.
  final Color? barcodeHighlightColor;

  /// Stroke width of the box drawn around each detected barcode.
  final double? barcodeHighlightStrokeWidth;

  /// Colour of the ring drawn where the user tapped to focus.
  final Color? focusRingColor;

  /// Text style of the on-screen guidance copy.
  final TextStyle? hintTextStyle;

  /// Background of the pill behind the on-screen guidance copy.
  final Color? hintBackgroundColor;

  /// Background of sheets and cards the scanner presents.
  final Color? surfaceColor;

  /// Foreground of sheets and cards the scanner presents.
  final Color? onSurfaceColor;

  /// Corner radius used by the scanner's own surfaces.
  final double? borderRadius;

  /// The built-in defaults, tuned for legibility over a live camera preview.
  static const ScannerTheme fallback = ScannerTheme(
    reticleColor: Color(0xFFFFFFFF),
    reticleSuccessColor: Color(0xFF32D74B),
    reticleErrorColor: Color(0xFFFF453A),
    reticleStrokeWidth: 5,
    scanLineColor: Color(0xFF32D74B),
    overlayColor: Color(0x8C000000),
    overlayBlurSigma: 4,
    controlBackgroundColor: Color(0x59FFFFFF),
    controlForegroundColor: Color(0xFFFFFFFF),
    controlActiveBackgroundColor: Color(0xFFFFD60A),
    controlActiveForegroundColor: Color(0xFF1C1C1E),
    controlSize: 48,
    controlSpacing: 12,
    barcodeHighlightColor: Color(0xFF32D74B),
    barcodeHighlightStrokeWidth: 3,
    focusRingColor: Color(0xFFFFD60A),
    hintTextStyle: TextStyle(
      color: Color(0xFFFFFFFF),
      fontSize: 15,
      fontWeight: FontWeight.w500,
      height: 1.3,
    ),
    hintBackgroundColor: Color(0x66000000),
    surfaceColor: Color(0xFF1C1C1E),
    onSurfaceColor: Color(0xFFFFFFFF),
    borderRadius: 20,
  );

  /// Returns a copy of this theme with every `null` field filled in from
  /// [fallback], so downstream widgets never have to null-check.
  ScannerTheme resolve() => merge(fallback);

  /// Returns a copy of this theme with every `null` field taken from [other].
  ScannerTheme merge(ScannerTheme other) {
    return ScannerTheme(
      reticleColor: reticleColor ?? other.reticleColor,
      reticleSuccessColor: reticleSuccessColor ?? other.reticleSuccessColor,
      reticleErrorColor: reticleErrorColor ?? other.reticleErrorColor,
      reticleStrokeWidth: reticleStrokeWidth ?? other.reticleStrokeWidth,
      scanLineColor: scanLineColor ?? other.scanLineColor,
      overlayColor: overlayColor ?? other.overlayColor,
      overlayBlurSigma: overlayBlurSigma ?? other.overlayBlurSigma,
      controlBackgroundColor:
          controlBackgroundColor ?? other.controlBackgroundColor,
      controlForegroundColor:
          controlForegroundColor ?? other.controlForegroundColor,
      controlActiveBackgroundColor:
          controlActiveBackgroundColor ?? other.controlActiveBackgroundColor,
      controlActiveForegroundColor:
          controlActiveForegroundColor ?? other.controlActiveForegroundColor,
      controlSize: controlSize ?? other.controlSize,
      controlSpacing: controlSpacing ?? other.controlSpacing,
      barcodeHighlightColor:
          barcodeHighlightColor ?? other.barcodeHighlightColor,
      barcodeHighlightStrokeWidth:
          barcodeHighlightStrokeWidth ?? other.barcodeHighlightStrokeWidth,
      focusRingColor: focusRingColor ?? other.focusRingColor,
      hintTextStyle: hintTextStyle ?? other.hintTextStyle,
      hintBackgroundColor: hintBackgroundColor ?? other.hintBackgroundColor,
      surfaceColor: surfaceColor ?? other.surfaceColor,
      onSurfaceColor: onSurfaceColor ?? other.onSurfaceColor,
      borderRadius: borderRadius ?? other.borderRadius,
    );
  }

  /// Returns a copy of this theme with the given fields replaced.
  ScannerTheme copyWith({
    Color? reticleColor,
    Color? reticleSuccessColor,
    Color? reticleErrorColor,
    double? reticleStrokeWidth,
    Color? scanLineColor,
    Color? overlayColor,
    double? overlayBlurSigma,
    Color? controlBackgroundColor,
    Color? controlForegroundColor,
    Color? controlActiveBackgroundColor,
    Color? controlActiveForegroundColor,
    double? controlSize,
    double? controlSpacing,
    Color? barcodeHighlightColor,
    double? barcodeHighlightStrokeWidth,
    Color? focusRingColor,
    TextStyle? hintTextStyle,
    Color? hintBackgroundColor,
    Color? surfaceColor,
    Color? onSurfaceColor,
    double? borderRadius,
  }) {
    return ScannerTheme(
      reticleColor: reticleColor ?? this.reticleColor,
      reticleSuccessColor: reticleSuccessColor ?? this.reticleSuccessColor,
      reticleErrorColor: reticleErrorColor ?? this.reticleErrorColor,
      reticleStrokeWidth: reticleStrokeWidth ?? this.reticleStrokeWidth,
      scanLineColor: scanLineColor ?? this.scanLineColor,
      overlayColor: overlayColor ?? this.overlayColor,
      overlayBlurSigma: overlayBlurSigma ?? this.overlayBlurSigma,
      controlBackgroundColor:
          controlBackgroundColor ?? this.controlBackgroundColor,
      controlForegroundColor:
          controlForegroundColor ?? this.controlForegroundColor,
      controlActiveBackgroundColor:
          controlActiveBackgroundColor ?? this.controlActiveBackgroundColor,
      controlActiveForegroundColor:
          controlActiveForegroundColor ?? this.controlActiveForegroundColor,
      controlSize: controlSize ?? this.controlSize,
      controlSpacing: controlSpacing ?? this.controlSpacing,
      barcodeHighlightColor:
          barcodeHighlightColor ?? this.barcodeHighlightColor,
      barcodeHighlightStrokeWidth:
          barcodeHighlightStrokeWidth ?? this.barcodeHighlightStrokeWidth,
      focusRingColor: focusRingColor ?? this.focusRingColor,
      hintTextStyle: hintTextStyle ?? this.hintTextStyle,
      hintBackgroundColor: hintBackgroundColor ?? this.hintBackgroundColor,
      surfaceColor: surfaceColor ?? this.surfaceColor,
      onSurfaceColor: onSurfaceColor ?? this.onSurfaceColor,
      borderRadius: borderRadius ?? this.borderRadius,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ScannerTheme &&
      other.reticleColor == reticleColor &&
      other.reticleSuccessColor == reticleSuccessColor &&
      other.reticleErrorColor == reticleErrorColor &&
      other.reticleStrokeWidth == reticleStrokeWidth &&
      other.scanLineColor == scanLineColor &&
      other.overlayColor == overlayColor &&
      other.overlayBlurSigma == overlayBlurSigma &&
      other.controlBackgroundColor == controlBackgroundColor &&
      other.controlForegroundColor == controlForegroundColor &&
      other.controlActiveBackgroundColor == controlActiveBackgroundColor &&
      other.controlActiveForegroundColor == controlActiveForegroundColor &&
      other.controlSize == controlSize &&
      other.controlSpacing == controlSpacing &&
      other.barcodeHighlightColor == barcodeHighlightColor &&
      other.barcodeHighlightStrokeWidth == barcodeHighlightStrokeWidth &&
      other.focusRingColor == focusRingColor &&
      other.hintTextStyle == hintTextStyle &&
      other.hintBackgroundColor == hintBackgroundColor &&
      other.surfaceColor == surfaceColor &&
      other.onSurfaceColor == onSurfaceColor &&
      other.borderRadius == borderRadius;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    reticleColor,
    reticleSuccessColor,
    reticleErrorColor,
    reticleStrokeWidth,
    scanLineColor,
    overlayColor,
    overlayBlurSigma,
    controlBackgroundColor,
    controlForegroundColor,
    controlActiveBackgroundColor,
    controlActiveForegroundColor,
    controlSize,
    controlSpacing,
    barcodeHighlightColor,
    barcodeHighlightStrokeWidth,
    focusRingColor,
    hintTextStyle,
    hintBackgroundColor,
    surfaceColor,
    onSurfaceColor,
    borderRadius,
  ]);

  /// The resolved theme provided by the nearest [ScannerThemeScope], or the
  /// built-in [fallback] when the scanner chrome is used standalone.
  static ScannerTheme of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<ScannerThemeScope>();
    return scope?.theme ?? fallback;
  }
}

/// Provides a resolved [ScannerTheme] to the scanner's chrome widgets.
///
/// `AiBarcodeScanner` installs one of these automatically; you only need it if
/// you compose the individual control widgets yourself.
class ScannerThemeScope extends InheritedWidget {
  /// Creates a scope that exposes [theme] to its descendants.
  const ScannerThemeScope({
    required this.theme,
    required super.child,
    super.key,
  });

  /// The fully resolved theme. Callers should pass a theme that has already
  /// been through [ScannerTheme.resolve] so descendants never see `null`.
  final ScannerTheme theme;

  @override
  bool updateShouldNotify(ScannerThemeScope oldWidget) =>
      oldWidget.theme != theme;
}
