import 'package:ai_barcode_scanner/ai_barcode_scanner.dart';
import 'package:flutter/material.dart';

import 'demos/batch_scan_page.dart';
import 'demos/embedded_scanner_page.dart';
import 'demos/full_control_page.dart';
import 'demos/themed_scanner_page.dart';

void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Barcode Scanner',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF0A84FF),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xFF0A84FF),
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Barcode? _lastBarcode;
  String? _note;

  void _showResult(Barcode? barcode, {String? note}) {
    if (!mounted) return;
    setState(() {
      _lastBarcode = barcode;
      _note = note;
    });
  }

  @override
  Widget build(BuildContext context) {
    final support = ScannerPlatformSupport.current;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Barcode Scanner'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Platform support',
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showSupportSheet(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: <Widget>[
          _ResultCard(barcode: _lastBarcode, note: _note),
          const SizedBox(height: 8),
          if (!support.isSupported)
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: ListTile(
                leading: const Icon(Icons.warning_amber_outlined),
                title: Text(
                  'Scanning is not available on '
                  '${ScannerPlatformSupport.currentPlatformName}',
                ),
                subtitle: const Text(
                  'The demos still open, and show the built-in '
                  'unsupported-platform screen.',
                ),
              ),
            ),
          const _SectionHeader('One-liners'),
          _DemoTile(
            icon: Icons.bolt_outlined,
            title: 'showAiBarcodeScanner',
            subtitle: 'Open, scan one code, come back with the result.',
            onTap: () async {
              final capture = await showAiBarcodeScanner(context);
              _showResult(capture?.firstBarcode);
            },
          ),
          _DemoTile(
            icon: Icons.qr_code_2_outlined,
            title: 'QR codes only',
            subtitle:
                'Restricting formats is the cheapest accuracy win there is.',
            onTap: () async {
              final capture = await showAiBarcodeScanner(
                context,
                formats: BarcodeFormatSets.qrOnly,
              );
              _showResult(capture?.firstBarcode);
            },
          ),
          _DemoTile(
            icon: Icons.shopping_bag_outlined,
            title: 'Retail barcodes',
            subtitle: 'EAN, UPC and Code 128, with a wide reticle.',
            onTap: () async {
              final capture = await showAiBarcodeScanner(
                context,
                formats: BarcodeFormatSets.retail,
                scanWindowConfig: const ScanWindowConfig(
                  shape: ScanWindowShape.wide,
                ),
              );
              _showResult(capture?.firstBarcode);
            },
          ),
          _DemoTile(
            icon: Icons.link_outlined,
            title: 'Validated scan',
            subtitle:
                'Only accepts links to pub.dev; anything else flashes red.',
            onTap: () async {
              final capture = await showAiBarcodeScanner(
                context,
                validator: ScanValidators.url(
                  allowedHosts: const <String>{'pub.dev'},
                ),
                labels: const ScannerLabels(scanHint: 'Scan a pub.dev link'),
              );
              _showResult(capture?.firstBarcode);
            },
          ),
          const _SectionHeader('Scan modes'),
          _DemoTile(
            icon: Icons.playlist_add_check_outlined,
            title: 'Batch collection',
            subtitle: 'Collect up to 10 distinct codes in one session.',
            onTap: () async {
              final barcodes = await Navigator.of(context).push<List<Barcode>>(
                MaterialPageRoute<List<Barcode>>(
                  builder: (_) => const BatchScanPage(),
                ),
              );
              if (barcodes == null || barcodes.isEmpty) return;
              _showResult(
                barcodes.first,
                note: '${barcodes.length} codes collected',
              );
            },
          ),
          _DemoTile(
            icon: Icons.all_inclusive,
            title: 'Continuous scanning',
            subtitle: 'Stays open and reports every code, once per second.',
            onTap:
                () => _openScanner(
                  AiBarcodeScanner(
                    scanMode: ScanMode.continuous,
                    scanCooldown: const Duration(seconds: 1),
                    enabledActionButtons: const <ScannerAction>{
                      ScannerAction.torch,
                      ScannerAction.cameraSwitch,
                      ScannerAction.close,
                    },
                    galleryButtonType: GalleryButtonType.none,
                    onDetect: (capture) => _showResult(capture.firstBarcode),
                  ),
                ),
          ),
          const _SectionHeader('UI and UX'),
          _DemoTile(
            icon: Icons.palette_outlined,
            title: 'Themed scanner',
            subtitle: 'Brand colours, custom copy and a full-border reticle.',
            onTap: () => _openScanner(ThemedScannerPage(onResult: _showResult)),
          ),
          _DemoTile(
            icon: Icons.crop_free,
            title: 'Embedded scanner',
            subtitle: 'A scanner inside your own page, with live results.',
            onTap:
                () => _openScanner(EmbeddedScannerPage(onResult: _showResult)),
          ),
          _DemoTile(
            icon: Icons.tune,
            title: 'Every control',
            subtitle: 'Torch, flip, lens, zoom, gallery, highlights and more.',
            onTap: () => _openScanner(FullControlPage(onResult: _showResult)),
          ),
          _DemoTile(
            icon: Icons.accessibility_new_outlined,
            title: 'Minimal and quiet',
            subtitle:
                'No animation, no blur, no haptics — cheap to render, calm to use.',
            onTap:
                () => _openScanner(
                  AiBarcodeScanner(
                    overlayConfig: const ScannerOverlayConfig.minimal(),
                    feedback: const ScannerFeedbackConfig.silent(),
                    showScanHint: false,
                    galleryButtonType: GalleryButtonType.none,
                    enabledActionButtons: const <ScannerAction>{
                      ScannerAction.close,
                    },
                    onDetect: (capture) {
                      _showResult(capture.firstBarcode);
                      Navigator.of(context).pop();
                    },
                  ),
                ),
          ),
        ],
      ),
    );
  }

  Future<void> _openScanner(Widget scanner) {
    return Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => scanner));
  }

  void _showSupportSheet(BuildContext context) {
    final support = ScannerPlatformSupport.current;
    showModalBottomSheet<void>(
      context: context,
      builder:
          (context) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(20),
              children: <Widget>[
                Text(
                  'Capabilities on ${ScannerPlatformSupport.currentPlatformName}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                for (final entry
                    in <String, bool>{
                      'Camera scanning': support.isSupported,
                      'Scan from gallery': support.analyzeImage,
                      'Scan window': support.scanWindow,
                      'Torch': support.torch,
                      'Zoom': support.zoom,
                      'Tap to focus': support.tapToFocus,
                      'Lens selection': support.lensType,
                      'Auto zoom': support.autoZoom,
                      'Invert image': support.invertImage,
                      'Frame bytes': support.returnImage,
                      'Barcode geometry': support.barcodeCorners,
                      'Web reader choice': support.webBarcodeReader,
                    }.entries)
                  ListTile(
                    dense: true,
                    leading: Icon(
                      entry.value
                          ? Icons.check_circle_outline
                          : Icons.remove_circle_outline,
                      color: entry.value ? Colors.green : Colors.grey,
                    ),
                    title: Text(entry.key),
                  ),
              ],
            ),
          ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          letterSpacing: 1.2,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class _DemoTile extends StatelessWidget {
  const _DemoTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.barcode, this.note});

  final Barcode? barcode;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final code = barcode;

    if (code == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: <Widget>[
              const Icon(Icons.qr_code_scanner, size: 32),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Pick a demo below to scan something.',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(code.typeIcon, size: 20),
                const SizedBox(width: 8),
                Text(code.typeLabel, style: theme.textTheme.titleSmall),
                const Spacer(),
                Text(
                  code.format.displayName,
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ),
            const SizedBox(height: 10),
            SelectableText(
              code.bestValue.isEmpty ? '(empty)' : code.bestValue,
              style: theme.textTheme.bodyLarge,
            ),
            // The structured payload — Wi-Fi credentials, a contact card, a
            // calendar event — comes straight from ML Kit; `fields` just makes
            // it presentable.
            for (final field in code.fields)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '${field.label}: '
                  '${field.obscure ? '••••••' : field.value}',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            if (note != null) ...<Widget>[
              const SizedBox(height: 10),
              Text(note!, style: theme.textTheme.labelMedium),
            ],
          ],
        ),
      ),
    );
  }
}
