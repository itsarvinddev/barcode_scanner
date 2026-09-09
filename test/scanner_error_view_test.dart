import 'package:ai_barcode_scanner/ai_barcode_scanner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pumpError(
  WidgetTester tester,
  MobileScannerException error, {
  VoidCallback? onRetry,
  VoidCallback? onOpenSettings,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ScannerErrorView(
          error: error,
          onRetry: onRetry,
          onOpenSettings: onOpenSettings,
        ),
      ),
    ),
  );
}

void main() {
  const labels = ScannerLabels();

  testWidgets('a permission denial says so, and offers settings', (
    tester,
  ) async {
    // 7.x rendered `errorDetails?.message ?? 'An unknown error occurred.'`,
    // and a permission denial carries no details — so the most common failure
    // showed the least useful copy.
    await pumpError(
      tester,
      const MobileScannerException(
        errorCode: MobileScannerErrorCode.permissionDenied,
      ),
      onOpenSettings: () {},
    );

    expect(find.text(labels.permissionDeniedTitle), findsOneWidget);
    expect(find.text(labels.permissionDeniedMessage), findsOneWidget);
    expect(find.text(labels.openSettingsButton), findsOneWidget);
    expect(find.textContaining('unknown'), findsNothing);
  });

  testWidgets('the settings button is hidden without a handler', (
    tester,
  ) async {
    await pumpError(
      tester,
      const MobileScannerException(
        errorCode: MobileScannerErrorCode.permissionDenied,
      ),
    );

    expect(find.text(labels.openSettingsButton), findsNothing);
  });

  testWidgets('an unsupported device gets its own copy and no retry', (
    tester,
  ) async {
    await pumpError(
      tester,
      const MobileScannerException(
        errorCode: MobileScannerErrorCode.unsupported,
      ),
      onRetry: () {},
    );

    expect(find.text(labels.cameraUnsupportedTitle), findsOneWidget);
    expect(
      find.text(labels.retryButton),
      findsNothing,
      reason: 'retrying cannot conjure a camera',
    );
  });

  testWidgets('a generic failure surfaces the platform detail', (tester) async {
    await pumpError(
      tester,
      const MobileScannerException(
        errorCode: MobileScannerErrorCode.genericError,
        errorDetails: MobileScannerErrorDetails(message: 'Camera in use'),
      ),
      onRetry: () {},
    );

    expect(find.text(labels.cameraErrorTitle), findsOneWidget);
    expect(find.text('Camera in use'), findsOneWidget);
    expect(find.text(labels.retryButton), findsOneWidget);
  });

  testWidgets('a detail-less generic failure falls back to the code message', (
    tester,
  ) async {
    await pumpError(
      tester,
      const MobileScannerException(
        errorCode: MobileScannerErrorCode.controllerUninitialized,
      ),
    );

    expect(
      find.text(MobileScannerErrorCode.controllerUninitialized.message),
      findsOneWidget,
    );
  });

  testWidgets('retry is wired up', (tester) async {
    var retried = 0;
    await pumpError(
      tester,
      const MobileScannerException(
        errorCode: MobileScannerErrorCode.genericError,
      ),
      onRetry: () => retried++,
    );

    await tester.tap(find.text(labels.retryButton));
    await tester.pump();

    expect(retried, 1);
  });

  testWidgets('the unsupported-platform view names the platform', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ScannerUnsupportedPlatformView())),
    );

    expect(find.text(labels.unsupportedPlatformTitle), findsOneWidget);
    expect(
      find.textContaining(ScannerPlatformSupport.currentPlatformName),
      findsOneWidget,
    );
  });
}
