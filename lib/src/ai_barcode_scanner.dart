import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'config/gallery_button_type.dart';
import 'config/overlay_config.dart';
import 'config/scan_mode.dart';
import 'config/scan_window_config.dart';
import 'config/scanner_action.dart';
import 'config/scanner_feedback.dart';
import 'config/scanner_labels.dart';
import 'config/scanner_theme.dart';
import 'controller/ai_barcode_scanner_controller.dart';
import 'ui/focus_indicator.dart';
import 'ui/gallery_button.dart';
import 'ui/scan_hint.dart';
import 'ui/scanner_control_button.dart';
import 'ui/scanner_controls_bar.dart';
import 'ui/scanner_error_view.dart';
import 'ui/scanner_overlay.dart';
import 'ui/zoom_slider.dart';
import 'utils/barcode_extensions.dart';
import 'utils/platform_support.dart';

/// A complete, ready-to-use barcode scanner.
///
/// The default constructor builds a full-screen scanner you can push onto the
/// navigator; [AiBarcodeScanner.embedded] builds the same scanner without a
/// [Scaffold] so you can drop it into a page you already have.
///
/// The simplest useful form is a single callback:
///
/// ```dart
/// AiBarcodeScanner(
///   onDetect: (capture) {
///     debugPrint(capture.barcodes.first.rawValue);
///     Navigator.of(context).pop();
///   },
/// )
/// ```
///
/// Every camera option from `mobile_scanner` is available directly here — you
/// do not need to build a controller to restrict formats or change detection
/// speed:
///
/// ```dart
/// AiBarcodeScanner(
///   formats: const [BarcodeFormat.qrCode, BarcodeFormat.ean13],
///   detectionSpeed: DetectionSpeed.noDuplicates,
///   onDetect: handleScan,
/// )
/// ```
class AiBarcodeScanner extends StatefulWidget {
  /// Creates a full-screen scanner, wrapped in a [Scaffold].
  const AiBarcodeScanner({
    super.key,
    this.onDetect,
    this.validator,
    this.onDetectError,
    this.onScanComplete,
    this.controller,
    this.formats = const <BarcodeFormat>[],
    this.detectionSpeed = DetectionSpeed.noDuplicates,
    this.detectionTimeoutMs = 250,
    this.facing = CameraFacing.back,
    this.lensType = CameraLensType.any,
    this.cameraResolution,
    this.torchEnabled = false,
    this.autoStart = true,
    this.autoZoom = false,
    this.invertImage = false,
    this.initialZoom,
    this.returnImage = false,
    this.webBarcodeReader,
    this.webBarcodeLibraryScriptUrl,
    this.scanMode = ScanMode.single,
    this.maxScans,
    this.scanCooldown = const Duration(milliseconds: 1200),
    this.resultFlashDuration = const Duration(milliseconds: 1000),
    this.useAppLifecycleState = true,
    this.preferredOrientations,
    this.restoreOrientationsOnDispose = DeviceOrientation.values,
    this.tapToFocus = true,
    this.enablePinchToZoom = true,
    this.pinchZoomSensitivity = 1.0,
    this.doubleTapToResetZoom = true,
    this.idleHintDelay = const Duration(seconds: 6),
    this.showScanHint = true,
    this.theme,
    this.labels = const ScannerLabels(),
    this.overlayConfig = const ScannerOverlayConfig(),
    this.scanWindowConfig = const ScanWindowConfig(),
    this.feedback = const ScannerFeedbackConfig(),
    this.enabledActionButtons = const <ScannerAction>{
      ScannerAction.gallery,
      ScannerAction.cameraSwitch,
      ScannerAction.torch,
    },
    this.galleryButtonType = GalleryButtonType.filled,
    this.galleryIcon = Icons.photo_library_outlined,
    this.cameraSwitchIcon = Icons.cameraswitch_outlined,
    this.flashOnIcon = Icons.flashlight_on,
    this.flashOffIcon = Icons.flashlight_off_outlined,
    this.lensIcon = Icons.center_focus_strong_outlined,
    this.closeIcon = Icons.close,
    this.fit = BoxFit.cover,
    this.extendBodyBehindAppBar = true,
    this.appBarBuilder,
    this.bottomSheetBuilder,
    this.bottomNavigationBarBuilder,
    this.overlayBuilder,
    this.errorBuilder,
    this.placeholderBuilder,
    this.unsupportedBuilder,
    this.actions,
    this.child,
    this.scanWindow,
    this.restrictDetectionToScanWindow = false,
    this.scanWindowUpdateThreshold = 0.0,
    this.onImagePick,
    this.imagePicker,
    this.onGalleryScanError,
    this.onDispose,
    this.onClose,
    this.onScannerStarted,
    this.onError,
    this.onOpenSettings,
    this.onZoomChanged,
    this.onTorchChanged,
  }) : _embedded = false;

  /// Creates a scanner without a [Scaffold], for embedding in your own page.
  ///
  /// The app bar, bottom sheet and bottom navigation bar builders are not
  /// available here — the surrounding page owns that chrome.
  ///
  /// The defaults are quieter than the full-screen scanner's, on the
  /// assumption that an embedded preview sits inside a UI you have already
  /// designed: no controls, no gallery button and no guidance copy. Pass
  /// [enabledActionButtons], [galleryButtonType] and [showScanHint] to turn
  /// them back on.
  const AiBarcodeScanner.embedded({
    super.key,
    this.onDetect,
    this.validator,
    this.onDetectError,
    this.onScanComplete,
    this.controller,
    this.formats = const <BarcodeFormat>[],
    this.detectionSpeed = DetectionSpeed.noDuplicates,
    this.detectionTimeoutMs = 250,
    this.facing = CameraFacing.back,
    this.lensType = CameraLensType.any,
    this.cameraResolution,
    this.torchEnabled = false,
    this.autoStart = true,
    this.autoZoom = false,
    this.invertImage = false,
    this.initialZoom,
    this.returnImage = false,
    this.webBarcodeReader,
    this.webBarcodeLibraryScriptUrl,
    this.scanMode = ScanMode.single,
    this.maxScans,
    this.scanCooldown = const Duration(milliseconds: 1200),
    this.resultFlashDuration = const Duration(milliseconds: 1000),
    this.useAppLifecycleState = true,
    this.tapToFocus = true,
    this.enablePinchToZoom = true,
    this.pinchZoomSensitivity = 1.0,
    this.doubleTapToResetZoom = true,
    this.idleHintDelay = const Duration(seconds: 6),
    this.showScanHint = false,
    this.theme,
    this.labels = const ScannerLabels(),
    this.overlayConfig = const ScannerOverlayConfig(),
    this.scanWindowConfig = const ScanWindowConfig(),
    this.feedback = const ScannerFeedbackConfig(),
    this.enabledActionButtons = const <ScannerAction>{},
    this.galleryButtonType = GalleryButtonType.none,
    this.galleryIcon = Icons.photo_library_outlined,
    this.cameraSwitchIcon = Icons.cameraswitch_outlined,
    this.flashOnIcon = Icons.flashlight_on,
    this.flashOffIcon = Icons.flashlight_off_outlined,
    this.lensIcon = Icons.center_focus_strong_outlined,
    this.closeIcon = Icons.close,
    this.fit = BoxFit.cover,
    this.overlayBuilder,
    this.errorBuilder,
    this.placeholderBuilder,
    this.unsupportedBuilder,
    this.child,
    this.scanWindow,
    this.restrictDetectionToScanWindow = false,
    this.scanWindowUpdateThreshold = 0.0,
    this.onImagePick,
    this.imagePicker,
    this.onGalleryScanError,
    this.onDispose,
    this.onScannerStarted,
    this.onError,
    this.onOpenSettings,
    this.onZoomChanged,
    this.onTorchChanged,
  }) : _embedded = true,
       preferredOrientations = null,
       restoreOrientationsOnDispose = null,
       extendBodyBehindAppBar = true,
       appBarBuilder = null,
       bottomSheetBuilder = null,
       bottomNavigationBarBuilder = null,
       actions = null,
       onClose = null;

  final bool _embedded;

  // ---------------------------------------------------------------------------
  // Detection
  // ---------------------------------------------------------------------------

  /// Called for every barcode that passes [validator].
  ///
  /// In [ScanMode.single] this fires once. In [ScanMode.continuous] it fires
  /// at most once per [scanCooldown]. In [ScanMode.batch] it fires for each
  /// newly collected barcode, and [onScanComplete] fires at the end.
  final void Function(BarcodeCapture capture)? onDetect;

  /// Decides whether a detection should be accepted.
  ///
  /// Return `false` to reject it: the overlay flashes the error colour, the
  /// rejection haptic fires, and [onDetect] is not called.
  final bool Function(BarcodeCapture capture)? validator;

  /// Called when the scanner itself reports a detection error.
  final void Function(Object error, StackTrace stackTrace)? onDetectError;

  /// Called in [ScanMode.batch] when collection finishes.
  final void Function(List<Barcode> barcodes)? onScanComplete;

  // ---------------------------------------------------------------------------
  // Camera
  // ---------------------------------------------------------------------------

  /// An externally owned controller.
  ///
  /// When this is null the scanner creates and disposes its own from the
  /// camera parameters below. When it is not null those parameters are
  /// ignored — the controller already carries them.
  final AiBarcodeScannerController? controller;

  /// Restricts detection to these symbologies. Empty means "detect everything",
  /// which is slower and more prone to misreads; naming your formats is the
  /// single easiest accuracy win.
  final List<BarcodeFormat> formats;

  /// How aggressively to report detections. Defaults to
  /// [DetectionSpeed.noDuplicates], which suits a scanner screen that closes
  /// on the first result.
  final DetectionSpeed detectionSpeed;

  /// Minimum gap between detections, in milliseconds.
  ///
  /// This is **forced to zero** unless [detectionSpeed] is
  /// [DetectionSpeed.normal] — `MobileScannerController` does that in its
  /// initialiser. Since the default here is [DetectionSpeed.noDuplicates],
  /// setting this without also setting `detectionSpeed: DetectionSpeed.normal`
  /// has no effect. To throttle callbacks in continuous mode, use
  /// [scanCooldown] instead.
  final int detectionTimeoutMs;

  /// Which camera to start with.
  final CameraFacing facing;

  /// Which lens to start with, on devices that expose more than one.
  final CameraLensType lensType;

  /// Desired camera resolution. Android only.
  final Size? cameraResolution;

  /// Whether the torch should be on when the camera starts.
  final bool torchEnabled;

  /// Whether to start the camera automatically.
  final bool autoStart;

  /// Whether the camera should zoom towards a distant barcode. Android only.
  final bool autoZoom;

  /// Whether to invert frames so white-on-black barcodes can be read.
  /// Android only, and costs performance.
  final bool invertImage;

  /// Zoom to apply when the camera starts, from `0` to `1`.
  final double? initialZoom;

  /// Whether `BarcodeCapture.image` should carry the camera frame.
  final bool returnImage;

  /// Which detection backend to use on the web. Ignored elsewhere.
  ///
  /// The default (`null`) leaves `mobile_scanner` on
  /// [WebBarcodeReader.auto], which uses the browser's native
  /// `BarcodeDetector` where available and falls back to zxing-wasm.
  final WebBarcodeReader? webBarcodeReader;

  /// A mirror to load the web detection library from. Ignored elsewhere.
  ///
  /// `mobile_scanner` fetches zxing from a public CDN on first use. Point this
  /// at your own copy when a content security policy or an air-gapped
  /// deployment forbids that.
  final String? webBarcodeLibraryScriptUrl;

  // ---------------------------------------------------------------------------
  // Behaviour
  // ---------------------------------------------------------------------------

  /// What the scanner does after an accepted detection.
  final ScanMode scanMode;

  /// In [ScanMode.batch], finish automatically after this many barcodes.
  final int? maxScans;

  /// Minimum gap between two accepted detections in [ScanMode.continuous].
  final Duration scanCooldown;

  /// How long the overlay stays tinted after a scan before returning to rest.
  final Duration resultFlashDuration;

  /// Whether to stop the camera when the app is backgrounded and restart it on
  /// resume.
  ///
  /// This is handled here rather than by `MobileScanner`, which only manages
  /// the lifecycle for a controller it created itself.
  final bool useAppLifecycleState;

  /// Orientations to lock the device to while the scanner is on screen.
  ///
  /// `null` — the default — leaves the app's own orientation policy alone.
  /// Pass `[DeviceOrientation.portraitUp]` for the classic locked-portrait
  /// scanner.
  final List<DeviceOrientation>? preferredOrientations;

  /// Orientations to restore when the scanner is disposed.
  ///
  /// Only applied when [preferredOrientations] is set, so the scanner never
  /// silently unlocks an orientation the host app had locked.
  final List<DeviceOrientation>? restoreOrientationsOnDispose;

  /// Whether tapping the preview focuses the camera there.
  final bool tapToFocus;

  /// Whether a two-finger pinch adjusts the zoom.
  final bool enablePinchToZoom;

  /// Multiplier applied to pinch gestures. Higher zooms faster.
  final double pinchZoomSensitivity;

  /// Whether a double tap resets the zoom to its default.
  final bool doubleTapToResetZoom;

  /// How long to wait with no detection before swapping the hint for
  /// [ScannerLabels.scanHintIdle].
  final Duration idleHintDelay;

  /// Whether to show guidance copy under the scan window.
  final bool showScanHint;

  // ---------------------------------------------------------------------------
  // Appearance
  // ---------------------------------------------------------------------------

  /// Palette for the scanner's chrome. Defaults to a palette tuned for
  /// legibility over a live camera preview.
  final ScannerTheme? theme;

  /// Every user-visible string.
  final ScannerLabels labels;

  /// How the scan window and its animation look.
  final ScannerOverlayConfig overlayConfig;

  /// How the scan window is sized and positioned.
  final ScanWindowConfig scanWindowConfig;

  /// Haptic and audible feedback.
  final ScannerFeedbackConfig feedback;

  /// Which controls to offer. Controls the platform cannot support are hidden
  /// regardless.
  final Set<ScannerAction> enabledActionButtons;

  /// How the gallery affordance is presented.
  ///
  /// [GalleryButtonType.none] hides only the gallery button; the other
  /// controls are unaffected.
  final GalleryButtonType galleryButtonType;

  /// Glyph for the gallery control.
  final IconData galleryIcon;

  /// Glyph for the camera flip control.
  final IconData cameraSwitchIcon;

  /// Glyph shown while the torch is on.
  final IconData flashOnIcon;

  /// Glyph shown while the torch is off.
  final IconData flashOffIcon;

  /// Glyph for the lens control.
  final IconData lensIcon;

  /// Glyph for the close control.
  final IconData closeIcon;

  /// How the camera preview fills its box.
  final BoxFit fit;

  /// Whether the body extends behind the app bar. Full-screen scanner only.
  final bool extendBodyBehindAppBar;

  // ---------------------------------------------------------------------------
  // Builders
  // ---------------------------------------------------------------------------

  /// Builds a custom app bar. Full-screen scanner only.
  ///
  /// Supplying one replaces the default app bar entirely. The torch, camera,
  /// lens and gallery controls live over the preview, so they are unaffected —
  /// unlike in 7.x, where a custom app bar removed them.
  ///
  /// [ScannerAction.close] is the exception: it renders in the default app
  /// bar's leading slot, so a custom app bar needs to provide its own way back.
  final PreferredSizeWidget? Function(
    BuildContext context,
    AiBarcodeScannerController controller,
  )?
  appBarBuilder;

  /// Builds a bottom sheet. Full-screen scanner only.
  final Widget? Function(
    BuildContext context,
    AiBarcodeScannerController controller,
  )?
  bottomSheetBuilder;

  /// Builds a bottom navigation bar. Full-screen scanner only.
  final Widget? Function(
    BuildContext context,
    AiBarcodeScannerController controller,
  )?
  bottomNavigationBarBuilder;

  /// Replaces the built-in overlay.
  ///
  /// [scanWindow] is the rectangle the scanner is actually reading, in the
  /// preview's coordinate space, and [isSuccess] is `null` while idle.
  final Widget Function(
    BuildContext context,
    BoxConstraints constraints,
    AiBarcodeScannerController controller,
    Rect scanWindow,
    bool? isSuccess,
  )?
  overlayBuilder;

  /// Replaces the built-in camera error screen.
  final Widget Function(BuildContext context, MobileScannerException error)?
  errorBuilder;

  /// Replaces the black placeholder shown while the camera starts.
  final Widget Function(BuildContext context)? placeholderBuilder;

  /// Replaces the screen shown on platforms without camera support.
  final Widget Function(BuildContext context)? unsupportedBuilder;

  /// Extra actions appended to the default app bar.
  final List<Widget>? actions;

  /// An extra widget stacked over the preview.
  ///
  /// Unlike in 7.x this is drawn *in addition to* the scanner's own controls
  /// rather than replacing them. Wrap it in [Align] or [Positioned] to place
  /// it.
  final Widget? child;

  /// An explicit scan window, in the preview's coordinate space.
  ///
  /// Overrides [scanWindowConfig]. Prefer the config unless you need a
  /// rectangle the config cannot describe.
  final Rect? scanWindow;

  /// Whether barcodes outside the scan window should be ignored.
  ///
  /// Defaults to `false`: the reticle is drawn as *guidance*, and a barcode is
  /// accepted wherever it appears in the preview. That is what users expect,
  /// and it avoids two sharp edges in the platform implementations:
  ///
  /// * Android requires the barcode to be **entirely** inside the window
  ///   (`cornerPoints.all { window.contains(it) }`), not merely to intersect
  ///   it as the upstream documentation says — so a long EAN-13 held across a
  ///   portrait reticle is silently rejected.
  /// * Android also drops any barcode for which ML Kit reports no corner
  ///   points at all, but only when a window is set.
  ///
  /// Turn this on when several barcodes are visible at once and you need the
  /// user to choose one by aiming.
  final bool restrictDetectionToScanWindow;

  /// Threshold below which scan window changes are ignored, to avoid churn
  /// during layout animations.
  final double scanWindowUpdateThreshold;

  // ---------------------------------------------------------------------------
  // Callbacks
  // ---------------------------------------------------------------------------

  /// Called with the path of the image the user picked, or `null` if they
  /// cancelled.
  final void Function(String? path)? onImagePick;

  /// Replaces the built-in `image_picker` call.
  ///
  /// Return the path of an image to analyse, or `null` to cancel. The picked
  /// image still runs through the normal validation and feedback pipeline.
  final Future<String?> Function(BuildContext context)? imagePicker;

  /// Called when analysing a picked image fails.
  ///
  /// Without this, a failed gallery scan is reported only through the overlay.
  final void Function(Object error, StackTrace stackTrace)? onGalleryScanError;

  /// Called from [State.dispose].
  final VoidCallback? onDispose;

  /// Called when the user taps the close control.
  ///
  /// Defaults to popping the current route.
  final VoidCallback? onClose;

  /// Called once the camera has started, with the live controller.
  final void Function(AiBarcodeScannerController controller)? onScannerStarted;

  /// Called whenever the camera reports an error.
  final void Function(MobileScannerException error)? onError;

  /// Called when the user asks to open the app's settings from the permission
  /// screen. The button is hidden when this is null.
  final VoidCallback? onOpenSettings;

  /// Called when the zoom changes, with a value from `0` to `1`.
  final void Function(double zoomScale)? onZoomChanged;

  /// Called when the torch state changes.
  final void Function(TorchState state)? onTorchChanged;

  @override
  State<AiBarcodeScanner> createState() => _AiBarcodeScannerState();
}

class _AiBarcodeScannerState extends State<AiBarcodeScanner>
    with WidgetsBindingObserver {
  late AiBarcodeScannerController _controller;
  bool _ownsController = false;

  final ValueNotifier<bool?> _isSuccess = ValueNotifier<bool?>(null);
  final ValueNotifier<Offset?> _focusPoint = ValueNotifier<Offset?>(null);
  final ValueNotifier<bool> _isPickingImage = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _showIdleHint = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _hasMultipleLenses = ValueNotifier<bool>(false);

  Timer? _resultFlashTimer;
  Timer? _focusRingTimer;
  Timer? _idleHintTimer;

  DateTime? _lastAcceptedAt;
  DateTime? _lastRejectedAt;
  bool _startedReported = false;
  double _pinchBaseZoom = 0;
  TorchState? _lastTorchState;
  double? _lastZoomScale;
  CameraFacing? _lastFacing;
  bool _batchFinished = false;

  bool get _supported => ScannerPlatformSupport.current.isSupported;

  @override
  void initState() {
    super.initState();

    final orientations = widget.preferredOrientations;
    if (orientations != null &&
        ScannerPlatformSupport.supportsOrientationLock) {
      unawaited(SystemChrome.setPreferredOrientations(orientations));
    }

    if (kIsWeb) {
      final reader = widget.webBarcodeReader;
      if (reader != null) {
        MobileScannerPlatform.instance.setWebBarcodeReader(reader);
      }
      final scriptUrl = widget.webBarcodeLibraryScriptUrl;
      if (scriptUrl != null) {
        MobileScannerPlatform.instance.setBarcodeLibraryScriptUrl(scriptUrl);
      }
    }

    final provided = widget.controller;
    if (provided != null) {
      assert(
        widget.formats.isEmpty &&
            !widget.returnImage &&
            !widget.torchEnabled &&
            !widget.autoZoom &&
            !widget.invertImage &&
            widget.initialZoom == null &&
            widget.cameraResolution == null,
        'Camera options such as formats, returnImage and torchEnabled are '
        'ignored when `controller` is supplied — set them on the '
        'AiBarcodeScannerController instead.',
      );
      _controller = provided;
      _ownsController = false;
    } else {
      _controller = AiBarcodeScannerController(
        autoStart: widget.autoStart,
        cameraResolution: widget.cameraResolution,
        lensType: widget.lensType,
        detectionSpeed: widget.detectionSpeed,
        detectionTimeoutMs: widget.detectionTimeoutMs,
        facing: widget.facing,
        formats: widget.formats,
        returnImage: widget.returnImage,
        torchEnabled: widget.torchEnabled,
        invertImage: widget.invertImage,
        autoZoom: widget.autoZoom,
        initialZoom: widget.initialZoom,
      );
      _ownsController = true;
    }

    _controller.state.addListener(_onScannerStateChanged);

    if (widget.useAppLifecycleState) {
      WidgetsBinding.instance.addObserver(this);
    }

    _restartIdleHintTimer();
  }

  @override
  void didUpdateWidget(covariant AiBarcodeScanner oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.useAppLifecycleState != widget.useAppLifecycleState) {
      if (widget.useAppLifecycleState) {
        WidgetsBinding.instance.addObserver(this);
      } else {
        WidgetsBinding.instance.removeObserver(this);
      }
    }

    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.state.removeListener(_onScannerStateChanged);
      _controller.state.removeListener(_onScannerStateChanged);
      if (_ownsController) {
        _controller.dispose();
      }
      final provided = widget.controller;
      _controller =
          provided ??
          AiBarcodeScannerController(
            autoStart: widget.autoStart,
            formats: widget.formats,
            detectionSpeed: widget.detectionSpeed,
            detectionTimeoutMs: widget.detectionTimeoutMs,
            facing: widget.facing,
            lensType: widget.lensType,
            cameraResolution: widget.cameraResolution,
            torchEnabled: widget.torchEnabled,
            returnImage: widget.returnImage,
            invertImage: widget.invertImage,
            autoZoom: widget.autoZoom,
            initialZoom: widget.initialZoom,
          );
      _ownsController = provided == null;
      _controller.state.addListener(_onScannerStateChanged);
      _startedReported = false;
      _lastTorchState = null;
      _lastZoomScale = null;
      _lastFacing = null;
      _hasMultipleLenses.value = false;
    }
  }

  @override
  void dispose() {
    _resultFlashTimer?.cancel();
    _focusRingTimer?.cancel();
    _idleHintTimer?.cancel();

    if (widget.useAppLifecycleState) {
      WidgetsBinding.instance.removeObserver(this);
    }

    _controller.state.removeListener(_onScannerStateChanged);
    if (_ownsController) {
      _controller.dispose();
    }

    _isSuccess.dispose();
    _focusPoint.dispose();
    _isPickingImage.dispose();
    _showIdleHint.dispose();
    _hasMultipleLenses.dispose();

    // Only touch the orientation policy if this widget changed it, so the host
    // app's own lock survives.
    final restore = widget.restoreOrientationsOnDispose;
    if (widget.preferredOrientations != null &&
        restore != null &&
        ScannerPlatformSupport.supportsOrientationLock) {
      unawaited(SystemChrome.setPreferredOrientations(restore));
    }

    widget.onDispose?.call();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!widget.useAppLifecycleState) return;
    if (!_controller.value.hasCameraPermission) return;

    switch (state) {
      case AppLifecycleState.resumed:
        // Only the route the user can actually see should reclaim the camera;
        // otherwise two stacked scanners both call start() and race for the
        // single platform session.
        if (ModalRoute.of(context)?.isCurrent ?? true) {
          unawaited(_controller.start());
        }
      case AppLifecycleState.inactive:
        unawaited(_controller.stop());
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        return;
    }
  }

  // ---------------------------------------------------------------------------
  // State plumbing
  // ---------------------------------------------------------------------------

  void _onScannerStateChanged() {
    final state = _controller.value;

    if (!_startedReported && state.isRunning) {
      _startedReported = true;
      widget.onScannerStarted?.call(_controller);
      unawaited(_probeLenses());
    }

    if (state.cameraDirection != _lastFacing) {
      _lastFacing = state.cameraDirection;
      if (_startedReported) unawaited(_probeLenses());
    }

    if (state.torchState != _lastTorchState) {
      _lastTorchState = state.torchState;
      widget.onTorchChanged?.call(state.torchState);
    }

    if (state.zoomScale != _lastZoomScale) {
      _lastZoomScale = state.zoomScale;
      widget.onZoomChanged?.call(state.zoomScale);
    }

    final error = state.error;
    if (error != null) {
      widget.onError?.call(error);
    }
  }

  void _restartIdleHintTimer() {
    _idleHintTimer?.cancel();
    _showIdleHint.value = false;
    if (!widget.showScanHint) return;
    _idleHintTimer = Timer(widget.idleHintDelay, () {
      if (mounted) _showIdleHint.value = true;
    });
  }

  void _flashResult({required bool success}) {
    _isSuccess.value = success;
    _resultFlashTimer?.cancel();
    _resultFlashTimer = Timer(widget.resultFlashDuration, () {
      if (mounted) _isSuccess.value = null;
    });
  }

  // ---------------------------------------------------------------------------
  // Detection pipeline
  // ---------------------------------------------------------------------------

  void _onDetect(BarcodeCapture capture, {bool fromGallery = false}) {
    // A gallery pick is an explicit user action, so it bypasses both the
    // paused-session guard and the continuous-mode cooldown: the user asked
    // for this image to be read, now.
    if (!fromGallery && _controller.isScanningPaused) return;
    if (capture.barcodes.isEmpty) return;
    if (_controller.collected.isEmpty) _batchFinished = false;

    _restartIdleHintTimer();

    bool accepted;
    try {
      accepted = widget.validator?.call(capture) ?? true;
    } catch (error, stackTrace) {
      // A throwing validator is a bug in the host app, but it must not take
      // the scanner down with it.
      accepted = false;
      widget.onDetectError?.call(error, stackTrace);
    }

    if (!accepted) {
      // Without a cooldown, a rejected code held in frame fires the rejection
      // haptic on every detection callback — a continuous buzz.
      final lastReject = _lastRejectedAt;
      final rejectedAt = DateTime.now();
      if (lastReject == null ||
          rejectedAt.difference(lastReject) >= widget.scanCooldown) {
        _lastRejectedAt = rejectedAt;
        _flashResult(success: false);
        unawaited(widget.feedback.play(ScannerFeedbackEvent.reject));
      }
      return;
    }

    final now = DateTime.now();
    if (!fromGallery && widget.scanMode == ScanMode.continuous) {
      final last = _lastAcceptedAt;
      if (last != null && now.difference(last) < widget.scanCooldown) {
        return;
      }
    }
    _lastAcceptedAt = now;

    switch (widget.scanMode) {
      case ScanMode.single:
        _controller.pauseScanning();
        _flashResult(success: true);
        unawaited(widget.feedback.play(ScannerFeedbackEvent.detect));
        widget.onDetect?.call(capture);
      case ScanMode.continuous:
        _flashResult(success: true);
        unawaited(widget.feedback.play(ScannerFeedbackEvent.detect));
        widget.onDetect?.call(capture);
      case ScanMode.batch:
        final limit = widget.maxScans;
        var collectedAny = false;
        for (final barcode in capture.barcodes) {
          // Stop at the limit rather than taking the whole capture: a single
          // frame can carry more barcodes than the budget has room for.
          if (limit != null && _controller.collected.length >= limit) break;
          if (_controller.collect(barcode)) collectedAny = true;
        }
        if (!collectedAny) return;
        _flashResult(success: true);
        unawaited(widget.feedback.play(ScannerFeedbackEvent.detect));
        widget.onDetect?.call(capture);

        if (limit != null && _controller.collected.length >= limit) {
          _finishBatch();
        }
    }
  }

  void _finishBatch() {
    // `onScanComplete` hands over ownership of the collected list; firing it
    // twice for one session would double-submit whatever the host does with it.
    if (_batchFinished) return;
    _batchFinished = true;
    _controller.pauseScanning();
    widget.onScanComplete?.call(_controller.collected);
  }

  // ---------------------------------------------------------------------------
  // Gallery
  // ---------------------------------------------------------------------------

  Future<void> _pickAndAnalyzeImage() async {
    if (_isPickingImage.value) return;
    _isPickingImage.value = true;
    unawaited(widget.feedback.play(ScannerFeedbackEvent.control));

    try {
      final String? path;
      final customPicker = widget.imagePicker;
      if (customPicker != null) {
        path = await customPicker(context);
      } else {
        final file = await ImagePicker().pickImage(source: ImageSource.gallery);
        path = file?.path;
      }

      widget.onImagePick?.call(path);
      if (path == null) return;

      final capture = await _controller.analyzeImage(
        path,
        // Read the formats off the live controller, not the widget: when the
        // caller supplies a controller, `widget.formats` is asserted empty.
        formats: _controller.raw.formats,
      );

      if (!mounted) return;

      if (capture == null || capture.barcodes.isEmpty) {
        _flashResult(success: false);
        unawaited(widget.feedback.play(ScannerFeedbackEvent.reject));
        return;
      }

      _onDetect(capture, fromGallery: true);
    } catch (error, stackTrace) {
      if (!mounted) return;
      _flashResult(success: false);
      unawaited(widget.feedback.play(ScannerFeedbackEvent.reject));
      // Previously this escaped as an unhandled async error and the user got
      // no feedback at all.
      if (widget.onGalleryScanError != null) {
        widget.onGalleryScanError!.call(error, stackTrace);
      } else {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stackTrace,
            library: 'ai_barcode_scanner',
            context: ErrorDescription('while analyzing a picked image'),
          ),
        );
      }
    } finally {
      if (mounted) _isPickingImage.value = false;
    }
  }

  // ---------------------------------------------------------------------------
  // Gestures
  // ---------------------------------------------------------------------------

  void _onScaleStart(ScaleStartDetails details) {
    if (details.pointerCount < 2) return;
    _pinchBaseZoom = _controller.value.zoomScale;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (!widget.enablePinchToZoom) return;
    if (details.pointerCount < 2) return;
    if (!_controller.isRunning) return;

    // `details.scale` is a span *ratio*, so adding `scale - 1` straight onto a
    // normalised 0..1 zoom is neither symmetric nor proportional: a gentle
    // spread saturates the zoom while the matching pinch barely moves it.
    // Mapping through log2 makes doubling the span and halving it equal and
    // opposite, and one octave moves the zoom by half the sensitivity.
    if ((details.scale - 1).abs() < 0.01) return;
    final octaves = math.log(details.scale) / math.ln2;
    final delta = octaves * 0.5 * widget.pinchZoomSensitivity;

    // No setState here: the controller pushes the new zoom through its own
    // ValueNotifier, which is what the slider and callbacks listen to.
    unawaited(_controller.setZoomScale(_pinchBaseZoom + delta));
  }

  Future<void> _onTapFocus(Offset localPosition, Size previewSize) async {
    if (!widget.tapToFocus) return;
    if (previewSize.width <= 0 || previewSize.height <= 0) return;

    _focusPoint.value = localPosition;
    _focusRingTimer?.cancel();
    _focusRingTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) _focusPoint.value = null;
    });

    await _controller.setFocusPoint(
      Offset(
        (localPosition.dx / previewSize.width).clamp(0.0, 1.0),
        (localPosition.dy / previewSize.height).clamp(0.0, 1.0),
      ),
    );
  }

  Future<void> _onDoubleTap() async {
    if (!widget.doubleTapToResetZoom) return;
    unawaited(widget.feedback.play(ScannerFeedbackEvent.control));
    await _controller.resetZoomScale();
  }

  void _handleClose() {
    unawaited(widget.feedback.play(ScannerFeedbackEvent.control));
    final onClose = widget.onClose;
    if (onClose != null) {
      onClose();
      return;
    }
    final navigator = Navigator.maybeOf(context);
    if (navigator != null && navigator.canPop()) {
      navigator.pop();
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = (widget.theme ?? const ScannerTheme()).resolve();

    if (!_supported) {
      final unsupported =
          widget.unsupportedBuilder?.call(context) ??
          ScannerUnsupportedPlatformView(labels: widget.labels, theme: theme);
      return ScannerThemeScope(
        theme: theme,
        child:
            widget._embedded
                ? unsupported
                : Scaffold(
                  appBar: widget.appBarBuilder?.call(context, _controller),
                  body: unsupported,
                ),
      );
    }

    final body = ScannerThemeScope(theme: theme, child: _buildBody(theme));

    if (widget._embedded) return body;

    return ScannerThemeScope(
      theme: theme,
      child: Scaffold(
        backgroundColor: theme.surfaceColor,
        extendBodyBehindAppBar: widget.extendBodyBehindAppBar,
        appBar:
            widget.appBarBuilder?.call(context, _controller) ??
            _buildDefaultAppBar(theme),
        bottomSheet: widget.bottomSheetBuilder?.call(context, _controller),
        bottomNavigationBar: widget.bottomNavigationBarBuilder?.call(
          context,
          _controller,
        ),
        body: body,
      ),
    );
  }

  PreferredSizeWidget? _buildDefaultAppBar(ScannerTheme theme) {
    final showClose = widget.enabledActionButtons.contains(ScannerAction.close);
    final extra = widget.actions;
    if (!showClose && (extra == null || extra.isEmpty)) return null;

    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: theme.controlForegroundColor,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      leading:
          showClose
              ? Padding(
                padding: const EdgeInsets.all(6),
                child: ScannerControlButton(
                  icon: widget.closeIcon,
                  onPressed: _handleClose,
                  tooltip: widget.labels.closeTooltip,
                  theme: theme,
                ),
              )
              : null,
      actions: <Widget>[...?extra],
    );
  }

  Widget _buildBody(ScannerTheme theme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final safeArea = MediaQuery.paddingOf(context);
        final prefersSquare =
            widget.formats.isEmpty ||
            widget.formats.every((f) => f.isTwoDimensional);

        final scanWindow =
            widget.scanWindow ??
            widget.scanWindowConfig.resolve(
              context,
              constraints,
              prefersSquare: prefersSquare,
              safeArea: safeArea,
            );

        // Only hand the window to the platform when detection should actually
        // be restricted; otherwise it is purely decorative.
        final effectiveScanWindow =
            widget.restrictDetectionToScanWindow &&
                    !(widget.scanWindowConfig.isFullPreview &&
                        widget.scanWindow == null)
                ? scanWindow
                : null;

        final preview = MobileScanner(
          // `_MobileScannerState.controller` is `late final` — it is captured
          // once in initState and never revisited — so swapping the controller
          // has to remount the subtree, or upstream keeps driving the old one.
          key: ValueKey<MobileScannerController>(_controller.raw),
          controller: _controller.raw,
          fit: widget.fit,
          scanWindow: effectiveScanWindow,
          scanWindowUpdateThreshold: widget.scanWindowUpdateThreshold,
          onDetect: _onDetect,
          onDetectError: (error, stackTrace) {
            widget.onDetectError?.call(error, stackTrace);
          },
          // Handled by this widget instead, so a focus ring can be drawn and
          // the tap can be mapped against the preview box rather than the
          // whole screen.
          tapToFocus: false,
          errorBuilder:
              (context, error) =>
                  widget.errorBuilder?.call(context, error) ??
                  ScannerErrorView(
                    error: error,
                    labels: widget.labels,
                    theme: theme,
                    onRetry: () => unawaited(_controller.start()),
                    onOpenSettings: widget.onOpenSettings,
                  ),
          placeholderBuilder:
              (context) =>
                  widget.placeholderBuilder?.call(context) ??
                  _buildPlaceholder(theme),
          overlayBuilder: (context, overlayConstraints) {
            return ValueListenableBuilder<bool?>(
              valueListenable: _isSuccess,
              builder: (context, isSuccess, _) {
                final custom = widget.overlayBuilder;
                if (custom != null) {
                  return custom(
                    context,
                    overlayConstraints,
                    _controller,
                    scanWindow,
                    isSuccess,
                  );
                }
                if (widget.scanWindowConfig.isFullPreview &&
                    widget.overlayConfig.scannerBorder == ScannerBorder.none &&
                    widget.overlayConfig.scannerOverlayBackground ==
                        ScannerOverlayBackground.none) {
                  return const SizedBox.shrink();
                }
                return ScannerOverlay(
                  scanWindow: scanWindow,
                  config: widget.overlayConfig,
                  theme: theme,
                  isSuccess: isSuccess,
                );
              },
            );
          },
          // The wrapper owns lifecycle handling; upstream would ignore this
          // anyway because a controller is always supplied.
          useAppLifecycleState: false,
        );

        // The gesture layer wraps only the preview. If it wrapped the whole
        // stack, its tap recognisers would compete with — and beat — the
        // controls layered on top, so tapping the torch would silently do
        // nothing whenever tap-to-focus or double-tap-to-zoom was enabled.
        final gestureLayer = GestureDetector(
          behavior: HitTestBehavior.translucent,
          onScaleStart: widget.enablePinchToZoom ? _onScaleStart : null,
          onScaleUpdate: widget.enablePinchToZoom ? _onScaleUpdate : null,
          onDoubleTap: widget.doubleTapToResetZoom ? _onDoubleTap : null,
          onTapUp:
              widget.tapToFocus
                  ? (details) => unawaited(
                    _onTapFocus(details.localPosition, constraints.biggest),
                  )
                  : null,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              preview,
              if (widget.overlayConfig.showBarcodeHighlights &&
                  ScannerPlatformSupport.current.barcodeCorners)
                IgnorePointer(
                  child: BarcodeOverlay(
                    controller: _controller.raw,
                    boxFit: widget.fit,
                    color: theme.barcodeHighlightColor!.withValues(alpha: 0.35),
                  ),
                ),
              if (widget.tapToFocus)
                ValueListenableBuilder<Offset?>(
                  valueListenable: _focusPoint,
                  builder:
                      (context, point, _) => Stack(
                        children: <Widget>[
                          FocusIndicator(position: point, theme: theme),
                        ],
                      ),
                ),
            ],
          ),
        );

        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            gestureLayer,
            _buildChrome(theme, constraints, scanWindow),
            if (widget.child != null) widget.child!,
          ],
        );
      },
    );
  }

  Future<void> _probeLenses() async {
    if (!ScannerPlatformSupport.current.lensType) return;
    if (!widget.enabledActionButtons.contains(ScannerAction.lens)) return;
    final lenses = await _controller.supportedLenses(
      facing: _controller.value.cameraDirection,
    );
    final specific =
        lenses.where((lens) => lens != CameraLensType.any).toList();
    if (mounted) _hasMultipleLenses.value = specific.length > 1;
  }

  /// The controls that make sense on this platform, for this device, right now.
  List<Widget> _buildControls(ScannerTheme theme, MobileScannerState state) {
    final support = ScannerPlatformSupport.current;
    final enabled = widget.enabledActionButtons;
    final controls = <Widget>[];

    if (enabled.contains(ScannerAction.gallery) &&
        widget.galleryButtonType == GalleryButtonType.icon &&
        support.analyzeImage) {
      controls.add(
        ValueListenableBuilder<bool>(
          valueListenable: _isPickingImage,
          builder:
              (context, busy, _) => GalleryButton(
                type: GalleryButtonType.icon,
                onPressed: () => unawaited(_pickAndAnalyzeImage()),
                label: widget.labels.galleryButton,
                tooltip: widget.labels.galleryTooltip,
                icon: widget.galleryIcon,
                theme: theme,
                isBusy: busy,
              ),
        ),
      );
    }

    if (enabled.contains(ScannerAction.torch) &&
        support.torch &&
        state.torchState != TorchState.unavailable) {
      final isOn = state.torchState == TorchState.on;
      controls.add(
        ScannerControlButton(
          icon: isOn ? widget.flashOnIcon : widget.flashOffIcon,
          isActive: isOn,
          tooltip: switch (state.torchState) {
            TorchState.on => widget.labels.torchOnTooltip,
            TorchState.auto => widget.labels.torchAutoTooltip,
            TorchState.off ||
            TorchState.unavailable => widget.labels.torchOffTooltip,
          },
          theme: theme,
          onPressed: () {
            unawaited(widget.feedback.play(ScannerFeedbackEvent.control));
            unawaited(_controller.toggleTorch());
          },
        ),
      );
    }

    if (enabled.contains(ScannerAction.cameraSwitch) &&
        _controller.hasMultipleCameras) {
      controls.add(
        ScannerControlButton(
          icon: widget.cameraSwitchIcon,
          tooltip: widget.labels.switchCameraTooltip,
          theme: theme,
          onPressed: () {
            unawaited(widget.feedback.play(ScannerFeedbackEvent.control));
            unawaited(_controller.switchCamera());
          },
        ),
      );
    }

    if (enabled.contains(ScannerAction.lens) && _hasMultipleLenses.value) {
      controls.add(
        ScannerControlButton(
          icon: widget.lensIcon,
          tooltip: widget.labels.switchLensTooltip,
          theme: theme,
          onPressed: () {
            unawaited(widget.feedback.play(ScannerFeedbackEvent.control));
            unawaited(_controller.switchLens());
          },
        ),
      );
    }

    return controls;
  }

  /// The scanner's own chrome: guidance copy, controls, zoom and batch actions.
  ///
  /// The layout follows the shape of the preview rather than the device class:
  /// a bottom row when the preview is taller than it is wide, and a trailing
  /// column when it is not — which keeps the controls off the scan window in
  /// landscape and on desktop.
  Widget _buildChrome(
    ScannerTheme theme,
    BoxConstraints constraints,
    Rect scanWindow,
  ) {
    return ValueListenableBuilder<MobileScannerState>(
      valueListenable: _controller.state,
      builder: (context, state, _) {
        // While the placeholder or the error view is showing, the chrome would
        // be floating over something it does not belong to.
        if (!state.isInitialized || state.error != null) {
          return const SizedBox.shrink();
        }

        return ValueListenableBuilder<bool>(
          valueListenable: _hasMultipleLenses,
          builder: (context, hasMultipleLenses, _) {
            final controls = _buildControls(theme, state);
            final isWide = constraints.maxWidth > constraints.maxHeight;
            final safeArea = MediaQuery.paddingOf(context);

            final zoomSlider =
                widget.enabledActionButtons.contains(ScannerAction.zoom) &&
                        ScannerPlatformSupport.current.zoom
                    ? ScannerZoomSlider(
                      value: state.zoomScale,
                      vertical: isWide,
                      semanticLabel: widget.labels.zoomTooltip,
                      theme: theme,
                      onChanged:
                          (value) => unawaited(_controller.setZoomScale(value)),
                    )
                    : null;

            final galleryFilled =
                widget.enabledActionButtons.contains(ScannerAction.gallery) &&
                        widget.galleryButtonType == GalleryButtonType.filled &&
                        ScannerPlatformSupport.current.analyzeImage
                    ? ValueListenableBuilder<bool>(
                      valueListenable: _isPickingImage,
                      builder:
                          (context, busy, _) => GalleryButton(
                            type: GalleryButtonType.filled,
                            onPressed: () => unawaited(_pickAndAnalyzeImage()),
                            label: widget.labels.galleryButton,
                            tooltip: widget.labels.galleryTooltip,
                            icon: widget.galleryIcon,
                            theme: theme,
                            isBusy: busy,
                          ),
                    )
                    : null;

            final batchBar =
                widget.scanMode == ScanMode.batch
                    ? ListenableBuilder(
                      listenable: _controller,
                      builder: (context, _) {
                        final count = _controller.collected.length;
                        return FilledButton.icon(
                          onPressed: count == 0 ? null : _finishBatch,
                          icon: ScannerCountBadge(count: count, theme: theme),
                          label: Text(widget.labels.doneButton),
                          style: FilledButton.styleFrom(
                            backgroundColor: theme.controlBackgroundColor,
                            foregroundColor: theme.controlForegroundColor,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 14,
                            ),
                          ),
                        );
                      },
                    )
                    : null;

            final hint =
                widget.showScanHint
                    ? ValueListenableBuilder<bool>(
                      valueListenable: _showIdleHint,
                      builder:
                          (context, idle, _) => ScanHint(
                            text:
                                widget.scanMode == ScanMode.batch
                                    ? widget.labels.scanHintBatch
                                    : (idle
                                        ? widget.labels.scanHintIdle
                                        : widget.labels.scanHint),
                            theme: theme,
                          ),
                    )
                    : null;

            final bottomCluster = <Widget>[
              if (hint != null) hint,
              if (zoomSlider != null && !isWide) zoomSlider,
              if (!isWide && controls.isNotEmpty)
                ScannerControlsBar(theme: theme, children: controls),
              if (galleryFilled != null) galleryFilled,
              if (batchBar != null) batchBar,
            ];

            return Stack(
              fit: StackFit.expand,
              children: <Widget>[
                // Anchored to the bottom and sized to its own content, with no
                // `top`. Constraining the top to the scan window's bottom edge
                // instead would collapse the cluster to zero height — and make
                // every control untappable — whenever the window reaches the
                // bottom of the preview: a short landscape screen, or
                // ScanWindowShape.fullPreview.
                Positioned(
                  left: isWide && zoomSlider != null ? 56 : 0,
                  right: isWide ? theme.controlSize! + 32 : 0,
                  bottom: 0,
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          for (
                            var i = 0;
                            i < bottomCluster.length;
                            i++
                          ) ...<Widget>[
                            if (i > 0) SizedBox(height: theme.controlSpacing!),
                            bottomCluster[i],
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                if (isWide && controls.isNotEmpty)
                  Positioned(
                    top: 0,
                    bottom: 0,
                    right: safeArea.right + 12,
                    child: Center(
                      child: ScannerControlsBar(
                        axis: Axis.vertical,
                        theme: theme,
                        children: controls,
                      ),
                    ),
                  ),
                if (isWide && zoomSlider != null)
                  Positioned(
                    top: 0,
                    bottom: 0,
                    left: safeArea.left + 12,
                    child: Center(child: zoomSlider),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildPlaceholder(ScannerTheme theme) {
    return ColoredBox(
      color: const Color(0xFF000000),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox.square(
              dimension: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: theme.controlForegroundColor,
              ),
            ),
            const SizedBox(height: 14),
            Text(widget.labels.startingCamera, style: theme.hintTextStyle),
          ],
        ),
      ),
    );
  }
}
