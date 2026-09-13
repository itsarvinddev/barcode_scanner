// Gallery scanning on the web: #199.
//
// `mobile_scanner` has no still-image support in the browser, so the scanner
// routes picked images to its built-in decoder. These run in a real browser
// against the real zxing-wasm build, like image_decoder_web_test.dart:
//
//   flutter test --platform chrome test/web
//   flutter test --platform chrome --wasm test/web
//
// `@TestOn('browser')` makes a plain `flutter test` skip this file.
@TestOn('browser')
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:ai_barcode_scanner/ai_barcode_scanner.dart';
import 'package:ai_barcode_scanner/src/utils/image_decoder/image_decoder.dart';
import 'package:ai_barcode_scanner/src/utils/image_decoder/image_decoder_web.dart'
    show debugResetImageDecoder, zxingWasmScriptUrl;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart' show XFile;
// The real web implementation, so the fallback is proven against the exact
// error `mobile_scanner` throws rather than a fake's imitation of it.
// ignore: implementation_imports
import 'package:mobile_scanner/src/web/mobile_scanner_web.dart';
import 'package:web/web.dart' as web;

import 'fixtures.dart';

/// Enough of a web platform to mount the scanner without a camera.
///
/// `analyzeImage` throws exactly what `MobileScannerWeb` 7.4 does, so the
/// widget exercises the same fallback as a real page.
class _FakeWebPlatform extends MobileScannerPlatform {
  final _barcodes = StreamController<BarcodeCapture>.broadcast();
  final _torch = StreamController<TorchState>.broadcast();
  final _zoom = StreamController<double>.broadcast();

  @override
  Stream<BarcodeCapture?> get barcodesStream => _barcodes.stream;

  @override
  Stream<TorchState> get torchStateStream => _torch.stream;

  @override
  Stream<double> get zoomScaleStateStream => _zoom.stream;

  @override
  Widget buildCameraView() => const ColoredBox(color: Color(0xFF123456));

  @override
  Future<MobileScannerViewAttributes> start(StartOptions startOptions) async {
    return MobileScannerViewAttributes(
      cameraDirection: startOptions.cameraDirection,
      currentTorchMode: TorchState.unavailable,
      size: const Size(320, 480),
      numberOfCameras: 1,
    );
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<void> updateScanWindow(Rect? window) async {}

  @override
  Future<BarcodeCapture?> analyzeImage(
    String path, {
    List<BarcodeFormat> formats = const <BarcodeFormat>[],
  }) {
    throw UnsupportedError('analyzeImage() is not supported on the web.');
  }
}

/// A platform whose `analyzeImage` works, standing in for a future
/// `mobile_scanner` release that implements it on the web.
class _ImplementedWebPlatform extends _FakeWebPlatform {
  final List<String> paths = <String>[];

  @override
  Future<BarcodeCapture?> analyzeImage(
    String path, {
    List<BarcodeFormat> formats = const <BarcodeFormat>[],
  }) async {
    paths.add(path);
    return const BarcodeCapture(
      barcodes: <Barcode>[Barcode(rawValue: 'upstream')],
    );
  }
}

const _staticOverlay = ScannerOverlayConfig(
  scannerAnimation: ScannerAnimation.none,
);

/// A `blob:` URL for [bytes]. Revoke it when done.
String _objectUrl(Uint8List bytes, String type) => web.URL.createObjectURL(
  web.Blob(<web.BlobPart>[bytes.toJS].toJS, web.BlobPropertyBag(type: type)),
);

/// Taps the gallery button and lets real time pass — the decoder fetches and
/// runs WebAssembly — until [done], pumping between slices so continuations
/// queued in the test's fake zone run.
Future<void> _scanFromGallery(
  WidgetTester tester, {
  required bool Function() done,
}) async {
  await tester.tap(find.byIcon(Icons.photo_library_outlined));
  await tester.pump();
  for (var i = 0; i < 1200 && !done(); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
  }
  expect(done(), isTrue, reason: 'the gallery pick did not finish');
  await tester.pumpAndSettle();
}

void main() {
  // The first read fetches the WebAssembly binary; give slow CI runners room.
  const timeout = Timeout(Duration(minutes: 2));

  setUpAll(() async {
    // Load zxing-wasm once, outside any fake clock, so the widget tests below
    // are not the ones paying for the download.
    await decodeBarcodesFromImageBytes(qrPng);
  });

  tearDown(MobileScannerController.resetPlatformSessionOwner);

  test('gallery scanning is reported as supported', () {
    expect(ScannerPlatformSupport.current.analyzeImage, isTrue);
  });

  group('AiBarcodeScannerController', () {
    late AiBarcodeScannerController controller;

    setUp(() {
      MobileScannerPlatform.instance = MobileScannerWeb();
      controller = AiBarcodeScannerController(autoStart: false);
    });

    tearDown(() => controller.dispose());

    test('analyzeScannerImage decodes bytes', () async {
      final capture = await controller.analyzeScannerImage(
        ScannerImage.bytes(qrPng),
      );

      expect(capture!.barcodes.single.rawValue, qrText);
      expect(capture.barcodes.single.format, BarcodeFormat.qrCode);
    }, timeout: timeout);

    test('analyzeScannerImage honours formats', () async {
      final capture = await controller.analyzeScannerImage(
        ScannerImage.bytes(qrPng),
        formats: const <BarcodeFormat>[BarcodeFormat.ean13],
      );

      expect(capture!.barcodes, isEmpty);
    }, timeout: timeout);

    test('analyzeScannerImage reads an XFile from its own data', () async {
      final file = XFile.fromData(ean13Png, mimeType: 'image/png');

      final capture = await controller.analyzeScannerImage(
        ScannerImage.xFile(file),
      );

      expect(capture!.barcodes.single.rawValue, ean13Text);
    }, timeout: timeout);

    test(
      'analyzeScannerImage reports an unreadable XFile as a barcode error',
      () async {
        // What image_picker hands out on the web: an XFile over a blob: URL.
        // A revoked URL fails the read the way a CSP without blob: does.
        final url = _objectUrl(qrPng, 'image/png');
        web.URL.revokeObjectURL(url);

        await expectLater(
          controller.analyzeScannerImage(ScannerImage.xFile(XFile(url))),
          throwsA(
            isA<MobileScannerBarcodeException>().having(
              (error) => error.message,
              'message',
              contains('blob: in connect-src'),
            ),
          ),
        );
      },
      timeout: timeout,
    );

    test('analyzeScannerImage fetches a path, as a URL', () async {
      final url = _objectUrl(qrWebp, 'image/webp');
      addTearDown(() => web.URL.revokeObjectURL(url));

      final capture = await controller.analyzeScannerImage(
        ScannerImage.path(url),
      );

      expect(capture!.barcodes.single.rawValue, qrText);
    }, timeout: timeout);

    test(
      'analyzeImage falls back to the built-in decoder for a blob URL',
      () async {
        final url = _objectUrl(qrJpeg, 'image/jpeg');
        addTearDown(() => web.URL.revokeObjectURL(url));

        // The real web implementation still refuses...
        expect(() => controller.raw.analyzeImage(url), throwsUnsupportedError);
        // ...so the facade reads the image itself.
        final capture = await controller.analyzeImage(url);

        expect(capture!.barcodes.single.rawValue, qrText);
      },
      timeout: timeout,
    );

    test('analyzeImage reports an unreadable URL as a barcode error', () async {
      final url = _objectUrl(qrPng, 'image/png');
      web.URL.revokeObjectURL(url);

      await expectLater(
        controller.analyzeImage(url),
        throwsA(
          isA<MobileScannerBarcodeException>().having(
            (error) => error.message,
            'message',
            // A CSP block fails the fetch the same way, so the message names
            // the source connect-src has to allow.
            allOf(contains(url), contains('blob: in connect-src')),
          ),
        ),
      );
    }, timeout: timeout);

    test(
      'analyzeImage defers to mobile_scanner once it supports the web',
      () async {
        final platform = _ImplementedWebPlatform();
        MobileScannerPlatform.instance = platform;

        final capture = await controller.analyzeImage('blob:whatever');

        expect(platform.paths, <String>['blob:whatever']);
        expect(capture!.barcodes.single.rawValue, 'upstream');
      },
    );
  });

  group('AiBarcodeScanner', () {
    setUp(() => MobileScannerPlatform.instance = _FakeWebPlatform());

    testWidgets('shows the gallery button by default', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AiBarcodeScanner(overlayConfig: _staticOverlay),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.photo_library_outlined), findsOneWidget);
    });

    testWidgets('scans picked bytes with the built-in decoder', (tester) async {
      BarcodeCapture? detected;
      Object? error;

      await tester.pumpWidget(
        MaterialApp(
          home: AiBarcodeScanner(
            overlayConfig: _staticOverlay,
            feedback: const ScannerFeedbackConfig.silent(),
            galleryImagePicker: (_) async => ScannerImage.bytes(qrPng),
            onDetect: (capture) => detected = capture,
            onGalleryScanError: (e, _) => error = e,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _scanFromGallery(
        tester,
        done: () => detected != null || error != null,
      );

      expect(error, isNull);
      expect(detected!.barcodes.single.rawValue, qrText);
    }, timeout: timeout);

    testWidgets(
      'loads the decoder from webBarcodeLibraryScriptUrl, not jsDelivr',
      (tester) async {
        // A self-hosted copy of the reader, served from the page's own origin.
        final mirror = await tester.runAsync(() async {
          final response =
              await web.window.fetch(zxingWasmScriptUrl.toJS).toDart;
          final script = (await response.text().toDart).toDart;
          return web.URL.createObjectURL(
            web.Blob(
              <web.BlobPart>[script.toJS].toJS,
              web.BlobPropertyBag(type: 'text/javascript'),
            ),
          );
        });
        addTearDown(() => web.URL.revokeObjectURL(mirror!));

        // A page that has not loaded zxing-wasm yet.
        debugResetImageDecoder();
        addTearDown(debugResetImageDecoder);
        const scriptSelector = 'script#ai-barcode-scanner-zxing-wasm';
        web.document.querySelector(scriptSelector)?.remove();
        globalContext.setProperty('ZXingWASM'.toJS, null);

        BarcodeCapture? detected;
        Object? error;
        await tester.pumpWidget(
          MaterialApp(
            home: AiBarcodeScanner(
              overlayConfig: _staticOverlay,
              feedback: const ScannerFeedbackConfig.silent(),
              webBarcodeLibraryScriptUrl: mirror,
              galleryImagePicker: (_) async => ScannerImage.bytes(qrPng),
              onDetect: (capture) => detected = capture,
              onGalleryScanError: (e, _) => error = e,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await _scanFromGallery(
          tester,
          done: () => detected != null || error != null,
        );

        expect(error, isNull);
        expect(detected!.barcodes.single.rawValue, qrText);
        expect(
          web.document.querySelector(scriptSelector)?.getAttribute('src'),
          mirror,
        );
      },
      timeout: timeout,
    );

    testWidgets(
      'hides the gallery button when the mirror is ZXing-js, unless an '
      'analyzer is given',
      (tester) async {
        const zxingJsMirror = 'https://example.com/zxing-library.min.js';

        await tester.pumpWidget(
          const MaterialApp(
            home: AiBarcodeScanner(
              overlayConfig: _staticOverlay,
              webBarcodeReader: WebBarcodeReader.zxingJs,
              webBarcodeLibraryScriptUrl: zxingJsMirror,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.photo_library_outlined), findsNothing);

        await tester.pumpWidget(
          MaterialApp(
            home: AiBarcodeScanner(
              key: UniqueKey(),
              overlayConfig: _staticOverlay,
              webBarcodeReader: WebBarcodeReader.zxingJs,
              webBarcodeLibraryScriptUrl: zxingJsMirror,
              galleryImageAnalyzer: (image, formats) async => null,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.photo_library_outlined), findsOneWidget);
      },
    );

    testWidgets('hands galleryImageAnalyzer the picked bytes', (tester) async {
      ScannerImage? analyzed;
      Uint8List? analyzedBytes;
      BarcodeCapture? detected;

      await tester.pumpWidget(
        MaterialApp(
          home: AiBarcodeScanner(
            overlayConfig: _staticOverlay,
            feedback: const ScannerFeedbackConfig.silent(),
            galleryImagePicker: (_) async => ScannerImage.bytes(ean13Png),
            galleryImageAnalyzer: (image, formats) async {
              analyzed = image;
              analyzedBytes = await image.readAsBytes();
              return const BarcodeCapture(
                barcodes: <Barcode>[Barcode(rawValue: 'custom')],
              );
            },
            onDetect: (capture) => detected = capture,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _scanFromGallery(tester, done: () => detected != null);

      expect(analyzed!.bytes, same(ean13Png));
      expect(analyzedBytes, same(ean13Png));
      expect(detected!.barcodes.single.rawValue, 'custom');
    });
  });
}
