// Renders the README and pub.dev screens from the package's real widgets.
//
//   flutter test test/render_test.dart
//
// Each test mounts ai_barcode_scanner exactly as an app would, with a fake
// camera platform that shows a photographed scene (assets/scene_*.jpg) and
// reports the barcodes decoded from it. Frames are written to build/screens/;
// compose/compose.mjs frames them into the final images.

library;

import 'package:ai_barcode_scanner/ai_barcode_scanner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'src/fake_camera.dart';
import 'src/harness.dart';
import 'src/receive_stock_page.dart';

/// The controls `showAiBarcodeScanner` enables by default.
const Set<ScannerAction> _fullScreenActions = <ScannerAction>{
  ScannerAction.gallery,
  ScannerAction.cameraSwitch,
  ScannerAction.torch,
  ScannerAction.close,
};

const String _url = 'https://pub.dev/packages/ai_barcode_scanner';

final _ios = TargetPlatformVariant.only(TargetPlatform.iOS);

void main() {
  setUpAll(loadFonts);

  testWidgets('scan', variant: _ios, (tester) async {
    final scene = await loadScene(tester, 'label');
    setUpPhone(tester, FakeCameraPlatform(scene: scene));

    await tester.pumpWidget(
      sceneApp(
        home: AiBarcodeScanner(
          enabledActionButtons: _fullScreenActions,
          onDetect: (_) {},
        ),
      ),
    );
    await startCamera(tester);
    // Catch the scan line as it crosses the code.
    await advance(tester, const Duration(milliseconds: 560));
    await capture(tester, 'scan');
  });

  testWidgets('detected', variant: _ios, (tester) async {
    final scene = await loadScene(tester, 'label');
    final camera = FakeCameraPlatform(scene: scene);
    setUpPhone(tester, camera);
    silencePlatformChannels(tester);

    await tester.pumpWidget(
      sceneApp(
        home: AiBarcodeScanner(
          enabledActionButtons: _fullScreenActions,
          onDetect: (_) {},
        ),
      ),
    );
    await startCamera(tester);
    await advance(tester, const Duration(milliseconds: 900));
    camera.emit(scene.capture(<Barcode>[_qr(scene)]));
    await tester.pump();
    // Settled in the success colours (they hold for resultFlashDuration, 1 s),
    // with the scan line at the bottom of its travel so the code is
    // unobstructed. Every frame of the 220 ms fade in or out is murkier: the
    // overlay tweens from translucent black to translucent green.
    await advance(tester, const Duration(milliseconds: 600));
    await capture(tester, 'detected');
  });

  testWidgets('result', variant: _ios, (tester) async {
    final scene = await loadScene(tester, 'label');
    final camera = FakeCameraPlatform(scene: scene);
    setUpPhone(tester, camera);
    silencePlatformChannels(tester);

    await tester.pumpWidget(
      sceneApp(
        home: Builder(
          builder:
              (context) => AiBarcodeScanner(
                enabledActionButtons: _fullScreenActions,
                onDetect:
                    (capture) => BarcodeResultSheet.show(
                      context,
                      barcode: capture.barcodes.first,
                      onOpen: (_) {},
                      onShare: (_) {},
                    ),
              ),
        ),
      ),
    );
    await startCamera(tester);
    await advance(tester, const Duration(milliseconds: 900));
    camera.emit(scene.capture(<Barcode>[_qr(scene)]));
    await tester.pump();
    // The sheet is up and the reticle has faded back from its success flash.
    await advance(tester, const Duration(milliseconds: 1500));
    await capture(tester, 'result');
  });

  testWidgets('batch', variant: _ios, (tester) async {
    final scene = await loadScene(tester, 'box');
    final camera = FakeCameraPlatform(scene: scene);
    setUpPhone(tester, camera);
    silencePlatformChannels(tester);

    await tester.pumpWidget(
      sceneApp(
        // As `showAiBarcodeScannerBatch` opens it, for a stock count.
        home: AiBarcodeScanner(
          scanMode: ScanMode.batch,
          formats: const <BarcodeFormat>[
            BarcodeFormat.ean13,
            BarcodeFormat.code128,
          ],
          enabledActionButtons: const <ScannerAction>{
            ScannerAction.cameraSwitch,
            ScannerAction.torch,
            ScannerAction.close,
          },
          galleryButtonType: GalleryButtonType.none,
          onScanComplete: (_) {},
        ),
      ),
    );
    await startCamera(tester);
    // A carton scanned a moment ago, then both codes on this one.
    camera.emit(
      scene.capture(const <Barcode>[
        Barcode(
          format: BarcodeFormat.ean13,
          type: BarcodeType.product,
          rawValue: '2004172403179',
          displayValue: '2004172403179',
        ),
      ]),
    );
    await advance(tester, const Duration(milliseconds: 1400));
    camera.emit(scene.capture(<Barcode>[_boxEan(scene), _serial(scene)]));
    await tester.pump();
    // Back at rest after the success flash, with three collected.
    await advance(tester, const Duration(milliseconds: 2150));
    await capture(tester, 'batch');
  });

  testWidgets('themed', variant: _ios, (tester) async {
    final scene = await loadScene(tester, 'box');
    setUpPhone(tester, FakeCameraPlatform(scene: scene));

    const brand = Color(0xFF8B7CFF);
    await tester.pumpWidget(
      sceneApp(
        home: AiBarcodeScanner(
          // Linear formats only, so the scan window turns wide.
          formats: const <BarcodeFormat>[
            BarcodeFormat.ean13,
            BarcodeFormat.upcA,
          ],
          theme: ScannerTheme.fromColors(
            primary: brand,
            surface: const Color(0xFF15131F),
          ).copyWith(controlSize: 54, borderRadius: 18),
          overlayConfig: const ScannerOverlayConfig(
            scannerBorder: ScannerBorder.full,
            borderRadius: 18,
            borderStrokeWidth: 3,
            scannerOverlayBackground: ScannerOverlayBackground.dim,
            backgroundColor: Color(0xB3100E1A),
            lineThickness: 3,
          ),
          labels: const ScannerLabels(scanHint: 'Scan the product barcode'),
          enabledActionButtons: const <ScannerAction>{
            ScannerAction.gallery,
            ScannerAction.torch,
            ScannerAction.zoom,
            ScannerAction.close,
          },
          galleryButtonType: GalleryButtonType.icon,
          torchEnabled: true,
          initialZoom: 0.3,
          onDetect: (_) {},
        ),
      ),
    );
    await startCamera(tester);
    await advance(tester, const Duration(milliseconds: 700));
    await capture(tester, 'themed');
  });

  testWidgets('embedded', variant: _ios, (tester) async {
    final scene = await loadScene(tester, 'box');
    final camera = FakeCameraPlatform(scene: scene);
    setUpPhone(tester, camera);
    silencePlatformChannels(tester);

    await tester.pumpWidget(
      sceneApp(
        theme: appTheme(Brightness.light),
        home: const ReceiveStockPage(),
      ),
    );
    await startCamera(tester);
    await advance(tester, const Duration(milliseconds: 400));
    camera.emit(scene.capture(<Barcode>[_boxEan(scene)]));
    await tester.pump();
    await advance(tester, const Duration(milliseconds: 1500));
    await capture(tester, 'embedded');
  });

  testWidgets('permission', variant: _ios, (tester) async {
    setUpPhone(
      tester,
      FakeCameraPlatform(
        startError: const MobileScannerException(
          errorCode: MobileScannerErrorCode.permissionDenied,
        ),
      ),
    );

    await tester.pumpWidget(
      sceneApp(
        home: AiBarcodeScanner(
          enabledActionButtons: _fullScreenActions,
          onOpenSettings: () {},
          onDetect: (_) {},
        ),
      ),
    );
    await startCamera(tester);
    await advance(tester, const Duration(milliseconds: 300));
    await capture(tester, 'permission');
  });

  testWidgets('flow animation', variant: _ios, (tester) async {
    final scene = await loadScene(tester, 'label');
    final camera = FakeCameraPlatform(scene: scene);
    setUpPhone(tester, camera);
    silencePlatformChannels(tester);

    await tester.pumpWidget(
      sceneApp(
        home: Builder(
          builder:
              (context) => AiBarcodeScanner(
                enabledActionButtons: _fullScreenActions,
                onDetect: (capture) async {
                  // Let the success flash register before the sheet covers it.
                  await Future<void>.delayed(const Duration(milliseconds: 350));
                  if (!context.mounted) return;
                  await BarcodeResultSheet.show(
                    context,
                    barcode: capture.barcodes.first,
                    onOpen: (_) {},
                    onShare: (_) {},
                  );
                },
              ),
        ),
      ),
    );
    await startCamera(tester);

    // 6 s at 20 fps — two sweeps of the scan line, so the loop is seamless:
    // scanning, the code is read, the result sheet comes up, and it is
    // dismissed so the loop returns to scanning.
    const frames = 120;
    const frame = Duration(milliseconds: 50);
    for (var i = 0; i < frames; i++) {
      if (i == 36) camera.emit(scene.capture(<Barcode>[_qr(scene)]));
      // A tap on the dimmed barrier above the sheet dismisses it.
      if (i == 94) await tester.tapAt(const Offset(196, 200));
      await capture(
        tester,
        'flow/frame_${i.toString().padLeft(3, '0')}',
        pixelRatio: 2,
      );
      await advance(tester, frame);
    }
  });
}

/// The QR code on the label, as the platform reports a URL payload.
Barcode _qr(CameraScene scene) => scene.barcode(
  'QRCode',
  format: BarcodeFormat.qrCode,
  type: BarcodeType.url,
  url: const UrlBookmark(url: _url),
);

/// The EAN-13 on the headphone box.
Barcode _boxEan(CameraScene scene) => scene.barcode(
  'EAN13',
  format: BarcodeFormat.ean13,
  type: BarcodeType.product,
);

/// The Code 128 serial number on the headphone box.
Barcode _serial(CameraScene scene) => scene.barcode(
  'Code128',
  format: BarcodeFormat.code128,
  type: BarcodeType.text,
);
