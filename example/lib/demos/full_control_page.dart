import 'package:ai_barcode_scanner/ai_barcode_scanner.dart';
import 'package:flutter/material.dart';

/// Every control the scanner offers, on one screen.
///
/// Controls that the current platform or device cannot support hide
/// themselves, so this is also a quick way to see the capability matrix in
/// action: a macOS build shows no torch, a single-camera device no flip.
class FullControlPage extends StatefulWidget {
  const FullControlPage({required this.onResult, super.key});

  final void Function(Barcode? barcode, {String? note}) onResult;

  @override
  State<FullControlPage> createState() => _FullControlPageState();
}

class _FullControlPageState extends State<FullControlPage> {
  late final AiBarcodeScannerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AiBarcodeScannerController(
      // Android can zoom towards a distant code by itself; on iOS the
      // close-range lens is the better answer, offered by the lens control.
      autoZoom: true,
      detectionSpeed: DetectionSpeed.noDuplicates,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AiBarcodeScanner(
      controller: _controller,
      scanMode: ScanMode.continuous,
      enabledActionButtons: const <ScannerAction>{
        ScannerAction.gallery,
        ScannerAction.torch,
        ScannerAction.cameraSwitch,
        ScannerAction.lens,
        ScannerAction.zoom,
        ScannerAction.close,
      },
      galleryButtonType: GalleryButtonType.icon,
      overlayConfig: const ScannerOverlayConfig(
        showBarcodeHighlights: true,
        scannerAnimation: ScannerAnimation.fullWidth,
      ),
      // The reticle is guidance; leave detection unrestricted so a wide
      // barcode held across the frame still reads.
      restrictDetectionToScanWindow: false,
      onDetect: (capture) => widget.onResult(capture.firstBarcode),
      onGalleryScanError: (error, _) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not read that image: $error')),
        );
      },
      onOpenSettings: () {
        // Wire this to permission_handler's openAppSettings() in a real app.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Open your app settings to allow the camera'),
          ),
        );
      },
      bottomSheetBuilder:
          (context, controller) => Material(
            color: Theme.of(context).colorScheme.surface,
            child: SafeArea(
              top: false,
              child: ListenableBuilder(
                listenable: controller.state,
                builder: (context, _) {
                  final state = controller.value;
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: Wrap(
                      spacing: 16,
                      runSpacing: 4,
                      alignment: WrapAlignment.center,
                      children: <Widget>[
                        Text('Lens: ${state.cameraLensType.name}'),
                        Text('Facing: ${state.cameraDirection.name}'),
                        Text('Zoom: ${(state.zoomScale * 100).round()}%'),
                        Text('Torch: ${state.torchState.name}'),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
    );
  }
}
