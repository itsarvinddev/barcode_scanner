import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// A fake platform implementation so widget tests can mount a scanner without
/// a camera.
///
/// `MobileScannerPlatform.instance` verifies a token that every subclass of
/// [MobileScannerPlatform] carries, so a plain subclass is assignable.
class FakeMobileScannerPlatform extends MobileScannerPlatform {
  FakeMobileScannerPlatform({
    this.numberOfCameras = 2,
    this.torchMode = TorchState.off,
    this.supportedLenses = const <CameraLensType>{CameraLensType.normal},
    this.startError,
    this.analyzeImageResult,
    this.analyzeImageError,
  });

  /// How many cameras the fake device reports.
  final int numberOfCameras;

  /// The torch state reported at start-up.
  final TorchState torchMode;

  /// The lenses `getSupportedLenses` reports.
  final Set<CameraLensType> supportedLenses;

  /// When set, `start` fails with this exception instead of succeeding.
  final MobileScannerException? startError;

  /// What `analyzeImage` returns.
  final BarcodeCapture? analyzeImageResult;

  /// When set, `analyzeImage` throws this instead of returning.
  final Object? analyzeImageError;

  final StreamController<BarcodeCapture> _barcodes =
      StreamController<BarcodeCapture>.broadcast();
  final StreamController<TorchState> _torch =
      StreamController<TorchState>.broadcast();
  final StreamController<double> _zoom = StreamController<double>.broadcast();

  /// Records of what the scanner asked the platform to do.
  final List<StartOptions> startCalls = <StartOptions>[];
  final List<Rect?> scanWindowUpdates = <Rect?>[];
  final List<double> zoomScaleCalls = <double>[];
  final List<Offset> focusPointCalls = <Offset>[];

  /// Every path `analyzeImage` was given, in order.
  final List<String> analyzeImagePaths = <String>[];

  /// The formats passed alongside each entry of [analyzeImagePaths].
  final List<List<BarcodeFormat>> analyzeImageFormats = <List<BarcodeFormat>>[];

  /// The contents of the file behind each analysed path, or `null` where no
  /// file existed.
  ///
  /// Read synchronously inside `analyzeImage`, because a temporary file the
  /// scanner wrote for bytes is deleted as soon as the call completes.
  final List<List<int>?> analyzedFileBytes = <List<int>?>[];

  /// When set, `analyzeImage` awaits this, after recording the call and
  /// before returning, so a test can hold an analysis open or fail one.
  Future<void> Function(String path)? analyzeImageGate;

  /// The most `analyzeImage` calls that were ever in progress at once.
  int maxConcurrentAnalyzeImageCalls = 0;
  int _analyzeImageCallsInProgress = 0;
  int toggleTorchCount = 0;
  int stopCount = 0;
  int disposeCount = 0;

  bool _torchOn = false;

  /// Pushes a detection through to the scanner.
  void emitBarcode(BarcodeCapture capture) => _barcodes.add(capture);

  /// Pushes a torch state change through to the scanner.
  void emitTorchState(TorchState state) => _torch.add(state);

  /// Pushes a zoom change through to the scanner.
  void emitZoomScale(double value) => _zoom.add(value);

  @override
  Stream<BarcodeCapture?> get barcodesStream => _barcodes.stream;

  @override
  Stream<TorchState> get torchStateStream => _torch.stream;

  @override
  Stream<double> get zoomScaleStateStream => _zoom.stream;

  @override
  Widget buildCameraView() => const ColoredBox(color: Color(0xFF123456));

  @override
  Future<MobileScannerViewAttributes> start(StartOptions startOptions) async {
    startCalls.add(startOptions);
    final error = startError;
    if (error != null) throw error;
    return MobileScannerViewAttributes(
      cameraDirection: startOptions.cameraDirection,
      currentTorchMode: torchMode,
      size: const Size(320, 480),
      numberOfCameras: numberOfCameras,
    );
  }

  @override
  Future<void> stop() async => stopCount++;

  @override
  Future<void> pause() async {}

  @override
  Future<void> dispose() async => disposeCount++;

  @override
  Future<void> toggleTorch() async {
    toggleTorchCount++;
    _torchOn = !_torchOn;
    _torch.add(_torchOn ? TorchState.on : TorchState.off);
  }

  @override
  Future<void> setZoomScale(double zoomScale) async {
    zoomScaleCalls.add(zoomScale);
    _zoom.add(zoomScale);
  }

  @override
  Future<void> resetZoomScale() async {
    zoomScaleCalls.add(0);
    _zoom.add(0);
  }

  @override
  Future<void> setFocusPoint(Offset position) async =>
      focusPointCalls.add(position);

  @override
  Future<void> updateScanWindow(Rect? window) async =>
      scanWindowUpdates.add(window);

  @override
  Future<Set<CameraLensType>> getSupportedLenses({
    CameraFacing? facing,
  }) async => supportedLenses;

  @override
  Future<CameraLensType?> getBestCloseRangeScanningLens({
    CameraFacing facing = CameraFacing.back,
  }) async => supportedLenses.isEmpty ? null : supportedLenses.first;

  @override
  Future<BarcodeCapture?> analyzeImage(
    String path, {
    List<BarcodeFormat> formats = const <BarcodeFormat>[],
  }) async {
    analyzeImagePaths.add(path);
    analyzeImageFormats.add(formats);
    final file = File(path);
    analyzedFileBytes.add(file.existsSync() ? file.readAsBytesSync() : null);

    _analyzeImageCallsInProgress++;
    if (_analyzeImageCallsInProgress > maxConcurrentAnalyzeImageCalls) {
      maxConcurrentAnalyzeImageCalls = _analyzeImageCallsInProgress;
    }
    try {
      await analyzeImageGate?.call(path);
      final error = analyzeImageError;
      if (error != null) throw error;
      return analyzeImageResult;
    } finally {
      _analyzeImageCallsInProgress--;
    }
  }
}
