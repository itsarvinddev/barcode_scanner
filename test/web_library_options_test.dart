// The web detection-library options on the one-line scanners, and the
// widget-free way to point the still-image decoder at a self-hosted script.
//
// These run on the VM, where the options only have to reach the scanner and
// the decoder setting has to be a harmless no-op. What they do in a browser is
// covered by test/web/gallery_web_test.dart.
import 'dart:async';

import 'package:ai_barcode_scanner/ai_barcode_scanner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_mobile_scanner_platform.dart';

const _staticOverlay = ScannerOverlayConfig(
  scannerAnimation: ScannerAnimation.none,
  scannerOverlayBackground: ScannerOverlayBackground.dim,
);

const _mirror = 'zxing-wasm/index.js';

Future<BuildContext> _pumpHost(WidgetTester tester) async {
  late BuildContext hostContext;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) {
          hostContext = context;
          return const SizedBox();
        },
      ),
    ),
  );
  return hostContext;
}

void main() {
  setUp(() => MobileScannerPlatform.instance = FakeMobileScannerPlatform());

  tearDown(MobileScannerController.resetPlatformSessionOwner);

  group('showAiBarcodeScanner', () {
    testWidgets('forwards webBarcodeReader and webBarcodeLibraryScriptUrl', (
      tester,
    ) async {
      final context = await _pumpHost(tester);

      unawaited(
        showAiBarcodeScanner(
          context,
          overlayConfig: _staticOverlay,
          webBarcodeReader: WebBarcodeReader.zxingWasm,
          webBarcodeLibraryScriptUrl: _mirror,
        ),
      );
      await tester.pumpAndSettle();

      final scanner = tester.widget<AiBarcodeScanner>(
        find.byType(AiBarcodeScanner),
      );
      expect(scanner.webBarcodeReader, WebBarcodeReader.zxingWasm);
      expect(scanner.webBarcodeLibraryScriptUrl, _mirror);
    });

    testWidgets('leaves both unset by default', (tester) async {
      final context = await _pumpHost(tester);

      unawaited(showAiBarcodeScanner(context, overlayConfig: _staticOverlay));
      await tester.pumpAndSettle();

      final scanner = tester.widget<AiBarcodeScanner>(
        find.byType(AiBarcodeScanner),
      );
      expect(scanner.webBarcodeReader, isNull);
      expect(scanner.webBarcodeLibraryScriptUrl, isNull);
    });
  });

  group('showAiBarcodeScannerBatch', () {
    testWidgets('forwards webBarcodeReader and webBarcodeLibraryScriptUrl', (
      tester,
    ) async {
      final context = await _pumpHost(tester);

      unawaited(
        showAiBarcodeScannerBatch(
          context,
          overlayConfig: _staticOverlay,
          webBarcodeReader: WebBarcodeReader.barcodeDetector,
          webBarcodeLibraryScriptUrl: _mirror,
        ),
      );
      await tester.pumpAndSettle();

      final scanner = tester.widget<AiBarcodeScanner>(
        find.byType(AiBarcodeScanner),
      );
      expect(scanner.scanMode, ScanMode.batch);
      expect(scanner.webBarcodeReader, WebBarcodeReader.barcodeDetector);
      expect(scanner.webBarcodeLibraryScriptUrl, _mirror);
    });

    testWidgets('leaves both unset by default', (tester) async {
      final context = await _pumpHost(tester);

      unawaited(
        showAiBarcodeScannerBatch(context, overlayConfig: _staticOverlay),
      );
      await tester.pumpAndSettle();

      final scanner = tester.widget<AiBarcodeScanner>(
        find.byType(AiBarcodeScanner),
      );
      expect(scanner.webBarcodeReader, isNull);
      expect(scanner.webBarcodeLibraryScriptUrl, isNull);
    });
  });

  group('AiBarcodeScannerController.setWebImageDecoderScriptUrl', () {
    test('is a no-op outside the web', () async {
      // Safe to call unconditionally, e.g. from a shared main().
      AiBarcodeScannerController.setWebImageDecoderScriptUrl(_mirror);
      AiBarcodeScannerController.setWebImageDecoderScriptUrl('other.js');

      // Native image analysis is unaffected: the path still goes straight to
      // the platform.
      final platform = FakeMobileScannerPlatform();
      MobileScannerPlatform.instance = platform;
      final controller = AiBarcodeScannerController(autoStart: false);
      addTearDown(controller.dispose);

      await controller.analyzeImage('/tmp/code.png');

      expect(platform.analyzeImagePaths, <String>['/tmp/code.png']);
    });
  });
}
