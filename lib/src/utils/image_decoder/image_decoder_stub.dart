import 'dart:typed_data';

import 'package:mobile_scanner/mobile_scanner.dart';

/// Whether this build carries the built-in still-image decoder.
///
/// `false` here: this stub is what every non-web build compiles, and those
/// platforms read images through `MobileScannerController.analyzeImage`
/// instead. Check this before calling anything else in this library.
const bool kHasWebImageDecoder = false;

/// Loads the web decoder's library from [scriptUrl].
///
/// Behind `AiBarcodeScannerController.setWebImageDecoderScriptUrl`, which
/// apps may call unconditionally.
///
/// Does nothing outside the web, where there is no library to load. See the
/// web implementation for the contract.
void useImageDecoderScriptUrl(String scriptUrl) {}

/// Looks for barcodes in the encoded image [bytes].
///
/// Unavailable outside the web; always throws [UnsupportedError]. See the web
/// implementation for the contract.
Future<BarcodeCapture?> decodeBarcodesFromImageBytes(
  Uint8List bytes, {
  List<BarcodeFormat> formats = const <BarcodeFormat>[],
  String? scriptUrl,
}) {
  throw UnsupportedError(
    'The built-in image decoder is only available on the web. '
    'Use MobileScannerController.analyzeImage on this platform.',
  );
}

/// Reads the bytes behind a browser URL, such as the `blob:` URL an `XFile`
/// carries as its path on the web.
///
/// Unavailable outside the web, where a path is a file on disk; always throws
/// [UnsupportedError].
Future<Uint8List> readImageUrlBytes(String url) {
  throw UnsupportedError(
    'Reading image URLs is only available on the web. '
    'Pass the file path to MobileScannerController.analyzeImage instead.',
  );
}
