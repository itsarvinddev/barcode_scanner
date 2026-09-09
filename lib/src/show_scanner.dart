import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'ai_barcode_scanner.dart';
import 'config/gallery_button_type.dart';
import 'config/overlay_config.dart';
import 'config/scan_mode.dart';
import 'config/scan_window_config.dart';
import 'config/scanner_action.dart';
import 'config/scanner_feedback.dart';
import 'config/scanner_labels.dart';
import 'config/scanner_theme.dart';

/// Pushes a full-screen scanner and returns the first accepted detection.
///
/// This is the one-liner for the most common case — open a scanner, get a
/// barcode back, close it — without writing a route and a callback:
///
/// ```dart
/// final capture = await showAiBarcodeScanner(context);
/// if (capture != null) print(capture.barcodes.first.rawValue);
/// ```
///
/// Returns `null` when the user backs out without scanning anything. The
/// scanner closes itself on the first accepted detection; pass a [validator]
/// to control what counts as acceptable.
///
/// For anything more involved — batch collection, staying open after a scan,
/// custom chrome — use [AiBarcodeScanner] directly.
Future<BarcodeCapture?> showAiBarcodeScanner(
  BuildContext context, {
  bool Function(BarcodeCapture capture)? validator,
  List<BarcodeFormat> formats = const <BarcodeFormat>[],
  DetectionSpeed detectionSpeed = DetectionSpeed.noDuplicates,
  CameraFacing facing = CameraFacing.back,
  bool torchEnabled = false,
  ScannerTheme? theme,
  ScannerLabels labels = const ScannerLabels(),
  ScannerOverlayConfig overlayConfig = const ScannerOverlayConfig(),
  ScanWindowConfig scanWindowConfig = const ScanWindowConfig(),
  ScannerFeedbackConfig feedback = const ScannerFeedbackConfig(),
  Set<ScannerAction> enabledActionButtons = const <ScannerAction>{
    ScannerAction.gallery,
    ScannerAction.cameraSwitch,
    ScannerAction.torch,
    ScannerAction.close,
  },
  GalleryButtonType galleryButtonType = GalleryButtonType.filled,
  bool showScanHint = true,
  List<DeviceOrientation>? preferredOrientations,
  VoidCallback? onOpenSettings,
  RouteSettings? routeSettings,
  bool fullscreenDialog = true,
  bool useRootNavigator = false,
}) {
  return Navigator.of(
    context,
    rootNavigator: useRootNavigator,
  ).push<BarcodeCapture>(
    MaterialPageRoute<BarcodeCapture>(
      settings: routeSettings,
      fullscreenDialog: fullscreenDialog,
      builder:
          (routeContext) => AiBarcodeScanner(
            validator: validator,
            formats: formats,
            detectionSpeed: detectionSpeed,
            facing: facing,
            torchEnabled: torchEnabled,
            theme: theme,
            labels: labels,
            overlayConfig: overlayConfig,
            scanWindowConfig: scanWindowConfig,
            feedback: feedback,
            enabledActionButtons: enabledActionButtons,
            galleryButtonType: galleryButtonType,
            showScanHint: showScanHint,
            preferredOrientations: preferredOrientations,
            onOpenSettings: onOpenSettings,
            onDetect: (capture) {
              final navigator = Navigator.of(routeContext);
              if (navigator.canPop()) navigator.pop(capture);
            },
          ),
    ),
  );
}

/// Pushes a full-screen scanner in batch mode and returns every distinct
/// barcode the user collected.
///
/// Returns an empty list when the user backs out without collecting anything.
///
/// ```dart
/// final items = await showAiBarcodeScannerBatch(context, maxScans: 20);
/// ```
Future<List<Barcode>> showAiBarcodeScannerBatch(
  BuildContext context, {
  int? maxScans,
  bool Function(BarcodeCapture capture)? validator,
  List<BarcodeFormat> formats = const <BarcodeFormat>[],
  CameraFacing facing = CameraFacing.back,
  ScannerTheme? theme,
  ScannerLabels labels = const ScannerLabels(),
  ScannerOverlayConfig overlayConfig = const ScannerOverlayConfig(),
  ScanWindowConfig scanWindowConfig = const ScanWindowConfig(),
  ScannerFeedbackConfig feedback = const ScannerFeedbackConfig(),
  Set<ScannerAction> enabledActionButtons = const <ScannerAction>{
    ScannerAction.cameraSwitch,
    ScannerAction.torch,
    ScannerAction.close,
  },
  bool showScanHint = true,
  List<DeviceOrientation>? preferredOrientations,
  VoidCallback? onOpenSettings,
  RouteSettings? routeSettings,
  bool fullscreenDialog = true,
  bool useRootNavigator = false,
}) async {
  final result = await Navigator.of(
    context,
    rootNavigator: useRootNavigator,
  ).push<List<Barcode>>(
    MaterialPageRoute<List<Barcode>>(
      settings: routeSettings,
      fullscreenDialog: fullscreenDialog,
      builder:
          (routeContext) => AiBarcodeScanner(
            scanMode: ScanMode.batch,
            maxScans: maxScans,
            validator: validator,
            formats: formats,
            facing: facing,
            theme: theme,
            labels: labels,
            overlayConfig: overlayConfig,
            scanWindowConfig: scanWindowConfig,
            feedback: feedback,
            enabledActionButtons: enabledActionButtons,
            galleryButtonType: GalleryButtonType.none,
            showScanHint: showScanHint,
            preferredOrientations: preferredOrientations,
            onOpenSettings: onOpenSettings,
            onScanComplete: (barcodes) {
              final navigator = Navigator.of(routeContext);
              if (navigator.canPop()) navigator.pop(barcodes);
            },
          ),
    ),
  );
  return result ?? const <Barcode>[];
}
