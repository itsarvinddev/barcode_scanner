import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:ai_barcode_scanner/ai_barcode_scanner.dart';
import 'package:flutter/widgets.dart';

/// A photographed camera frame and the barcodes that were decoded from it.
///
/// Produced by `compose/scenes.mjs`: the JPEG is the frame, and the JSON
/// sidecar holds each barcode's corner points as zxing-wasm decoded them from
/// that very image, in camera-frame coordinates.
class CameraScene {
  CameraScene._(this.image, this.frameSize, this._codes);

  /// The decoded frame, painted by [FakeCameraPlatform.buildCameraView].
  final ui.Image image;

  /// The size `mobile_scanner` reports for the camera output.
  final Size frameSize;

  final List<_SceneCode> _codes;

  /// Loads `assets/scene_<name>.jpg` and its JSON sidecar.
  ///
  /// Must run inside `tester.runAsync`, because image decoding is real I/O.
  static Future<CameraScene> load(String name) async {
    final bytes = await File('assets/scene_$name.jpg').readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final json =
        jsonDecode(await File('assets/scene_$name.json').readAsString())
            as Map<String, dynamic>;
    final codes = <_SceneCode>[
      for (final entry in json['barcodes'] as List<dynamic>)
        _SceneCode.fromJson(entry as Map<String, dynamic>),
    ];
    return CameraScene._(
      frame.image,
      Size(
        (json['width'] as num).toDouble(),
        (json['height'] as num).toDouble(),
      ),
      codes,
    );
  }

  /// A [Barcode] for the code in the scene with the given zxing [format]
  /// name, carrying its real corners.
  ///
  /// [format], [type] and the structured payload are what ML Kit or Apple
  /// Vision would report for that symbol.
  Barcode barcode(
    String zxingFormat, {
    required BarcodeFormat format,
    required BarcodeType type,
    UrlBookmark? url,
  }) {
    final code = _codes.firstWhere((c) => c.format == zxingFormat);
    var left = double.infinity, top = double.infinity;
    var right = -double.infinity, bottom = -double.infinity;
    for (final c in code.corners) {
      if (c.dx < left) left = c.dx;
      if (c.dx > right) right = c.dx;
      if (c.dy < top) top = c.dy;
      if (c.dy > bottom) bottom = c.dy;
    }
    return Barcode(
      format: format,
      type: type,
      rawValue: code.text,
      displayValue: code.text,
      url: url,
      corners: code.corners,
      size: Size(right - left, bottom - top),
    );
  }

  /// A capture of [barcodes] against this frame.
  BarcodeCapture capture(List<Barcode> barcodes) =>
      BarcodeCapture(barcodes: barcodes, size: frameSize);
}

class _SceneCode {
  _SceneCode.fromJson(Map<String, dynamic> json)
    : format = json['format'] as String,
      text = json['text'] as String,
      corners = <Offset>[
        for (final point in json['corners'] as List<dynamic>)
          Offset(
            ((point as List<dynamic>)[0] as num).toDouble(),
            (point[1] as num).toDouble(),
          ),
      ];

  final String format;
  final String text;
  final List<Offset> corners;
}

/// A `mobile_scanner` platform whose "camera" is a still [CameraScene].
///
/// Adapted from the package's own `test/fake_mobile_scanner_platform.dart`:
/// everything the scanner asks of the platform succeeds, detections are pushed
/// in with [emit], and [startError] makes the camera fail to start.
class FakeCameraPlatform extends MobileScannerPlatform {
  FakeCameraPlatform({this.scene, this.startError});

  /// The frame to show. `null` shows black, as a camera does while starting.
  final CameraScene? scene;

  /// When set, starting the camera fails with this.
  final MobileScannerException? startError;

  final StreamController<BarcodeCapture> _barcodes =
      StreamController<BarcodeCapture>.broadcast();
  final StreamController<TorchState> _torch =
      StreamController<TorchState>.broadcast();
  final StreamController<double> _zoom = StreamController<double>.broadcast();

  bool _torchOn = false;

  /// Pushes a detection through to the scanner, as the camera would.
  void emit(BarcodeCapture capture) => _barcodes.add(capture);

  @override
  Stream<BarcodeCapture?> get barcodesStream => _barcodes.stream;

  @override
  Stream<TorchState> get torchStateStream => _torch.stream;

  @override
  Stream<double> get zoomScaleStateStream => _zoom.stream;

  @override
  Widget buildCameraView() {
    final image = scene?.image;
    if (image == null) return const ColoredBox(color: Color(0xFF000000));
    return RawImage(
      image: image,
      fit: BoxFit.fill,
      filterQuality: FilterQuality.high,
    );
  }

  @override
  Future<MobileScannerViewAttributes> start(StartOptions startOptions) async {
    final error = startError;
    if (error != null) throw error;
    _torchOn = startOptions.torchEnabled;
    // A camera reports its zoom once running; this lands after the
    // controller has applied its own start-up state.
    Timer.run(() => _zoom.add(startOptions.initialZoom ?? 0));
    return MobileScannerViewAttributes(
      cameraDirection: startOptions.cameraDirection,
      currentTorchMode: _torchOn ? TorchState.on : TorchState.off,
      size: scene?.frameSize ?? const Size(1080, 1920),
      numberOfCameras: 2,
    );
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<void> toggleTorch() async {
    _torchOn = !_torchOn;
    _torch.add(_torchOn ? TorchState.on : TorchState.off);
  }

  @override
  Future<void> setZoomScale(double zoomScale) async => _zoom.add(zoomScale);

  @override
  Future<void> resetZoomScale() async => _zoom.add(0);

  @override
  Future<void> setFocusPoint(Offset position) async {}

  @override
  Future<void> updateScanWindow(Rect? window) async {}

  @override
  Future<Set<CameraLensType>> getSupportedLenses({
    CameraFacing? facing,
  }) async => const <CameraLensType>{CameraLensType.normal};

  @override
  Future<CameraLensType?> getBestCloseRangeScanningLens({
    CameraFacing facing = CameraFacing.back,
  }) async => CameraLensType.normal;

  @override
  Future<BarcodeCapture?> analyzeImage(
    String path, {
    List<BarcodeFormat> formats = const <BarcodeFormat>[],
  }) async => null;
}
