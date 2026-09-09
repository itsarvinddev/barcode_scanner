import 'package:ai_barcode_scanner/ai_barcode_scanner.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AiBarcodeX.bestValue', () {
    test('prefers displayValue', () {
      const barcode = Barcode(rawValue: 'WIFI:S:Home;;', displayValue: 'Home');
      expect(barcode.bestValue, 'Home');
    });

    test('falls back to rawValue', () {
      const barcode = Barcode(rawValue: 'raw');
      expect(barcode.bestValue, 'raw');
    });

    test('falls back to rawValue when displayValue is blank', () {
      const barcode = Barcode(rawValue: 'raw', displayValue: '');
      expect(barcode.bestValue, 'raw');
    });

    test('is empty for an empty barcode', () {
      expect(const Barcode().isEmpty, isTrue);
    });
  });

  group('AiBarcodeX.fields', () {
    test('flattens a Wi-Fi payload and marks the password sensitive', () {
      const barcode = Barcode(
        type: BarcodeType.wifi,
        wifi: WiFi(
          ssid: 'Home',
          password: 'hunter2',
          encryptionType: EncryptionType.wpa,
        ),
      );

      final fields = barcode.fields;
      expect(fields.map((f) => f.key), <String>[
        'wifi.ssid',
        'wifi.password',
        'wifi.security',
      ]);
      expect(fields[0].value, 'Home');
      expect(fields[1].obscure, isTrue);
      expect(fields[2].value, 'WPA/WPA2');
    });

    test('flattens a contact, skipping empty parts', () {
      const barcode = Barcode(
        type: BarcodeType.contactInfo,
        contactInfo: ContactInfo(
          name: PersonName(first: 'Ada', last: 'Lovelace'),
          organization: 'Analytical Engines',
          phones: <Phone>[Phone(number: '+441234567890')],
          emails: <Email>[Email(address: 'ada@example.com')],
        ),
      );

      final fields = barcode.fields;
      expect(
        fields.firstWhere((f) => f.key == 'contact.name').value,
        'Ada Lovelace',
      );
      expect(fields.any((f) => f.key == 'contact.title'), isFalse);
      expect(fields.any((f) => f.key == 'contact.phone'), isTrue);
    });

    test('is empty for a plain text payload', () {
      const barcode = Barcode(type: BarcodeType.text, rawValue: 'hello');
      expect(barcode.fields, isEmpty);
    });
  });

  group('AiBarcodeX.actionUri', () {
    test('builds a mailto with subject and body', () {
      const barcode = Barcode(
        type: BarcodeType.email,
        email: Email(address: 'a@b.com', subject: 'Hi', body: 'There'),
      );
      final uri = barcode.actionUri!;
      expect(uri.scheme, 'mailto');
      expect(uri.path, 'a@b.com');
      expect(uri.queryParameters['subject'], 'Hi');
    });

    test('omits the query when there is nothing to put in it', () {
      const barcode = Barcode(
        type: BarcodeType.email,
        email: Email(address: 'a@b.com'),
      );
      expect(barcode.actionUri.toString(), 'mailto:a@b.com');
    });

    test('builds a tel URI', () {
      const barcode = Barcode(
        type: BarcodeType.phone,
        phone: Phone(number: '+15551234'),
      );
      expect(barcode.actionUri?.scheme, 'tel');
    });

    test('builds a geo URI', () {
      const barcode = Barcode(
        type: BarcodeType.geo,
        geoPoint: GeoPoint(latitude: 51.5, longitude: -0.12),
      );
      expect(barcode.actionUri.toString(), 'geo:51.5,-0.12');
    });

    test('recognises a URL hiding in a text payload', () {
      const barcode = Barcode(
        type: BarcodeType.text,
        rawValue: 'https://example.com/x',
      );
      expect(barcode.actionUri?.host, 'example.com');
    });

    test('is null for a payload with no natural action', () {
      const barcode = Barcode(type: BarcodeType.text, rawValue: 'just words');
      expect(barcode.actionUri, isNull);
    });
  });

  group('AiBarcodeX.boundingBox', () {
    test('is null without corner points', () {
      expect(const Barcode().boundingBox, isNull);
    });

    test('is the extent of the corner points', () {
      const barcode = Barcode(
        corners: <Offset>[
          Offset(10, 20),
          Offset(50, 22),
          Offset(48, 60),
          Offset(12, 58),
        ],
      );
      expect(barcode.boundingBox, const Rect.fromLTRB(10, 20, 50, 60));
    });
  });

  group('AiBarcodeCaptureX', () {
    test('exposes the first barcode and all values', () {
      const capture = BarcodeCapture(
        barcodes: <Barcode>[
          Barcode(rawValue: 'one'),
          Barcode(rawValue: ''),
          Barcode(rawValue: 'two'),
        ],
      );
      expect(capture.firstRawValue, 'one');
      expect(capture.values, <String>['one', 'two']);
    });

    test('handles an empty capture', () {
      const capture = BarcodeCapture();
      expect(capture.firstBarcode, isNull);
      expect(capture.values, isEmpty);
    });
  });

  group('AiBarcodeFormatX', () {
    test('names every format', () {
      for (final format in BarcodeFormat.values) {
        expect(format.displayName, isNotEmpty, reason: '$format');
      }
    });

    test('classifies 2D and linear symbologies', () {
      expect(BarcodeFormat.qrCode.isTwoDimensional, isTrue);
      expect(BarcodeFormat.dataMatrix.isTwoDimensional, isTrue);
      expect(BarcodeFormat.ean13.isTwoDimensional, isFalse);
      expect(BarcodeFormat.code128.isTwoDimensional, isFalse);
    });
  });
}
