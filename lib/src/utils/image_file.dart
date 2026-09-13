/// Temporary image files for the platform decoders that only read files.
///
/// `MobileScannerController.analyzeImage` takes a path on Android, iOS and
/// macOS: ML Kit and Apple Vision are handed a file URL, never bytes. An image
/// a picker returned only as bytes — or an `XFile.fromData` — therefore has to
/// be put on disk before it can be analysed.
///
/// Internal: not exported from `package:ai_barcode_scanner`. The web has no
/// `dart:io` and compiles the stub, which throws; the scanner never reaches it
/// there, because the web reads images through the built-in decoder instead.
library;

export 'image_file_stub.dart' if (dart.library.io) 'image_file_io.dart';
