import 'package:ai_barcode_scanner/ai_barcode_scanner.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_mobile_scanner_platform.dart';

/// The overlay's sweeping line never settles, so tests turn it off; the point
/// of these tests is the chrome and the detection pipeline, not the animation.
const _staticOverlay = ScannerOverlayConfig(
  scannerAnimation: ScannerAnimation.none,
  scannerOverlayBackground: ScannerOverlayBackground.dim,
);

Future<void> pumpScanner(WidgetTester tester, Widget scanner) async {
  await tester.pumpWidget(MaterialApp(home: scanner));
  await tester.pumpAndSettle();
}

void main() {
  late FakeMobileScannerPlatform platform;

  setUp(() {
    platform = FakeMobileScannerPlatform();
    MobileScannerPlatform.instance = platform;
    // `flutter_test` already reports TargetPlatform.android, which is what the
    // capability matrix is exercised against here. Overriding
    // `debugDefaultTargetPlatformOverride` would trip the binding's
    // "debug variable changed by the test" invariant.
  });

  tearDown(MobileScannerController.resetPlatformSessionOwner);

  group('control visibility (regression for #176)', () {
    testWidgets('GalleryButtonType.none hides only the gallery button', (
      tester,
    ) async {
      await pumpScanner(
        tester,
        const AiBarcodeScanner(
          galleryButtonType: GalleryButtonType.none,
          overlayConfig: _staticOverlay,
        ),
      );

      // The gallery affordance is gone...
      expect(find.byIcon(Icons.photo_library_outlined), findsNothing);
      // ...but the torch and camera flip are still there.
      expect(find.byIcon(Icons.flashlight_off_outlined), findsOneWidget);
      expect(find.byIcon(Icons.cameraswitch_outlined), findsOneWidget);
    });

    testWidgets('a custom appBarBuilder does not remove the controls', (
      tester,
    ) async {
      await pumpScanner(
        tester,
        AiBarcodeScanner(
          galleryButtonType: GalleryButtonType.icon,
          overlayConfig: _staticOverlay,
          appBarBuilder:
              (context, controller) => AppBar(title: const Text('Custom')),
        ),
      );

      expect(find.text('Custom'), findsOneWidget);
      expect(find.byIcon(Icons.flashlight_off_outlined), findsOneWidget);
      expect(find.byIcon(Icons.cameraswitch_outlined), findsOneWidget);
      expect(find.byIcon(Icons.photo_library_outlined), findsOneWidget);
    });

    testWidgets('a child does not replace the controls', (tester) async {
      await pumpScanner(
        tester,
        const AiBarcodeScanner(
          overlayConfig: _staticOverlay,
          child: Align(
            alignment: Alignment.topCenter,
            child: Text('Custom child'),
          ),
        ),
      );

      expect(find.text('Custom child'), findsOneWidget);
      expect(find.byIcon(Icons.flashlight_off_outlined), findsOneWidget);
    });

    testWidgets('enabledActionButtons selects exactly what is shown', (
      tester,
    ) async {
      await pumpScanner(
        tester,
        const AiBarcodeScanner(
          enabledActionButtons: <ScannerAction>{ScannerAction.torch},
          overlayConfig: _staticOverlay,
        ),
      );

      expect(find.byIcon(Icons.flashlight_off_outlined), findsOneWidget);
      expect(find.byIcon(Icons.cameraswitch_outlined), findsNothing);
      expect(find.byIcon(Icons.photo_library_outlined), findsNothing);
    });

    testWidgets('an empty action set shows no controls at all', (tester) async {
      await pumpScanner(
        tester,
        const AiBarcodeScanner(
          enabledActionButtons: <ScannerAction>{},
          galleryButtonType: GalleryButtonType.none,
          overlayConfig: _staticOverlay,
        ),
      );

      expect(find.byType(ScannerControlButton), findsNothing);
    });
  });

  group('capability gating', () {
    testWidgets('the torch button is hidden when the device has no torch', (
      tester,
    ) async {
      MobileScannerPlatform.instance = FakeMobileScannerPlatform(
        torchMode: TorchState.unavailable,
      );

      await pumpScanner(
        tester,
        const AiBarcodeScanner(overlayConfig: _staticOverlay),
      );

      expect(find.byIcon(Icons.flashlight_off_outlined), findsNothing);
    });

    testWidgets('the camera flip is hidden on a single-camera device', (
      tester,
    ) async {
      MobileScannerPlatform.instance = FakeMobileScannerPlatform(
        numberOfCameras: 1,
      );

      await pumpScanner(
        tester,
        const AiBarcodeScanner(overlayConfig: _staticOverlay),
      );

      expect(find.byIcon(Icons.cameraswitch_outlined), findsNothing);
    });

    testWidgets('the lens button is hidden with only one lens', (tester) async {
      await pumpScanner(
        tester,
        const AiBarcodeScanner(
          enabledActionButtons: <ScannerAction>{ScannerAction.lens},
          galleryButtonType: GalleryButtonType.none,
          overlayConfig: _staticOverlay,
        ),
      );

      expect(find.byIcon(Icons.center_focus_strong_outlined), findsNothing);
    });

    testWidgets('the lens button appears when the device has several lenses', (
      tester,
    ) async {
      MobileScannerPlatform.instance = FakeMobileScannerPlatform(
        supportedLenses: const <CameraLensType>{
          CameraLensType.normal,
          CameraLensType.wide,
        },
      );

      await pumpScanner(
        tester,
        const AiBarcodeScanner(
          enabledActionButtons: <ScannerAction>{ScannerAction.lens},
          galleryButtonType: GalleryButtonType.none,
          overlayConfig: _staticOverlay,
        ),
      );

      expect(find.byIcon(Icons.center_focus_strong_outlined), findsOneWidget);
    });
  });

  group('torch state', () {
    testWidgets('the icon follows the platform, not a manual setState', (
      tester,
    ) async {
      await pumpScanner(
        tester,
        const AiBarcodeScanner(overlayConfig: _staticOverlay),
      );

      expect(find.byIcon(Icons.flashlight_off_outlined), findsOneWidget);

      // A torch change pushed from the platform — not from our button — must
      // still repaint the control.
      platform.emitTorchState(TorchState.on);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.flashlight_on), findsOneWidget);
      expect(find.byIcon(Icons.flashlight_off_outlined), findsNothing);
    });

    testWidgets('tapping the torch reaches the platform', (tester) async {
      await pumpScanner(
        tester,
        const AiBarcodeScanner(overlayConfig: _staticOverlay),
      );

      await tester.tap(find.byIcon(Icons.flashlight_off_outlined));
      await tester.pumpAndSettle();

      expect(platform.toggleTorchCount, 1);
    });

    testWidgets('controls stay tappable with tap-to-focus enabled', (
      tester,
    ) async {
      // The preview's gesture recogniser must not win the arena against a
      // control layered above it, or every button becomes inert as soon as
      // tap-to-focus or double-tap-to-zoom is on — which they are by default.
      await pumpScanner(
        tester,
        const AiBarcodeScanner(
          overlayConfig: _staticOverlay,
          tapToFocus: true,
          doubleTapToResetZoom: true,
          enablePinchToZoom: true,
        ),
      );

      await tester.tap(find.byIcon(Icons.flashlight_off_outlined));
      await tester.pumpAndSettle();

      expect(platform.toggleTorchCount, 1);
      expect(
        platform.focusPointCalls,
        isEmpty,
        reason: 'a tap on a control is not a tap on the preview',
      );
    });

    testWidgets('tapping the preview sets a focus point', (tester) async {
      await pumpScanner(
        tester,
        const AiBarcodeScanner(
          overlayConfig: _staticOverlay,
          enabledActionButtons: <ScannerAction>{},
          galleryButtonType: GalleryButtonType.none,
        ),
      );

      await tester.tapAt(const Offset(200, 200));
      // A double-tap recogniser is also in the arena, so the single tap only
      // resolves once its timeout expires — a plain pumpAndSettle would not
      // advance that timer because no frame is scheduled.
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(platform.focusPointCalls, hasLength(1));
      final point = platform.focusPointCalls.single;
      expect(point.dx, inInclusiveRange(0, 1));
      expect(point.dy, inInclusiveRange(0, 1));
    });
  });

  group('detection pipeline', () {
    testWidgets('onDetect receives accepted captures', (tester) async {
      BarcodeCapture? received;

      await pumpScanner(
        tester,
        AiBarcodeScanner(
          overlayConfig: _staticOverlay,
          feedback: const ScannerFeedbackConfig.silent(),
          onDetect: (capture) => received = capture,
        ),
      );

      const capture = BarcodeCapture(
        barcodes: <Barcode>[Barcode(rawValue: 'hello')],
      );
      platform.emitBarcode(capture);
      await tester.pumpAndSettle();

      expect(received, capture);
    });

    testWidgets('a rejecting validator suppresses onDetect', (tester) async {
      var detected = 0;

      await pumpScanner(
        tester,
        AiBarcodeScanner(
          overlayConfig: _staticOverlay,
          feedback: const ScannerFeedbackConfig.silent(),
          validator: (capture) => false,
          onDetect: (_) => detected++,
        ),
      );

      platform.emitBarcode(
        const BarcodeCapture(barcodes: <Barcode>[Barcode(rawValue: 'nope')]),
      );
      await tester.pumpAndSettle();

      expect(detected, 0);
    });

    testWidgets('a throwing validator rejects instead of crashing', (
      tester,
    ) async {
      Object? reported;
      var detected = 0;

      await pumpScanner(
        tester,
        AiBarcodeScanner(
          overlayConfig: _staticOverlay,
          feedback: const ScannerFeedbackConfig.silent(),
          validator: (capture) => throw StateError('boom'),
          onDetectError: (error, _) => reported = error,
          onDetect: (_) => detected++,
        ),
      );

      platform.emitBarcode(
        const BarcodeCapture(barcodes: <Barcode>[Barcode(rawValue: 'x')]),
      );
      await tester.pumpAndSettle();

      expect(detected, 0);
      expect(reported, isA<StateError>());
    });

    testWidgets('ScanMode.single reports once and then stops', (tester) async {
      var detected = 0;

      await pumpScanner(
        tester,
        AiBarcodeScanner(
          overlayConfig: _staticOverlay,
          feedback: const ScannerFeedbackConfig.silent(),
          onDetect: (_) => detected++,
        ),
      );

      for (var i = 0; i < 3; i++) {
        platform.emitBarcode(
          BarcodeCapture(barcodes: <Barcode>[Barcode(rawValue: 'code-$i')]),
        );
        await tester.pumpAndSettle();
      }

      expect(detected, 1);
    });

    testWidgets('ScanMode.continuous throttles by scanCooldown', (
      tester,
    ) async {
      var detected = 0;

      await pumpScanner(
        tester,
        AiBarcodeScanner(
          overlayConfig: _staticOverlay,
          feedback: const ScannerFeedbackConfig.silent(),
          scanMode: ScanMode.continuous,
          scanCooldown: const Duration(hours: 1),
          onDetect: (_) => detected++,
        ),
      );

      for (var i = 0; i < 4; i++) {
        platform.emitBarcode(
          BarcodeCapture(barcodes: <Barcode>[Barcode(rawValue: 'code-$i')]),
        );
        await tester.pumpAndSettle();
      }

      expect(detected, 1, reason: 'the cooldown has not elapsed');
    });

    testWidgets('ScanMode.batch collects distinct codes and finishes', (
      tester,
    ) async {
      List<Barcode>? completed;

      await pumpScanner(
        tester,
        AiBarcodeScanner(
          overlayConfig: _staticOverlay,
          feedback: const ScannerFeedbackConfig.silent(),
          scanMode: ScanMode.batch,
          maxScans: 2,
          onScanComplete: (barcodes) => completed = barcodes,
        ),
      );

      // The duplicate must not count towards the limit.
      for (final value in <String>['a', 'a', 'b']) {
        platform.emitBarcode(
          BarcodeCapture(barcodes: <Barcode>[Barcode(rawValue: value)]),
        );
        await tester.pumpAndSettle();
      }

      expect(completed, isNotNull);
      expect(completed!.map((b) => b.rawValue).toList(), <String>['a', 'b']);
    });
  });

  group('batch limits', () {
    testWidgets('never collects past maxScans, even from one capture', (
      tester,
    ) async {
      List<Barcode>? completed;

      await pumpScanner(
        tester,
        AiBarcodeScanner(
          overlayConfig: _staticOverlay,
          feedback: const ScannerFeedbackConfig.silent(),
          scanMode: ScanMode.batch,
          maxScans: 2,
          onScanComplete: (barcodes) => completed = barcodes,
        ),
      );

      // One frame carrying more barcodes than the budget has room for.
      platform.emitBarcode(
        const BarcodeCapture(
          barcodes: <Barcode>[
            Barcode(rawValue: 'a'),
            Barcode(rawValue: 'b'),
            Barcode(rawValue: 'c'),
            Barcode(rawValue: 'd'),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(completed, hasLength(2));
      expect(completed!.map((b) => b.rawValue), <String>['a', 'b']);
    });

    testWidgets('onScanComplete fires exactly once per session', (
      tester,
    ) async {
      var completions = 0;

      await pumpScanner(
        tester,
        AiBarcodeScanner(
          overlayConfig: _staticOverlay,
          feedback: const ScannerFeedbackConfig.silent(),
          scanMode: ScanMode.batch,
          maxScans: 1,
          onScanComplete: (_) => completions++,
        ),
      );

      for (final value in <String>['a', 'b', 'c']) {
        platform.emitBarcode(
          BarcodeCapture(barcodes: <Barcode>[Barcode(rawValue: value)]),
        );
        await tester.pumpAndSettle();
      }

      expect(completions, 1);
    });
  });

  group('rejection feedback', () {
    testWidgets('a rejected code held in frame does not buzz repeatedly', (
      tester,
    ) async {
      final events = <ScannerFeedbackEvent>[];

      await pumpScanner(
        tester,
        AiBarcodeScanner(
          overlayConfig: _staticOverlay,
          feedback: ScannerFeedbackConfig.silent(onFeedback: events.add),
          scanCooldown: const Duration(hours: 1),
          validator: (_) => false,
          onDetect: (_) {},
        ),
      );

      for (var i = 0; i < 5; i++) {
        platform.emitBarcode(
          const BarcodeCapture(barcodes: <Barcode>[Barcode(rawValue: 'no')]),
        );
        await tester.pumpAndSettle();
      }

      expect(
        events.where((e) => e == ScannerFeedbackEvent.reject).length,
        1,
        reason: 'the rejection haptic is throttled by scanCooldown',
      );
    });
  });

  group('scan window', () {
    testWidgets('does not restrict detection by default', (tester) async {
      // The reticle is guidance. Android rejects any barcode that is not
      // *entirely* inside the window — and any barcode with no corner points
      // at all — so restricting by default is what made #166 fail to scan a
      // barcode that was plainly visible.
      await pumpScanner(
        tester,
        const AiBarcodeScanner(overlayConfig: _staticOverlay),
      );

      expect(platform.scanWindowUpdates, isEmpty);
    });

    testWidgets('restricts detection when asked, in texture coordinates', (
      tester,
    ) async {
      await pumpScanner(
        tester,
        const AiBarcodeScanner(
          overlayConfig: _staticOverlay,
          restrictDetectionToScanWindow: true,
        ),
      );

      expect(platform.scanWindowUpdates, isNotEmpty);
      final window = platform.scanWindowUpdates.last;
      expect(window, isNotNull);
      // The platform receives the window as a 0..1 fraction of the camera
      // texture. Anything outside that range means the rect was computed
      // against the screen rather than the preview box.
      expect(window!.left, inInclusiveRange(0, 1));
      expect(window.top, inInclusiveRange(0, 1));
      expect(window.right, inInclusiveRange(0, 1));
      expect(window.bottom, inInclusiveRange(0, 1));
    });

    testWidgets('fullPreview never restricts, even when asked', (tester) async {
      await pumpScanner(
        tester,
        const AiBarcodeScanner(
          overlayConfig: _staticOverlay,
          scanWindowConfig: ScanWindowConfig.fullPreview(),
          restrictDetectionToScanWindow: true,
        ),
      );

      expect(platform.scanWindowUpdates, isEmpty);
    });
  });

  group('small and awkward layouts', () {
    testWidgets('renders in a box smaller than the reticle minimum', (
      tester,
    ) async {
      // ScanWindowConfig.resolve used to throw ArgumentError from num.clamp
      // here, replacing the whole scanner with an error widget.
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              height: 120,
              child: AiBarcodeScanner.embedded(overlayConfig: _staticOverlay),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(MobileScanner), findsOneWidget);
    });

    testWidgets(
      'keeps its controls tappable when the window fills the preview',
      (tester) async {
        // The bottom cluster used to be a Positioned whose top was pinned to
        // scanWindow.bottom, so a full-preview window collapsed it to zero
        // height and every control became untappable.
        await pumpScanner(
          tester,
          const AiBarcodeScanner(
            overlayConfig: _staticOverlay,
            scanWindowConfig: ScanWindowConfig.fullPreview(),
          ),
        );

        await tester.tap(find.byIcon(Icons.flashlight_off_outlined));
        await tester.pumpAndSettle();

        expect(platform.toggleTorchCount, 1);
      },
    );

    testWidgets('keeps its controls tappable on a short landscape preview', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(900, 380));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await pumpScanner(
        tester,
        const AiBarcodeScanner(overlayConfig: _staticOverlay),
      );

      await tester.tap(find.byIcon(Icons.flashlight_off_outlined));
      await tester.pumpAndSettle();

      expect(platform.toggleTorchCount, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('does not overflow at a 2x text scale', (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: const MaterialApp(
            home: AiBarcodeScanner(overlayConfig: _staticOverlay),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group('lifecycle and ownership', () {
    testWidgets('a supplied controller survives the scanner', (tester) async {
      final controller = AiBarcodeScannerController();

      await pumpScanner(
        tester,
        AiBarcodeScanner(controller: controller, overlayConfig: _staticOverlay),
      );
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pumpAndSettle();

      // Still usable: disposing it here must not throw.
      expect(controller.isScanningPaused, isFalse);
      controller.dispose();
    });

    testWidgets('swapping the controller rewires the preview', (tester) async {
      // `_MobileScannerState.controller` is `late final`, so without a key
      // change the preview keeps driving the controller that was just
      // disposed.
      final first = AiBarcodeScannerController();
      final second = AiBarcodeScannerController();
      addTearDown(first.dispose);
      addTearDown(second.dispose);

      await pumpScanner(
        tester,
        AiBarcodeScanner(controller: first, overlayConfig: _staticOverlay),
      );
      final startsAfterFirst = platform.startCalls.length;

      await tester.pumpWidget(
        MaterialApp(
          home: AiBarcodeScanner(
            controller: second,
            overlayConfig: _staticOverlay,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        platform.startCalls.length,
        greaterThan(startsAfterFirst),
        reason: 'the new controller started its own camera session',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a gallery scan uses the supplied controller\'s formats', (
      tester,
    ) async {
      final controller = AiBarcodeScannerController(
        formats: const <BarcodeFormat>[BarcodeFormat.qrCode],
      );
      addTearDown(controller.dispose);

      await pumpScanner(
        tester,
        AiBarcodeScanner(controller: controller, overlayConfig: _staticOverlay),
      );

      // `widget.formats` is asserted empty when a controller is supplied, so
      // reading formats off the widget would analyse with none at all.
      expect(controller.raw.formats, <BarcodeFormat>[BarcodeFormat.qrCode]);
    });

    testWidgets('the orientation policy is left alone by default', (
      tester,
    ) async {
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          calls.add(call);
          return null;
        },
      );

      await pumpScanner(
        tester,
        const AiBarcodeScanner(overlayConfig: _staticOverlay),
      );
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pumpAndSettle();

      expect(
        calls.where((c) => c.method == 'SystemChrome.setPreferredOrientations'),
        isEmpty,
        reason: 'the host app owns the orientation policy unless asked',
      );

      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });
  });

  group('embedded variant', () {
    testWidgets('renders without a Scaffold of its own', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 300,
              child: AiBarcodeScanner.embedded(overlayConfig: _staticOverlay),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Exactly one Scaffold: the host page's.
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(MobileScanner), findsOneWidget);
    });
  });
}
