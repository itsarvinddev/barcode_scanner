import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// A single label/value pair extracted from a structured barcode payload.
///
/// [key] is a stable, non-localised identifier (`'wifi.ssid'`, `'contact.name'`,
/// …). Use it to look up a translated label; [label] is the English fallback.
@immutable
class BarcodeField {
  /// Creates a label/value pair.
  const BarcodeField({
    required this.key,
    required this.label,
    required this.value,
    this.obscure = false,
  });

  /// Stable identifier for translation lookups.
  final String key;

  /// English label, used when no translation is supplied.
  final String label;

  /// The already-formatted value.
  final String value;

  /// Whether the value is sensitive and should be masked by default
  /// (currently only the Wi-Fi password).
  final bool obscure;

  @override
  bool operator ==(Object other) =>
      other is BarcodeField &&
      other.key == key &&
      other.label == label &&
      other.value == value &&
      other.obscure == obscure;

  @override
  int get hashCode => Object.hash(key, label, value, obscure);

  @override
  String toString() => 'BarcodeField($key: $value)';
}

/// Builds a query string with percent encoding rather than form encoding.
///
/// `Uri(queryParameters: …)` applies `application/x-www-form-urlencoded`, which
/// turns a space into `+`. Mail and SMS clients render that literally.
String _percentEncodedQuery(Map<String, String> parameters) {
  return parameters.entries
      .map(
        (e) =>
            '${Uri.encodeQueryComponent(e.key)}='
            '${Uri.encodeComponent(e.value)}',
      )
      .join('&');
}

/// Presentation helpers for a scanned [Barcode].
///
/// `mobile_scanner` hands back a rich, strongly typed payload (Wi-Fi networks,
/// contacts, calendar events, …) but leaves presentation entirely to the app.
/// These helpers turn that payload into something you can put on screen or act
/// on without writing a `switch` over every [BarcodeType].
extension AiBarcodeX on Barcode {
  /// The most presentable string for this barcode.
  ///
  /// Prefers [displayValue] (which ML Kit normalises — e.g. it strips the
  /// `WIFI:` prefix) and falls back to [rawValue].
  String get bestValue {
    final display = displayValue;
    if (display != null && display.isNotEmpty) return display;
    return rawValue ?? '';
  }

  /// Whether this barcode carried no readable payload at all.
  bool get isEmpty => bestValue.isEmpty;

  /// A Material icon that represents the kind of content in this barcode.
  IconData get typeIcon {
    switch (type) {
      case BarcodeType.contactInfo:
        return Icons.person_outline;
      case BarcodeType.email:
        return Icons.alternate_email;
      case BarcodeType.isbn:
        return Icons.menu_book_outlined;
      case BarcodeType.phone:
        return Icons.call_outlined;
      case BarcodeType.product:
        return Icons.shopping_bag_outlined;
      case BarcodeType.sms:
        return Icons.sms_outlined;
      case BarcodeType.text:
        return Icons.notes_outlined;
      case BarcodeType.url:
        return Icons.link_outlined;
      case BarcodeType.wifi:
        return Icons.wifi_outlined;
      case BarcodeType.geo:
        return Icons.place_outlined;
      case BarcodeType.calendarEvent:
        return Icons.event_outlined;
      case BarcodeType.driverLicense:
        return Icons.badge_outlined;
      case BarcodeType.unknown:
        return Icons.qr_code_2_outlined;
    }
  }

  /// An English name for the kind of content in this barcode.
  ///
  /// Override this in the UI with a translated string keyed on [type] when you
  /// need localisation.
  String get typeLabel {
    switch (type) {
      case BarcodeType.contactInfo:
        return 'Contact';
      case BarcodeType.email:
        return 'Email';
      case BarcodeType.isbn:
        return 'ISBN';
      case BarcodeType.phone:
        return 'Phone';
      case BarcodeType.product:
        return 'Product';
      case BarcodeType.sms:
        return 'SMS';
      case BarcodeType.text:
        return 'Text';
      case BarcodeType.url:
        return 'Link';
      case BarcodeType.wifi:
        return 'Wi-Fi';
      case BarcodeType.geo:
        return 'Location';
      case BarcodeType.calendarEvent:
        return 'Event';
      case BarcodeType.driverLicense:
        return 'ID document';
      case BarcodeType.unknown:
        return 'Barcode';
    }
  }

  /// A URI that represents the natural "open" action for this barcode, or
  /// `null` when there is no sensible one.
  ///
  /// The package deliberately does not depend on `url_launcher`; hand the
  /// result to whichever launcher your app already uses.
  Uri? get actionUri {
    switch (type) {
      case BarcodeType.url:
        final raw = url?.url ?? bestValue;
        final parsed = Uri.tryParse(raw);
        // `Uri.tryParse('example.com')` succeeds but yields a scheme-less
        // relative reference that no launcher can open.
        if (parsed == null || !parsed.hasScheme) return null;
        return parsed;
      case BarcodeType.email:
        final address = email?.address;
        if (address == null || address.isEmpty) return null;
        final query = <String, String>{
          if (email?.subject case final String s when s.isNotEmpty)
            'subject': s,
          if (email?.body case final String b when b.isNotEmpty) 'body': b,
        };
        return Uri(
          scheme: 'mailto',
          path: address,
          // Not `queryParameters`: that applies form encoding, so a space
          // arrives at the mail client as a literal '+'.
          query: query.isEmpty ? null : _percentEncodedQuery(query),
        );
      case BarcodeType.phone:
        final number = phone?.number;
        if (number == null || number.isEmpty) return null;
        return Uri(scheme: 'tel', path: number);
      case BarcodeType.sms:
        final number = sms?.phoneNumber;
        if (number == null || number.isEmpty) return null;
        final body = sms?.message;
        return Uri(
          scheme: 'sms',
          path: number,
          query:
              body == null || body.isEmpty
                  ? null
                  : _percentEncodedQuery(<String, String>{'body': body}),
        );
      case BarcodeType.geo:
        final point = geoPoint;
        if (point == null) return null;
        return Uri.parse('geo:${point.latitude},${point.longitude}');
      case BarcodeType.text:
      case BarcodeType.isbn:
      case BarcodeType.product:
      case BarcodeType.contactInfo:
      case BarcodeType.wifi:
      case BarcodeType.calendarEvent:
      case BarcodeType.driverLicense:
      case BarcodeType.unknown:
        // A bare text payload is very often a URL that ML Kit did not classify.
        final parsed = Uri.tryParse(bestValue);
        if (parsed != null && parsed.hasScheme && parsed.host.isNotEmpty) {
          return parsed;
        }
        return null;
    }
  }

  /// The structured payload of this barcode, flattened into ordered
  /// label/value pairs ready for display.
  ///
  /// Returns an empty list for barcodes whose payload is just text; use
  /// [bestValue] for those.
  List<BarcodeField> get fields {
    switch (type) {
      case BarcodeType.wifi:
        final network = wifi;
        if (network == null) return const <BarcodeField>[];
        return <BarcodeField>[
          if (network.ssid case final String v when v.isNotEmpty)
            BarcodeField(key: 'wifi.ssid', label: 'Network', value: v),
          if (network.password case final String v when v.isNotEmpty)
            BarcodeField(
              key: 'wifi.password',
              label: 'Password',
              value: v,
              obscure: true,
            ),
          BarcodeField(
            key: 'wifi.security',
            label: 'Security',
            value: switch (network.encryptionType) {
              EncryptionType.open => 'Open',
              EncryptionType.wpa => 'WPA/WPA2',
              EncryptionType.wep => 'WEP',
              EncryptionType.unknown => 'Unknown',
            },
          ),
        ];
      case BarcodeType.url:
        final bookmark = url;
        if (bookmark == null) return const <BarcodeField>[];
        return <BarcodeField>[
          if (bookmark.title case final String v when v.isNotEmpty)
            BarcodeField(key: 'url.title', label: 'Title', value: v),
          BarcodeField(key: 'url.url', label: 'URL', value: bookmark.url),
        ];
      case BarcodeType.email:
        final mail = email;
        if (mail == null) return const <BarcodeField>[];
        return <BarcodeField>[
          if (mail.address case final String v when v.isNotEmpty)
            BarcodeField(key: 'email.address', label: 'Address', value: v),
          if (mail.subject case final String v when v.isNotEmpty)
            BarcodeField(key: 'email.subject', label: 'Subject', value: v),
          if (mail.body case final String v when v.isNotEmpty)
            BarcodeField(key: 'email.body', label: 'Message', value: v),
        ];
      case BarcodeType.phone:
        final number = phone?.number;
        if (number == null || number.isEmpty) return const <BarcodeField>[];
        return <BarcodeField>[
          BarcodeField(key: 'phone.number', label: 'Number', value: number),
        ];
      case BarcodeType.sms:
        final message = sms;
        if (message == null) return const <BarcodeField>[];
        return <BarcodeField>[
          BarcodeField(
            key: 'sms.number',
            label: 'Number',
            value: message.phoneNumber,
          ),
          if (message.message case final String v when v.isNotEmpty)
            BarcodeField(key: 'sms.message', label: 'Message', value: v),
        ];
      case BarcodeType.geo:
        final point = geoPoint;
        if (point == null) return const <BarcodeField>[];
        return <BarcodeField>[
          BarcodeField(
            key: 'geo.latitude',
            label: 'Latitude',
            value: point.latitude.toString(),
          ),
          BarcodeField(
            key: 'geo.longitude',
            label: 'Longitude',
            value: point.longitude.toString(),
          ),
        ];
      case BarcodeType.calendarEvent:
        final event = calendarEvent;
        if (event == null) return const <BarcodeField>[];
        return <BarcodeField>[
          if (event.summary case final String v when v.isNotEmpty)
            BarcodeField(key: 'event.summary', label: 'Title', value: v),
          if (event.location case final String v when v.isNotEmpty)
            BarcodeField(key: 'event.location', label: 'Location', value: v),
          if (event.start case final DateTime v)
            BarcodeField(
              key: 'event.start',
              label: 'Starts',
              value: v.toLocal().toString(),
            ),
          if (event.end case final DateTime v)
            BarcodeField(
              key: 'event.end',
              label: 'Ends',
              value: v.toLocal().toString(),
            ),
          if (event.organizer case final String v when v.isNotEmpty)
            BarcodeField(key: 'event.organizer', label: 'Organizer', value: v),
          if (event.description case final String v when v.isNotEmpty)
            BarcodeField(key: 'event.description', label: 'Details', value: v),
        ];
      case BarcodeType.contactInfo:
        final contact = contactInfo;
        if (contact == null) return const <BarcodeField>[];
        final name =
            contact.name?.formattedName ??
            <String?>[
              contact.name?.prefix,
              contact.name?.first,
              contact.name?.middle,
              contact.name?.last,
              contact.name?.suffix,
            ].whereType<String>().where((p) => p.isNotEmpty).join(' ');
        return <BarcodeField>[
          if (name.isNotEmpty)
            BarcodeField(key: 'contact.name', label: 'Name', value: name),
          if (contact.title case final String v when v.isNotEmpty)
            BarcodeField(key: 'contact.title', label: 'Title', value: v),
          if (contact.organization case final String v when v.isNotEmpty)
            BarcodeField(
              key: 'contact.organization',
              label: 'Organization',
              value: v,
            ),
          for (final phone in contact.phones)
            if (phone.number case final String v when v.isNotEmpty)
              BarcodeField(key: 'contact.phone', label: 'Phone', value: v),
          for (final mail in contact.emails)
            if (mail.address case final String v when v.isNotEmpty)
              BarcodeField(key: 'contact.email', label: 'Email', value: v),
          for (final address in contact.addresses)
            if (address.addressLines.join(', ') case final String v
                when v.isNotEmpty)
              BarcodeField(key: 'contact.address', label: 'Address', value: v),
          for (final link in contact.urls)
            if (link.isNotEmpty)
              BarcodeField(key: 'contact.url', label: 'Website', value: link),
        ];
      case BarcodeType.driverLicense:
        final licence = driverLicense;
        if (licence == null) return const <BarcodeField>[];
        final name = <String?>[
          licence.firstName,
          licence.middleName,
          licence.lastName,
        ].whereType<String>().where((p) => p.isNotEmpty).join(' ');
        final street = <String?>[
          licence.addressStreet,
          licence.addressCity,
          licence.addressState,
          licence.addressZip,
        ].whereType<String>().where((p) => p.isNotEmpty).join(', ');
        return <BarcodeField>[
          if (name.isNotEmpty)
            BarcodeField(key: 'licence.name', label: 'Name', value: name),
          if (licence.documentType case final String v when v.isNotEmpty)
            BarcodeField(key: 'licence.type', label: 'Document', value: v),
          if (licence.licenseNumber case final String v when v.isNotEmpty)
            BarcodeField(key: 'licence.number', label: 'Number', value: v),
          if (licence.birthDate case final String v when v.isNotEmpty)
            BarcodeField(key: 'licence.birthDate', label: 'Born', value: v),
          if (licence.issueDate case final String v when v.isNotEmpty)
            BarcodeField(key: 'licence.issueDate', label: 'Issued', value: v),
          if (licence.expiryDate case final String v when v.isNotEmpty)
            BarcodeField(key: 'licence.expiryDate', label: 'Expires', value: v),
          if (licence.issuingCountry case final String v when v.isNotEmpty)
            BarcodeField(key: 'licence.country', label: 'Country', value: v),
          if (street.isNotEmpty)
            BarcodeField(
              key: 'licence.address',
              label: 'Address',
              value: street,
            ),
        ];
      case BarcodeType.text:
      case BarcodeType.isbn:
      case BarcodeType.product:
      case BarcodeType.unknown:
        return const <BarcodeField>[];
    }
  }

  /// The bounding rectangle of this barcode in camera-output coordinates, or
  /// `null` when the platform did not report corner points (the web backend
  /// never does).
  Rect? get boundingBox {
    if (corners.isEmpty) return null;
    var left = corners.first.dx;
    var top = corners.first.dy;
    var right = left;
    var bottom = top;
    for (final corner in corners) {
      if (corner.dx < left) left = corner.dx;
      if (corner.dx > right) right = corner.dx;
      if (corner.dy < top) top = corner.dy;
      if (corner.dy > bottom) bottom = corner.dy;
    }
    return Rect.fromLTRB(left, top, right, bottom);
  }
}

/// Convenience accessors for a [BarcodeCapture].
extension AiBarcodeCaptureX on BarcodeCapture {
  /// The first detected barcode, or `null` when the capture was empty.
  Barcode? get firstBarcode => barcodes.isEmpty ? null : barcodes.first;

  /// The raw value of the first detected barcode.
  String? get firstRawValue => firstBarcode?.rawValue;

  /// The most presentable value of the first detected barcode.
  String? get firstDisplayValue => firstBarcode?.bestValue;

  /// Every non-empty presentable value in this capture.
  List<String> get values => <String>[
    for (final barcode in barcodes)
      if (barcode.bestValue.isNotEmpty) barcode.bestValue,
  ];
}

/// Presentation helpers for [BarcodeFormat].
extension AiBarcodeFormatX on BarcodeFormat {
  /// The conventional, human readable name of this symbology.
  String get displayName {
    switch (this) {
      case BarcodeFormat.all:
        return 'All formats';
      case BarcodeFormat.code128:
        return 'Code 128';
      case BarcodeFormat.code39:
        return 'Code 39';
      case BarcodeFormat.code93:
        return 'Code 93';
      case BarcodeFormat.codabar:
        return 'Codabar';
      case BarcodeFormat.dataMatrix:
        return 'Data Matrix';
      case BarcodeFormat.ean13:
        return 'EAN-13';
      case BarcodeFormat.ean8:
        return 'EAN-8';
      case BarcodeFormat.itf2of5:
        return 'ITF 2 of 5';
      case BarcodeFormat.itf2of5WithChecksum:
        return 'ITF 2 of 5 (checksum)';
      case BarcodeFormat.itf14:
        return 'ITF-14';
      case BarcodeFormat.qrCode:
        return 'QR Code';
      case BarcodeFormat.upcA:
        return 'UPC-A';
      case BarcodeFormat.upcE:
        return 'UPC-E';
      case BarcodeFormat.pdf417:
        return 'PDF417';
      case BarcodeFormat.aztec:
        return 'Aztec';
      case BarcodeFormat.maxiCode:
        return 'MaxiCode';
      case BarcodeFormat.microQrCode:
        return 'Micro QR Code';
      case BarcodeFormat.dataBar:
        return 'GS1 DataBar';
      case BarcodeFormat.dataBarExpanded:
        return 'GS1 DataBar Expanded';
      case BarcodeFormat.dataBarLimited:
        return 'GS1 DataBar Limited';
      case BarcodeFormat.unknown:
        return 'Unknown';
      // ignore: deprecated_member_use
      case BarcodeFormat.itf:
        return 'ITF-14';
    }
  }

  /// Whether this is a 2D (matrix) symbology.
  ///
  /// The scanner uses this to pick a sensible default scan-window shape: a
  /// square reticle reads QR codes best, a wide one reads linear barcodes best.
  bool get isTwoDimensional {
    switch (this) {
      case BarcodeFormat.qrCode:
      case BarcodeFormat.microQrCode:
      case BarcodeFormat.aztec:
      case BarcodeFormat.dataMatrix:
      case BarcodeFormat.maxiCode:
      case BarcodeFormat.pdf417:
        return true;
      case BarcodeFormat.all:
      case BarcodeFormat.unknown:
      case BarcodeFormat.code128:
      case BarcodeFormat.code39:
      case BarcodeFormat.code93:
      case BarcodeFormat.codabar:
      case BarcodeFormat.ean13:
      case BarcodeFormat.ean8:
      case BarcodeFormat.itf2of5:
      case BarcodeFormat.itf2of5WithChecksum:
      case BarcodeFormat.itf14:
      case BarcodeFormat.upcA:
      case BarcodeFormat.upcE:
      case BarcodeFormat.dataBar:
      case BarcodeFormat.dataBarExpanded:
      case BarcodeFormat.dataBarLimited:
        return false;
      // ignore: deprecated_member_use
      case BarcodeFormat.itf:
        return false;
    }
  }
}
