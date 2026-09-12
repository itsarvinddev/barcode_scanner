import 'package:flutter/widgets.dart';

/// The shape of the area the scanner looks for barcodes in.
enum ScanWindowShape {
  /// Pick a shape from the barcode formats the scanner was configured with:
  /// a square when only 2D symbologies (QR, Aztec, Data Matrix…) are enabled,
  /// and a wide landscape rectangle otherwise.
  auto,

  /// A square, which is the best shape for QR codes.
  square,

  /// A wide, short rectangle, which is the best shape for linear barcodes
  /// such as EAN-13 or Code 128.
  wide,

  /// A tall, narrow rectangle, for barcodes printed vertically.
  tall,

  /// No restriction: barcodes are detected anywhere in the preview.
  fullPreview,

  /// The rectangle comes from [ScanWindowConfig.widthFactor],
  /// [ScanWindowConfig.heightFactor] and [ScanWindowConfig.aspectRatio], or
  /// from [ScanWindowConfig.builder].
  custom,
}

/// Describes the scan window — the sub-rectangle of the camera preview that
/// barcodes must intersect to be reported.
///
/// The rectangle this produces is relative to the **layout box of the camera
/// preview**, not to the screen. That distinction matters: an app bar, a bottom
/// sheet or a notch all shrink the preview, and a window computed against the
/// full screen ends up offset from what the user sees — which is why barcodes
/// could appear to be inside the reticle and still not scan.
///
/// The same rectangle drives the visual reticle, so the two can never drift
/// apart.
@immutable
class ScanWindowConfig {
  /// Creates a scan window description.
  const ScanWindowConfig({
    this.shape = ScanWindowShape.auto,
    this.widthFactor,
    this.heightFactor,
    this.aspectRatio,
    this.minWidth = 140,
    this.minHeight = 96,
    this.maxWidth = 460,
    this.maxHeight = 460,
    this.alignment = const Alignment(0, -0.08),
    this.padding = const EdgeInsets.all(24),
    this.builder,
  });

  /// Detect barcodes anywhere in the preview and draw no reticle cut-out.
  const ScanWindowConfig.fullPreview()
    : shape = ScanWindowShape.fullPreview,
      widthFactor = null,
      heightFactor = null,
      aspectRatio = null,
      minWidth = 0,
      minHeight = 0,
      maxWidth = double.infinity,
      maxHeight = double.infinity,
      alignment = Alignment.center,
      padding = EdgeInsets.zero,
      builder = null;

  /// Compute the rectangle yourself from the preview's constraints.
  const ScanWindowConfig.builder(
    Rect Function(BuildContext context, BoxConstraints constraints)
    this.builder,
  ) : shape = ScanWindowShape.custom,
      widthFactor = null,
      heightFactor = null,
      aspectRatio = null,
      minWidth = 0,
      minHeight = 0,
      maxWidth = double.infinity,
      maxHeight = double.infinity,
      alignment = Alignment.center,
      padding = EdgeInsets.zero;

  /// The overall shape of the window.
  final ScanWindowShape shape;

  /// Width of the window as a fraction of the available width.
  ///
  /// Defaults are chosen per [shape] when this is null.
  final double? widthFactor;

  /// Height of the window as a fraction of the available height.
  ///
  /// When null the height is derived from the width and the effective aspect
  /// ratio, which keeps the reticle a consistent shape across screen sizes.
  final double? heightFactor;

  /// Width divided by height. Only used when [heightFactor] is null.
  final double? aspectRatio;

  /// Lower bound on the window's width, in logical pixels.
  final double minWidth;

  /// Lower bound on the window's height, in logical pixels.
  final double minHeight;

  /// Upper bound on the window's width, in logical pixels.
  ///
  /// This is what keeps the reticle a sane size on tablets, desktops and wide
  /// browser windows instead of growing to fill a 1400 px viewport.
  final double maxWidth;

  /// Upper bound on the window's height, in logical pixels.
  final double maxHeight;

  /// Where the window sits inside the available area.
  ///
  /// The default sits slightly above centre, which leaves room for the control
  /// row and any guidance copy underneath.
  final Alignment alignment;

  /// Space kept clear around the window, on top of the safe area.
  final EdgeInsets padding;

  /// Escape hatch: compute the rectangle from the preview's constraints.
  final Rect Function(BuildContext context, BoxConstraints constraints)?
  builder;

  /// Whether this configuration means "scan the whole preview".
  bool get isFullPreview => shape == ScanWindowShape.fullPreview;

  /// Resolves the scan window against the preview's [constraints].
  ///
  /// [prefersSquare] is the hint used by [ScanWindowShape.auto]; the scanner
  /// derives it from the configured barcode formats. [safeArea] is added to
  /// [padding] so the window never lands under a notch or a home indicator.
  Rect resolve(
    BuildContext context,
    BoxConstraints constraints, {
    bool prefersSquare = true,
    EdgeInsets safeArea = EdgeInsets.zero,
  }) {
    final layout = constraints.biggest;

    final customBuilder = builder;
    if (customBuilder != null) {
      return customBuilder(context, constraints);
    }

    if (shape == ScanWindowShape.fullPreview) {
      return Offset.zero & layout;
    }

    final insets = padding + safeArea;
    final availableWidth = (layout.width - insets.horizontal).clamp(
      0.0,
      layout.width,
    );
    final availableHeight = (layout.height - insets.vertical).clamp(
      0.0,
      layout.height,
    );

    if (availableWidth <= 0 || availableHeight <= 0) {
      return Offset.zero & layout;
    }

    final targetAspect = switch (shape) {
      ScanWindowShape.square => 1,
      ScanWindowShape.wide => 1.9,
      ScanWindowShape.tall => 0.6,
      ScanWindowShape.auto => prefersSquare ? 1.0 : 1.6,
      ScanWindowShape.custom => aspectRatio ?? 1.0,
      ScanWindowShape.fullPreview => 1,
    };

    final defaultWidthFactor = switch (shape) {
      ScanWindowShape.square => 0.82,
      ScanWindowShape.wide => 0.9,
      ScanWindowShape.tall => 0.6,
      ScanWindowShape.auto => prefersSquare ? 0.82 : 0.9,
      ScanWindowShape.custom => 0.82,
      ScanWindowShape.fullPreview => 1,
    };

    var width = availableWidth * (widthFactor ?? defaultWidthFactor);
    var height =
        heightFactor != null
            ? availableHeight * heightFactor!
            : width / targetAspect;

    // Keep the window inside the preview before applying the caller's bounds,
    // so a tall reticle on a short landscape screen shrinks instead of
    // overflowing.
    if (height > availableHeight) {
      height = availableHeight;
      if (heightFactor == null) width = height * targetAspect;
    }
    if (width > availableWidth) {
      width = availableWidth;
      if (heightFactor == null) height = width / targetAspect;
    }

    // Both bounds must be narrowed to what is actually available before they
    // are used: `num.clamp` throws an ArgumentError — not a debug-only assert —
    // when its lower limit exceeds its upper one, which would replace the whole
    // scanner with an error widget on any preview smaller than minWidth x
    // minHeight (an embedded scanner in a small card, a narrow desktop window,
    // split-screen).
    final effectiveMinWidth = minWidth.clamp(0.0, availableWidth);
    final effectiveMinHeight = minHeight.clamp(0.0, availableHeight);

    width = width.clamp(
      effectiveMinWidth,
      maxWidth.clamp(effectiveMinWidth, availableWidth),
    );
    height = height.clamp(
      effectiveMinHeight,
      maxHeight.clamp(effectiveMinHeight, availableHeight),
    );

    // Place the window inside the padded area using [alignment].
    final slackX = availableWidth - width;
    final slackY = availableHeight - height;
    final left = insets.left + slackX * ((alignment.x + 1) / 2).clamp(0.0, 1.0);
    final top = insets.top + slackY * ((alignment.y + 1) / 2).clamp(0.0, 1.0);

    return Rect.fromLTWH(left, top, width, height);
  }

  /// Returns a copy of this configuration with the given fields replaced.
  ///
  /// Pass `clearBuilder: true` to drop a [builder] — passing `builder: null`
  /// cannot express that, since null means "leave it alone".
  ScanWindowConfig copyWith({
    ScanWindowShape? shape,
    double? widthFactor,
    double? heightFactor,
    double? aspectRatio,
    double? minWidth,
    double? minHeight,
    double? maxWidth,
    double? maxHeight,
    Alignment? alignment,
    EdgeInsets? padding,
    Rect Function(BuildContext context, BoxConstraints constraints)? builder,
    bool clearBuilder = false,
  }) {
    return ScanWindowConfig(
      shape: shape ?? this.shape,
      widthFactor: widthFactor ?? this.widthFactor,
      heightFactor: heightFactor ?? this.heightFactor,
      aspectRatio: aspectRatio ?? this.aspectRatio,
      minWidth: minWidth ?? this.minWidth,
      minHeight: minHeight ?? this.minHeight,
      maxWidth: maxWidth ?? this.maxWidth,
      maxHeight: maxHeight ?? this.maxHeight,
      alignment: alignment ?? this.alignment,
      padding: padding ?? this.padding,
      // `builder` wins over every other field in `resolve`, so there has to be
      // a way to take it back off.
      builder: clearBuilder ? null : (builder ?? this.builder),
    );
  }
}
