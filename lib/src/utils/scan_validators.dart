import 'package:mobile_scanner/mobile_scanner.dart';

/// Ready-made validators for `AiBarcodeScanner.validator`.
///
/// A validator decides whether a detection should be accepted. Rejected
/// detections flash the overlay red, fire the rejection haptic, and never
/// reach `onDetect` — which is usually what you want instead of accepting
/// everything and filtering afterwards.
///
/// ```dart
/// AiBarcodeScanner(
///   validator: ScanValidators.all([
///     ScanValidators.formats(const {BarcodeFormat.qrCode}),
///     ScanValidators.startsWith('https://example.com/'),
///   ]),
///   onDetect: handleScan,
/// )
/// ```
abstract final class ScanValidators {
  /// Accepts everything. Useful as a neutral element.
  static bool any(BarcodeCapture capture) => true;

  /// Accepts a capture only when every one of [validators] accepts it.
  static bool Function(BarcodeCapture) all(
    List<bool Function(BarcodeCapture)> validators,
  ) {
    return (capture) => validators.every((validator) => validator(capture));
  }

  /// Accepts a capture when at least one of [validators] accepts it.
  static bool Function(BarcodeCapture) either(
    List<bool Function(BarcodeCapture)> validators,
  ) {
    return (capture) => validators.any((validator) => validator(capture));
  }

  /// Accepts captures whose first barcode is one of [formats].
  ///
  /// Prefer restricting `AiBarcodeScanner.formats` as well: that stops the
  /// detector from looking for the other symbologies in the first place, which
  /// is faster and reduces misreads. This validator is the belt to that
  /// braces, useful when a controller you do not own is supplied.
  static bool Function(BarcodeCapture) formats(Set<BarcodeFormat> formats) {
    return (capture) {
      final barcode = capture.barcodes.firstOrNull;
      return barcode != null && formats.contains(barcode.format);
    };
  }

  /// Accepts captures whose first barcode is one of [types].
  static bool Function(BarcodeCapture) types(Set<BarcodeType> types) {
    return (capture) {
      final barcode = capture.barcodes.firstOrNull;
      return barcode != null && types.contains(barcode.type);
    };
  }

  /// Accepts captures whose value contains [needle].
  static bool Function(BarcodeCapture) contains(
    String needle, {
    bool caseSensitive = true,
  }) {
    return (capture) {
      final value = _valueOf(capture);
      if (value == null) return false;
      return caseSensitive
          ? value.contains(needle)
          : value.toLowerCase().contains(needle.toLowerCase());
    };
  }

  /// Accepts captures whose value starts with [prefix].
  static bool Function(BarcodeCapture) startsWith(String prefix) {
    return (capture) => _valueOf(capture)?.startsWith(prefix) ?? false;
  }

  /// Accepts captures whose value matches [pattern] in full.
  ///
  /// The pattern is anchored for you, so `RegExp(r'\d{4}')` accepts `1234` and
  /// rejects `12345`. Anchoring by hand — `matchAsPrefix` plus a length check —
  /// silently rejects alternations that do match, because `matchAsPrefix` takes
  /// the first alternative that fits and never backtracks: against `ab`,
  /// `RegExp('a|ab')` matches only `a`.
  static bool Function(BarcodeCapture) matches(RegExp pattern) {
    final anchored = RegExp(
      '^(?:${pattern.pattern})\$',
      caseSensitive: pattern.isCaseSensitive,
      dotAll: pattern.isDotAll,
      unicode: pattern.isUnicode,
    );
    return (capture) {
      final value = _valueOf(capture);
      if (value == null) return false;
      return anchored.hasMatch(value);
    };
  }

  /// Accepts captures whose value parses as an absolute URL, optionally
  /// restricted to [allowedHosts].
  static bool Function(BarcodeCapture) url({Set<String>? allowedHosts}) {
    return (capture) {
      final value = _valueOf(capture);
      if (value == null) return false;
      final uri = Uri.tryParse(value);
      if (uri == null || !uri.hasScheme || uri.host.isEmpty) return false;
      if (allowedHosts == null) return true;
      return allowedHosts.contains(uri.host);
    };
  }

  /// Accepts captures whose value is exactly [length] characters long.
  static bool Function(BarcodeCapture) length(int length) {
    return (capture) => _valueOf(capture)?.length == length;
  }

  static String? _valueOf(BarcodeCapture capture) {
    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null) return null;
    final display = barcode.displayValue;
    if (display != null && display.isNotEmpty) return display;
    return barcode.rawValue;
  }
}

/// Curated [BarcodeFormat] sets for common scanning jobs.
///
/// Naming the formats you expect is the single cheapest accuracy and
/// performance win available: an unrestricted detector runs every decoder over
/// every frame.
abstract final class BarcodeFormatSets {
  /// QR codes only — the right default for links, tickets and payments.
  static const List<BarcodeFormat> qrOnly = <BarcodeFormat>[
    BarcodeFormat.qrCode,
  ];

  /// Every 2D symbology.
  static const List<BarcodeFormat> twoDimensional = <BarcodeFormat>[
    BarcodeFormat.qrCode,
    BarcodeFormat.microQrCode,
    BarcodeFormat.aztec,
    BarcodeFormat.dataMatrix,
    BarcodeFormat.pdf417,
    BarcodeFormat.maxiCode,
  ];

  /// The symbologies printed on retail packaging.
  static const List<BarcodeFormat> retail = <BarcodeFormat>[
    BarcodeFormat.ean13,
    BarcodeFormat.ean8,
    BarcodeFormat.upcA,
    BarcodeFormat.upcE,
    BarcodeFormat.code128,
    BarcodeFormat.dataBar,
    BarcodeFormat.dataBarExpanded,
    BarcodeFormat.dataBarLimited,
  ];

  /// The symbologies used on warehouse and logistics labels.
  static const List<BarcodeFormat> logistics = <BarcodeFormat>[
    BarcodeFormat.code128,
    BarcodeFormat.code39,
    BarcodeFormat.code93,
    BarcodeFormat.itf14,
    BarcodeFormat.dataMatrix,
    BarcodeFormat.qrCode,
  ];

  /// The symbologies on identity documents and boarding passes.
  static const List<BarcodeFormat> documents = <BarcodeFormat>[
    BarcodeFormat.pdf417,
    BarcodeFormat.qrCode,
    BarcodeFormat.aztec,
    BarcodeFormat.dataMatrix,
  ];
}
