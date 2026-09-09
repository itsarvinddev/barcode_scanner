import 'dart:ui' show ImageFilter;

import 'package:flutter/widgets.dart';

import '../config/overlay_config.dart';
import '../config/scanner_theme.dart';
import 'overlay_clipper.dart';
import 'scanner_border_painter.dart';
import 'scanner_line_painter.dart';

/// The dimming, reticle and scan animation drawn over the camera preview.
///
/// [scanWindow] must be in the coordinate space of the preview widget — the
/// same rectangle handed to `MobileScanner.scanWindow` — so the reticle and the
/// area the scanner actually reads can never disagree.
class ScannerOverlay extends StatefulWidget {
  /// Creates a scanner overlay.
  const ScannerOverlay({
    required this.scanWindow,
    super.key,
    this.config = const ScannerOverlayConfig(),
    this.theme,
    this.isSuccess,
  });

  /// The scan window, relative to this widget's own box.
  final Rect scanWindow;

  /// How the overlay should look and animate.
  final ScannerOverlayConfig config;

  /// Palette to fall back on for colours the config leaves unset. Defaults to
  /// the [ScannerTheme] in scope.
  final ScannerTheme? theme;

  /// `null` while idle, `true` after an accepted scan, `false` after a
  /// rejected one.
  final bool? isSuccess;

  @override
  State<ScannerOverlay> createState() => _ScannerOverlayState();
}

class _ScannerOverlayState extends State<ScannerOverlay>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _buildAnimation();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimationState();
  }

  @override
  void didUpdateWidget(covariant ScannerOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config.animation != widget.config.animation ||
        oldWidget.config.animationDuration != widget.config.animationDuration ||
        oldWidget.config.curve != widget.config.curve) {
      _controller?.dispose();
      _controller = null;
      _buildAnimation();
    }
    _syncAnimationState();
  }

  void _buildAnimation() {
    final external = widget.config.animation;
    if (external != null) {
      _animation = external;
      return;
    }
    final controller = AnimationController(
      vsync: this,
      duration: widget.config.animationDuration,
    );
    _controller = controller;
    _animation = CurvedAnimation(
      parent: controller,
      curve: widget.config.curve ?? Curves.easeInOut,
    );
  }

  /// Starts or stops the ticker to match the configuration.
  ///
  /// Keeping a repeating [AnimationController] alive when nothing is drawn
  /// from it costs a frame callback for the lifetime of the scanner, and makes
  /// the widget tree never settle — which breaks `pumpAndSettle` in tests and
  /// wastes power in production.
  void _syncAnimationState() {
    final controller = _controller;
    if (controller == null) return;

    final reduceMotion =
        widget.config.respectReduceMotion &&
        MediaQuery.disableAnimationsOf(context);
    final shouldRun =
        !reduceMotion &&
        widget.config.scannerAnimation != ScannerAnimation.none;

    if (shouldRun && !controller.isAnimating) {
      controller.repeat(reverse: true);
    } else if (!shouldRun && controller.isAnimating) {
      controller.stop();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Color _stateColor(Color resting, Color success, Color error) {
    final isSuccess = widget.isSuccess;
    if (isSuccess == null) return resting;
    if (isSuccess && widget.config.animateOnSuccess) return success;
    if (!isSuccess && widget.config.animateOnError) return error;
    return resting;
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    final theme = (widget.theme ?? ScannerTheme.of(context)).resolve();
    final scanWindow = widget.scanWindow;

    final reduceMotion =
        config.respectReduceMotion && MediaQuery.disableAnimationsOf(context);
    final animationStyle =
        reduceMotion ? ScannerAnimation.none : config.scannerAnimation;

    final borderColor = _stateColor(
      config.borderColor ?? theme.reticleColor!,
      config.successColor ?? theme.reticleSuccessColor!,
      config.errorColor ?? theme.reticleErrorColor!,
    );
    final backgroundColor = _stateColor(
      config.backgroundColor ?? theme.overlayColor!,
      (config.successColor ?? theme.reticleSuccessColor!).withValues(
        alpha: 0.25,
      ),
      (config.errorColor ?? theme.reticleErrorColor!).withValues(alpha: 0.25),
    );
    final lineColor = _stateColor(
      config.animationColor ?? theme.scanLineColor!,
      config.successColor ?? theme.reticleSuccessColor!,
      config.errorColor ?? theme.reticleErrorColor!,
    );

    return IgnorePointer(
      child: TweenAnimationBuilder<Color?>(
        tween: ColorTween(end: borderColor),
        duration: config.stateTransitionDuration,
        builder: (context, animatedBorder, _) {
          return TweenAnimationBuilder<Color?>(
            tween: ColorTween(end: backgroundColor),
            duration: config.stateTransitionDuration,
            builder: (context, animatedBackground, _) {
              return Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  if (config.scannerOverlayBackground !=
                      ScannerOverlayBackground.none)
                    _buildBackground(
                      config: config,
                      theme: theme,
                      scanWindow: scanWindow,
                      color: animatedBackground ?? backgroundColor,
                    ),
                  if (config.scannerBorder != ScannerBorder.none)
                    CustomPaint(
                      painter: ScannerCornerPainter(
                        scanWindow: scanWindow,
                        borderRadius: config.borderRadius,
                        cornerRadius: config.cornerRadius,
                        borderColor: animatedBorder ?? borderColor,
                        borderType: config.scannerBorder,
                        cornerLength: config.cornerLength,
                        strokeWidth:
                            config.borderStrokeWidth ??
                            theme.reticleStrokeWidth!,
                      ),
                    ),
                  if (animationStyle == ScannerAnimation.center)
                    AnimatedBuilder(
                      animation: _animation,
                      builder:
                          (context, _) => CustomPaint(
                            painter: ScanningLinePainter(
                              animationValue: _animation.value,
                              scanWindow: scanWindow,
                              lineThickness: config.lineThickness,
                              animationColor: lineColor,
                              borderRadius: config.borderRadius,
                            ),
                          ),
                    ),
                  if (animationStyle == ScannerAnimation.fullWidth)
                    _FullWidthSweep(animation: _animation, color: lineColor),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildBackground({
    required ScannerOverlayConfig config,
    required ScannerTheme theme,
    required Rect scanWindow,
    required Color color,
  }) {
    final child = config.background ?? ColoredBox(color: color);
    final clipped = ClipPath(
      clipper: OverlayClipper(
        scanWindow: scanWindow,
        borderRadius: config.borderRadius,
      ),
      child: child,
    );

    final sigma = config.blurSigma ?? theme.overlayBlurSigma!;
    if (config.scannerOverlayBackground != ScannerOverlayBackground.blur ||
        sigma <= 0) {
      return clipped;
    }

    return ClipPath(
      clipper: OverlayClipper(
        scanWindow: scanWindow,
        borderRadius: config.borderRadius,
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: child,
      ),
    );
  }
}

/// The wide glow that sweeps across the whole preview.
class _FullWidthSweep extends StatelessWidget {
  const _FullWidthSweep({required this.animation, required this.color});

  final Animation<double> animation;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        return AnimatedBuilder(
          animation: animation,
          builder: (context, _) {
            const bandHeight = 120.0;
            return Stack(
              children: <Widget>[
                Positioned(
                  top: animation.value * (height + bandHeight) - bandHeight,
                  left: 0,
                  right: 0,
                  height: bandHeight,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[
                          color.withValues(alpha: 0),
                          color.withValues(alpha: 0.4),
                          color.withValues(alpha: 0),
                        ],
                        stops: const <double>[0.1, 0.5, 0.9],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
