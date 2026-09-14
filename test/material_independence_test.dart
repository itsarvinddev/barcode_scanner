// Issue #198: Flutter 3.47 decoupled Material into `package:material_ui`, whose
// MaterialApp provides none of the `flutter/material` ambient state this
// package's widgets were written against — no Theme, no MaterialLocalizations,
// no ScaffoldMessenger, no Material. A bare WidgetsApp is the same host without
// the extra package, so these tests use one: if the scanner works there, it
// works in a `material_ui` app without MaterialUiCompatibilityBridge.
//
// The second half pins the other side of the bargain: a classic MaterialApp
// must see exactly what it saw before.

import 'dart:async';

import 'package:ai_barcode_scanner/ai_barcode_scanner.dart';
import 'package:flutter/cupertino.dart' show CupertinoLocalizations;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_mobile_scanner_platform.dart';

const _staticOverlay = ScannerOverlayConfig(
  scannerAnimation: ScannerAnimation.none,
  scannerOverlayBackground: ScannerOverlayBackground.dim,
);

const _labels = ScannerLabels();

const _urlBarcode = Barcode(
  rawValue: 'https://example.com/a',
  type: BarcodeType.url,
  url: UrlBookmark(url: 'https://example.com/a'),
);

const _textBarcode = Barcode(rawValue: 'hello scanner world');

const _locales = <Locale>[Locale('en'), Locale('de'), Locale('ar')];

final _hostKey = GlobalKey(debugLabel: 'host page');

/// What both `MaterialApp`s give text that is not inside a Material: loud on
/// purpose, so a missing text style is obvious. The fallback sheet has to
/// replace it.
const _loudTextStyle = TextStyle(
  color: Color(0xD0FF0000),
  fontSize: 48,
  decoration: TextDecoration.underline,
  decorationColor: Color(0xFFFFFF00),
  decorationStyle: TextDecorationStyle.double,
);

/// Widgets localizations that report right-to-left for Arabic, standing in for
/// `GlobalWidgetsLocalizations` so the package needs no extra dev dependency.
class _TestWidgetsLocalizations extends DefaultWidgetsLocalizations {
  const _TestWidgetsLocalizations(this.textDirection);

  @override
  final TextDirection textDirection;
}

class _TestWidgetsLocalizationsDelegate
    extends LocalizationsDelegate<WidgetsLocalizations> {
  const _TestWidgetsLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<WidgetsLocalizations> load(Locale locale) =>
      SynchronousFuture<WidgetsLocalizations>(
        _TestWidgetsLocalizations(
          locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr,
        ),
      );

  @override
  bool shouldReload(_TestWidgetsLocalizationsDelegate old) => false;
}

TextDirection _directionFor(Locale locale) =>
    locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr;

/// A host app with no `flutter/material` state anywhere above [home].
Widget _widgetsHost({
  required Widget home,
  Locale locale = const Locale('en'),
  List<LocalizationsDelegate<dynamic>> delegates =
      const <LocalizationsDelegate<dynamic>>[],
  TransitionBuilder? builder,
}) {
  return WidgetsApp(
    builder: builder,
    color: const Color(0xFF2196F3),
    locale: locale,
    supportedLocales: _locales,
    localizationsDelegates: <LocalizationsDelegate<dynamic>>[
      ...delegates,
      const _TestWidgetsLocalizationsDelegate(),
    ],
    textStyle: _loudTextStyle,
    pageRouteBuilder:
        <T>(RouteSettings settings, WidgetBuilder builder) =>
            PageRouteBuilder<T>(
              settings: settings,
              pageBuilder: (context, _, _) => builder(context),
            ),
    home: KeyedSubtree(key: _hostKey, child: home),
  );
}

/// Guards the premise of every test in the first group.
void _expectNoMaterialInHost(WidgetTester tester) {
  final context = tester.element(find.byKey(_hostKey));
  expect(
    Localizations.of<MaterialLocalizations>(context, MaterialLocalizations),
    isNull,
  );
  expect(context.findAncestorWidgetOfExactType<Theme>(), isNull);
  expect(ScaffoldMessenger.maybeOf(context), isNull);
  expect(Material.maybeOf(context), isNull);
}

/// The background colour of the surface of the filled button labelled
/// [label].
Color? _filledButtonColor(WidgetTester tester, String label) {
  final button = find.ancestor(
    of: find.text(label),
    matching: find.byWidgetPredicate((widget) => widget is FilledButton),
  );
  final surface = find.descendant(of: button, matching: find.byType(Material));
  return tester.widget<Material>(surface.first).color;
}

void main() {
  late FakeMobileScannerPlatform platform;
  String? clipboardText;

  setUp(() {
    platform = FakeMobileScannerPlatform();
    MobileScannerPlatform.instance = platform;
    clipboardText = null;
    TestWidgetsFlutterBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          switch (call.method) {
            case 'Clipboard.setData':
              final arguments = call.arguments as Map<Object?, Object?>;
              clipboardText = arguments['text'] as String?;
              return null;
            case 'Clipboard.hasStrings':
              return <String, Object?>{'value': clipboardText != null};
            case 'Clipboard.getData':
              return <String, Object?>{'text': clipboardText};
          }
          return null;
        });
  });

  tearDown(() {
    TestWidgetsFlutterBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
    MobileScannerController.resetPlatformSessionOwner();
  });

  group('in a host without flutter/material', () {
    for (final locale in _locales) {
      final direction = _directionFor(locale);

      group('locale ${locale.languageCode}', () {
        testWidgets('the full-screen scanner, app bar and close action work', (
          tester,
        ) async {
          await tester.pumpWidget(
            _widgetsHost(locale: locale, home: const SizedBox.expand()),
          );
          _expectNoMaterialInHost(tester);

          var closed = false;
          unawaited(
            showAiBarcodeScanner(
              tester.element(find.byKey(_hostKey)),
              overlayConfig: _staticOverlay,
              enabledActionButtons: const <ScannerAction>{
                ScannerAction.close,
                ScannerAction.torch,
                ScannerAction.zoom,
              },
            ).then((_) => closed = true),
          );
          await tester.pumpAndSettle();

          // AppBar asserts MaterialLocalizations; before 8.1 this threw.
          expect(tester.takeException(), isNull);
          expect(find.byType(AppBar), findsOneWidget);
          expect(
            Directionality.of(tester.element(find.byType(ScannerControlsBar))),
            direction,
            reason: 'the host text direction survives the override',
          );

          await tester.longPress(find.byTooltip(_labels.closeTooltip));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          await tester.tap(find.byTooltip(_labels.closeTooltip));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(closed, isTrue);
          expect(find.byType(AiBarcodeScanner), findsNothing);
        });

        testWidgets('the embedded scanner, its controls and zoom slider work', (
          tester,
        ) async {
          await tester.pumpWidget(
            _widgetsHost(
              locale: locale,
              home: const Center(
                child: SizedBox(
                  width: 320,
                  height: 480,
                  child: AiBarcodeScanner.embedded(
                    overlayConfig: _staticOverlay,
                    enabledActionButtons: <ScannerAction>{
                      ScannerAction.torch,
                      ScannerAction.zoom,
                    },
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          _expectNoMaterialInHost(tester);
          expect(tester.takeException(), isNull);

          await tester.tap(find.byIcon(Icons.flashlight_off_outlined));
          await tester.pumpAndSettle();
          expect(platform.toggleTorchCount, 1);

          // Slider asserts a Material ancestor, and there is none here. Drag
          // towards the "more zoom" end, which flips with the text direction.
          final towardsMore = direction == TextDirection.rtl ? -80.0 : 80.0;
          await tester.drag(find.byType(Slider), Offset(towardsMore, 0));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(platform.zoomScaleCalls, isNotEmpty);
          expect(platform.zoomScaleCalls.last, greaterThan(0));
        });

        testWidgets('BarcodeResultSheet.show opens, copies, opens and closes', (
          tester,
        ) async {
          final semantics = tester.ensureSemantics();
          await tester.pumpWidget(
            _widgetsHost(locale: locale, home: const SizedBox.expand()),
          );
          _expectNoMaterialInHost(tester);

          final opened = <Uri>[];
          var dismissed = false;
          unawaited(
            BarcodeResultSheet.show(
              tester.element(find.byKey(_hostKey)),
              barcode: _urlBarcode,
              onOpen: opened.add,
            ).then((_) => dismissed = true),
          );
          await tester.pumpAndSettle();

          // showModalBottomSheet asserts MaterialLocalizations; before 8.1
          // this threw instead of opening.
          expect(tester.takeException(), isNull);
          expect(find.byType(BarcodeResultSheet), findsOneWidget);
          expect(find.byType(BottomSheet), findsNothing);

          final sheet = tester.element(find.byType(BarcodeResultSheet));
          expect(Directionality.of(sheet), direction);
          expect(
            DefaultTextStyle.of(sheet).style.decoration,
            isNot(TextDecoration.underline),
            reason: "the host's loud missing-Material style is replaced",
          );
          expect(
            find.bySemanticsLabel(_labels.dismissSheetLabel),
            findsWidgets,
          );

          // Styled from the scanner's palette, not ThemeData.fallback().
          expect(
            _filledButtonColor(tester, _labels.openAction),
            ScannerTheme.fallback.controlActiveBackgroundColor,
          );
          await tester.tap(find.text(_labels.openAction));
          await tester.pumpAndSettle();
          expect(opened, <Uri>[Uri.parse('https://example.com/a')]);

          // No ScaffoldMessenger, so the button confirms the copy itself.
          await tester.tap(find.text(_labels.copyAction));
          await tester.pump();
          expect(clipboardText, 'https://example.com/a');
          expect(find.text(_labels.copiedConfirmation), findsOneWidget);
          expect(find.byType(SnackBar), findsNothing);
          expect(tester.takeException(), isNull);

          await tester.pump(const Duration(seconds: 2));
          await tester.pumpAndSettle();
          expect(find.text(_labels.copiedConfirmation), findsNothing);
          expect(find.text(_labels.copyAction), findsOneWidget);

          // The barrier dismisses the sheet and completes the future.
          await tester.tapAt(const Offset(8, 8));
          await tester.pumpAndSettle();
          expect(find.byType(BarcodeResultSheet), findsNothing);
          expect(dismissed, isTrue);
          expect(tester.takeException(), isNull);
          semantics.dispose();
        });

        testWidgets('the fallback sheet can be dragged down to dismiss', (
          tester,
        ) async {
          await tester.pumpWidget(
            _widgetsHost(locale: locale, home: const SizedBox.expand()),
          );

          var dismissed = false;
          unawaited(
            BarcodeResultSheet.show(
              tester.element(find.byKey(_hostKey)),
              barcode: _urlBarcode,
            ).then((_) => dismissed = true),
          );
          await tester.pumpAndSettle();

          // A short drag springs back.
          await tester.drag(
            find.byIcon(_urlBarcode.typeIcon),
            const Offset(0, 20),
          );
          await tester.pumpAndSettle();
          expect(find.byType(BarcodeResultSheet), findsOneWidget);
          expect(dismissed, isFalse);

          // A fling closes it.
          await tester.fling(
            find.byIcon(_urlBarcode.typeIcon),
            const Offset(0, 200),
            1500,
          );
          await tester.pumpAndSettle();
          expect(find.byType(BarcodeResultSheet), findsNothing);
          expect(dismissed, isTrue);
          expect(tester.takeException(), isNull);
        });

        testWidgets('the permission error view and retry work', (tester) async {
          platform = FakeMobileScannerPlatform(
            startError: const MobileScannerException(
              errorCode: MobileScannerErrorCode.permissionDenied,
            ),
          );
          MobileScannerPlatform.instance = platform;
          var settingsOpened = 0;

          await tester.pumpWidget(
            _widgetsHost(
              locale: locale,
              home: AiBarcodeScanner(
                overlayConfig: _staticOverlay,
                onOpenSettings: () => settingsOpened++,
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.text(_labels.permissionDeniedTitle), findsOneWidget);

          expect(
            _filledButtonColor(tester, _labels.retryButton),
            ScannerTheme.fallback.controlActiveBackgroundColor,
          );

          await tester.tap(find.text(_labels.retryButton));
          await tester.pumpAndSettle();
          await tester.tap(find.text(_labels.openSettingsButton));
          await tester.pumpAndSettle();
          expect(settingsOpened, 1);
          expect(tester.takeException(), isNull);

          // And on its own, outside the scanner.
          var retried = 0;
          await tester.pumpWidget(
            _widgetsHost(
              locale: locale,
              home: ScannerErrorView(
                error: const MobileScannerException(
                  errorCode: MobileScannerErrorCode.permissionDenied,
                ),
                onRetry: () => retried++,
              ),
            ),
          );
          await tester.tap(find.text(_labels.retryButton));
          await tester.pumpAndSettle();
          expect(retried, 1);
          expect(tester.takeException(), isNull);
        });
      });
    }

    for (final targetPlatform in <TargetPlatform>[
      TargetPlatform.android,
      TargetPlatform.iOS,
    ]) {
      testWidgets(
        'the selectable text menu resolves its labels on ${targetPlatform.name}',
        (tester) async {
          // The toolbar picks its Material or Cupertino flavour from
          // Theme.of(context).platform. With no Theme at all that is a cached
          // ThemeData.fallback(), whose platform is whatever it was first
          // created on — so this host pins it with a Theme above the navigator.
          // Localizations are still missing, which is what matters here.
          await tester.pumpWidget(
            _widgetsHost(
              locale: const Locale('de'),
              builder:
                  (context, child) => Theme(
                    data: ThemeData(platform: targetPlatform),
                    child: child!,
                  ),
              home: const Align(
                alignment: Alignment.bottomCenter,
                child: BarcodeResultSheet(barcode: _textBarcode),
              ),
            ),
          );
          final host = tester.element(find.byKey(_hostKey));
          expect(
            Localizations.of<MaterialLocalizations>(
              host,
              MaterialLocalizations,
            ),
            isNull,
          );
          expect(
            Localizations.of<CupertinoLocalizations>(
              host,
              CupertinoLocalizations,
            ),
            isNull,
          );

          // The toolbar is built in the navigator's overlay, outside the
          // sheet, and reads Material (Android) or Cupertino (iOS)
          // localizations for its button labels.
          await tester.longPress(find.byType(SelectableText));
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          final toolbar = find.byType(AdaptiveTextSelectionToolbar);
          expect(toolbar, findsOneWidget);
          expect(
            find.descendant(
              of: toolbar,
              matching: find.text(
                targetPlatform == TargetPlatform.iOS
                    ? 'Select All'
                    : 'Select all',
              ),
            ),
            findsOneWidget,
          );
        },
        variant: TargetPlatformVariant.only(targetPlatform),
      );
    }

    testWidgets('show() from inside the scanner still uses the fallback', (
      tester,
    ) async {
      // A context inside the scanner resolves the localizations the scanner
      // supplied, but the sheet is built under the navigator, which has none.
      BuildContext? inside;
      await tester.pumpWidget(
        _widgetsHost(
          home: AiBarcodeScanner.embedded(
            overlayConfig: _staticOverlay,
            child: Builder(
              builder: (context) {
                inside = context;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        Localizations.of<MaterialLocalizations>(inside!, MaterialLocalizations),
        isNotNull,
      );

      unawaited(BarcodeResultSheet.show(inside!, barcode: _textBarcode));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(BarcodeResultSheet), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
    });

    testWidgets('a custom barrier label is used', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_widgetsHost(home: const SizedBox.expand()));

      unawaited(
        BarcodeResultSheet.show(
          tester.element(find.byKey(_hostKey)),
          barcode: _textBarcode,
          labels: const ScannerLabels(dismissSheetLabel: 'Schließen'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Schließen'), findsWidgets);
      semantics.dispose();
    });

    testWidgets('the batch Done button is legible while disabled', (
      tester,
    ) async {
      await tester.pumpWidget(
        _widgetsHost(
          home: const AiBarcodeScanner(
            overlayConfig: _staticOverlay,
            scanMode: ScanMode.batch,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        _filledButtonColor(tester, _labels.doneButton),
        ScannerTheme.fallback.controlBackgroundColor,
        reason: 'no ThemeData.fallback() grey over the preview',
      );
    });

    testWidgets('a rejected scan shows and announces invalidBarcode', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _widgetsHost(
          home: AiBarcodeScanner(
            overlayConfig: _staticOverlay,
            feedback: const ScannerFeedbackConfig.silent(),
            validator: (_) => false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      _expectNoMaterialInHost(tester);

      platform.emitBarcode(
        const BarcodeCapture(barcodes: <Barcode>[Barcode(rawValue: 'no')]),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text(_labels.invalidBarcode), findsOneWidget);
      expect(
        tester.getSemantics(find.text(_labels.invalidBarcode)),
        isSemantics(label: _labels.invalidBarcode, isLiveRegion: true),
      );

      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.text(_labels.invalidBarcode), findsNothing);
      expect(find.text(_labels.scanHint), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('gaining Material localizations keeps the preview mounted', (
      tester,
    ) async {
      Widget host({required bool material}) => _widgetsHost(
        delegates: <LocalizationsDelegate<dynamic>>[
          if (material) DefaultMaterialLocalizations.delegate,
        ],
        home: const AiBarcodeScanner.embedded(overlayConfig: _staticOverlay),
      );

      await tester.pumpWidget(host(material: false));
      await tester.pumpAndSettle();
      final starts = platform.startCalls.length;
      final preview = tester.state(find.byType(MobileScanner));

      // The override above the preview comes and goes; the preview's own
      // state — and with it the platform camera view — must survive both.
      await tester.pumpWidget(host(material: true));
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(MobileScanner)), same(preview));

      await tester.pumpWidget(host(material: false));
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(MobileScanner)), same(preview));

      expect(tester.takeException(), isNull);
      expect(platform.startCalls.length, starts);
    });

    testWidgets('a tree with no Localizations at all is left alone', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(size: Size(400, 800)),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: AiBarcodeScanner.embedded(overlayConfig: _staticOverlay),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(Localizations), findsNothing);
      expect(
        Directionality.of(tester.element(find.byType(ScannerOverlay))),
        TextDirection.rtl,
      );
    });
  });

  group('in a classic MaterialApp, nothing changes', () {
    final hostTheme = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFE91E63)),
    );

    testWidgets('show() is showModalBottomSheet, with a SnackBar on copy', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: hostTheme,
          home: Scaffold(
            body: KeyedSubtree(key: _hostKey, child: const SizedBox.expand()),
          ),
        ),
      );

      unawaited(
        BarcodeResultSheet.show(
          tester.element(find.byKey(_hostKey)),
          barcode: _urlBarcode,
          onOpen: (_) {},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsOneWidget);
      expect(
        _filledButtonColor(tester, _labels.openAction),
        hostTheme.colorScheme.primary,
      );

      await tester.tap(find.text(_labels.copyAction));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text(_labels.copiedConfirmation), findsOneWidget);
      // The button itself does not change: the SnackBar is the confirmation.
      expect(find.text(_labels.copyAction), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Retry follows the host colour scheme', (tester) async {
      platform = FakeMobileScannerPlatform(
        startError: const MobileScannerException(
          errorCode: MobileScannerErrorCode.permissionDenied,
        ),
      );
      MobileScannerPlatform.instance = platform;

      await tester.pumpWidget(
        MaterialApp(
          theme: hostTheme,
          home: const AiBarcodeScanner(overlayConfig: _staticOverlay),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(_labels.retryButton), findsOneWidget);
      expect(
        _filledButtonColor(tester, _labels.retryButton),
        hostTheme.colorScheme.primary,
      );
    });

    testWidgets('the scanner adds no Localizations and no extra Material', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: hostTheme,
          home: const AiBarcodeScanner(
            overlayConfig: _staticOverlay,
            enabledActionButtons: <ScannerAction>{
              ScannerAction.close,
              ScannerAction.zoom,
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(AiBarcodeScanner),
          matching: find.byType(Localizations),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(ScannerZoomSlider),
          matching: find.byType(Material),
        ),
        findsNothing,
        reason: 'the Scaffold already provides the Material the slider needs',
      );
    });

    testWidgets('the disabled Done button keeps the host theme colours', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: hostTheme,
          home: const AiBarcodeScanner(
            overlayConfig: _staticOverlay,
            scanMode: ScanMode.batch,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        _filledButtonColor(tester, _labels.doneButton),
        isSameColorAs(hostTheme.colorScheme.onSurface.withValues(alpha: 0.12)),
      );
    });
  });
}
