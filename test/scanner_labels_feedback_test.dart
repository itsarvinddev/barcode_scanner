// The three ScannerLabels that shipped in 8.0.0 without ever being shown:
// invalidBarcode, noBarcodeFoundInImage and galleryUnsupported. They now take
// over the scan hint for a moment, and only where the hint is shown at all.
//
// Every label is given a custom value, so a passing test proves the label is
// read rather than a hard-coded English string.
import 'dart:ui' show SemanticsFlag;

import 'package:ai_barcode_scanner/ai_barcode_scanner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_mobile_scanner_platform.dart';

const _staticOverlay = ScannerOverlayConfig(
  scannerAnimation: ScannerAnimation.none,
  scannerOverlayBackground: ScannerOverlayBackground.dim,
);

const _labels = ScannerLabels(
  scanHint: 'Aim at a code',
  scanHintIdle: 'Come a little closer',
  scanHintBatch: 'Keep going',
  invalidBarcode: 'Not one of ours',
  noBarcodeFoundInImage: 'Nothing in that picture',
  galleryUnsupported: 'No image scanning here',
);

/// Every transient message, for asserting that none of them is showing.
final _transientMessages = <String>[
  _labels.invalidBarcode,
  _labels.noBarcodeFoundInImage,
  _labels.galleryUnsupported,
];

const _good = BarcodeCapture(barcodes: <Barcode>[Barcode(rawValue: 'good')]);
const _bad = BarcodeCapture(barcodes: <Barcode>[Barcode(rawValue: 'bad')]);
const _empty = BarcodeCapture(barcodes: <Barcode>[]);

bool _acceptsGood(BarcodeCapture capture) =>
    capture.barcodes.first.rawValue == 'good';

Future<void> _pumpScanner(WidgetTester tester, Widget scanner) async {
  await tester.pumpWidget(MaterialApp(home: scanner));
  await tester.pumpAndSettle();
}

/// The message the scanner is asking the hint pill to show.
///
/// Read off the widget rather than found as text, because the pill fades
/// between messages and keeps the old one in the tree while it does.
String? _hintText(WidgetTester tester) =>
    tester.widget<ScanHint>(find.byType(ScanHint)).text;

bool _hintAnnounces(WidgetTester tester) =>
    tester.widget<ScanHint>(find.byType(ScanHint)).announce;

void _expectNoTransientMessage() {
  for (final message in _transientMessages) {
    expect(find.text(message), findsNothing, reason: message);
  }
}

/// Records feedback events; a gallery scan that got as far as analysis always
/// ends with a detect or reject event.
class _Feedback {
  final List<ScannerFeedbackEvent> events = <ScannerFeedbackEvent>[];

  ScannerFeedbackConfig get config =>
      ScannerFeedbackConfig.silent(onFeedback: events.add);

  int get rejects =>
      events.where((e) => e == ScannerFeedbackEvent.reject).length;

  bool finished() =>
      events.contains(ScannerFeedbackEvent.detect) ||
      events.contains(ScannerFeedbackEvent.reject);
}

/// Taps the gallery button and waits until [done] reports the pick has been
/// handled, letting real time through in case the analysis does `dart:io`
/// work (see gallery_image_test.dart). The test clock does not move.
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
  await tester.pump();
}

void main() {
  late FakeMobileScannerPlatform platform;
  late _Feedback feedback;

  void usePlatform(FakeMobileScannerPlatform fake) {
    platform = fake;
    MobileScannerPlatform.instance = fake;
  }

  setUp(() {
    usePlatform(FakeMobileScannerPlatform());
    feedback = _Feedback();
  });

  tearDown(MobileScannerController.resetPlatformSessionOwner);

  /// Emits [capture] from the camera and lets the scanner handle it, without
  /// moving the test clock.
  Future<void> emit(WidgetTester tester, BarcodeCapture capture) async {
    platform.emitBarcode(capture);
    await tester.pump();
    await tester.pump();
  }

  group('invalidBarcode', () {
    testWidgets('replaces the hint when the validator rejects, then clears', (
      tester,
    ) async {
      var detected = 0;
      await _pumpScanner(
        tester,
        AiBarcodeScanner(
          overlayConfig: _staticOverlay,
          feedback: feedback.config,
          labels: _labels,
          validator: (_) => false,
          onDetect: (_) => detected++,
        ),
      );
      expect(_hintText(tester), _labels.scanHint);
      expect(_hintAnnounces(tester), isFalse);

      await emit(tester, _bad);
      expect(_hintText(tester), _labels.invalidBarcode);
      expect(_hintAnnounces(tester), isTrue);
      expect(feedback.rejects, 1);
      expect(detected, 0);

      // Rendered, in place of the guidance, once the fade has run.
      await tester.pumpAndSettle();
      expect(find.text(_labels.invalidBarcode), findsOneWidget);
      expect(find.text(_labels.scanHint), findsNothing);

      await tester.pump(const Duration(milliseconds: 2000));
      expect(_hintText(tester), _labels.invalidBarcode);

      await tester.pump(const Duration(milliseconds: 1000));
      expect(_hintText(tester), _labels.scanHint);
      expect(_hintAnnounces(tester), isFalse);
      await tester.pumpAndSettle();
      expect(find.text(_labels.invalidBarcode), findsNothing);
      expect(find.text(_labels.scanHint), findsOneWidget);
    });

    testWidgets('is throttled by scanCooldown, like the rejection haptic', (
      tester,
    ) async {
      await _pumpScanner(
        tester,
        AiBarcodeScanner(
          overlayConfig: _staticOverlay,
          feedback: feedback.config,
          labels: _labels,
          scanCooldown: const Duration(hours: 1),
          validator: (_) => false,
        ),
      );

      await emit(tester, _bad);
      expect(_hintText(tester), _labels.invalidBarcode);
      await tester.pump(const Duration(seconds: 3));
      expect(_hintText(tester), _labels.scanHint);

      // Still inside the cooldown: no haptic, so no message either.
      await emit(tester, _bad);
      expect(_hintText(tester), _labels.scanHint);
      expect(feedback.rejects, 1);
    });

    testWidgets('a rejection while it is up starts its time again', (
      tester,
    ) async {
      await _pumpScanner(
        tester,
        AiBarcodeScanner(
          overlayConfig: _staticOverlay,
          feedback: feedback.config,
          labels: _labels,
          // The cooldown is measured with DateTime.now(), which the test clock
          // does not fake, so every rejection passes it here.
          scanCooldown: Duration.zero,
          validator: (_) => false,
        ),
      );

      await emit(tester, _bad); // 0 s
      await tester.pump(const Duration(milliseconds: 1500));
      await emit(tester, _bad); // 1.5 s: starts the message's time again
      expect(feedback.rejects, 2);

      await tester.pump(const Duration(milliseconds: 2000)); // 3.5 s
      expect(_hintText(tester), _labels.invalidBarcode);

      await tester.pump(const Duration(milliseconds: 1000)); // 4.5 s
      expect(_hintText(tester), _labels.scanHint);
    });

    testWidgets('lasts at least as long as a longer resultFlashDuration', (
      tester,
    ) async {
      await _pumpScanner(
        tester,
        AiBarcodeScanner(
          overlayConfig: _staticOverlay,
          feedback: feedback.config,
          labels: _labels,
          resultFlashDuration: const Duration(seconds: 4),
          validator: (_) => false,
        ),
      );

      await emit(tester, _bad);
      await tester.pump(const Duration(milliseconds: 3800));
      expect(_hintText(tester), _labels.invalidBarcode);

      await tester.pump(const Duration(milliseconds: 400));
      expect(_hintText(tester), _labels.scanHint);
    });

    testWidgets('an accepted scan clears it at once', (tester) async {
      final detected = <String?>[];
      await _pumpScanner(
        tester,
        AiBarcodeScanner(
          overlayConfig: _staticOverlay,
          feedback: feedback.config,
          labels: _labels,
          scanMode: ScanMode.continuous,
          validator: _acceptsGood,
          onDetect: (capture) => detected.add(capture.barcodes.first.rawValue),
        ),
      );

      await emit(tester, _bad);
      await tester.pump(const Duration(milliseconds: 500));
      expect(_hintText(tester), _labels.invalidBarcode);

      await emit(tester, _good); // no time passes
      expect(detected, <String?>['good']);
      expect(_hintText(tester), _labels.scanHint);
      expect(_hintAnnounces(tester), isFalse);
    });

    testWidgets('an accepted batch scan clears it at once', (tester) async {
      await _pumpScanner(
        tester,
        AiBarcodeScanner(
          overlayConfig: _staticOverlay,
          feedback: feedback.config,
          labels: _labels,
          scanMode: ScanMode.batch,
          validator: _acceptsGood,
        ),
      );

      await emit(tester, _bad);
      expect(_hintText(tester), _labels.invalidBarcode);

      await emit(tester, _good); // no time passes
      expect(
        feedback.events.where((e) => e == ScannerFeedbackEvent.detect),
        hasLength(1),
      );
      expect(_hintText(tester), _labels.scanHintBatch);
      expect(_hintAnnounces(tester), isFalse);
    });

    testWidgets('an empty label turns the message off and keeps the guidance', (
      tester,
    ) async {
      await _pumpScanner(
        tester,
        AiBarcodeScanner(
          overlayConfig: _staticOverlay,
          feedback: feedback.config,
          labels: const ScannerLabels(scanHint: 'Aim', invalidBarcode: ''),
          validator: (_) => false,
        ),
      );
      final size = tester.getSize(find.byType(ScanHint));

      await emit(tester, _bad);
      await tester.pumpAndSettle();
      expect(feedback.rejects, 1, reason: 'the haptic still fires');
      expect(_hintText(tester), 'Aim');
      expect(_hintAnnounces(tester), isFalse);
      expect(find.text('Aim'), findsOneWidget);
      expect(tester.getSize(find.byType(ScanHint)), size);
    });

    testWidgets('a labels change while it is up shows the new text', (
      tester,
    ) async {
      Widget scanner(ScannerLabels labels) => AiBarcodeScanner(
        overlayConfig: _staticOverlay,
        feedback: feedback.config,
        labels: labels,
        validator: (_) => false,
      );
      await _pumpScanner(tester, scanner(_labels));

      await emit(tester, _bad);
      expect(_hintText(tester), _labels.invalidBarcode);

      await tester.pumpWidget(
        MaterialApp(
          home: scanner(
            const ScannerLabels(scanHint: 'Visez', invalidBarcode: 'Refusé'),
          ),
        ),
      );
      expect(_hintText(tester), 'Refusé');
      expect(_hintAnnounces(tester), isTrue);

      // Emptied while up: the guidance comes straight back.
      await tester.pumpWidget(
        MaterialApp(
          home: scanner(
            const ScannerLabels(scanHint: 'Visez', invalidBarcode: ''),
          ),
        ),
      );
      expect(_hintText(tester), 'Visez');
      expect(_hintAnnounces(tester), isFalse);

      await tester.pump(const Duration(seconds: 3));
      expect(_hintText(tester), 'Visez');
    });

    testWidgets('turning showScanHint off clears it, so turning it back on '
        'shows the guidance', (tester) async {
      Widget scanner({required bool hint}) => AiBarcodeScanner(
        overlayConfig: _staticOverlay,
        feedback: feedback.config,
        labels: _labels,
        showScanHint: hint,
        validator: (_) => false,
      );
      await _pumpScanner(tester, scanner(hint: true));

      await emit(tester, _bad);
      expect(_hintText(tester), _labels.invalidBarcode);

      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpWidget(MaterialApp(home: scanner(hint: false)));
      expect(find.byType(ScanHint), findsNothing);

      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpWidget(MaterialApp(home: scanner(hint: true)));
      expect(_hintText(tester), _labels.scanHint);
      expect(_hintAnnounces(tester), isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('turning showScanHint on does not surface an earlier '
        'rejection', (tester) async {
      Widget scanner({required bool hint}) => AiBarcodeScanner(
        overlayConfig: _staticOverlay,
        feedback: feedback.config,
        labels: _labels,
        showScanHint: hint,
        validator: (_) => false,
      );
      await _pumpScanner(tester, scanner(hint: false));

      await emit(tester, _bad);
      expect(feedback.rejects, 1);

      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpWidget(MaterialApp(home: scanner(hint: true)));
      await tester.pump();
      expect(_hintText(tester), _labels.scanHint);
      expect(_hintAnnounces(tester), isFalse);
    });

    testWidgets('shows over the batch hint, which then returns', (
      tester,
    ) async {
      await _pumpScanner(
        tester,
        AiBarcodeScanner(
          overlayConfig: _staticOverlay,
          feedback: feedback.config,
          labels: _labels,
          scanMode: ScanMode.batch,
          validator: _acceptsGood,
        ),
      );
      expect(_hintText(tester), _labels.scanHintBatch);

      await emit(tester, _bad);
      expect(_hintText(tester), _labels.invalidBarcode);
      await tester.pumpAndSettle();
      expect(find.text(_labels.invalidBarcode), findsOneWidget);
      expect(find.text(_labels.scanHintBatch), findsNothing);

      await tester.pump(const Duration(seconds: 3));
      expect(_hintText(tester), _labels.scanHintBatch);
    });

    testWidgets('the idle hint waits for it, then takes over', (tester) async {
      await _pumpScanner(
        tester,
        AiBarcodeScanner(
          overlayConfig: _staticOverlay,
          feedback: feedback.config,
          labels: _labels,
          idleHintDelay: const Duration(seconds: 1),
          validator: (_) => false,
        ),
      );

      await emit(tester, _bad); // restarts the idle timer as well
      await tester.pump(const Duration(milliseconds: 1500)); // idle by now
      expect(_hintText(tester), _labels.invalidBarcode);

      await tester.pump(const Duration(milliseconds: 1500));
      expect(_hintText(tester), _labels.scanHintIdle);
    });

    testWidgets('shows for a picked image the validator rejects', (
      tester,
    ) async {
      await _pumpScanner(
        tester,
        AiBarcodeScanner(
          overlayConfig: _staticOverlay,
          feedback: feedback.config,
          labels: _labels,
          galleryImagePicker: (_) async => const ScannerImage.path('/p.png'),
          galleryImageAnalyzer: (_, _) async => _bad,
          validator: _acceptsGood,
        ),
      );

      await _scanFromGallery(tester, done: feedback.finished);
      expect(feedback.rejects, 1);
      expect(_hintText(tester), _labels.invalidBarcode);
    });

    testWidgets('is announced to screen readers; the steady hint is not', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _pumpScanner(
        tester,
        AiBarcodeScanner(
          overlayConfig: _staticOverlay,
          feedback: feedback.config,
          labels: _labels,
          validator: (_) => false,
        ),
      );
      final liveRegions = find.semantics.byFlag(SemanticsFlag.isLiveRegion);
      expect(liveRegions, findsNothing);

      await emit(tester, _bad);
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(find.text(_labels.invalidBarcode)),
        isSemantics(label: _labels.invalidBarcode, isLiveRegion: true),
      );
      expect(liveRegions, findsOne);

      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(liveRegions, findsNothing);
      semantics.dispose();
    });

    testWidgets('a scanner removed mid-message leaves no timer behind', (
      tester,
    ) async {
      // The test binding fails the test if a timer is still pending once the
      // tree is gone, so this passes only if dispose cancels it.
      await _pumpScanner(
        tester,
        AiBarcodeScanner(
          overlayConfig: _staticOverlay,
          feedback: feedback.config,
          labels: _labels,
          validator: (_) => false,
        ),
      );
      await emit(tester, _bad);
      expect(_hintText(tester), _labels.invalidBarcode);

      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    });
  });

  group('noBarcodeFoundInImage', () {
    for (final result in <BarcodeCapture?>[null, _empty]) {
      final what = result == null ? 'null' : 'an empty capture';

      testWidgets('shows when the built-in decoder returns $what', (
        tester,
      ) async {
        usePlatform(FakeMobileScannerPlatform(analyzeImageResult: result));
        Object? reported;
        await _pumpScanner(
          tester,
          AiBarcodeScanner(
            overlayConfig: _staticOverlay,
            feedback: feedback.config,
            labels: _labels,
            galleryImagePicker: (_) async => const ScannerImage.path('/p.png'),
            onGalleryScanError: (error, _) => reported = error,
          ),
        );

        await _scanFromGallery(tester, done: feedback.finished);
        expect(platform.analyzeImagePaths, <String>['/p.png']);
        expect(_hintText(tester), _labels.noBarcodeFoundInImage);
        expect(_hintAnnounces(tester), isTrue);
        expect(feedback.rejects, 1);
        expect(reported, isNull);

        await tester.pumpAndSettle();
        expect(find.text(_labels.noBarcodeFoundInImage), findsOneWidget);

        await tester.pump(const Duration(seconds: 3));
        expect(_hintText(tester), _labels.scanHint);
      });

      testWidgets('shows when galleryImageAnalyzer returns $what', (
        tester,
      ) async {
        await _pumpScanner(
          tester,
          AiBarcodeScanner(
            overlayConfig: _staticOverlay,
            feedback: feedback.config,
            labels: _labels,
            galleryImagePicker: (_) async => const ScannerImage.path('/p.png'),
            galleryImageAnalyzer: (_, _) async => result,
          ),
        );

        await _scanFromGallery(tester, done: feedback.finished);
        expect(platform.analyzeImagePaths, isEmpty);
        expect(_hintText(tester), _labels.noBarcodeFoundInImage);
      });
    }

    testWidgets('a cancelled pick shows nothing', (tester) async {
      final picked = <ScannerImage?>[];
      await _pumpScanner(
        tester,
        AiBarcodeScanner(
          overlayConfig: _staticOverlay,
          feedback: feedback.config,
          labels: _labels,
          galleryImagePicker: (_) async => null,
          galleryImageAnalyzer: (_, _) async => null,
          onGalleryImagePick: picked.add,
        ),
      );

      await _scanFromGallery(tester, done: () => picked.isNotEmpty);
      await tester.pumpAndSettle();
      expect(picked, <ScannerImage?>[null]);
      expect(_hintText(tester), _labels.scanHint);
      _expectNoTransientMessage();
      expect(feedback.rejects, 0);
    });
  });

  group('galleryUnsupported', () {
    testWidgets('shows when the platform cannot analyse images, and the error '
        'still reaches onGalleryScanError', (tester) async {
      // What a platform implementation without still-image support throws.
      final error = UnsupportedError(
        'Analyzing an image from a file is not supported on this platform.',
      );
      usePlatform(FakeMobileScannerPlatform(analyzeImageError: error));
      final reported = <Object>[];
      await _pumpScanner(
        tester,
        AiBarcodeScanner(
          overlayConfig: _staticOverlay,
          feedback: feedback.config,
          labels: _labels,
          galleryImagePicker: (_) async => const ScannerImage.path('/p.png'),
          onGalleryScanError: (error, _) => reported.add(error),
        ),
      );

      await _scanFromGallery(tester, done: feedback.finished);
      expect(reported, <Object>[same(error)]);
      expect(feedback.rejects, 1);
      expect(_hintText(tester), _labels.galleryUnsupported);
      expect(_hintAnnounces(tester), isTrue);
      expect(tester.takeException(), isNull);

      await tester.pumpAndSettle();
      expect(find.text(_labels.galleryUnsupported), findsOneWidget);

      await tester.pump(const Duration(seconds: 3));
      expect(_hintText(tester), _labels.scanHint);
    });

    testWidgets('shows for an analyzer that throws UnsupportedError, which '
        'still goes to FlutterError.reportError without a callback', (
      tester,
    ) async {
      final error = UnsupportedError('no decoder on this platform');
      await _pumpScanner(
        tester,
        AiBarcodeScanner(
          overlayConfig: _staticOverlay,
          feedback: feedback.config,
          labels: _labels,
          galleryImagePicker: (_) async => const ScannerImage.path('/p.png'),
          galleryImageAnalyzer: (_, _) async => throw error,
        ),
      );

      await _scanFromGallery(tester, done: feedback.finished);
      expect(tester.takeException(), same(error));
      expect(_hintText(tester), _labels.galleryUnsupported);
    });

    testWidgets('shows when the picker throws UnimplementedError, before any '
        'analysis', (tester) async {
      final error = UnimplementedError('picker not implemented');
      final reported = <Object>[];
      var analyzed = false;
      await _pumpScanner(
        tester,
        AiBarcodeScanner(
          overlayConfig: _staticOverlay,
          feedback: feedback.config,
          labels: _labels,
          galleryImagePicker: (_) async => throw error,
          galleryImageAnalyzer: (_, _) async {
            analyzed = true;
            return null;
          },
          onGalleryScanError: (error, _) => reported.add(error),
        ),
      );

      await _scanFromGallery(tester, done: feedback.finished);
      expect(analyzed, isFalse);
      expect(reported, <Object>[same(error)]);
      expect(feedback.rejects, 1);
      expect(_hintText(tester), _labels.galleryUnsupported);
    });

    for (final error in <Object>[
      const MobileScannerBarcodeException('Could not decode the image.'),
      StateError('decoder offline'),
    ]) {
      testWidgets('is not shown for ${error.runtimeType}, nor is any other '
          'message', (tester) async {
        final reported = <Object>[];
        await _pumpScanner(
          tester,
          AiBarcodeScanner(
            overlayConfig: _staticOverlay,
            feedback: feedback.config,
            labels: _labels,
            galleryImagePicker: (_) async => const ScannerImage.path('/p.png'),
            galleryImageAnalyzer: (_, _) async => throw error,
            onGalleryScanError: (error, _) => reported.add(error),
          ),
        );

        await _scanFromGallery(tester, done: feedback.finished);
        expect(reported, <Object>[same(error)]);
        expect(feedback.rejects, 1);
        expect(_hintText(tester), _labels.scanHint);
        await tester.pumpAndSettle();
        _expectNoTransientMessage();
      });
    }
  });

  group('without the scan hint', () {
    final scanners = <String, Widget Function(ScannerImage? Function() pick)>{
      'showScanHint: false':
          (pick) => AiBarcodeScanner(
            overlayConfig: _staticOverlay,
            feedback: feedback.config,
            labels: _labels,
            showScanHint: false,
            galleryImagePicker: (_) async => pick(),
            validator: _acceptsGood,
          ),
      'the embedded default':
          (pick) => Scaffold(
            body: AiBarcodeScanner.embedded(
              overlayConfig: _staticOverlay,
              feedback: feedback.config,
              labels: _labels,
              galleryButtonType: GalleryButtonType.filled,
              enabledActionButtons: const <ScannerAction>{
                ScannerAction.gallery,
              },
              galleryImagePicker: (_) async => pick(),
              validator: _acceptsGood,
            ),
          ),
    };

    for (final MapEntry(key: name, value: build) in scanners.entries) {
      group(name, () {
        testWidgets('a rejected scan shows no message', (tester) async {
          await _pumpScanner(tester, build(() => null));
          expect(find.byType(ScanHint), findsNothing);

          await emit(tester, _bad);
          await tester.pumpAndSettle();
          expect(feedback.rejects, 1, reason: 'the haptic still fires');
          expect(find.byType(ScanHint), findsNothing);
          _expectNoTransientMessage();
        });

        testWidgets('an image without a barcode shows no message', (
          tester,
        ) async {
          usePlatform(FakeMobileScannerPlatform(analyzeImageResult: _empty));
          await _pumpScanner(
            tester,
            build(() => const ScannerImage.path('/p.png')),
          );

          await _scanFromGallery(tester, done: feedback.finished);
          await tester.pumpAndSettle();
          expect(feedback.rejects, 1);
          expect(find.byType(ScanHint), findsNothing);
          _expectNoTransientMessage();
        });

        testWidgets('unsupported image analysis shows no message', (
          tester,
        ) async {
          usePlatform(
            FakeMobileScannerPlatform(
              analyzeImageError: UnsupportedError('no still-image support'),
            ),
          );
          await _pumpScanner(
            tester,
            build(() => const ScannerImage.path('/p.png')),
          );

          await _scanFromGallery(tester, done: feedback.finished);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isA<UnsupportedError>());
          expect(feedback.rejects, 1);
          expect(find.byType(ScanHint), findsNothing);
          _expectNoTransientMessage();
        });
      });
    }
  });

  group('ScanHint', () {
    Widget host(Widget hint) =>
        Directionality(textDirection: TextDirection.ltr, child: hint);

    testWidgets('is not a live region by default', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(host(const ScanHint(text: 'Steady guidance')));
      await tester.pumpAndSettle();

      expect(find.text('Steady guidance'), findsOneWidget);
      expect(find.semantics.byFlag(SemanticsFlag.isLiveRegion), findsNothing);
      semantics.dispose();
    });

    testWidgets('announce makes its message a live region of its own', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        host(const ScanHint(text: 'Heads up', announce: true)),
      );
      await tester.pumpAndSettle();

      expect(
        tester.getSemantics(find.text('Heads up')),
        matchesSemantics(label: 'Heads up', isLiveRegion: true),
      );
      semantics.dispose();
    });
  });
}
