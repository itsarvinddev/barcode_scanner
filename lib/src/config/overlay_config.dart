import 'package:flutter/widgets.dart';

/// The animation drawn inside the scan window.
enum ScannerAnimation {
  /// A soft line that sweeps up and down inside the scan window.
  center,

  /// A wide glow that sweeps across the whole preview.
  fullWidth,

  /// No animation. Also what the scanner falls back to when the platform
  /// reports that the user prefers reduced motion.
  none,
}

/// How the area outside the scan window is treated.
enum ScannerOverlayBackground {
  /// Dim and blur everything outside the scan window.
  blur,

  /// Dim everything outside the scan window, without the (expensive) blur.
  dim,

  /// Leave the preview untouched.
  none,
}

/// The style of the scan window's border.
enum ScannerBorder {
  /// Four L-shaped corner brackets.
  corner,

  /// A complete rounded rectangle.
  full,

  /// No border.
  none,
}

const double _kBorderRadius = 24;

/// Everything about how the scan window looks.
///
/// Colours are nullable: leaving one `null` takes the value from the
/// [ScannerTheme] in scope, which is how the scanner stays consistent when you
/// theme it once at the top level.
@immutable
class ScannerOverlayConfig {
  /// Creates an overlay configuration.
  const ScannerOverlayConfig({
    this.animationColor,
    this.borderColor,
    this.backgroundColor,
    this.borderRadius = _kBorderRadius,
    this.cornerRadius = _kBorderRadius,
    this.scannerAnimation = ScannerAnimation.center,
    this.scannerOverlayBackground = ScannerOverlayBackground.blur,
    this.scannerBorder = ScannerBorder.corner,
    this.curve,
    this.background,
    this.lineThickness = 4,
    this.borderStrokeWidth,
    this.animation,
    this.animationDuration = const Duration(milliseconds: 1500),
    this.successColor,
    this.errorColor,
    this.animateOnSuccess = true,
    this.animateOnError = true,
    this.cornerLength = 44,
    this.blurSigma,
    this.respectReduceMotion = true,
    this.showBarcodeHighlights = false,
    this.stateTransitionDuration = const Duration(milliseconds: 220),
  });

  /// A minimal overlay: no dimming, no animation, just corner brackets.
  ///
  /// This is the cheapest configuration to render and the right choice for an
  /// embedded scanner or a low-end device.
  const ScannerOverlayConfig.minimal({
    this.borderColor,
    this.successColor,
    this.errorColor,
    this.borderRadius = _kBorderRadius,
    this.cornerRadius = _kBorderRadius,
    this.cornerLength = 44,
    this.borderStrokeWidth,
  }) : animationColor = null,
       backgroundColor = null,
       scannerAnimation = ScannerAnimation.none,
       scannerOverlayBackground = ScannerOverlayBackground.none,
       scannerBorder = ScannerBorder.corner,
       curve = null,
       background = null,
       lineThickness = 4,
       animation = null,
       animationDuration = const Duration(milliseconds: 1500),
       animateOnSuccess = true,
       animateOnError = true,
       blurSigma = 0,
       respectReduceMotion = true,
       showBarcodeHighlights = false,
       stateTransitionDuration = const Duration(milliseconds: 220);

  /// Colour of the sweeping scan line. Falls back to
  /// `ScannerTheme.scanLineColor`.
  final Color? animationColor;

  /// Colour of the scan window border. Falls back to
  /// `ScannerTheme.reticleColor`.
  final Color? borderColor;

  /// Colour laid over the preview outside the scan window. Falls back to
  /// `ScannerTheme.overlayColor`.
  final Color? backgroundColor;

  /// Corner radius of the scan window cut-out.
  final double borderRadius;

  /// Radius of the arc at the tip of each corner bracket.
  final double cornerRadius;

  /// Which animation to draw inside the scan window.
  final ScannerAnimation scannerAnimation;

  /// How to treat the area outside the scan window.
  final ScannerOverlayBackground scannerOverlayBackground;

  /// The border style of the scan window.
  final ScannerBorder scannerBorder;

  /// Easing applied to the scan animation. Defaults to [Curves.easeInOut].
  final Curve? curve;

  /// A widget drawn outside the scan window instead of a flat colour — a
  /// gradient, an image, anything.
  final Widget? background;

  /// Thickness of the sweeping scan line.
  final double lineThickness;

  /// Stroke width of the scan window border. Falls back to
  /// `ScannerTheme.reticleStrokeWidth`.
  final double? borderStrokeWidth;

  /// Drive the scan animation from your own [Animation] instead of the
  /// built-in repeating controller.
  final Animation<double>? animation;

  /// Duration of one sweep of the scan animation.
  final Duration animationDuration;

  /// Border colour after a barcode passes validation. Falls back to
  /// `ScannerTheme.reticleSuccessColor`.
  final Color? successColor;

  /// Border colour after a barcode fails validation. Falls back to
  /// `ScannerTheme.reticleErrorColor`.
  final Color? errorColor;

  /// Whether to tint the overlay on a successful scan.
  final bool animateOnSuccess;

  /// Whether to tint the overlay on a rejected scan.
  final bool animateOnError;

  /// Length of each corner bracket, in logical pixels.
  final double cornerLength;

  /// Gaussian blur sigma used when [scannerOverlayBackground] is
  /// [ScannerOverlayBackground.blur]. Falls back to
  /// `ScannerTheme.overlayBlurSigma`.
  final double? blurSigma;

  /// Whether to drop the scan animation when the platform reports that the
  /// user prefers reduced motion.
  ///
  /// Leave this on: a continuously sweeping line is exactly the kind of motion
  /// that setting exists to suppress.
  final bool respectReduceMotion;

  /// Whether to outline every detected barcode in the preview.
  ///
  /// Useful when several barcodes are visible at once and the user needs to
  /// see which ones were picked up. Has no effect on the web, where the
  /// detection backend does not report barcode geometry.
  final bool showBarcodeHighlights;

  /// How long the overlay takes to fade between its resting, success and error
  /// colours.
  final Duration stateTransitionDuration;

  /// Returns a copy of this configuration with the given fields replaced.
  ScannerOverlayConfig copyWith({
    Color? animationColor,
    Color? borderColor,
    Color? backgroundColor,
    double? borderRadius,
    double? cornerRadius,
    ScannerAnimation? scannerAnimation,
    ScannerOverlayBackground? scannerOverlayBackground,
    ScannerBorder? scannerBorder,
    Curve? curve,
    Widget? background,
    double? lineThickness,
    double? borderStrokeWidth,
    Animation<double>? animation,
    Duration? animationDuration,
    Color? successColor,
    Color? errorColor,
    bool? animateOnSuccess,
    bool? animateOnError,
    double? cornerLength,
    double? blurSigma,
    bool? respectReduceMotion,
    bool? showBarcodeHighlights,
    Duration? stateTransitionDuration,
  }) {
    return ScannerOverlayConfig(
      animationColor: animationColor ?? this.animationColor,
      borderColor: borderColor ?? this.borderColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      borderRadius: borderRadius ?? this.borderRadius,
      cornerRadius: cornerRadius ?? this.cornerRadius,
      scannerAnimation: scannerAnimation ?? this.scannerAnimation,
      scannerOverlayBackground:
          scannerOverlayBackground ?? this.scannerOverlayBackground,
      scannerBorder: scannerBorder ?? this.scannerBorder,
      curve: curve ?? this.curve,
      background: background ?? this.background,
      lineThickness: lineThickness ?? this.lineThickness,
      borderStrokeWidth: borderStrokeWidth ?? this.borderStrokeWidth,
      animation: animation ?? this.animation,
      animationDuration: animationDuration ?? this.animationDuration,
      successColor: successColor ?? this.successColor,
      errorColor: errorColor ?? this.errorColor,
      animateOnSuccess: animateOnSuccess ?? this.animateOnSuccess,
      animateOnError: animateOnError ?? this.animateOnError,
      cornerLength: cornerLength ?? this.cornerLength,
      blurSigma: blurSigma ?? this.blurSigma,
      respectReduceMotion: respectReduceMotion ?? this.respectReduceMotion,
      showBarcodeHighlights:
          showBarcodeHighlights ?? this.showBarcodeHighlights,
      stateTransitionDuration:
          stateTransitionDuration ?? this.stateTransitionDuration,
    );
  }
}
