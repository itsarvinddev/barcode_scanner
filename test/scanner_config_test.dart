import 'package:ai_barcode_scanner/ai_barcode_scanner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ScannerTheme', () {
    test('resolve fills every null from the fallback', () {
      const theme = ScannerTheme(reticleColor: Color(0xFF00FF00));
      final resolved = theme.resolve();

      expect(resolved.reticleColor, const Color(0xFF00FF00));
      expect(resolved.controlSize, ScannerTheme.fallback.controlSize);
      expect(resolved.hintTextStyle, isNotNull);
      expect(resolved.overlayBlurSigma, isNotNull);
    });

    test('fallback has no nulls, so widgets can bang every field', () {
      const f = ScannerTheme.fallback;
      expect(<Object?>[
        f.reticleColor,
        f.reticleSuccessColor,
        f.reticleErrorColor,
        f.reticleStrokeWidth,
        f.scanLineColor,
        f.overlayColor,
        f.overlayBlurSigma,
        f.controlBackgroundColor,
        f.controlForegroundColor,
        f.controlActiveBackgroundColor,
        f.controlActiveForegroundColor,
        f.controlSize,
        f.controlSpacing,
        f.barcodeHighlightColor,
        f.barcodeHighlightStrokeWidth,
        f.focusRingColor,
        f.hintTextStyle,
        f.hintBackgroundColor,
        f.surfaceColor,
        f.onSurfaceColor,
        f.borderRadius,
      ], everyElement(isNotNull));
    });

    test('fromColorScheme picks up the brand colours', () {
      final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF6750A4));
      final theme = ScannerTheme.fromColorScheme(scheme);

      expect(theme.reticleColor, scheme.primary);
      expect(theme.reticleErrorColor, scheme.error);
    });

    test(
      'equality is by value, so the scope only notifies on real changes',
      () {
        const a = ScannerTheme(reticleColor: Color(0xFF112233));
        const b = ScannerTheme(reticleColor: Color(0xFF112233));
        const c = ScannerTheme(reticleColor: Color(0xFF332211));

        expect(a, b);
        expect(a.hashCode, b.hashCode);
        expect(a, isNot(c));
      },
    );

    testWidgets('of() returns the scoped theme, or the fallback', (
      tester,
    ) async {
      late ScannerTheme scoped;
      late ScannerTheme bare;

      await tester.pumpWidget(
        Column(
          children: <Widget>[
            ScannerThemeScope(
              theme: const ScannerTheme(controlSize: 99).resolve(),
              child: Builder(
                builder: (context) {
                  scoped = ScannerTheme.of(context);
                  return const SizedBox();
                },
              ),
            ),
            Builder(
              builder: (context) {
                bare = ScannerTheme.of(context);
                return const SizedBox();
              },
            ),
          ],
        ),
      );

      expect(scoped.controlSize, 99);
      expect(bare, ScannerTheme.fallback);
    });
  });

  group('ScannerLabels', () {
    test('copyWith replaces only what it is given', () {
      const labels = ScannerLabels(galleryButton: 'Pick');
      final copy = labels.copyWith(scanHint: 'Aim');

      expect(copy.galleryButton, 'Pick');
      expect(copy.scanHint, 'Aim');
      expect(copy.doneButton, const ScannerLabels().doneButton);
    });

    test('field and type labels fall back to the English default', () {
      const labels = ScannerLabels(
        barcodeFieldLabels: <String, String>{'wifi.ssid': 'Reseau'},
        barcodeTypeLabels: <String, String>{'wifi': 'Wi-Fi FR'},
      );

      expect(labels.fieldLabel('wifi.ssid', 'Network'), 'Reseau');
      expect(labels.fieldLabel('wifi.password', 'Password'), 'Password');
      expect(labels.typeLabel('wifi', 'Wi-Fi'), 'Wi-Fi FR');
      expect(labels.typeLabel('url', 'Link'), 'Link');
    });

    test('pluralises the scanned count', () {
      const labels = ScannerLabels();
      expect(labels.scannedCountLabel(1), '1 scanned');
      expect(labels.scannedCountLabel(3), '3 scanned');
    });
  });

  group('ScannerFeedbackConfig', () {
    test(
      'silent disables haptics and sound but still reports events',
      () async {
        final events = <ScannerFeedbackEvent>[];
        final config = ScannerFeedbackConfig.silent(onFeedback: events.add);

        expect(config.detectHaptic, ScannerHaptic.none);
        expect(config.playSystemSound, isFalse);

        await config.play(ScannerFeedbackEvent.detect);
        expect(events, <ScannerFeedbackEvent>[ScannerFeedbackEvent.detect]);
      },
    );

    test('copyWith keeps unrelated fields', () {
      const config = ScannerFeedbackConfig(detectHaptic: ScannerHaptic.light);
      final copy = config.copyWith(playSystemSound: false);

      expect(copy.detectHaptic, ScannerHaptic.light);
      expect(copy.playSystemSound, isFalse);
    });
  });

  group('ScanValidators', () {
    BarcodeCapture capture(String value, {BarcodeFormat? format}) {
      return BarcodeCapture(
        barcodes: <Barcode>[
          Barcode(rawValue: value, format: format ?? BarcodeFormat.qrCode),
        ],
      );
    }

    test('all requires every validator to accept', () {
      final validator = ScanValidators.all(<bool Function(BarcodeCapture)>[
        ScanValidators.startsWith('https://'),
        ScanValidators.contains('example'),
      ]);

      expect(validator(capture('https://example.com')), isTrue);
      expect(validator(capture('https://other.com')), isFalse);
    });

    test('either accepts when any validator accepts', () {
      final validator = ScanValidators.either(<bool Function(BarcodeCapture)>[
        ScanValidators.startsWith('A'),
        ScanValidators.startsWith('B'),
      ]);

      expect(validator(capture('Bravo')), isTrue);
      expect(validator(capture('Charlie')), isFalse);
    });

    test('formats matches on the symbology', () {
      final validator = ScanValidators.formats(<BarcodeFormat>{
        BarcodeFormat.ean13,
      });

      expect(validator(capture('x', format: BarcodeFormat.ean13)), isTrue);
      expect(validator(capture('x', format: BarcodeFormat.qrCode)), isFalse);
    });

    test('matches anchors the whole value', () {
      final validator = ScanValidators.matches(RegExp(r'\d{4}'));

      expect(validator(capture('1234')), isTrue);
      expect(validator(capture('12345')), isFalse);
      expect(validator(capture('12a4')), isFalse);
    });

    test('matches backtracks across alternations', () {
      // `matchAsPrefix` takes the first alternative that fits and never
      // backtracks, so hand-anchoring rejects 'ab' here even though the
      // pattern matches it.
      final validator = ScanValidators.matches(RegExp('a|ab'));

      expect(validator(capture('a')), isTrue);
      expect(validator(capture('ab')), isTrue);
      expect(validator(capture('abc')), isFalse);
    });

    test('matches respects the pattern flags', () {
      final validator = ScanValidators.matches(
        RegExp('abc', caseSensitive: false),
      );

      expect(validator(capture('ABC')), isTrue);
      expect(validator(capture('abcd')), isFalse);
    });

    test('matches does not let a newline sneak past the anchor', () {
      final validator = ScanValidators.matches(RegExp(r'\d{4}'));

      expect(validator(capture('1234\nevil')), isFalse);
    });

    test('url can be restricted to a host allowlist', () {
      final validator = ScanValidators.url(
        allowedHosts: <String>{'example.com'},
      );

      expect(validator(capture('https://example.com/a')), isTrue);
      expect(validator(capture('https://evil.com/a')), isFalse);
      expect(validator(capture('not a url')), isFalse);
    });

    test('every validator rejects an empty capture', () {
      const empty = BarcodeCapture();
      expect(ScanValidators.startsWith('a')(empty), isFalse);
      expect(ScanValidators.url()(empty), isFalse);
      expect(ScanValidators.length(3)(empty), isFalse);
      expect(
        ScanValidators.formats(<BarcodeFormat>{BarcodeFormat.qrCode})(empty),
        isFalse,
      );
    });
  });

  group('BarcodeFormatSets', () {
    test('every 2D preset entry really is 2D', () {
      for (final format in BarcodeFormatSets.twoDimensional) {
        expect(format.isTwoDimensional, isTrue, reason: '$format');
      }
    });

    test('the retail preset is all linear', () {
      for (final format in BarcodeFormatSets.retail) {
        expect(format.isTwoDimensional, isFalse, reason: '$format');
      }
    });
  });
}
