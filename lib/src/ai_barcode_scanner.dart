// lib/src/ai_barcode_scanner.dart
import 'dart:async' show Timer;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:universal_platform/universal_platform.dart';

import 'error_builder.dart';
import 'gallery_button.dart';
import 'overlay.dart';

/// The set of quick action controls that can be shown alongside the scanner.
enum ScannerAction { cameraSwitch, torch, gallery }

/// The main barcode scanner widget.
class AiBarcodeScanner extends StatefulWidget {
  /// Defines how the camera preview will be fitted into the layout.
  final BoxFit fit;

  /// The controller for the mobile scanner.
  final MobileScannerController? controller;

  /// A builder for a custom overlay that can be placed on top of the scanner.
  /// This will override the default custom overlay.
  final Widget Function(
    BuildContext,
    BoxConstraints,
    MobileScannerController,
    bool?,
  )? overlayBuilder;

  /// A builder for displaying an error widget when the scanner fails to start.
  /// If null, a default error widget is used.
  final Widget Function(BuildContext, MobileScannerException)? errorBuilder;

  /// A callback function that is called when an error occurs during barcode detection.
  final void Function(Object, StackTrace)? onDetectError;

  /// Whether to use the app lifecycle state to pause the camera when the app is paused.
  final bool useAppLifecycleState;

  /// A builder for a placeholder widget that is displayed while the camera is initializing.
  /// If null, a black `ColoredBox` is used.
  final Widget Function(BuildContext)? placeholderBuilder;

  /// A callback function that is called when the widget is disposed.
  final void Function()? onDispose;

  /// A builder for the `AppBar` of the scanner screen.
  final PreferredSizeWidget? Function(
    BuildContext context,
    MobileScannerController controller,
  )? appBarBuilder;

  /// A builder for a bottom sheet that is displayed below the camera preview.
  final Widget? Function(
    BuildContext context,
    MobileScannerController controller,
  )? bottomSheetBuilder;

  /// A builder for the bottom navigation bar of the scanner screen.
  final Widget? Function(
    BuildContext context,
    MobileScannerController controller,
  )? bottomNavigationBarBuilder;

  /// The rectangular area on the screen where the scanner will focus on detecting barcodes.
  /// If null, a default window will be used.
  /// **REFACTORED:** This is now the single source of truth for the scan window dimensions.
  final Rect? scanWindow;

  /// The threshold for updates to the [scanWindow].
  final double scanWindowUpdateThreshold;

  /// A function that validates a detected barcode.
  /// Returns `true` if the barcode is valid, `false` otherwise.
  final bool Function(BarcodeCapture)? validator;

  /// A callback function that is called when an image is picked from the gallery.
  /// Returns the path of the picked image.
  final void Function(String?)? onImagePick;

  /// The primary callback function that is called when a barcode is detected.
  final void Function(BarcodeCapture)? onDetect;

  /// The type of gallery button to use.
  final GalleryButtonType galleryButtonType;

  /// Whether the body of the scaffold should extend behind the app bar. Defaults to `true`.
  final bool extendBodyBehindAppBar;

  /// The alignment of the gallery button.
  final AlignmentGeometry? galleryButtonAlignment;

  /// The text to display on the gallery button.
  final String galleryButtonText;

  /// A list of additional actions to be added to the `AppBar`.
  final List<Widget>? actions;

  /// Locks the screen orientation to portrait mode. Defaults to `true`.
  final bool setPortraitOrientation;

  /// Configuration for the scanner overlay (lines, borders, colors).
  final ScannerOverlayConfig overlayConfig;

  /// Custom icon for the gallery button
  final IconData galleryIcon;

  /// Custom icon for the camera switch button
  final IconData cameraSwitchIcon;

  /// Custom icon for the flashlight when on
  final IconData flashOnIcon;

  /// Custom icon for the flashlight when off
  final IconData flashOffIcon;

  /// Controls which quick action icons (camera switch, torch, gallery) are displayed.
  final Set<ScannerAction> enabledActionButtons;

  /// Whether to return the raw image data (Uint8List) along with the BarcodeCapture.
  /// This can be useful for post-scan image processing such as color analysis or saving the frame.
  /// Defaults to `false`.
  final bool returnImage;

  /// for custom image picker function.
  final Future<void> Function(
    bool Function(BarcodeCapture)? validator,
    void Function(BarcodeCapture)? onDetect,
    MobileScannerController controller,
  )? onCustomImagePicker;

  /// for custom child any where in the body.
  /// This will override the gallery button for filled.
  /// use [Align/Positioned] to position the child.
  final Widget? child;

  const AiBarcodeScanner({
    super.key,
    this.fit = BoxFit.cover,
    this.controller,
    this.scanWindowUpdateThreshold = 0.0,
    this.overlayBuilder,
    this.errorBuilder,
    this.onDetectError,
    this.useAppLifecycleState = true,
    this.placeholderBuilder,
    this.onDispose,
    this.scanWindow,
    this.appBarBuilder,
    this.onDetect,
    this.validator,
    this.onImagePick,
    this.galleryButtonType = GalleryButtonType.filled,
    this.bottomSheetBuilder,
    this.bottomNavigationBarBuilder,
    this.extendBodyBehindAppBar = true,
    this.galleryButtonAlignment,
    this.actions,
    this.setPortraitOrientation = true,
    this.overlayConfig = const ScannerOverlayConfig(),
    this.galleryButtonText = 'Upload from gallery',
    this.galleryIcon = CupertinoIcons.photo,
    this.cameraSwitchIcon = CupertinoIcons.arrow_2_circlepath,
    this.flashOnIcon = CupertinoIcons.bolt_fill,
    this.flashOffIcon = CupertinoIcons.bolt,
    this.enabledActionButtons = const {
      ScannerAction.gallery,
      ScannerAction.cameraSwitch,
      ScannerAction.torch,
    },
    this.returnImage = false,
    this.onCustomImagePicker,
    this.child,
  });

  @override
  State<AiBarcodeScanner> createState() => _AiBarcodeScannerState();
}

class _AiBarcodeScannerState extends State<AiBarcodeScanner> {
  final ValueNotifier<bool?> _isSuccess = ValueNotifier<bool?>(null);
  late MobileScannerController _controller;
  // State variable to store the initial zoom scale upon starting a pinch gesture.
  double _baseZoomScale = 0.0;

  // A timer to reset the overlay color after a scan.
  Timer? _colorResetTimer;

  @override
  void initState() {
    super.initState();
    if (widget.setPortraitOrientation) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }
    _controller = widget.controller ??
        MobileScannerController(
          // Passes the returnImage flag to control whether frame images are returned with barcode data
          returnImage: widget.returnImage,
        );
  }

  @override
  void dispose() {
    // Cancel the timer when the widget is disposed to prevent memory leaks.
    _colorResetTimer?.cancel();

    if (widget.controller == null) {
      _controller.dispose();
    }
    // Restore preferred orientations if they were set
    if (widget.setPortraitOrientation) {
      SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    }
    widget.onDispose?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Unsupported platforms return a message.
    if (UniversalPlatform.isWindows || UniversalPlatform.isLinux) {
      return Scaffold(
        appBar: widget.appBarBuilder?.call(context, _controller),
        body: Center(
          child: SelectableText.rich(
            TextSpan(children: [
              TextSpan(
                  text:
                      'This platform(${UniversalPlatform.operatingSystem}) is not supported.\nPlease visit '),
              TextSpan(
                text:
                    'https://pub.dev/packages/mobile_scanner#platform-support',
                style: TextStyle(color: Theme.of(context).primaryColor),
              ),
              TextSpan(text: ' for more information.'),
            ]),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
      );
    }

    // This makes it responsive and correctly positioned on any screen.
    final config = widget.overlayConfig;
    final isNoRect = (config.scannerBorder == ScannerBorder.none ||
            config.scannerBorder == ScannerBorder.full) ||
        config.scannerOverlayBackground == ScannerOverlayBackground.none ||
        (config.scannerAnimation == ScannerAnimation.fullWidth ||
            config.scannerAnimation == ScannerAnimation.none);

    final screenSize = MediaQuery.sizeOf(context);
    final defaultScanWindowWidth =
        isNoRect ? screenSize.width : screenSize.width * 0.8;
    final defaultScanWindowHeight =
        isNoRect ? screenSize.height : screenSize.height * 0.36;
    final defaultScanWindow = Rect.fromCenter(
      center: screenSize.center(Offset.zero),
      width: defaultScanWindowWidth,
      height: defaultScanWindowHeight,
    );
    // NEW: Use the provided scanWindow or the default one.
    final Rect scanWindow = widget.scanWindow ?? defaultScanWindow;
    final isTorchOn = _controller.value.torchState == TorchState.on;

    /// default action icons
    /// camera switch and torch for easier access
    final actionButtons = _buildActionButtons(isTorchOn);
    final showGalleryAction =
        widget.enabledActionButtons.contains(ScannerAction.gallery);

    return Scaffold(
      appBar: widget.appBarBuilder?.call(context, _controller) ??
          AppBar(
            backgroundColor: Colors.transparent,
            actions: [
              if (widget.galleryButtonType == GalleryButtonType.icon) ...[
                if (showGalleryAction)
                  GalleryButton.icon(
                    onImagePick: widget.onImagePick,
                    onDetect: widget.onDetect,
                    validator: widget.validator,
                    controller: _controller,
                    isSuccess: _isSuccess,
                    text: widget.galleryButtonText,
                    onCustomImagePicker: widget.onCustomImagePicker,
                  ),
                ...actionButtons,
              ],
              ...?widget.actions,
            ],
          ),
      extendBodyBehindAppBar: widget.extendBodyBehindAppBar,
      bottomSheet: widget.bottomSheetBuilder?.call(context, _controller),
      bottomNavigationBar:
          widget.bottomNavigationBarBuilder?.call(context, _controller),
      body: GestureDetector(
        // UPDATED: onScaleStart and onScaleUpdate logic is now more robust.
        onScaleStart: (details) {
          _baseZoomScale = _controller.value.zoomScale;
          setState(() {});
        },
        onScaleUpdate: (details) {
          // The `details.scale` is a multiplier (e.g., 1.2 for 20% zoom in).
          // We calculate the change (`delta`) from the start of the gesture.
          final double delta = details.scale - 1.0;

          // Add the delta to the base zoom scale.
          final double newZoomScale = _baseZoomScale + delta;

          // Set the new zoom scale, ensuring it's within the valid range [0.0, 1.0].
          _controller.setZoomScale(newZoomScale.clamp(0.0, 1.0));
          setState(() {});
        },
        child: Stack(
          children: [
            MobileScanner(
              key: widget.key,
              controller: _controller,
              onDetect: _onDetect,
              fit: widget.fit,
              scanWindow: scanWindow,
              errorBuilder: widget.errorBuilder ??
                  (context, error) => ErrorBuilder(error: error),
              placeholderBuilder: widget.placeholderBuilder,
              scanWindowUpdateThreshold: widget.scanWindowUpdateThreshold,
              overlayBuilder: (context, overlay) =>
                  ValueListenableBuilder<bool?>(
                valueListenable: _isSuccess,
                builder: (context, isSuccess, child) {
                  return widget.overlayBuilder
                          ?.call(context, overlay, _controller, isSuccess) ??
                      ScannerOverlay(
                        // REFACTORED: Pass the scanWindow to the overlay.
                        scanWindow: scanWindow,
                        config: widget.overlayConfig,
                        isSuccess: isSuccess,
                      );
                },
              ),
              onDetectError: widget.onDetectError ??
                  (error, stackTrace) {
                    debugPrint('Error during barcode detection: $error');
                  },
              useAppLifecycleState: widget.useAppLifecycleState,
            ),
            widget.child ??
                (widget.galleryButtonType == GalleryButtonType.filled &&
                        (showGalleryAction || actionButtons.isNotEmpty)
                    ? Align(
                        alignment: widget.galleryButtonAlignment ??
                            Alignment.lerp(
                              Alignment.bottomCenter,
                              Alignment.center,
                              0.42,
                            )!,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (showGalleryAction)
                              GalleryButton(
                                onImagePick: widget.onImagePick,
                                onDetect: widget.onDetect,
                                validator: widget.validator,
                                controller: _controller,
                                isSuccess: _isSuccess,
                                text: widget.galleryButtonText,
                                icon: widget.galleryIcon,
                                onCustomImagePicker: widget.onCustomImagePicker,
                              ),
                            if (showGalleryAction && actionButtons.isNotEmpty)
                              const SizedBox(width: 4),
                            ...actionButtons,
                          ],
                        ),
                      )
                    : const SizedBox.shrink()),
          ],
        ),
      ),
    );
  }

  /// REFACTORED: Renamed for clarity and improved error handling.
  void _onDetect(BarcodeCapture capture) {
    // Cancel any existing timer to prevent premature color reset on rapid scans.
    _colorResetTimer?.cancel();
    try {
      HapticFeedback.lightImpact(); // Always give feedback on scan
      final validator = widget.validator;
      late final bool isValid;

      if (validator == null) {
        isValid = true;
      } else {
        isValid = validator.call(capture);
      }

      _isSuccess.value = isValid;

      if (isValid) {
        // Only call the main onDetect if the barcode is valid.
        widget.onDetect?.call(capture);
        HapticFeedback.mediumImpact();
      } else {
        // Give stronger feedback for an invalid barcode.
        HapticFeedback.heavyImpact();
      }
    } catch (e) {
      _isSuccess.value = false;
      debugPrint('Error during barcode validation: $e');
    }
    // Start a new timer to reset the color back to normal (null).
    _colorResetTimer = Timer(const Duration(milliseconds: 1000), () {
      if (mounted) {
        _isSuccess.value = null;
      }
    });
  }

  List<Widget> _buildActionButtons(bool isTorchOn) {
    final actions = widget.enabledActionButtons;
    final icons = <Widget>[];

    if (actions.contains(ScannerAction.cameraSwitch)) {
      icons.add(
        IconButton.filled(
          style: IconButton.styleFrom(
            backgroundColor: CupertinoColors.systemGrey6,
            foregroundColor: CupertinoColors.darkBackgroundGray,
          ),
          icon: Icon(widget.cameraSwitchIcon),
          onPressed: () async {
            await _controller.switchCamera();
            setState(() {});
          },
        ),
      );
    }

    if (actions.contains(ScannerAction.torch)) {
      icons.add(
        IconButton.filled(
          style: IconButton.styleFrom(
            backgroundColor: isTorchOn
                ? CupertinoColors.activeOrange
                : CupertinoColors.systemGrey6,
            foregroundColor: CupertinoColors.darkBackgroundGray,
          ),
          icon: Icon(isTorchOn ? widget.flashOnIcon : widget.flashOffIcon),
          onPressed: () async {
            await _controller.toggleTorch();
            setState(() {});
          },
        ),
      );
    }

    return icons;
  }
}
