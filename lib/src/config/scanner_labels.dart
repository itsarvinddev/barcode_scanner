import 'package:flutter/widgets.dart';

/// Every user-visible string the scanner can render.
///
/// The package ships English defaults and deliberately does not depend on
/// `intl` or on generated ARB localisations, so it stays usable in apps that
/// have no localisation setup at all. To translate the scanner, build a
/// [ScannerLabels] from your own localisation delegate and pass it to
/// `AiBarcodeScanner.labels`:
///
/// ```dart
/// AiBarcodeScanner(
///   labels: ScannerLabels(
///     galleryButton: AppLocalizations.of(context)!.pickFromGallery,
///     scanHint: AppLocalizations.of(context)!.pointAtBarcode,
///   ),
/// )
/// ```
///
/// Anything you leave out keeps its English default, so partial translations
/// are fine.
@immutable
class ScannerLabels {
  /// Creates a set of scanner labels. Every field has an English default.
  const ScannerLabels({
    this.galleryButton = 'Upload from gallery',
    this.galleryTooltip = 'Scan a barcode from an image',
    this.torchOnTooltip = 'Turn flashlight off',
    this.torchOffTooltip = 'Turn flashlight on',
    this.torchAutoTooltip = 'Flashlight is automatic',
    this.switchCameraTooltip = 'Switch camera',
    this.switchLensTooltip = 'Switch lens',
    this.closeTooltip = 'Close scanner',
    this.zoomTooltip = 'Zoom',
    this.resetZoomTooltip = 'Reset zoom',
    this.scanHint = 'Point the camera at a barcode',
    this.scanHintIdle = 'Hold steady and move a little closer',
    this.scanHintBatch = 'Keep scanning — tap Done when finished',
    this.doneButton = 'Done',
    this.retryButton = 'Try again',
    this.openSettingsButton = 'Open settings',
    this.cameraErrorTitle = 'Could not start the camera',
    this.cameraErrorMessage = 'Something went wrong while starting the camera.',
    this.permissionDeniedTitle = 'Camera access needed',
    this.permissionDeniedMessage =
        'Allow camera access in Settings so barcodes can be scanned.',
    this.cameraUnsupportedTitle = 'Scanning is not available',
    this.cameraUnsupportedMessage =
        'This device does not have a camera that can be used for scanning.',
    this.startingCamera = 'Starting camera…',
    this.noBarcodeFoundInImage = 'No barcode found in that image',
    this.galleryUnsupported =
        'Scanning images from the gallery is not supported on this platform.',
    this.invalidBarcode = 'That barcode is not accepted here',
    this.copyAction = 'Copy',
    this.copiedConfirmation = 'Copied to clipboard',
    this.openAction = 'Open',
    this.shareAction = 'Share',
    this.scannedCountLabel = _defaultScannedCount,
    this.unsupportedPlatformTitle = 'Not supported on this platform',
    this.unsupportedPlatformMessage = _defaultUnsupportedPlatform,
    this.barcodeTypeLabels = const <String, String>{},
    this.barcodeFieldLabels = const <String, String>{},
  });

  /// Label of the filled "pick an image" button.
  final String galleryButton;

  /// Tooltip and semantics label of the gallery icon button.
  final String galleryTooltip;

  /// Tooltip shown while the torch is on.
  final String torchOnTooltip;

  /// Tooltip shown while the torch is off.
  final String torchOffTooltip;

  /// Tooltip shown while the torch is in automatic mode.
  final String torchAutoTooltip;

  /// Tooltip of the front/back camera button.
  final String switchCameraTooltip;

  /// Tooltip of the lens (wide / normal / zoom) button.
  final String switchLensTooltip;

  /// Tooltip of the close button.
  final String closeTooltip;

  /// Semantics label of the zoom slider.
  final String zoomTooltip;

  /// Tooltip shown on the double-tap-to-reset-zoom affordance.
  final String resetZoomTooltip;

  /// Guidance shown under the reticle when scanning starts.
  final String scanHint;

  /// Guidance shown when nothing has been detected for a while.
  final String scanHintIdle;

  /// Guidance shown while collecting multiple barcodes.
  final String scanHintBatch;

  /// Label of the button that finishes a batch scan.
  final String doneButton;

  /// Label of the button that retries starting the camera.
  final String retryButton;

  /// Label of the button that sends the user to the app settings.
  final String openSettingsButton;

  /// Title of the generic camera failure screen.
  final String cameraErrorTitle;

  /// Body of the generic camera failure screen.
  final String cameraErrorMessage;

  /// Title of the "camera permission denied" screen.
  final String permissionDeniedTitle;

  /// Body of the "camera permission denied" screen.
  final String permissionDeniedMessage;

  /// Title shown when the device has no usable camera.
  final String cameraUnsupportedTitle;

  /// Body shown when the device has no usable camera.
  final String cameraUnsupportedMessage;

  /// Shown over the placeholder while the camera is initialising.
  final String startingCamera;

  /// Shown when a picked image contained no readable barcode.
  final String noBarcodeFoundInImage;

  /// Shown when image analysis is not available on this platform.
  final String galleryUnsupported;

  /// Shown when a scanned barcode fails the caller's validator.
  final String invalidBarcode;

  /// Label of the "copy value" action on a result.
  final String copyAction;

  /// Confirmation shown after copying a result.
  final String copiedConfirmation;

  /// Label of the "open" action on a result.
  final String openAction;

  /// Label of the "share" action on a result.
  final String shareAction;

  /// Builds the "N scanned" badge label for batch mode.
  final String Function(int count) scannedCountLabel;

  /// Title of the unsupported-platform screen (Windows / Linux).
  final String unsupportedPlatformTitle;

  /// Builds the body of the unsupported-platform screen for a platform name.
  final String Function(String platformName) unsupportedPlatformMessage;

  /// Overrides for the barcode kind names produced by `AiBarcodeX.typeLabel`,
  /// keyed by [BarcodeType.name] — for example `{'wifi': 'Réseau Wi-Fi'}`.
  final Map<String, String> barcodeTypeLabels;

  /// Overrides for the structured field labels produced by `AiBarcodeX.fields`,
  /// keyed by `BarcodeField.key` — for example `{'wifi.ssid': 'Réseau'}`.
  final Map<String, String> barcodeFieldLabels;

  static String _defaultScannedCount(int count) =>
      count == 1 ? '1 scanned' : '$count scanned';

  static String _defaultUnsupportedPlatform(String platformName) =>
      'Barcode scanning is not available on $platformName. '
      'See pub.dev/packages/mobile_scanner for the platform support matrix.';

  /// The translated label for a `BarcodeField.key`, falling back to
  /// [fallback] when no override was supplied.
  String fieldLabel(String key, String fallback) =>
      barcodeFieldLabels[key] ?? fallback;

  /// The translated label for a `BarcodeType.name`, falling back to
  /// [fallback] when no override was supplied.
  String typeLabel(String typeName, String fallback) =>
      barcodeTypeLabels[typeName] ?? fallback;

  /// Returns a copy of these labels with the given fields replaced.
  ScannerLabels copyWith({
    String? galleryButton,
    String? galleryTooltip,
    String? torchOnTooltip,
    String? torchOffTooltip,
    String? torchAutoTooltip,
    String? switchCameraTooltip,
    String? switchLensTooltip,
    String? closeTooltip,
    String? zoomTooltip,
    String? resetZoomTooltip,
    String? scanHint,
    String? scanHintIdle,
    String? scanHintBatch,
    String? doneButton,
    String? retryButton,
    String? openSettingsButton,
    String? cameraErrorTitle,
    String? cameraErrorMessage,
    String? permissionDeniedTitle,
    String? permissionDeniedMessage,
    String? cameraUnsupportedTitle,
    String? cameraUnsupportedMessage,
    String? startingCamera,
    String? noBarcodeFoundInImage,
    String? galleryUnsupported,
    String? invalidBarcode,
    String? copyAction,
    String? copiedConfirmation,
    String? openAction,
    String? shareAction,
    String Function(int count)? scannedCountLabel,
    String? unsupportedPlatformTitle,
    String Function(String platformName)? unsupportedPlatformMessage,
    Map<String, String>? barcodeTypeLabels,
    Map<String, String>? barcodeFieldLabels,
  }) {
    return ScannerLabels(
      galleryButton: galleryButton ?? this.galleryButton,
      galleryTooltip: galleryTooltip ?? this.galleryTooltip,
      torchOnTooltip: torchOnTooltip ?? this.torchOnTooltip,
      torchOffTooltip: torchOffTooltip ?? this.torchOffTooltip,
      torchAutoTooltip: torchAutoTooltip ?? this.torchAutoTooltip,
      switchCameraTooltip: switchCameraTooltip ?? this.switchCameraTooltip,
      switchLensTooltip: switchLensTooltip ?? this.switchLensTooltip,
      closeTooltip: closeTooltip ?? this.closeTooltip,
      zoomTooltip: zoomTooltip ?? this.zoomTooltip,
      resetZoomTooltip: resetZoomTooltip ?? this.resetZoomTooltip,
      scanHint: scanHint ?? this.scanHint,
      scanHintIdle: scanHintIdle ?? this.scanHintIdle,
      scanHintBatch: scanHintBatch ?? this.scanHintBatch,
      doneButton: doneButton ?? this.doneButton,
      retryButton: retryButton ?? this.retryButton,
      openSettingsButton: openSettingsButton ?? this.openSettingsButton,
      cameraErrorTitle: cameraErrorTitle ?? this.cameraErrorTitle,
      cameraErrorMessage: cameraErrorMessage ?? this.cameraErrorMessage,
      permissionDeniedTitle:
          permissionDeniedTitle ?? this.permissionDeniedTitle,
      permissionDeniedMessage:
          permissionDeniedMessage ?? this.permissionDeniedMessage,
      cameraUnsupportedTitle:
          cameraUnsupportedTitle ?? this.cameraUnsupportedTitle,
      cameraUnsupportedMessage:
          cameraUnsupportedMessage ?? this.cameraUnsupportedMessage,
      startingCamera: startingCamera ?? this.startingCamera,
      noBarcodeFoundInImage:
          noBarcodeFoundInImage ?? this.noBarcodeFoundInImage,
      galleryUnsupported: galleryUnsupported ?? this.galleryUnsupported,
      invalidBarcode: invalidBarcode ?? this.invalidBarcode,
      copyAction: copyAction ?? this.copyAction,
      copiedConfirmation: copiedConfirmation ?? this.copiedConfirmation,
      openAction: openAction ?? this.openAction,
      shareAction: shareAction ?? this.shareAction,
      scannedCountLabel: scannedCountLabel ?? this.scannedCountLabel,
      unsupportedPlatformTitle:
          unsupportedPlatformTitle ?? this.unsupportedPlatformTitle,
      unsupportedPlatformMessage:
          unsupportedPlatformMessage ?? this.unsupportedPlatformMessage,
      barcodeTypeLabels: barcodeTypeLabels ?? this.barcodeTypeLabels,
      barcodeFieldLabels: barcodeFieldLabels ?? this.barcodeFieldLabels,
    );
  }
}
