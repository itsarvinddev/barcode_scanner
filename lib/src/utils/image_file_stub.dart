import 'dart:typed_data';

/// Whether a file exists at [path].
///
/// Always `false` without `dart:io`: there is no file system to look in.
Future<bool> isExistingImageFile(String path) => Future<bool>.value(false);

/// Runs [action] with the path of a temporary file holding [bytes].
///
/// Unavailable without `dart:io`, which in practice means the web; always
/// throws [UnsupportedError]. See the `dart:io` implementation for the
/// contract.
Future<T> withTemporaryImageFile<T>(
  Uint8List bytes,
  Future<T> Function(String path) action, {
  String? mimeType,
}) {
  throw UnsupportedError(
    'Temporary image files need dart:io, which this platform does not have.',
  );
}
