// Gallery scanning from something other than a file path: #199.
//
// The platform decoders on Android, iOS and macOS only read files, so an image
// picked as bytes goes through a temporary file. These tests run on the VM
// against a fake `mobile_scanner` platform that records what it was asked to
// analyse — including the contents of the file, read before the scanner gets
// the chance to delete it. The web side is covered by
// test/web/gallery_web_test.dart.
@TestOn('!browser')
library;

import 'dart:async';
import 'dart:io';

import 'package:ai_barcode_scanner/ai_barcode_scanner.dart';
import 'package:ai_barcode_scanner/src/utils/image_file_io.dart'
    show imageFileExtension;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart' show XFile;

import 'fake_mobile_scanner_platform.dart';

const _staticOverlay = ScannerOverlayConfig(
  scannerAnimation: ScannerAnimation.none,
  scannerOverlayBackground: ScannerOverlayBackground.dim,
);

const _hit = BarcodeCapture(
  barcodes: <Barcode>[Barcode(rawValue: 'from-image')],
);

/// The start of a PNG: enough for the signature to be recognised. The fake
/// platform never decodes it.
final Uint8List _png = Uint8List.fromList(<int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 1, 2, 3, 4, //
]);

const _imagePickerChannel = MethodChannel('plugins.flutter.io/image_picker');

Future<void> _pumpScanner(WidgetTester tester, Widget scanner) async {
  await tester.pumpWidget(MaterialApp(home: scanner));
  await tester.pumpAndSettle();
}

/// Taps the gallery button and waits until [done] reports the pick has been
/// handled.
///
/// The temporary-file path does real `dart:io` work, which never completes
/// inside the test's fake clock on its own. Real time is let through in short
/// slices, with a pump after each so the continuations queued in the fake zone
/// run. `pumpAndSettle` cannot be used before the pick finishes: the busy
/// spinner animates for as long as it lasts.
Future<void> _scanFromGallery(
  WidgetTester tester, {
  required bool Function() done,
}) async {
  await tester.tap(find.byIcon(Icons.photo_library_outlined));
  await tester.pump();
  for (var i = 0; i < 400 && !done(); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await tester.pump();
  }
  expect(done(), isTrue, reason: 'the gallery pick did not finish');
  await tester.pumpAndSettle();
}

/// Records feedback events; a gallery scan always ends with a detect or reject
/// event, which is what [finished] looks for.
class _Feedback {
  final List<ScannerFeedbackEvent> events = <ScannerFeedbackEvent>[];

  ScannerFeedbackConfig get config =>
      ScannerFeedbackConfig.silent(onFeedback: events.add);

  bool finished() =>
      events.contains(ScannerFeedbackEvent.detect) ||
      events.contains(ScannerFeedbackEvent.reject);
}

void main() {
  late FakeMobileScannerPlatform platform;
  late _Feedback feedback;

  setUp(() {
    platform = FakeMobileScannerPlatform(analyzeImageResult: _hit);
    MobileScannerPlatform.instance = platform;
    feedback = _Feedback();
  });

  tearDown(MobileScannerController.resetPlatformSessionOwner);

  /// A real image file on disk, removed after the test.
  File realFile(String name) {
    final directory = Directory.systemTemp.createTempSync('gallery_test_');
    addTearDown(() => directory.deleteSync(recursive: true));
    return File('${directory.path}${Platform.pathSeparator}$name')
      ..writeAsBytesSync(_png);
  }

  group('galleryImagePicker', () {
    testWidgets('bytes are analysed through a temporary file that is deleted', (
      tester,
    ) async {
      BarcodeCapture? detected;
      final picked = <ScannerImage?>[];

      await _pumpScanner(
        tester,
        AiBarcodeScanner(
          overlayConfig: _staticOverlay,
          feedback: feedback.config,
          galleryImagePicker: (_) async => ScannerImage.bytes(_png),
          onGalleryImagePick: picked.add,
          onDetect: (capture) => detected = capture,
        ),
      );
      await _scanFromGallery(tester, done: feedback.finished);

      expect(picked, hasLength(1));
      expect(picked.single?.bytes, same(_png));

      final path = platform.analyzeImagePaths.single;
      expect(path, endsWith('.png'), reason: 'extension sniffed from bytes');
      expect(platform.analyzedFileBytes.single, _png);
      expect(File(path).existsSync(), isFalse);
      expect(File(path).parent.existsSync(), isFalse);

      expect(detected, same(_hit));
      expect(feedback.events, contains(ScannerFeedbackEvent.detect));
    });

    testWidgets('a path is handed to the platform untouched', (tester) async {
      // Not even checked for existence: the platform reports a missing file
      // itself, exactly as it did before 8.1.0.
      await _pumpScanner(
        tester,
        AiBarcodeScanner(
          overlayConfig: _staticOverlay,
          feedback: feedback.config,
          galleryImagePicker:
              (_) async => const ScannerImage.path('/no/such/image.jpg'),
        ),
      );
      await _scanFromGallery(tester, done: feedback.finished);

      expect(platform.analyzeImagePaths, <String>['/no/such/image.jpg']);
      expect(platform.analyzedFileBytes, <List<int>?>[null]);
    });

    testWidgets('an XFile backed by a real file is analysed in place', (
      tester,
    ) async {
      final file = realFile('code.jpg');

      await _pumpScanner(
        tester,
        AiBarcodeScanner(
          overlayConfig: _staticOverlay,
          feedback: feedback.config,
          galleryImagePicker: (_) async => ScannerImage.xFile(XFile(file.path)),
        ),
      );
      await _scanFromGallery(tester, done: feedback.finished);

      expect(platform.analyzeImagePaths, <String>[file.path]);
      expect(file.existsSync(), isTrue, reason: 'never delete the caller file');
    });

    testWidgets('an XFile whose file is gone is handed to the platform as a '
        'path', (tester) async {
      // The platform reports the missing file itself, exactly as it does for
      // a ScannerImage.path, rather than the scanner failing to read it first.
      final missing =
          '${Directory.systemTemp.path}${Platform.pathSeparator}'
          'ai_barcode_scanner_test_missing.jpg';

      await _pumpScanner(
        tester,
        AiBarcodeScanner(
          overlayConfig: _staticOverlay,
          feedback: feedback.config,
          galleryImagePicker: (_) async => ScannerImage.xFile(XFile(missing)),
        ),
      );
      await _scanFromGallery(tester, done: feedback.finished);

      expect(platform.analyzeImagePaths, <String>[missing]);
      expect(platform.analyzedFileBytes, <List<int>?>[null]);
    });

    testWidgets('an XFile.fromData without a path falls back to its bytes', (
      tester,
    ) async {
      await _pumpScanner(
        tester,
        AiBarcodeScanner(
          overlayConfig: _staticOverlay,
          feedback: feedback.config,
          galleryImagePicker:
              (_) async => ScannerImage.xFile(XFile.fromData(_png)),
        ),
      );
      await _scanFromGallery(tester, done: feedback.finished);

      final path = platform.analyzeImagePaths.single;
      expect(platform.analyzedFileBytes.single, _png);
      expect(File(path).existsSync(), isFalse);
    });

    testWidgets('an XFile.fromData with a nominal path uses its bytes', (
      tester,
    ) async {
      await _pumpScanner(
        tester,
        AiBarcodeScanner(
          overlayConfig: _staticOverlay,
          feedback: feedback.config,
          galleryImagePicker:
              (_) async => ScannerImage.xFile(
                XFile.fromData(_png, path: '/nominal/only.png'),
              ),
        ),
      );
      await _scanFromGallery(tester, done: feedback.finished);

      expect(platform.analyzeImagePaths.single, isNot('/nominal/only.png'));
      expect(platform.analyzedFileBytes.single, _png);
    });

    testWidgets('cancelling reports null and analyses nothing', (tester) async {
      final picked = <ScannerImage?>[];

      await _pumpScanner(
        tester,
        AiBarcodeScanner(
          overlayConfig: _staticOverlay,
          feedback: feedback.config,
          galleryImagePicker: (_) async => null,
          onGalleryImagePick: picked.add,
        ),
      );
      await _scanFromGallery(tester, done: () => picked.isNotEmpty);

      expect(picked, <ScannerImage?>[null]);
      expect(platform.analyzeImagePaths, isEmpty);
      expect(feedback.events, isNot(contains(ScannerFeedbackEvent.reject)));
    });

    testWidgets('a picked image still goes through the validator', (
      tester,
    ) async {
      var detected = 0;
      BarcodeCapture? validated;

      await _pumpScanner(
        tester,
        AiBarcodeScanner(
          overlayConfig: _staticOverlay,
          feedback: feedback.config,
          galleryImagePicker: (_) async => ScannerImage.bytes(_png),
          validator: (capture) {
            validated = capture;
            return false;
          },
          onDetect: (_) => detected++,
        ),
      );
      await _scanFromGallery(tester, done: feedback.finished);

      expect(validated, same(_hit));
      expect(detected, 0);
      expect(feedback.events, contains(ScannerFeedbackEvent.reject));
    });

    testWidgets('a platform error still deletes the temporary file', (
      tester,
    ) async {
      platform = FakeMobileScannerPlatform(
        analyzeImageError: const MobileScannerBarcodeException('bad image'),
      );
      MobileScannerPlatform.instance = platform;
      Object? reported;

      await _pumpScanner(
        tester,
        AiBarcodeScanner(
          overlayConfig: _staticOverlay,
          feedback: feedback.config,
          galleryImagePicker: (_) async => ScannerImage.bytes(_png),
          onGalleryScanError: (error, _) => reported = error,
        ),
      );
      await _scanFromGallery(tester, done: feedback.finished);

      expect(reported, isA<MobileScannerBarcodeException>());
      expect(File(platform.analyzeImagePaths.single).existsSync(), isFalse);
    });

    testWidgets('works from the embedded scanner too', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AiBarcodeScanner.embedded(
              overlayConfig: _staticOverlay,
              feedback: feedback.config,
              galleryButtonType: GalleryButtonType.filled,
              enabledActionButtons: const <ScannerAction>{
                ScannerAction.gallery,
              },
              galleryImagePicker: (_) async => ScannerImage.bytes(_png),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _scanFromGallery(tester, done: feedback.finished);

      expect(platform.analyzedFileBytes.single, _png);
    });
  });

  group('the default image_picker call', () {
    testWidgets('analyses the picked file in place, as before', (tester) async {
      final file = realFile('picked.png');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        _imagePickerChannel,
        (call) async => call.method == 'pickImage' ? file.path : null,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          _imagePickerChannel,
          null,
        ),
      );
      final picked = <ScannerImage?>[];
      final paths = <String?>[];

      await _pumpScanner(
        tester,
        AiBarcodeScanner(
          overlayConfig: _staticOverlay,
          feedback: feedback.config,
          onGalleryImagePick: picked.add,
          // ignore: deprecated_member_use_from_same_package
          onImagePick: paths.add,
        ),
      );
      await _scanFromGallery(tester, done: feedback.finished);

      expect(picked.single?.path, file.path);
      expect(picked.single?.name, 'picked.png');
      expect(paths, <String?>[file.path]);
      expect(platform.analyzeImagePaths, <String>[file.path]);
    });
  });

  group('deprecated imagePicker and onImagePick', () {
    testWidgets('behave exactly as in 8.0.1', (tester) async {
      final paths = <String?>[];
      final picked = <ScannerImage?>[];
      BarcodeCapture? detected;

      await _pumpScanner(
        tester,
        AiBarcodeScanner(
          overlayConfig: _staticOverlay,
          feedback: feedback.config,
          // ignore: deprecated_member_use_from_same_package
          imagePicker: (_) async => '/does/not/exist.png',
          // ignore: deprecated_member_use_from_same_package
          onImagePick: paths.add,
          onGalleryImagePick: picked.add,
          onDetect: (capture) => detected = capture,
        ),
      );
      await _scanFromGallery(tester, done: feedback.finished);

      expect(paths, <String?>['/does/not/exist.png']);
      expect(platform.analyzeImagePaths, <String>['/does/not/exist.png']);
      expect(detected, same(_hit));
      // The new callback sees the same pick, wrapped.
      expect(picked.single?.path, '/does/not/exist.png');
      expect(picked.single?.bytes, isNull);
    });

    testWidgets('a cancelled legacy pick reports null to both callbacks', (
      tester,
    ) async {
      final paths = <String?>['sentinel'];
      final picked = <ScannerImage?>[];

      await _pumpScanner(
        tester,
        AiBarcodeScanner(
          overlayConfig: _staticOverlay,
          feedback: feedback.config,
          // ignore: deprecated_member_use_from_same_package
          imagePicker: (_) async => null,
          // ignore: deprecated_member_use_from_same_package
          onImagePick: paths.add,
          onGalleryImagePick: picked.add,
        ),
      );
      await _scanFromGallery(tester, done: () => picked.isNotEmpty);

      expect(paths, <String?>['sentinel', null]);
      expect(picked, <ScannerImage?>[null]);
      expect(platform.analyzeImagePaths, isEmpty);
    });

    testWidgets('onImagePick is not called for an image that has no path', (
      tester,
    ) async {
      final paths = <String?>[];

      await _pumpScanner(
        tester,
        AiBarcodeScanner(
          overlayConfig: _staticOverlay,
          feedback: feedback.config,
          galleryImagePicker: (_) async => ScannerImage.bytes(_png),
          // ignore: deprecated_member_use_from_same_package
          onImagePick: paths.add,
        ),
      );
      await _scanFromGallery(tester, done: feedback.finished);

      expect(paths, isEmpty, reason: 'null would read as a cancel');
      expect(platform.analyzeImagePaths, hasLength(1));
    });

    test('cannot be combined with galleryImagePicker', () {
      Future<String?> legacy(BuildContext _) async => null;
      Future<ScannerImage?> modern(BuildContext _) async => null;

      expect(
        () => AiBarcodeScanner(
          // ignore: deprecated_member_use_from_same_package
          imagePicker: legacy,
          galleryImagePicker: modern,
        ),
        throwsAssertionError,
      );
      expect(
        () => AiBarcodeScanner.embedded(
          // ignore: deprecated_member_use_from_same_package
          imagePicker: legacy,
          galleryImagePicker: modern,
        ),
        throwsAssertionError,
      );
    });
  });

  group('galleryImageAnalyzer', () {
    testWidgets('replaces the built-in decoding and receives the formats of a '
        'supplied controller', (tester) async {
      final controller = AiBarcodeScannerController(
        formats: const <BarcodeFormat>[BarcodeFormat.qrCode],
      );
      addTearDown(controller.dispose);
      final analyzed = <ScannerImage>[];
      List<BarcodeFormat>? formats;
      BarcodeCapture? detected;
      final image = ScannerImage.bytes(_png, name: 'code.png');

      await _pumpScanner(
        tester,
        AiBarcodeScanner(
          controller: controller,
          overlayConfig: _staticOverlay,
          feedback: feedback.config,
          galleryImagePicker: (_) async => image,
          galleryImageAnalyzer: (image, requested) async {
            analyzed.add(image);
            formats = requested;
            return const BarcodeCapture(
              barcodes: <Barcode>[Barcode(rawValue: 'custom')],
            );
          },
          onDetect: (capture) => detected = capture,
        ),
      );
      await _scanFromGallery(tester, done: feedback.finished);

      expect(analyzed, <ScannerImage>[image]);
      expect(formats, <BarcodeFormat>[BarcodeFormat.qrCode]);
      expect(platform.analyzeImagePaths, isEmpty);
      expect(detected?.barcodes.single.rawValue, 'custom');
    });

    testWidgets('finding nothing gives rejection feedback', (tester) async {
      var detected = 0;

      await _pumpScanner(
        tester,
        AiBarcodeScanner(
          overlayConfig: _staticOverlay,
          feedback: feedback.config,
          galleryImagePicker: (_) async => ScannerImage.bytes(_png),
          galleryImageAnalyzer: (_, _) async => null,
          onDetect: (_) => detected++,
        ),
      );
      await _scanFromGallery(tester, done: feedback.finished);

      expect(detected, 0);
      expect(feedback.events, contains(ScannerFeedbackEvent.reject));
    });

    testWidgets('an error is reported through onGalleryScanError', (
      tester,
    ) async {
      Object? reported;

      await _pumpScanner(
        tester,
        AiBarcodeScanner(
          overlayConfig: _staticOverlay,
          feedback: feedback.config,
          galleryImagePicker: (_) async => ScannerImage.bytes(_png),
          galleryImageAnalyzer: (_, _) async => throw StateError('no decoder'),
          onGalleryScanError: (error, _) => reported = error,
        ),
      );
      await _scanFromGallery(tester, done: feedback.finished);

      expect(reported, isA<StateError>());
      expect(feedback.events, contains(ScannerFeedbackEvent.reject));
      expect(tester.takeException(), isNull);
    });

    for (final type in <GalleryButtonType>[
      GalleryButtonType.icon,
      GalleryButtonType.filled,
    ]) {
      testWidgets('shows the ${type.name} gallery button', (tester) async {
        await _pumpScanner(
          tester,
          AiBarcodeScanner(
            overlayConfig: _staticOverlay,
            galleryButtonType: type,
            galleryImageAnalyzer: (_, _) async => null,
          ),
        );

        expect(find.byIcon(Icons.photo_library_outlined), findsOneWidget);
      });
    }
  });

  group('showAiBarcodeScanner', () {
    Future<BuildContext> pumpHost(WidgetTester tester) async {
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

    testWidgets('forwards the gallery picker, callback and analyzer', (
      tester,
    ) async {
      final context = await pumpHost(tester);
      final picked = <ScannerImage?>[];
      final image = ScannerImage.bytes(_png);
      ScannerImage? analyzed;

      final result = showAiBarcodeScanner(
        context,
        overlayConfig: _staticOverlay,
        feedback: feedback.config,
        galleryImagePicker: (_) async => image,
        onGalleryImagePick: picked.add,
        galleryImageAnalyzer: (image, _) async {
          analyzed = image;
          return _hit;
        },
      );
      await tester.pumpAndSettle();
      await _scanFromGallery(tester, done: feedback.finished);

      expect(picked, <ScannerImage?>[image]);
      expect(analyzed, same(image));
      expect(await result, same(_hit));
    });

    testWidgets('forwards onGalleryScanError', (tester) async {
      final context = await pumpHost(tester);
      Object? reported;

      unawaited(
        showAiBarcodeScanner(
          context,
          overlayConfig: _staticOverlay,
          feedback: feedback.config,
          galleryImagePicker: (_) async => ScannerImage.bytes(_png),
          galleryImageAnalyzer: (_, _) async => throw StateError('offline'),
          onGalleryScanError: (error, _) => reported = error,
        ),
      );
      await tester.pumpAndSettle();
      await _scanFromGallery(tester, done: feedback.finished);

      expect(reported, isA<StateError>());
    });
  });

  group('AiBarcodeScannerController.analyzeScannerImage', () {
    test('sends bytes through a temporary file with the formats', () async {
      final controller = AiBarcodeScannerController(autoStart: false);
      addTearDown(controller.dispose);

      final capture = await controller.analyzeScannerImage(
        ScannerImage.bytes(_png),
        formats: const <BarcodeFormat>[BarcodeFormat.ean13],
      );

      expect(capture, same(_hit));
      expect(platform.analyzedFileBytes.single, _png);
      expect(platform.analyzeImageFormats.single, <BarcodeFormat>[
        BarcodeFormat.ean13,
      ]);
      expect(File(platform.analyzeImagePaths.single).existsSync(), isFalse);
    });

    test('overlapping analyses reach the platform one at a time', () async {
      // On Android, mobile_scanner keeps a single pending result for
      // analyzeImage: a second call replaces the first, which then never
      // completes, and never deletes its temporary file either.
      final controller = AiBarcodeScannerController(autoStart: false);
      addTearDown(controller.dispose);
      final release = Completer<void>();
      platform.analyzeImageGate = (_) => release.future;

      final analyses = <Future<BarcodeCapture?>>[
        controller.analyzeScannerImage(ScannerImage.bytes(_png)),
        controller.analyzeImage('/some/image.png'),
        controller.analyzeScannerImage(ScannerImage.bytes(_png)),
      ];
      // Real time, for the temporary file's dart:io work.
      for (var i = 0; i < 100 && platform.analyzeImagePaths.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(platform.analyzeImagePaths, hasLength(1));

      release.complete();
      expect(await Future.wait(analyses), everyElement(same(_hit)));

      expect(platform.maxConcurrentAnalyzeImageCalls, 1);
      // In the order they were asked for, although the path needed no file.
      expect(platform.analyzeImagePaths, hasLength(3));
      expect(platform.analyzeImagePaths[1], '/some/image.png');
      expect(File(platform.analyzeImagePaths[0]).existsSync(), isFalse);
      expect(File(platform.analyzeImagePaths[2]).existsSync(), isFalse);
    });

    test('a failed analysis does not hold up the next one', () async {
      final controller = AiBarcodeScannerController(autoStart: false);
      addTearDown(controller.dispose);
      var calls = 0;
      platform.analyzeImageGate = (_) async {
        if (calls++ == 0) throw StateError('decoder crashed');
      };

      final failed = controller.analyzeImage('/first.png');
      final next = controller.analyzeImage('/second.png');

      await expectLater(failed, throwsStateError);
      expect(await next, same(_hit));
    });

    test('an unawaited failing analysis is still an uncaught error', () async {
      // As it was in 8.0.1, when analyzeImage went straight to the platform:
      // queueing must not quietly handle an error nobody listens for.
      final controller = AiBarcodeScannerController(autoStart: false);
      addTearDown(controller.dispose);
      platform.analyzeImageGate = (path) async {
        throw StateError('decoder crashed on $path');
      };
      final uncaught = <Object>[];
      final reported = Completer<void>();

      runZonedGuarded(
        () {
          unawaited(controller.analyzeImage('/first.png'));
          unawaited(
            controller.analyzeScannerImage(
              const ScannerImage.path('/second.png'),
            ),
          );
        },
        (error, _) {
          uncaught.add(error);
          if (uncaught.length == 2) reported.complete();
        },
      );
      await reported.future.timeout(const Duration(seconds: 5));

      expect(uncaught, <Matcher>[
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('first'),
        ),
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('second'),
        ),
      ]);
      // And the queue moved on past both.
      platform.analyzeImageGate = null;
      expect(await controller.analyzeImage('/third.png'), same(_hit));
    });

    test('an XFile whose file is gone fails as a missing path does', () async {
      platform = FakeMobileScannerPlatform(
        analyzeImageError: const MobileScannerBarcodeException('no such file'),
      );
      MobileScannerPlatform.instance = platform;
      final controller = AiBarcodeScannerController(autoStart: false);
      addTearDown(controller.dispose);
      const missing = '/no/such/picked.jpg';

      await expectLater(
        controller.analyzeScannerImage(ScannerImage.xFile(XFile(missing))),
        throwsA(
          isA<MobileScannerBarcodeException>().having(
            (error) => error.message,
            'message',
            'no such file',
          ),
        ),
      );
      expect(platform.analyzeImagePaths, <String>[missing]);
    });

    test(
      'a temporary file that cannot be written is a barcode error',
      () async {
        final controller = AiBarcodeScannerController(autoStart: false);
        addTearDown(controller.dispose);
        final unwritable = Directory(
          '${Directory.systemTemp.path}${Platform.pathSeparator}'
          'ai_barcode_scanner_test_no_such_dir${Platform.pathSeparator}nested',
        );

        await IOOverrides.runZoned(
          () => expectLater(
            controller.analyzeScannerImage(ScannerImage.bytes(_png)),
            throwsA(
              isA<MobileScannerBarcodeException>().having(
                (error) => error.message,
                'message',
                contains('Could not write the image to a temporary file'),
              ),
            ),
          ),
          getSystemTempDirectory: () => unwritable,
        );
        expect(platform.analyzeImagePaths, isEmpty);
      },
    );

    test('analyzeImage still hands a path straight over', () async {
      final controller = AiBarcodeScannerController(autoStart: false);
      addTearDown(controller.dispose);

      expect(await controller.analyzeImage('/some/image.png'), same(_hit));
      expect(platform.analyzeImagePaths, <String>['/some/image.png']);
    });
  });

  group('ScannerImage', () {
    test('readAsBytes reads every kind of source', () async {
      final file = realFile('a.png');

      expect(await ScannerImage.bytes(_png).readAsBytes(), _png);
      expect(await ScannerImage.path(file.path).readAsBytes(), _png);
      expect(await ScannerImage.xFile(XFile(file.path)).readAsBytes(), _png);
      expect(
        await ScannerImage.xFile(XFile.fromData(_png)).readAsBytes(),
        _png,
      );
    });

    test('copies what an XFile knows about itself', () {
      final file = realFile('receipt.jpg');

      final fromPath = ScannerImage.xFile(
        XFile(file.path, mimeType: 'image/jpeg'),
      );
      expect(fromPath.path, file.path);
      expect(fromPath.name, 'receipt.jpg');
      expect(fromPath.mimeType, 'image/jpeg');
      expect(fromPath.bytes, isNull);

      final fromData = ScannerImage.xFile(XFile.fromData(_png));
      expect(fromData.path, isNull);
      expect(fromData.name, isNull);
    });

    test('path and bytes constructors are const and exclusive', () {
      const fromPath = ScannerImage.path(
        '/x.png',
        name: 'x.png',
        mimeType: 'image/png',
      );
      expect(fromPath.path, '/x.png');
      expect(fromPath.bytes, isNull);
      expect(fromPath.name, 'x.png');

      final fromBytes = ScannerImage.bytes(_png, mimeType: 'image/png');
      expect(fromBytes.path, isNull);
      expect(fromBytes.bytes, same(_png));
      expect(fromBytes.toString(), contains('12 bytes'));
    });
  });

  group('temporary file extension', () {
    Uint8List bytes(List<int> values) => Uint8List.fromList(values);

    test('is recognised from the file signature', () {
      expect(imageFileExtension(_png), '.png');
      expect(imageFileExtension(bytes(<int>[0xFF, 0xD8, 0xFF, 0xE0])), '.jpg');
      expect(imageFileExtension(bytes('GIF89a'.codeUnits)), '.gif');
      expect(
        imageFileExtension(bytes('RIFF\x00\x00\x00\x00WEBPVP8 '.codeUnits)),
        '.webp',
      );
      expect(imageFileExtension(bytes('BM\x00\x00'.codeUnits)), '.bmp');
      expect(
        imageFileExtension(bytes('\x00\x00\x00\x18ftypheic'.codeUnits)),
        '.heic',
      );
      expect(
        imageFileExtension(bytes('\x00\x00\x00\x1cftypavif'.codeUnits)),
        '.avif',
      );
    });

    test('falls back to the MIME type, then to none', () {
      final unknown = bytes(<int>[1, 2, 3]);
      expect(imageFileExtension(unknown, mimeType: 'image/webp'), '.webp');
      expect(imageFileExtension(unknown), '');
      // The bytes win over a wrong MIME type.
      expect(imageFileExtension(_png, mimeType: 'image/jpeg'), '.png');
    });
  });
}
