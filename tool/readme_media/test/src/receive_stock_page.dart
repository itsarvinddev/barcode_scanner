import 'package:ai_barcode_scanner/ai_barcode_scanner.dart';
import 'package:flutter/material.dart';

/// A goods-in screen from an inventory app, with the scanner embedded in it.
///
/// Everything around the preview is ordinary app code; the preview itself is
/// `AiBarcodeScanner.embedded`, filling the form as codes are read.
class ReceiveStockPage extends StatefulWidget {
  /// Creates the page.
  const ReceiveStockPage({super.key});

  @override
  State<ReceiveStockPage> createState() => _ReceiveStockPageState();
}

class _ReceiveStockPageState extends State<ReceiveStockPage> {
  final TextEditingController _barcode = TextEditingController();
  bool _matched = false;
  int _quantity = 12;

  @override
  void dispose() {
    _barcode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {},
        ),
        title: const Text('Receive stock'),
        actions: <Widget>[
          IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'PO-10482 · Aurora Audio',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      Text('Carton 3 of 8', style: theme.textTheme.titleLarge),
                    ],
                  ),
                ),
                Chip(
                  avatar: Icon(
                    Icons.inventory_2_outlined,
                    color: scheme.primary,
                  ),
                  label: const Text('36 units'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: AiBarcodeScanner.embedded(
                  formats: const <BarcodeFormat>[
                    BarcodeFormat.ean13,
                    BarcodeFormat.code128,
                  ],
                  scanMode: ScanMode.continuous,
                  overlayConfig: const ScannerOverlayConfig(
                    scannerOverlayBackground: ScannerOverlayBackground.dim,
                    cornerLength: 32,
                  ),
                  scanWindowConfig: const ScanWindowConfig(
                    padding: EdgeInsets.all(16),
                  ),
                  onDetect: (capture) {
                    final barcode = capture.firstBarcode;
                    if (barcode == null) return;
                    setState(() {
                      _barcode.text = barcode.bestValue;
                      _matched = true;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _barcode,
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'Barcode',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.qr_code_scanner),
                suffixIcon:
                    _matched
                        ? const Icon(
                          Icons.check_circle,
                          color: Color(0xFF1E8E3E),
                        )
                        : null,
              ),
            ),
            const SizedBox(height: 12),
            Card.filled(
              margin: EdgeInsets.zero,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: scheme.primaryContainer,
                  child: Icon(
                    Icons.headphones_outlined,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                title: const Text('Studio Headphones AH-40'),
                subtitle: const Text('Graphite · SKU AUR-AH40-GR'),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Text('Quantity', style: theme.textTheme.titleMedium),
                const Spacer(),
                IconButton.filledTonal(
                  icon: const Icon(Icons.remove),
                  onPressed: () => setState(() => _quantity--),
                ),
                SizedBox(
                  width: 44,
                  child: Text(
                    '$_quantity',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                IconButton.filledTonal(
                  icon: const Icon(Icons.add),
                  onPressed: () => setState(() => _quantity++),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              icon: const Icon(Icons.add_task),
              label: const Text('Add to receipt'),
              onPressed: _matched ? () {} : null,
            ),
          ],
        ),
      ),
    );
  }
}
