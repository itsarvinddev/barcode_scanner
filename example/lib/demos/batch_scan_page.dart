import 'package:ai_barcode_scanner/ai_barcode_scanner.dart';
import 'package:flutter/material.dart';

/// Batch mode: keep the camera open, collect distinct codes, and hand the
/// whole list back at the end.
///
/// The list is driven straight off the controller, which notifies on every
/// collected barcode.
class BatchScanPage extends StatefulWidget {
  const BatchScanPage({super.key});

  @override
  State<BatchScanPage> createState() => _BatchScanPageState();
}

class _BatchScanPageState extends State<BatchScanPage> {
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
    return AiBarcodeScanner(
      controller: _controller,
      scanMode: ScanMode.batch,
      maxScans: 10,
      enabledActionButtons: const <ScannerAction>{
        ScannerAction.torch,
        ScannerAction.cameraSwitch,
        ScannerAction.close,
      },
      galleryButtonType: GalleryButtonType.none,
      overlayConfig: const ScannerOverlayConfig(showBarcodeHighlights: true),
      onScanComplete: (barcodes) => Navigator.of(context).pop(barcodes),
      bottomSheetBuilder:
          (context, controller) => _CollectedList(controller: controller),
    );
  }
}

class _CollectedList extends StatelessWidget {
  const _CollectedList({required this.controller});

  final AiBarcodeScannerController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final collected = controller.collected;
        if (collected.isEmpty) return const SizedBox.shrink();

        return Material(
          color: Theme.of(context).colorScheme.surface,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Text(
                        '${collected.length} collected',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: controller.clearCollected,
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: collected.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder:
                          (context, index) => Chip(
                            avatar: Icon(collected[index].typeIcon, size: 16),
                            label: Text(collected[index].bestValue),
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
