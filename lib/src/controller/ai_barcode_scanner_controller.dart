import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../utils/platform_support.dart';

/// A high-level handle on a running scanner.
///
/// It owns a [MobileScannerController] and adds the operations a scanner
/// screen actually needs: cycling lenses, jumping to the macro lens, pausing
/// *detection* without tearing the camera down, and collecting barcodes in
/// batch mode.
///
/// You rarely need to construct one. Every camera option is also available
/// directly on `AiBarcodeScanner`, and the widget creates and disposes a
/// controller for you. Construct one when you want to drive the scanner from
/// outside the widget:
///
/// ```dart
/// final controller = AiBarcodeScannerController(
///   formats: const [BarcodeFormat.qrCode],
///   detectionSpeed: DetectionSpeed.noDuplicates,
/// );
///
/// AiBarcodeScanner(
///   controller: controller,
///   onDetect: (capture) async {
///     controller.pauseScanning();          // freeze detection, keep preview
///     final ok = await verifyOnServer(capture);
///     if (!ok) controller.resumeScanning();
///   },
/// );
/// ```
///
/// If you already hold a [MobileScannerController], wrap it with
/// [AiBarcodeScannerController.fromMobileScanner] instead; ownership stays with
/// you and this class will not dispose it.
///
/// One upstream behaviour to be aware of when you keep a controller across
/// screens: `MobileScanner` calls `stop()` on whatever controller it was given
/// when it unmounts, as long as that controller has `autoStart` set. It does
/// not *dispose* it — the instance stays valid — but the camera session is
/// released, so call [start] again when you mount the next scanner.
///
/// The same applies to two scanners mounted at once, for example one route
/// pushed over another. The platform has a single camera session, so the
/// second scanner takes it and the first goes dark; when the second is popped,
/// call [start] on the first to reclaim it. The scanner does not do this for
/// you, because it cannot tell a session it lost from one you stopped on
/// purpose.
class AiBarcodeScannerController extends ChangeNotifier {
  /// Creates a controller that owns a new [MobileScannerController].
  ///
  /// The parameters mirror [MobileScannerController]'s; see its documentation
  /// for the per-platform support of each one.
  AiBarcodeScannerController({
    bool autoStart = true,
    Size? cameraResolution,
    CameraLensType lensType = CameraLensType.any,
    DetectionSpeed detectionSpeed = DetectionSpeed.noDuplicates,
    int detectionTimeoutMs = 250,
    CameraFacing facing = CameraFacing.back,
    List<BarcodeFormat> formats = const <BarcodeFormat>[],
    bool returnImage = false,
    bool torchEnabled = false,
    bool invertImage = false,
    bool autoZoom = false,
    double? initialZoom,
  }) : _ownsController = true,
       _controller = MobileScannerController(
         autoStart: autoStart,
         cameraResolution: cameraResolution,
         lensType: lensType,
         detectionSpeed: detectionSpeed,
         detectionTimeoutMs: detectionTimeoutMs,
         facing: facing,
         formats: formats,
         returnImage: returnImage,
         torchEnabled: torchEnabled,
         invertImage: invertImage,
         autoZoom: autoZoom,
         initialZoom: initialZoom,
       );

  /// Wraps an existing [MobileScannerController].
  ///
  /// The caller keeps ownership: disposing this facade does **not** dispose
  /// [controller].
  AiBarcodeScannerController.fromMobileScanner(
    MobileScannerController controller,
  ) : _ownsController = false,
      _controller = controller;

  final MobileScannerController _controller;
  final bool _ownsController;

  bool _scanningPaused = false;
  bool _disposed = false;
  final List<Barcode> _collected = <Barcode>[];

  /// The underlying `mobile_scanner` controller.
  ///
  /// Everything this facade does not expose is reachable here. Prefer the
  /// facade's own methods where they exist — they add the guards that keep the
  /// scanner from throwing when the camera is not running.
  MobileScannerController get raw => _controller;

  /// The live camera state: torch, zoom, orientation, errors, and so on.
  ///
  /// This is a [ValueListenable], so it can drive a [ValueListenableBuilder]
  /// directly.
  ValueListenable<MobileScannerState> get state => _controller;

  /// The current camera state.
  MobileScannerState get value => _controller.value;

  /// The stream of detections, including detections that arrive while
  /// [isScanningPaused] is true.
  ///
  /// The widget's `onDetect` callback is the filtered version of this.
  Stream<BarcodeCapture> get barcodes => _controller.barcodes;

  /// Whether detection results are currently being discarded.
  ///
  /// The camera keeps running and the preview keeps updating; only the
  /// scanner's callbacks are suppressed. Use this to hold the preview steady
  /// while you validate a scan.
  bool get isScanningPaused => _scanningPaused;

  /// Whether the camera is running.
  bool get isRunning => _controller.value.isRunning;

  /// Whether the camera has been initialised at least once.
  bool get isInitialized => _controller.value.isInitialized;

  /// Whether the torch is currently on.
  bool get isTorchOn => _controller.value.torchState == TorchState.on;

  /// Whether this device reported a usable torch.
  bool get hasTorch =>
      ScannerPlatformSupport.current.torch &&
      _controller.value.torchState != TorchState.unavailable;

  /// Whether more than one camera is available, so flipping makes sense.
  ///
  /// Returns `true` when the platform does not report a camera count, since
  /// hiding the control would be worse than showing one that does nothing.
  bool get hasMultipleCameras {
    final count = _controller.value.availableCameras;
    if (count == null) return true;
    return count > 1;
  }

  /// The barcodes collected so far in batch mode, oldest first.
  List<Barcode> get collected => List<Barcode>.unmodifiable(_collected);

  /// Stops delivering detections without stopping the camera.
  void pauseScanning() {
    if (_disposed || _scanningPaused) return;
    _scanningPaused = true;
    notifyListeners();
  }

  /// Resumes delivering detections after [pauseScanning].
  void resumeScanning() {
    if (_disposed || !_scanningPaused) return;
    _scanningPaused = false;
    notifyListeners();
  }

  /// Adds [barcode] to [collected] if it is not already there.
  ///
  /// Returns `true` when the barcode was new. Used by batch mode; call it
  /// yourself if you drive collection from your own `onDetect`.
  bool collect(Barcode barcode) {
    final value = barcode.rawValue ?? barcode.displayValue;
    if (value == null || value.isEmpty) return false;
    final alreadySeen = _collected.any(
      (b) => (b.rawValue ?? b.displayValue) == value,
    );
    if (alreadySeen) return false;
    _collected.add(barcode);
    notifyListeners();
    return true;
  }

  /// Empties [collected].
  void clearCollected() {
    if (_collected.isEmpty) return;
    _collected.clear();
    notifyListeners();
  }

  /// Starts the camera. Safe to call when it is already running.
  Future<void> start({
    CameraFacing? cameraDirection,
    CameraLensType? cameraLensType,
  }) async {
    if (_disposed) return;
    try {
      await _controller.start(
        cameraDirection: cameraDirection,
        cameraLensType: cameraLensType,
      );
    } on MobileScannerException catch (error, stackTrace) {
      // `start` reports permission and hardware failures through
      // `state.error`, which the widget renders. Anything that still escapes
      // here (a disposed or not-yet-attached controller) is a lifecycle race
      // rather than something the user can act on.
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'ai_barcode_scanner',
          context: ErrorDescription('while starting the camera'),
          silent: true,
        ),
      );
    }
  }

  /// Stops the camera and releases the platform session.
  Future<void> stop() async {
    if (_disposed) return;
    await _controller.stop();
  }

  /// Pauses the camera, keeping the session so [start] can resume it.
  Future<void> pause() async {
    if (_disposed) return;
    await _controller.pause();
  }

  /// Toggles the torch, if the device has one and the camera is running.
  Future<void> toggleTorch() async {
    if (_disposed || !isRunning || !hasTorch) return;
    await _guarded(_controller.toggleTorch);
  }

  /// Turns the torch [on] or off, if it is not already in that state.
  Future<void> setTorch({required bool on}) async {
    if (_disposed || !isRunning || !hasTorch) return;
    if (isTorchOn == on) return;
    await _guarded(_controller.toggleTorch);
  }

  /// Flips between the front and back camera.
  Future<void> switchCamera([
    SwitchCameraOption option = const ToggleDirection(),
  ]) async {
    if (_disposed || !isInitialized) return;
    await _guarded(() => _controller.switchCamera(option));
  }

  /// Cycles to the next available lens (normal → wide → zoom) on the current
  /// camera. Does nothing when the device only has one.
  Future<void> switchLens() => switchCamera(const ToggleLensType());

  /// The lenses this device offers, optionally restricted to one side.
  Future<Set<CameraLensType>> supportedLenses({CameraFacing? facing}) async {
    if (_disposed) return const <CameraLensType>{};
    try {
      return await _controller.getSupportedLenses(facing: facing);
    } on Object {
      // A capability probe must never fail the caller: platforms that do not
      // implement it throw UnimplementedError rather than a
      // MobileScannerException.
      return const <CameraLensType>{};
    }
  }

  /// Switches to the lens that focuses closest, which reads small, close-up
  /// barcodes best.
  ///
  /// In practice this is an **iOS 15+** feature: there it picks the camera
  /// with the shortest `minimumFocusDistance`, typically the ultra-wide lens
  /// that does macro autofocus at ~2 cm. Android always reports the normal
  /// lens, because CameraX cannot select physical sub-cameras independently —
  /// use `autoZoom: true` there instead. macOS and the web always report the
  /// normal lens too.
  ///
  /// Returns `true` if a switch happened. Does nothing and returns `false`
  /// when the device has no better lens than the one already in use.
  Future<bool> useCloseRangeLens({
    CameraFacing facing = CameraFacing.back,
  }) async {
    if (_disposed || !isInitialized) return false;
    if (!ScannerPlatformSupport.current.lensType) return false;
    try {
      final best = await _controller.getBestCloseRangeScanningLens(
        facing: facing,
      );
      if (best == null) return false;
      final supported = await _controller.getSupportedLenses(facing: facing);
      if (!supported.contains(best)) return false;
      if (_controller.value.cameraLensType == best) return false;
      await _controller.switchCamera(
        SelectCamera(facingDirection: facing, lensType: best),
      );
      return true;
    } on Object {
      return false;
    }
  }

  /// Sets the zoom, where `0.0` is the widest and `1.0` the most zoomed in.
  Future<void> setZoomScale(double zoomScale) async {
    if (_disposed || !isRunning) return;
    if (!ScannerPlatformSupport.current.zoom) return;
    await _guarded(() => _controller.setZoomScale(zoomScale.clamp(0.0, 1.0)));
  }

  /// Returns the zoom to its default.
  Future<void> resetZoomScale() async {
    if (_disposed || !isRunning) return;
    if (!ScannerPlatformSupport.current.zoom) return;
    await _guarded(_controller.resetZoomScale);
  }

  /// Focuses on a point, given in `0..1` coordinates relative to the preview.
  Future<void> setFocusPoint(Offset position) async {
    if (_disposed || !isRunning) return;
    if (!ScannerPlatformSupport.current.tapToFocus) return;
    await _guarded(() => _controller.setFocusPoint(position));
  }

  /// Runs a platform call, absorbing the "camera is no longer running"
  /// exception.
  ///
  /// Gestures and controls are inherently racy: the camera can stop between
  /// the `isRunning` check and the platform call — during a route pop, a
  /// lifecycle transition, or a camera flip — and the resulting
  /// [MobileScannerException] would otherwise surface as an unhandled async
  /// error from a fire-and-forget call site.
  Future<void> _guarded(Future<void> Function() action) async {
    try {
      await action();
    } on MobileScannerException {
      return;
    }
  }

  /// Looks for barcodes in the image file at [path].
  ///
  /// Returns `null` when nothing was found. Throws
  /// [MobileScannerBarcodeException] if the platform reported a decoding
  /// error, and [UnsupportedError] on platforms without image analysis — which
  /// is the web.
  ///
  /// The iOS Simulator also cannot analyse images, but that is indistinguishable
  /// from a device at runtime, so it surfaces as a platform error rather than
  /// an [UnsupportedError].
  Future<BarcodeCapture?> analyzeImage(
    String path, {
    List<BarcodeFormat> formats = const <BarcodeFormat>[],
  }) {
    if (!ScannerPlatformSupport.current.analyzeImage) {
      throw UnsupportedError(
        'Analyzing images is not supported on '
        '${ScannerPlatformSupport.currentPlatformName}.',
      );
    }
    return _controller.analyzeImage(path, formats: formats);
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _collected.clear();
    super.dispose();
    if (_ownsController) {
      unawaited(_controller.dispose());
    }
  }
}
