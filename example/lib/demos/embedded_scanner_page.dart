import 'package:ai_barcode_scanner/ai_barcode_scanner.dart';
import 'package:flutter/material.dart';

/// The scanner as one widget among many, rather than a whole screen.
///
/// `AiBarcodeScanner.embedded` skips the Scaffold and the default chrome, so
/// the surrounding page owns the layout — here a rounded card above a live
/// result list.
class EmbeddedScannerPage extends StatefulWidget {
  const EmbeddedScannerPage({required this.onResult, super.key});

  final void Function(Barcode? barcode, {String? note}) onResult;

  @override
  State<EmbeddedScannerPage> createState() => _EmbeddedScannerPageState();
}

class _EmbeddedScannerPageState extends State<EmbeddedScannerPage> {
  final List<Barcode> _seen = <Barcode>[];
  late final AiBarcodeScannerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AiBarcodeScannerController(
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
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Embedded scanner'),
        actions: <Widget>[
          // The controller drives the chrome the page builds for itself.
          ListenableBuilder(
            listenable: _controller.state,
            builder:
                (context, _) => IconButton(
                  tooltip: _controller.isTorchOn ? 'Torch off' : 'Torch on',
                  icon: Icon(
                    _controller.isTorchOn
                        ? Icons.flashlight_on
                        : Icons.flashlight_off_outlined,
                  ),
                  onPressed:
                      _controller.hasTorch ? _controller.toggleTorch : null,
                ),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: AspectRatio(
                aspectRatio: 3 / 4,
                child: AiBarcodeScanner.embedded(
                  controller: _controller,
                  scanMode: ScanMode.continuous,
                  scanCooldown: const Duration(milliseconds: 600),
                  overlayConfig: const ScannerOverlayConfig(
                    scannerOverlayBackground: ScannerOverlayBackground.dim,
                    cornerLength: 32,
                  ),
                  scanWindowConfig: const ScanWindowConfig(
                    shape: ScanWindowShape.square,
                    padding: EdgeInsets.all(16),
                  ),
                  onDetect: (capture) {
                    final barcode = capture.firstBarcode;
                    if (barcode == null) return;
                    setState(() => _seen.insert(0, barcode));
                    widget.onResult(barcode, note: 'Scanned inline');
                  },
                ),
              ),
            ),
          ),
          Expanded(
            child:
                _seen.isEmpty
                    ? Center(
                      child: Text(
                        'Point the camera at a barcode',
                        style: theme.textTheme.bodyMedium,
                      ),
                    )
                    : ListView.builder(
                      itemCount: _seen.length,
                      itemBuilder: (context, index) {
                        final barcode = _seen[index];
                        return ListTile(
                          leading: Icon(barcode.typeIcon),
                          title: Text(barcode.bestValue),
                          subtitle: Text(barcode.format.displayName),
                          onTap:
                              () => BarcodeResultSheet.show(
                                context,
                                barcode: barcode,
                              ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}
