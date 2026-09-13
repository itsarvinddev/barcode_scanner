import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:mobile_scanner/mobile_scanner.dart'
    show MobileScannerBarcodeException;

import 'image_decoder/image_decoder.dart';
import 'image_file.dart';

/// A still image to read barcodes from: a file path, encoded bytes held in
/// memory, or an [XFile].
///
/// This is what `AiBarcodeScanner.galleryImagePicker` returns and what
/// `AiBarcodeScannerController.analyzeScannerImage` accepts. Wrap whatever
/// your picker hands you:
///
/// ```dart
/// // image_picker, file_selector, camera and desktop_drop all return XFile.
/// final file = await ImagePicker().pickImage(source: ImageSource.gallery);
/// return file == null ? null : ScannerImage.xFile(file);
///
/// // A picker that only gives you a path.
/// return ScannerImage.path(result.files.single.path!);
///
/// // A picker that only gives you bytes: the web, the clipboard, a download.
/// return ScannerImage.bytes(result.files.single.bytes!, name: 'code.png');
/// ```
///
/// The bytes are always an **encoded image file** — PNG, JPEG, WebP, HEIC,
/// GIF, BMP, whatever the platform's image decoders accept — exactly as they
/// would be stored on disk. They are not raw pixels: a camera frame's YUV or
/// RGBA buffer is not something this class can describe.
///
/// How the image is read depends on the platform:
///
/// * **Android, iOS and macOS** decode images through the OS, and those
///   decoders only open files. A path is handed over as it is; an image that
///   has no readable file behind it is written to a temporary file for the
///   duration of the analysis, and the file is deleted straight afterwards.
/// * **The web** has no file system. The bytes are decoded by the browser and
///   read by zxing-wasm; a path there is a `blob:` or `data:` URL whose bytes
///   are fetched first.
///
/// Instances are immutable, and equality is identity: comparing images by
/// content would mean comparing megabytes of bytes.
@immutable
final class ScannerImage {
  /// An image stored at [path].
  ///
  /// On Android, iOS and macOS this is a file-system path, handed to the
  /// platform decoder untouched — exactly what `imagePicker` returned before
  /// 8.1.0. On the web a browser never exposes a real path, so there [path]
  /// has to be a URL the page can fetch: typically the `blob:` URL an [XFile]
  /// carries.
  ///
  /// [name] and [mimeType] are informational; nothing reads them to decide how
  /// to decode the image.
  const ScannerImage.path(String this.path, {this.name, this.mimeType})
    : bytes = null,
      _file = null;

  /// An image held in memory as encoded [bytes] — the contents of a PNG, JPEG,
  /// WebP or other image file, not raw pixels.
  ///
  /// [name] and [mimeType] are informational: the format is recognised from
  /// the bytes themselves.
  const ScannerImage.bytes(Uint8List this.bytes, {this.name, this.mimeType})
    : path = null,
      _file = null;

  /// An image wrapped in an [XFile], as returned by `image_picker`,
  /// `file_selector`, `camera` and most other file APIs.
  ///
  /// [path], [name] and [mimeType] are copied from [file], with empty strings
  /// read as unknown. The file itself is kept, and is what [readAsBytes]
  /// reads, so an `XFile.fromData` is read from memory rather than from its
  /// empty or nominal path.
  ///
  /// On Android, iOS and macOS the file's path is analysed in place when a file
  /// really exists there; otherwise — an `XFile.fromData`, whose path is empty
  /// or nominal — its bytes go through a temporary file. On the web, where
  /// `XFile.path` is an object URL, its bytes are read instead.
  ///
  /// The existence check wins over the bytes: when a file exists at the
  /// `XFile`'s path, that file is what gets analysed on those platforms. So
  /// `XFile.fromData(bytes, path: realFile)` analyses the file on disk, not
  /// the bytes in memory; leave the path out, or point it somewhere that does
  /// not exist, to have the bytes analysed. An `XFile` whose file has gone
  /// missing is still handed to the platform by its path, which reports it
  /// as it would a missing [ScannerImage.path].
  ScannerImage.xFile(XFile file)
    : path = file.path.isEmpty ? null : file.path,
      bytes = null,
      name = file.name.isEmpty ? null : file.name,
      mimeType = file.mimeType,
      _file = file;

  /// Where the image lives: a file-system path on Android, iOS and macOS, or a
  /// URL on the web.
  ///
  /// `null` for an image created with [ScannerImage.bytes], and for an
  /// `XFile.fromData` without a path on a native platform. Use [readAsBytes]
  /// to get the contents of any image regardless of where it lives.
  final String? path;

  /// The encoded image, for an image created with [ScannerImage.bytes].
  ///
  /// `null` for the other constructors, even when the bytes could be read —
  /// use [readAsBytes] for that.
  final Uint8List? bytes;

  /// The file name, such as `receipt.png`, if known. Informational only.
  final String? name;

  /// The MIME type, such as `image/png`, if known. Informational only.
  final String? mimeType;

  /// The [XFile] this image was created from, if any.
  ///
  /// Kept private so the package does not re-export `cross_file`'s type as
  /// part of its own API; an app that wants the file still has it.
  final XFile? _file;

  /// Reads the whole encoded image, wherever it lives.
  ///
  /// Bytes are returned as they are, an [XFile] reads itself, and a path is
  /// read from disk — or, on the web, fetched. Throws whatever the underlying
  /// read throws when the file or URL cannot be read.
  Future<Uint8List> readAsBytes() {
    final inMemory = bytes;
    if (inMemory != null) return Future<Uint8List>.value(inMemory);

    final file = _file;
    if (file != null) return file.readAsBytes();

    // On the web, fetch the URL through the decoder's reader, which reports a
    // revoked or blocked URL the same way a native platform reports a missing
    // file: as a MobileScannerBarcodeException.
    if (kIsWeb) return readImageUrlBytes(path!);
    return XFile(path!).readAsBytes();
  }

  @override
  String toString() {
    final source =
        bytes != null
            ? '${bytes!.lengthInBytes} bytes'
            : '${_file != null ? 'XFile' : 'path'}: $path';
    final details = <String>[
      source,
      if (name != null) 'name: $name',
      if (mimeType != null) 'mimeType: $mimeType',
    ];
    return 'ScannerImage(${details.join(', ')})';
  }
}

/// Whether [image] was created with [ScannerImage.xFile].
///
/// Not exported. On the web an `XFile` reads itself — from the blob it holds
/// when it has one — rather than having its object URL fetched like a plain
/// [ScannerImage.path].
bool isXFileScannerImage(ScannerImage image) => image._file != null;

/// Runs [analyze] with a path to [image] that a native platform decoder can
/// open, and returns its result.
///
/// Not exported: this is how `AiBarcodeScannerController.analyzeScannerImage`
/// reaches Android, iOS and macOS, whose decoders only read files.
///
/// * A [ScannerImage.path] is handed over untouched — not even checked for
///   existence — so it behaves exactly as the path-based API always has,
///   including the platform's own error for a missing file.
/// * A [ScannerImage.xFile] is used in place when a file really exists at its
///   path. `XFile.fromData` carries an empty or nominal path, and its bytes
///   only exist in memory.
/// * Everything else is written to a temporary file that is deleted as soon as
///   [analyze] completes, whether it succeeded or threw.
///
/// An `XFile` whose bytes cannot be read — typically one whose file was
/// deleted or moved after it was picked — is handed to the platform by its
/// path after all, so the platform reports it exactly as it reports a
/// [ScannerImage.path] that does not exist, and a caller sees the same error
/// whichever constructor it used. Only an image with no path to fall back on
/// reports the failed read itself, as a [MobileScannerBarcodeException].
/// Errors from [analyze] propagate untouched.
///
/// Native platforms only: on the web, where there is no file system to write
/// the temporary file to, that step throws [UnsupportedError].
Future<T> withScannerImageFile<T>(
  ScannerImage image,
  Future<T> Function(String path) analyze,
) async {
  final path = image.path;
  if (path != null && image.bytes == null) {
    if (image._file == null || await isExistingImageFile(path)) {
      return analyze(path);
    }
  }

  final Uint8List bytes;
  try {
    bytes = await image.readAsBytes();
  } on Exception catch (error, stackTrace) {
    if (path != null) return analyze(path);
    Error.throwWithStackTrace(
      MobileScannerBarcodeException('Could not read the image ($error).'),
      stackTrace,
    );
  }
  return withTemporaryImageFile(bytes, analyze, mimeType: image.mimeType);
}
