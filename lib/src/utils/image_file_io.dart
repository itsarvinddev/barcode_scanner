import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:mobile_scanner/mobile_scanner.dart'
    show MobileScannerBarcodeException;

/// Whether a file exists at [path].
///
/// Used to tell an `XFile` backed by a real file, which can be analysed in
/// place, from an `XFile.fromData` whose path is empty or only nominal.
Future<bool> isExistingImageFile(String path) {
  if (path.isEmpty) return Future<bool>.value(false);
  return File(path).exists();
}

/// Runs [action] with the path of a temporary file holding [bytes], and deletes
/// the file once [action] completes — whether it succeeded or threw.
///
/// Each call gets a directory of its own under [Directory.systemTemp], so no
/// two calls ever share a file, and removing the directory cannot touch
/// anything else. (The controller still runs analyses one at a time, because
/// `mobile_scanner` on Android cannot track two at once.) No plugin is needed
/// to find it: on Android the engine points the system temp directory at the
/// app's code cache, and on iOS and macOS the sandbox provides `TMPDIR`.
///
/// The file is named with an extension recognised from the bytes (see
/// [imageFileExtension]), falling back to [mimeType]. The platform decoders
/// look at the contents rather than the name, but an accurate extension costs
/// nothing and keeps a decoder that does consult it on the right path.
///
/// Deleting is best effort: a failure there must not replace the analysis
/// result, and the OS reclaims its temp directory eventually anyway.
///
/// A [FileSystemException] while creating or writing the file — a full disk,
/// a temp directory the app cannot write to — is reported as a
/// [MobileScannerBarcodeException], the type every other unreadable image is
/// reported as, with the original stack trace. Errors from [action] itself
/// propagate untouched.
Future<T> withTemporaryImageFile<T>(
  Uint8List bytes,
  Future<T> Function(String path) action, {
  String? mimeType,
}) async {
  final Directory directory;
  try {
    directory = await Directory.systemTemp.createTemp('ai_barcode_scanner_');
  } on FileSystemException catch (error, stackTrace) {
    _throwWriteFailure(error, stackTrace);
  }
  try {
    final extension = imageFileExtension(bytes, mimeType: mimeType);
    final file = File(
      '${directory.path}${Platform.pathSeparator}image$extension',
    );
    try {
      await file.writeAsBytes(bytes, flush: true);
    } on FileSystemException catch (error, stackTrace) {
      _throwWriteFailure(error, stackTrace);
    }
    return await action(file.path);
  } finally {
    try {
      await directory.delete(recursive: true);
    } on FileSystemException {
      // Best effort; see above.
    }
  }
}

Never _throwWriteFailure(FileSystemException error, StackTrace stackTrace) {
  Error.throwWithStackTrace(
    MobileScannerBarcodeException(
      'Could not write the image to a temporary file ($error).',
    ),
    stackTrace,
  );
}

/// The file extension, including the dot, for the encoded image [bytes].
///
/// The format is recognised from the file signature. Only when the bytes match
/// none of the known signatures is [mimeType] consulted, and when that is
/// unknown too the result is empty — a name without an extension is better
/// than a wrong one.
@visibleForTesting
String imageFileExtension(Uint8List bytes, {String? mimeType}) {
  final sniffed = _sniffExtension(bytes);
  if (sniffed != null) return sniffed;

  return switch (mimeType?.toLowerCase()) {
    'image/png' => '.png',
    'image/jpeg' || 'image/jpg' => '.jpg',
    'image/webp' => '.webp',
    'image/gif' => '.gif',
    'image/bmp' || 'image/x-ms-bmp' => '.bmp',
    'image/heic' || 'image/heif' => '.heic',
    'image/avif' => '.avif',
    'image/tiff' => '.tiff',
    _ => '',
  };
}

String? _sniffExtension(Uint8List bytes) {
  bool startsWith(List<int> signature, [int offset = 0]) {
    if (bytes.length < offset + signature.length) return false;
    for (var i = 0; i < signature.length; i++) {
      if (bytes[offset + i] != signature[i]) return false;
    }
    return true;
  }

  // PNG: \x89 P N G \r \n \x1a \n
  if (startsWith(const <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])) {
    return '.png';
  }
  // JPEG: SOI marker followed by the start of the next marker.
  if (startsWith(const <int>[0xFF, 0xD8, 0xFF])) return '.jpg';
  // GIF87a / GIF89a.
  if (startsWith(const <int>[0x47, 0x49, 0x46, 0x38])) return '.gif';
  // WebP: a RIFF container whose form type is WEBP.
  if (startsWith(const <int>[0x52, 0x49, 0x46, 0x46]) &&
      startsWith(const <int>[0x57, 0x45, 0x42, 0x50], 8)) {
    return '.webp';
  }
  // BMP: "BM".
  if (startsWith(const <int>[0x42, 0x4D])) return '.bmp';
  // TIFF, little- and big-endian.
  if (startsWith(const <int>[0x49, 0x49, 0x2A, 0x00]) ||
      startsWith(const <int>[0x4D, 0x4D, 0x00, 0x2A])) {
    return '.tiff';
  }
  // ISO base media (HEIF, AVIF): a box size, then "ftyp", then the brand.
  if (startsWith(const <int>[0x66, 0x74, 0x79, 0x70], 4) &&
      bytes.length >= 12) {
    final brand = String.fromCharCodes(bytes, 8, 12);
    if (brand == 'avif' || brand == 'avis') return '.avif';
    const heifBrands = <String>{
      'heic',
      'heix',
      'heim',
      'heis',
      'hevc',
      'hevx',
      'hevm',
      'hevs',
      'mif1',
      'msf1',
    };
    if (heifBrands.contains(brand)) return '.heic';
  }
  return null;
}
