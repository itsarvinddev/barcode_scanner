// The native side of the still-image decoder: a stub that must never be
// mistaken for a working decoder. The web implementation is covered by
// test/web/image_decoder_web_test.dart, which runs in a browser.
@TestOn('!browser')
library;

import 'dart:typed_data';

import 'package:ai_barcode_scanner/src/utils/image_decoder/image_decoder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reports that there is no built-in decoder', () {
    expect(kHasWebImageDecoder, isFalse);
  });

  test('throws UnsupportedError instead of pretending to decode', () {
    expect(
      () => decodeBarcodesFromImageBytes(Uint8List(0)),
      throwsUnsupportedError,
    );
    expect(() => readImageUrlBytes('blob:nothing'), throwsUnsupportedError);
  });

  test('ignores a script URL, which the scanner passes on every platform', () {
    expect(
      () => useImageDecoderScriptUrl('https://example.com/zxing.js'),
      returnsNormally,
    );
  });
}
