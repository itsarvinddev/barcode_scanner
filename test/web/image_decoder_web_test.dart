// The built-in still-image decoder behind gallery scanning on the web.
//
// These run in a real browser, against the real zxing-wasm build loaded from
// jsDelivr — the point is to prove the interop, the browser's image decoding
// and the coordinate mapping, none of which a fake would exercise:
//
//   flutter test --platform chrome test/web
//   flutter test --platform chrome --wasm test/web
//
// `@TestOn('browser')` makes a plain `flutter test` skip this file.
@TestOn('browser')
library;

import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:ui' show Rect, Size;

import 'package:ai_barcode_scanner/src/utils/image_decoder/image_decoder.dart';
import 'package:ai_barcode_scanner/src/utils/image_decoder/image_decoder_web.dart'
    show
        debugImageDecoderPassSizes,
        debugOnImageDecoderPass,
        debugResetImageDecoder,
        zxingWasmVersion;
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:web/web.dart' as web;

import 'fixtures.dart';

const _scriptSelector = 'script#ai-barcode-scanner-zxing-wasm';

/// The loading tests need a page that has never seen zxing-wasm. The IIFE
/// declares `var ZXingWASM`, which cannot be deleted, so blank it instead.
void _coldStart() {
  debugResetImageDecoder();
  web.document.querySelector(_scriptSelector)?.remove();
  globalContext.setProperty('ZXingWASM'.toJS, null);
}

/// Counts the zxing-wasm script tags added to `<head>` while [body] runs.
Future<int> _countScriptInjections(Future<void> Function() body) async {
  var count = 0;
  void record(JSArray<web.MutationRecord> records) {
    for (final record in records.toDart) {
      final added = record.addedNodes;
      for (var i = 0; i < added.length; i++) {
        final node = added.item(i);
        if (node != null &&
            node.nodeName.toLowerCase() == 'script' &&
            (node as web.Element).id == 'ai-barcode-scanner-zxing-wasm') {
          count++;
        }
      }
    }
  }

  final observer = web.MutationObserver(
    (JSArray<web.MutationRecord> records, web.MutationObserver _) {
      record(records);
    }.toJS,
  )..observe(web.document.head!, web.MutationObserverInit(childList: true));
  try {
    await body();
  } finally {
    record(observer.takeRecords());
    observer.disconnect();
  }
  return count;
}

/// A `blob:` URL for [bytes]. Revoke it when done.
String _objectUrl(Uint8List bytes, String type) => web.URL.createObjectURL(
  web.Blob(<web.BlobPart>[bytes.toJS].toJS, web.BlobPropertyBag(type: type)),
);

/// Re-encodes [png] through a canvas, as a photo app would have saved it.
Future<Uint8List> _reencode(
  Uint8List png, {
  required String type,
  double quality = 0.85,
}) async {
  final bitmap =
      await web.window
          .createImageBitmap(web.Blob(<web.BlobPart>[png.toJS].toJS))
          .toDart;
  final canvas = web.OffscreenCanvas(bitmap.width, bitmap.height);
  (canvas.getContext('2d')! as web.OffscreenCanvasRenderingContext2D).drawImage(
    bitmap,
    0,
    0,
  );
  bitmap.close();
  final blob =
      await canvas
          .convertToBlob(web.ImageEncodeOptions(type: type, quality: quality))
          .toDart;
  return (await blob.arrayBuffer().toDart).toDart.asUint8List();
}

/// A blank white PNG of [width] × [height], encoded by the browser.
Future<Uint8List> _blankPng(int width, int height) async {
  final canvas = web.OffscreenCanvas(width, height);
  (canvas.getContext('2d')! as web.OffscreenCanvasRenderingContext2D)
    ..fillStyle = 'white'.toJS
    ..fillRect(0, 0, width, height);
  final blob = await canvas.convertToBlob().toDart;
  return (await blob.arrayBuffer().toDart).toDart.asUint8List();
}

/// The axis-aligned box around [barcode]'s corners.
Rect _bounds(Barcode barcode) {
  final xs = barcode.corners.map((corner) => corner.dx);
  final ys = barcode.corners.map((corner) => corner.dy);
  return Rect.fromLTRB(
    xs.reduce((a, b) => a < b ? a : b),
    ys.reduce((a, b) => a < b ? a : b),
    xs.reduce((a, b) => a > b ? a : b),
    ys.reduce((a, b) => a > b ? a : b),
  );
}

/// Matches a [Rect] whose edges are each within [tolerance] of [expected].
Matcher _rectCloseTo(Rect expected, double tolerance) => predicate<Rect>(
  (actual) =>
      (actual.left - expected.left).abs() <= tolerance &&
      (actual.top - expected.top).abs() <= tolerance &&
      (actual.right - expected.right).abs() <= tolerance &&
      (actual.bottom - expected.bottom).abs() <= tolerance,
  'within $tolerance px of $expected',
);

/// Decodes [bytes] and records the raster size of every zxing pass.
Future<(BarcodeCapture?, List<Size>)> _decodeWithPasses(
  Uint8List bytes, {
  List<BarcodeFormat> formats = const <BarcodeFormat>[],
}) async {
  final passes = <Size>[];
  debugOnImageDecoderPass =
      (width, height) => passes.add(Size(width.toDouble(), height.toDouble()));
  try {
    final capture = await decodeBarcodesFromImageBytes(bytes, formats: formats);
    return (capture, passes);
  } finally {
    debugOnImageDecoderPass = null;
  }
}

final _isBarcodeException = isA<MobileScannerBarcodeException>();

void main() {
  // The first read fetches the WebAssembly binary; give slow CI runners room.
  const timeout = Timeout(Duration(minutes: 2));

  test('the conditional import selects the web implementation', () {
    expect(kHasWebImageDecoder, isTrue);
  });

  group('loading zxing-wasm', () {
    setUp(_coldStart);
    tearDown(debugResetImageDecoder);

    test('concurrent first calls inject the script once', () async {
      late List<BarcodeCapture?> captures;
      final injections = await _countScriptInjections(() async {
        captures = await Future.wait([
          decodeBarcodesFromImageBytes(qrPng),
          decodeBarcodesFromImageBytes(ean13Png),
          decodeBarcodesFromImageBytes(qrWebp),
        ]);
      });

      expect(injections, 1);
      expect(web.document.querySelectorAll(_scriptSelector).length, 1);
      expect(captures[0]!.barcodes.single.rawValue, qrText);
      expect(captures[1]!.barcodes.single.rawValue, ean13Text);
      expect(captures[2]!.barcodes.single.rawValue, qrText);
    }, timeout: timeout);

    test(
      'reuses a ZXingWASM already on the page, as mobile_scanner leaves one',
      () async {
        await decodeBarcodesFromImageBytes(qrPng);
        // Simulate a page where another script tag (mobile_scanner's) provided
        // the global: forget our load and our tag, keep the global.
        debugResetImageDecoder();
        web.document.querySelector(_scriptSelector)?.remove();

        late BarcodeCapture? capture;
        final injections = await _countScriptInjections(() async {
          capture = await decodeBarcodesFromImageBytes(qrPng);
        });

        expect(injections, 0);
        expect(capture!.barcodes.single.rawValue, qrText);
      },
      timeout: timeout,
    );

    test(
      'a failed load throws, cleans up, and the next call retries',
      () async {
        // A revoked object URL fails to load immediately and without a network.
        final deadUrl = _objectUrl(
          Uint8List.fromList(utf8.encode('/* never loaded */')),
          'text/javascript',
        );
        web.URL.revokeObjectURL(deadUrl);

        await expectLater(
          decodeBarcodesFromImageBytes(qrPng, scriptUrl: deadUrl),
          throwsA(
            _isBarcodeException.having(
              (error) => error.message,
              'message',
              allOf(
                contains(deadUrl),
                contains('https://cdn.jsdelivr.net'),
                contains('https://fastly.jsdelivr.net'),
                contains("'wasm-unsafe-eval'"),
              ),
            ),
          ),
        );
        expect(web.document.querySelector(_scriptSelector), isNull);

        // The failure is not memoized: the default URL loads on the next try.
        final capture = await decodeBarcodesFromImageBytes(qrPng);
        expect(capture!.barcodes.single.rawValue, qrText);
      },
      timeout: timeout,
    );

    test('a failed WebAssembly download is retried by the next call', () async {
      // A working script and module first, as on a page that has scanned.
      await decodeBarcodesFromImageBytes(qrPng);
      final zxing = globalContext.getProperty<JSObject>('ZXingWASM'.toJS);
      // Put zxing-wasm's own defaults back for the tests that follow.
      addTearDown(() => zxing.callMethod<JSAny?>('purgeZXingModule'.toJS));

      // Stand in for a dropped connection: the binary's URL is dead until
      // `offline` clears. The overrides object itself never changes, so
      // zxing-wasm has no reason of its own to rebuild the module once the
      // network is back — only the decoder's recovery can.
      var offline = true;
      final deadUrl = _objectUrl(Uint8List(1), 'application/wasm');
      web.URL.revokeObjectURL(deadUrl);
      final overrides =
          JSObject()..setProperty(
            'locateFile'.toJS,
            ((JSString path, JSString prefix) =>
                    offline
                        ? deadUrl.toJS
                        : 'https://fastly.jsdelivr.net/npm/zxing-wasm@'
                                '$zxingWasmVersion/dist/reader/${path.toDart}'
                            .toJS)
                .toJS,
          );
      zxing.callMethod<JSAny?>(
        'prepareZXingModule'.toJS,
        JSObject()..setProperty('overrides'.toJS, overrides),
      );

      await expectLater(
        decodeBarcodesFromImageBytes(qrPng),
        throwsA(
          _isBarcodeException.having(
            (error) => error.message,
            'message',
            contains('WebAssembly'),
          ),
        ),
      );

      offline = false;
      final capture = await decodeBarcodesFromImageBytes(qrPng);
      expect(capture!.barcodes.single.rawValue, qrText);
    }, timeout: timeout);

    test('a download that failed under another reader does not fail the next '
        'scan', () async {
      await decodeBarcodesFromImageBytes(qrPng);
      final zxing = globalContext.getProperty<JSObject>('ZXingWASM'.toJS);
      addTearDown(() => zxing.callMethod<JSAny?>('purgeZXingModule'.toJS));

      // mobile_scanner's zxing-wasm camera reader calls readBarcodes on
      // every frame and swallows the errors, so a download that fails under
      // it leaves a rejected module promise in zxing-wasm's page-wide cache
      // that no scan of ours ever saw. Leave one there the same way...
      var offline = true;
      final deadUrl = _objectUrl(Uint8List(1), 'application/wasm');
      web.URL.revokeObjectURL(deadUrl);
      final overrides =
          JSObject()..setProperty(
            'locateFile'.toJS,
            ((JSString path, JSString prefix) =>
                    offline
                        ? deadUrl.toJS
                        : 'https://fastly.jsdelivr.net/npm/zxing-wasm@'
                                '$zxingWasmVersion/dist/reader/'
                                '${path.toDart}'
                            .toJS)
                .toJS,
          );
      final stale = zxing.callMethod<JSPromise<JSAny?>>(
        'prepareZXingModule'.toJS,
        JSObject()
          ..setProperty('overrides'.toJS, overrides)
          ..setProperty('fireImmediately'.toJS, true.toJS),
      );
      await expectLater(stale.toDart, throwsA(anything));

      // ...then let the network come back without instantiating again: the
      // overrides object is unchanged, so zxing-wasm keeps serving the
      // rejection until someone drops it.
      offline = false;

      // The very first scan afterwards succeeds, not only the second.
      final capture = await decodeBarcodesFromImageBytes(qrPng);
      expect(capture!.barcodes.single.rawValue, qrText);
    }, timeout: timeout);

    test('a script that does not define ZXingWASM is reported', () async {
      final url = _objectUrl(
        Uint8List.fromList(utf8.encode('window.somethingElse = 1;')),
        'text/javascript',
      );
      addTearDown(() => web.URL.revokeObjectURL(url));

      await expectLater(
        decodeBarcodesFromImageBytes(qrPng, scriptUrl: url),
        throwsA(
          _isBarcodeException.having(
            (error) => error.message,
            'message',
            contains('did not define ZXingWASM.readBarcodes'),
          ),
        ),
      );
      expect(web.document.querySelector(_scriptSelector), isNull);
    }, timeout: timeout);
  });

  group('decoding', () {
    test('a PNG: format, value, bytes, corners and size', () async {
      final capture = await decodeBarcodesFromImageBytes(qrPng);

      expect(capture, isNotNull);
      expect(capture!.size, const Size(480, 360));
      final barcode = capture.barcodes.single;
      expect(barcode.format, BarcodeFormat.qrCode);
      expect(barcode.rawValue, qrText);
      expect(barcode.displayValue, qrText);
      expect(barcode.type, BarcodeType.text);
      expect(
        (barcode.rawDecodedBytes! as DecodedBarcodeBytes).bytes,
        utf8.encode(qrText),
      );
      // Clockwise from the top-left, in image pixels.
      expect(barcode.corners, hasLength(4));
      expect(barcode.corners[0].dx, closeTo(104, 1));
      expect(barcode.corners[0].dy, closeTo(40, 1));
      expect(barcode.corners[1].dx, closeTo(368, 1));
      expect(barcode.corners[1].dy, closeTo(40, 1));
      expect(barcode.corners[2].dx, closeTo(368, 1));
      expect(barcode.corners[2].dy, closeTo(304, 1));
      expect(barcode.corners[3].dx, closeTo(104, 1));
      expect(barcode.corners[3].dy, closeTo(304, 1));
      expect(barcode.size.width, closeTo(264, 1));
      expect(barcode.size.height, closeTo(264, 1));
    }, timeout: timeout);

    test('a JPEG', () async {
      final capture = await decodeBarcodesFromImageBytes(qrJpeg);

      expect(capture!.size, const Size(480, 360));
      expect(capture.barcodes.single.rawValue, qrText);
      expect(
        _bounds(capture.barcodes.single),
        _rectCloseTo(const Rect.fromLTRB(104, 40, 368, 304), 2),
      );
    }, timeout: timeout);

    test('a WebP, which zxing cannot decode from the file itself', () async {
      final capture = await decodeBarcodesFromImageBytes(qrWebp);

      expect(capture!.size, const Size(480, 360));
      expect(capture.barcodes.single.format, BarcodeFormat.qrCode);
      expect(capture.barcodes.single.rawValue, qrText);
    }, timeout: timeout);

    test(
      'EXIF orientation is applied: size and corners are as displayed',
      () async {
        final capture = await decodeBarcodesFromImageBytes(qrExif6Jpeg);

        // Stored 480 × 360; orientation 6 shows it rotated to 360 × 480.
        expect(capture!.size, const Size(360, 480));
        final barcode = capture.barcodes.single;
        expect(barcode.rawValue, qrText);
        expect(
          _bounds(barcode),
          _rectCloseTo(const Rect.fromLTRB(56, 104, 320, 368), 2),
        );
      },
      timeout: timeout,
    );

    test('a transparent background reads as white, not black', () async {
      final capture = await decodeBarcodesFromImageBytes(qrTransparentPng);

      expect(capture!.barcodes.single.rawValue, qrText);
    }, timeout: timeout);

    test('an EAN-13', () async {
      final capture = await decodeBarcodesFromImageBytes(ean13Png);

      expect(capture!.size, const Size(400, 240));
      final barcode = capture.barcodes.single;
      expect(barcode.format, BarcodeFormat.ean13);
      expect(barcode.rawValue, ean13Text);
      expect(barcode.corners, hasLength(4));
      // A linear code's corners span its bars, whose exact vertical extent
      // depends on the scan lines zxing used; check the horizontal span.
      final bounds = _bounds(barcode);
      expect(bounds.left, closeTo(58, 2));
      expect(bounds.right, closeTo(58 + 95 * 3, 4));
    }, timeout: timeout);

    test('a blank image yields a capture with no barcodes', () async {
      final capture = await decodeBarcodesFromImageBytes(blankPng);

      // Android, iOS and macOS answer an image without barcodes the same way.
      expect(capture, isNotNull);
      expect(capture!.barcodes, isEmpty);
      expect(capture.size, const Size(320, 240));
    }, timeout: timeout);

    test(
      'bytes that are not an image throw MobileScannerBarcodeException',
      () async {
        final garbage = Uint8List.fromList(
          List<int>.generate(512, (i) => (i * 37) & 0xff),
        );
        await expectLater(
          decodeBarcodesFromImageBytes(garbage),
          throwsA(
            _isBarcodeException.having(
              (error) => error.message,
              'message',
              contains('could not be decoded as an image'),
            ),
          ),
        );
        await expectLater(
          decodeBarcodesFromImageBytes(Uint8List(0)),
          throwsA(_isBarcodeException),
        );
      },
      timeout: timeout,
    );
  });

  group('formats', () {
    test('a restriction excludes other formats', () async {
      final qrAsEan = await decodeBarcodesFromImageBytes(
        qrPng,
        formats: const [BarcodeFormat.ean13],
      );
      final eanAsQr = await decodeBarcodesFromImageBytes(
        ean13Png,
        formats: const [BarcodeFormat.qrCode, BarcodeFormat.dataMatrix],
      );

      expect(qrAsEan!.barcodes, isEmpty);
      expect(eanAsQr!.barcodes, isEmpty);
    }, timeout: timeout);

    test('a restriction that includes the format finds it', () async {
      final capture = await decodeBarcodesFromImageBytes(
        ean13Png,
        formats: const [BarcodeFormat.qrCode, BarcodeFormat.ean13],
      );

      expect(capture!.barcodes.single.rawValue, ean13Text);
    }, timeout: timeout);

    test('`all`, or only formats zxing lacks, detect everything', () async {
      final all = await decodeBarcodesFromImageBytes(
        qrPng,
        formats: const [BarcodeFormat.all, BarcodeFormat.ean13],
      );
      final unknownOnly = await decodeBarcodesFromImageBytes(
        qrPng,
        formats: const [BarcodeFormat.unknown],
      );

      expect(all!.barcodes.single.rawValue, qrText);
      expect(unknownOnly!.barcodes.single.rawValue, qrText);
    }, timeout: timeout);
  });

  group('large images', () {
    test('a barcode that survives the downscale is found in one pass, with '
        'corners in original pixels', () async {
      final (capture, passes) = await _decodeWithPasses(largeQrPng);

      expect(passes, const [Size(2560, 1920)]);
      expect(capture!.size, const Size(4000, 3000));
      final barcode = capture.barcodes.single;
      expect(barcode.rawValue, qrText);
      // Scaled up from the 0.64× raster, so allow for rounding at that scale.
      expect(
        _bounds(barcode),
        _rectCloseTo(const Rect.fromLTRB(2600, 1900, 2864, 2164), 3),
      );
      expect(barcode.size.width, closeTo(264, 3));
    }, timeout: timeout);

    test(
      'a barcode too fine for the downscale is found by the full-size pass',
      () async {
        final (capture, passes) = await _decodeWithPasses(largeEanPng);

        expect(passes, const [Size(2560, 1920), Size(4000, 3000)]);
        expect(capture!.size, const Size(4000, 3000));
        final barcode = capture.barcodes.single;
        expect(barcode.rawValue, ean13Text);
        expect(_bounds(barcode).left, closeTo(1000, 2));
        expect(_bounds(barcode).top, closeTo(700, 2));
      },
      timeout: timeout,
    );

    test('a 12 MP JPEG from a photo app', () async {
      final jpeg = await _reencode(largeQrPng, type: 'image/jpeg');
      final (capture, passes) = await _decodeWithPasses(jpeg);

      expect(passes.first, const Size(2560, 1920));
      expect(capture!.size, const Size(4000, 3000));
      expect(capture.barcodes.single.rawValue, qrText);
      expect(
        _bounds(capture.barcodes.single),
        _rectCloseTo(const Rect.fromLTRB(2600, 1900, 2864, 2164), 4),
      );
    }, timeout: timeout);

    test('the full-size pass is capped at 8192 px on the long edge', () async {
      final (capture, passes) = await _decodeWithPasses(
        await _blankPng(9000, 900),
      );

      expect(passes, const [Size(2560, 256), Size(8192, 819)]);
      expect(capture!.size, const Size(9000, 900));
      expect(capture.barcodes, isEmpty);
    }, timeout: timeout);

    test('the full-size pass is capped at 16.7 MP', () async {
      final (capture, passes) = await _decodeWithPasses(
        await _blankPng(8000, 2500),
      );

      // sqrt(16777216 / 20000000) ≈ 0.9159 of each edge rounds to
      // 7327 × 2290, which is 1,614 pixels over; the long edge gives one up.
      expect(passes, const [Size(2560, 800), Size(7326, 2290)]);
      expect(
        passes.last.width * passes.last.height,
        lessThanOrEqualTo(16777216),
      );
      expect(capture!.size, const Size(8000, 2500));
    }, timeout: timeout);

    test('no full-size pass exceeds 16,777,216 pixels', () {
      // Phone photos from 12 to 50 MP — rounding each edge used to read a
      // 48 MP one at 4730 × 3547, 94 pixels over — then a sweep of shapes.
      const photos = <(int, int)>[
        (4000, 3000),
        (6016, 4016),
        (8000, 6000),
        (8160, 6120),
        (9248, 6936),
        (6936, 9248),
      ];
      final sizes = <(int, int)>[
        ...photos,
        for (var width = 2600; width <= 8200; width += 37)
          for (var height = 2600; height <= 8200; height += 41) (width, height),
      ];

      for (final (width, height) in sizes) {
        final full = debugImageDecoderPassSizes(width, height).last;
        expect(
          full.width * full.height,
          lessThanOrEqualTo(16777216),
          reason: '$width × $height read at $full',
        );
        expect(full.width, lessThanOrEqualTo(8192));
        expect(full.height, lessThanOrEqualTo(8192));
      }
      expect(debugImageDecoderPassSizes(8000, 6000), const [
        Size(2560, 1920),
        Size(4729, 3547),
      ]);
    });

    test('an image at most 2560 px is read once, at full size', () async {
      final (_, passes) = await _decodeWithPasses(await _blankPng(2560, 1440));

      expect(passes, const [Size(2560, 1440)]);
    }, timeout: timeout);
  });

  group('readImageUrlBytes', () {
    test('reads a blob: URL, as XFile.path is on the web', () async {
      final url = _objectUrl(qrJpeg, 'image/jpeg');
      addTearDown(() => web.URL.revokeObjectURL(url));

      final bytes = await readImageUrlBytes(url);

      expect(bytes, qrJpeg);
      final capture = await decodeBarcodesFromImageBytes(bytes);
      expect(capture!.barcodes.single.rawValue, qrText);
    }, timeout: timeout);

    test('reads a data: URL', () async {
      final bytes = await readImageUrlBytes(
        'data:image/png;base64,${base64Encode(qrPng)}',
      );

      expect(bytes, qrPng);
    });

    test('an unreadable URL throws MobileScannerBarcodeException', () async {
      final url = _objectUrl(qrPng, 'image/png');
      web.URL.revokeObjectURL(url);

      await expectLater(
        readImageUrlBytes(url),
        throwsA(
          _isBarcodeException.having(
            (error) => error.message,
            'message',
            contains('blob: in connect-src'),
          ),
        ),
      );
    });

    test('a failed fetch names the source connect-src has to allow', () async {
      // Nothing listens on port 1, so the fetch fails without a timeout.
      await expectLater(
        readImageUrlBytes('http://127.0.0.1:1/code.png'),
        throwsA(
          _isBarcodeException.having(
            (error) => error.message,
            'message',
            contains('http://127.0.0.1:1 in connect-src'),
          ),
        ),
      );
    }, timeout: timeout);
  });
}
