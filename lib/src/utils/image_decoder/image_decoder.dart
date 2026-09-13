/// Reads barcodes out of an encoded still image (PNG, JPEG, WebP, ...) held in
/// memory, on platforms where `mobile_scanner` cannot.
///
/// `MobileScannerController.analyzeImage` only exists on Android, iOS and
/// macOS: its web implementation throws `UnsupportedError`, and upstream has
/// no plan to change that yet (juliansteenbakker/mobile_scanner#1494). That is
/// why the gallery button has always been hidden on the web. This library
/// fills the gap with a decoder of our own, so a picked image can be scanned
/// in the browser too.
///
/// On the web the implementation lets the browser decode the file and runs
/// zxing-wasm over the pixels — the same library, at the same version, that
/// `mobile_scanner` already uses for the camera. Everywhere else
/// `kHasWebImageDecoder` is `false` and every function throws
/// `UnsupportedError`: native platforms keep using `analyzeImage`, which reads
/// files through the OS decoders.
///
/// Internal: not exported from `package:ai_barcode_scanner`. The selection
/// happens at compile time, so native builds never see `dart:js_interop` or
/// `package:web`, and web builds (dart2js and dart2wasm alike) never see the
/// stub.
library;

export 'image_decoder_stub.dart'
    if (dart.library.js_interop) 'image_decoder_web.dart';
