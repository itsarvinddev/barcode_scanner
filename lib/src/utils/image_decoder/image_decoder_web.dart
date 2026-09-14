import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:math' as math;
import 'dart:ui' show Offset, Size;

import 'package:flutter/foundation.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:web/web.dart' as web;

/// Whether this build carries the built-in still-image decoder.
///
/// `true` here: this is the web implementation, compiled by both dart2js and
/// dart2wasm.
const bool kHasWebImageDecoder = true;

/// The zxing-wasm release the decoder loads.
///
/// Keep this in sync with `zxingWasmVersion` in `mobile_scanner`'s
/// `lib/src/web/web_library_versions.dart`. The camera and this decoder use
/// one `ZXingWASM` global, so a mismatch would mean two different copies of
/// the script (and of its WebAssembly binary) and result format names that
/// differ depending on which copy defined the global last.
///
/// The sharing only works one way. This decoder reuses a zxing-wasm that
/// `mobile_scanner` already put on the page, but `mobile_scanner` does not
/// reuse one this decoder loaded — it only looks for a script tag with its own
/// id — so when an image is scanned before the camera's zxing-wasm reader
/// first starts, the camera loads the script again and instantiates the
/// WebAssembly module a second time.
const String zxingWasmVersion = '3.1.3';

/// Where the zxing-wasm reader is loaded from when no mirror is given.
///
/// The IIFE build defines `globalThis.ZXingWASM`. It fetches its WebAssembly
/// binary lazily, on the first read, from `fastly.jsdelivr.net` — a second
/// host a Content Security Policy has to allow.
const String zxingWasmScriptUrl =
    'https://cdn.jsdelivr.net/npm/zxing-wasm@$zxingWasmVersion'
    '/dist/iife/reader/index.js';

/// The id of the `<script>` tag this library injects.
///
/// Deliberately different from `mobile_scanner`'s own
/// `mobile-scanner-zxing-wasm`: that package skips loading when a tag with its
/// id exists, and must keep doing so for its own script, not ours.
const String _scriptId = 'ai-barcode-scanner-zxing-wasm';

/// Images whose long edge is above this are first read at this size.
///
/// Photos straight off a phone are 12 to 50 megapixels, and zxing's cost grows
/// with the pixel count while the barcode in a typical photo is large enough
/// to survive a downscale. 2560 keeps a first read well under a second on a
/// mid-range phone and still leaves a QR code that fills a tenth of the frame
/// several pixels per module.
const int _firstPassLongEdge = 2560;

/// The largest long edge the full-size second read will rasterize.
const int _maxLongEdge = 8192;

/// The largest pixel count the full-size second read will rasterize.
///
/// iOS Safari refuses canvases above 16,777,216 pixels (4096 × 4096) — the
/// context comes back `null` or silently draws nothing — and zxing copies a
/// grey byte per pixel into its WebAssembly heap on top of that. A 48 MP photo
/// would pass the [_maxLongEdge] cap, so the area needs a cap of its own.
const int _maxPixels = 16777216;

/// Called with the raster size of every zxing read, for tests.
///
/// The two-pass sizing is invisible in the result by design — corners are
/// always reported in the original image's coordinates — so this is the only
/// way to observe which passes ran.
@visibleForTesting
void Function(int width, int height)? debugOnImageDecoderPass;

/// The raster sizes [decodeBarcodesFromImageBytes] reads a [width] × [height]
/// image at, smallest first, for tests.
///
/// Lets the size caps be checked for any image size without allocating the
/// image.
@visibleForTesting
List<Size> debugImageDecoderPassSizes(int width, int height) => <Size>[
  for (final pass in _passSizes(width, height))
    Size(pass.width.toDouble(), pass.height.toDouble()),
];

/// Forgets the in-flight or failed script load, any in-flight retry of the
/// WebAssembly module, and any URL given to [useImageDecoderScriptUrl], for
/// tests.
///
/// Does not touch the DOM or the `ZXingWASM` global; a test that wants a cold
/// start removes those itself.
@visibleForTesting
void debugResetImageDecoder() {
  _pendingLoad = null;
  _pendingModuleRetry = null;
  _appScriptUrl = null;
}

/// The zxing-wasm reader URL the app configured through
/// `AiBarcodeScanner.webBarcodeLibraryScriptUrl` or
/// `AiBarcodeScannerController.setWebImageDecoderScriptUrl`, if any.
String? _appScriptUrl;

/// Loads zxing-wasm from [scriptUrl] instead of jsDelivr, from now on.
///
/// The scanner calls this with the `webBarcodeLibraryScriptUrl` it hands to
/// `mobile_scanner`, whenever that is a zxing-wasm build: an app mirrors the
/// library because its page cannot load it from the CDN, and that applies to
/// scanning a picked image just as much as to the camera. Loading the same
/// copy also keeps the camera and the decoder on one build of zxing-wasm.
/// `AiBarcodeScannerController.setWebImageDecoderScriptUrl` exposes it for
/// apps that scan images without a scanner on the page.
///
/// As with `MobileScannerPlatform.setBarcodeLibraryScriptUrl`, the setting is
/// for the whole page and the first URL wins. An explicit `scriptUrl` passed
/// to [decodeBarcodesFromImageBytes] still takes precedence.
void useImageDecoderScriptUrl(String scriptUrl) {
  _appScriptUrl ??= scriptUrl;
}

// -----------------------------------------------------------------------------
// Public (package-internal) API
// -----------------------------------------------------------------------------

/// Looks for barcodes in the encoded image [bytes] — PNG, JPEG, WebP, GIF, or
/// any other format the browser's own image decoders accept.
///
/// This is the web counterpart of `MobileScannerController.analyzeImage`, and
/// keeps its contract so callers can treat both alike:
///
/// * Barcodes found: a [BarcodeCapture] whose [BarcodeCapture.size] is the
///   image's size, with every barcode's corners in that image's pixel
///   coordinates. EXIF orientation is applied first, so "the image" is the
///   picture as a gallery shows it, not as the sensor stored it.
/// * Nothing found: a capture with no barcodes — which is what Android, iOS
///   and macOS return too. The return type stays nullable to match
///   `analyzeImage`; treat `null` and an empty capture the same.
/// * The bytes are not a decodable image, or the decoder could not be loaded:
///   a [MobileScannerBarcodeException], as a native platform throws for a file
///   it cannot read.
///
/// [formats] restricts detection, exactly as it does for the camera; empty, or
/// containing [BarcodeFormat.all], means every format.
///
/// [scriptUrl] replaces the jsDelivr URL of the zxing-wasm reader, for apps
/// that self-host it; without one, the URL given to
/// [useImageDecoderScriptUrl] does. It must be the same IIFE build. If
/// `mobile_scanner` (or an earlier call) has already put a working `ZXingWASM`
/// on the page, that instance is reused and nothing is loaded.
Future<BarcodeCapture?> decodeBarcodesFromImageBytes(
  Uint8List bytes, {
  List<BarcodeFormat> formats = const <BarcodeFormat>[],
  String? scriptUrl,
}) async {
  // Start fetching the library while the browser decodes the image: on a cold
  // start the two are independent network/CPU waits. `ignore` only stops an
  // early failure from surfacing as an unhandled error if the image decode
  // throws first; the `await` below still receives it.
  final zxingLoad = _loadZXingWasm(
    scriptUrl ?? _appScriptUrl ?? zxingWasmScriptUrl,
  )..ignore();

  final bitmap = await _decodeImage(bytes);
  try {
    final width = bitmap.width;
    final height = bitmap.height;
    if (width <= 0 || height <= 0) {
      throw const MobileScannerBarcodeException(
        'The selected file decoded to an empty image.',
      );
    }

    final zxing = await zxingLoad;
    await _prepareModule(zxing);
    final options = _readerOptions(formats);
    final imageSize = Size(width.toDouble(), height.toDouble());

    for (final pass in _passSizes(width, height)) {
      final barcodes = await _readPass(
        zxing,
        bitmap,
        pass.width,
        pass.height,
        options,
      );
      if (barcodes.isNotEmpty) {
        return BarcodeCapture(barcodes: barcodes, size: imageSize);
      }
    }

    return BarcodeCapture(size: imageSize);
  } finally {
    // An ImageBitmap pins its decoded pixels — 48 MB for a 12 MP photo — until
    // it is closed or collected, and collection is not prompt.
    bitmap.close();
  }
}

/// Reads the bytes behind a browser URL: a `blob:` object URL (what `XFile`
/// carries as its path on the web), a `data:` URL, or an `http(s):` URL the
/// page is allowed to fetch.
///
/// A failed read throws [MobileScannerBarcodeException], matching what a
/// native platform throws for a path it cannot open.
Future<Uint8List> readImageUrlBytes(String url) async {
  final web.Response response;
  try {
    response = await web.window.fetch(url.toJS).toDart;
  } catch (error) {
    // A network failure, a revoked object URL, or a CSP `connect-src` block.
    // The error type differs between dart2js (a DOM exception) and dart2wasm
    // (a wrapped JS value), hence the untyped catch. The browser reports a CSP
    // block as the same generic failure as the others, so name the source the
    // policy would have to allow.
    throw MobileScannerBarcodeException(
      'Could not read the image at ${_describeUrl(url)} ($error). If the page '
      'has a Content Security Policy, make sure it allows '
      '${_connectSrcSourceFor(url)} in connect-src.',
    );
  }

  if (!response.ok) {
    throw MobileScannerBarcodeException(
      'Could not read the image at ${_describeUrl(url)} '
      '(HTTP ${response.status}).',
    );
  }

  try {
    final buffer = await response.arrayBuffer().toDart;
    return buffer.toDart.asUint8List();
  } catch (error) {
    throw MobileScannerBarcodeException(
      'Could not read the image at ${_describeUrl(url)} ($error).',
    );
  }
}

/// [url] as it can go into an error message: a `data:` URL carries the whole
/// image, which would bury the message under megabytes of base64.
String _describeUrl(String url) =>
    url.length <= 128 ? url : '${url.substring(0, 125)}...';

/// The Content Security Policy `connect-src` source that lets the page fetch
/// [url]: the `blob:` or `data:` scheme, or an `http(s)` URL's origin.
///
/// The schemes are recognised from the prefix, so a megabytes-long `data:` URL
/// is not parsed just to name its scheme.
String _connectSrcSourceFor(String url) {
  final scheme = url.substring(0, math.min(url.length, 5)).toLowerCase();
  if (scheme == 'blob:') return 'blob:';
  if (scheme == 'data:') return 'data:';
  final uri = Uri.tryParse(url);
  if (uri != null &&
      (uri.scheme == 'http' || uri.scheme == 'https') &&
      uri.hasAuthority) {
    return uri.origin;
  }
  return 'that URL';
}

// -----------------------------------------------------------------------------
// Loading zxing-wasm
// -----------------------------------------------------------------------------

/// The load every concurrent first call shares, so the script is injected
/// once. Cleared when it fails, so the next attempt starts afresh instead of
/// replaying a network error for the rest of the session.
Future<_ZXingWasm>? _pendingLoad;

/// Resolves to a ready `ZXingWASM`, loading the script only if needed.
Future<_ZXingWasm> _loadZXingWasm(String scriptUrl) {
  // `mobile_scanner` loads the same global for the camera; after a hot restart
  // our own earlier load is still on the page. Either way there is nothing to
  // do.
  final ready = _readyZXingWasm();
  if (ready != null) return Future<_ZXingWasm>.value(ready);

  final pending = _pendingLoad;
  if (pending != null) return pending;

  final load = _injectScript(scriptUrl);
  _pendingLoad = load;
  load.then<void>(
    (_) {},
    onError: (Object _) {
      if (identical(_pendingLoad, load)) _pendingLoad = null;
    },
  );
  return load;
}

/// The page's `ZXingWASM`, if one is loaded and usable.
///
/// Checks for a callable `readBarcodes` rather than just the global: a
/// half-initialised or unrelated object under that name must not be mistaken
/// for the library.
_ZXingWasm? _readyZXingWasm() {
  final global = _zxingWasmGlobal;
  if (global == null || !global.typeofEquals('object')) return null;
  final readBarcodes = global.getProperty<JSAny?>('readBarcodes'.toJS);
  if (readBarcodes == null || !readBarcodes.typeofEquals('function')) {
    return null;
  }
  return global;
}

Future<_ZXingWasm> _injectScript(String scriptUrl) async {
  // A tag we did not see finish can only be left over from before a hot
  // restart. Its load event may already have fired, so waiting for it could
  // hang forever; replace it instead. Running the IIFE twice is harmless — it
  // only reassigns the global, and the WebAssembly binary is fetched lazily and
  // cached by the browser.
  web.document.querySelector('script#$_scriptId')?.remove();

  // Completes with whether the script loaded. Only the first event counts.
  final loaded = Completer<bool>();
  final script =
      web.HTMLScriptElement()
        ..id = _scriptId
        ..async = true
        ..crossOrigin = 'anonymous'
        ..src = scriptUrl
        ..onload = ((web.Event _) => _completeOnce(loaded, true)).toJS
        ..onerror = ((web.Event _) => _completeOnce(loaded, false)).toJS;
  web.document.head!.appendChild(script);

  final didLoad = await loaded.future;
  final zxing = didLoad ? _readyZXingWasm() : null;
  if (zxing != null) return zxing;

  // Remove the dead tag so that a retry starts from a clean page.
  script.remove();

  if (!didLoad) {
    // A network error, a blocked host, or a CSP `script-src` violation — the
    // browser does not say which.
    throw MobileScannerBarcodeException(
      'Could not load the zxing-wasm barcode decoder from $scriptUrl. '
      'Scanning images on the web downloads it from jsDelivr on first use: '
      "check the network connection, and make sure the page's Content "
      'Security Policy allows https://cdn.jsdelivr.net in script-src — and, '
      'for its WebAssembly binary, https://fastly.jsdelivr.net in connect-src '
      "and 'wasm-unsafe-eval' in script-src.",
    );
  }
  throw MobileScannerBarcodeException(
    'The script at $scriptUrl loaded, but did not define '
    'ZXingWASM.readBarcodes. A self-hosted copy must be the IIFE reader '
    'build of zxing-wasm $zxingWasmVersion (dist/iife/reader/index.js).',
  );
}

void _completeOnce(Completer<bool> completer, bool value) {
  if (!completer.isCompleted) completer.complete(value);
}

/// The one fresh instantiation attempt that every call whose first attempt
/// failed shares; see [_prepareModule]. Cleared once it settles.
Future<void>? _pendingModuleRetry;

/// Instantiates zxing-wasm's WebAssembly module, downloading its binary on
/// first use, and recovers from a failed download.
///
/// zxing-wasm caches the promise of its module and never forgets a rejected
/// one. Left alone, a single failed download — a connection that drops during
/// the first scan — would make every later read fail at once with the same
/// error, without another request, until the page is reloaded. So the module
/// is instantiated here as a step of its own, and when that fails zxing-wasm
/// is told to drop the promise and one fresh attempt is made.
///
/// The fresh attempt is not only for a download that fails right now. The
/// cached promise belongs to the page, not to this decoder: `mobile_scanner`'s
/// zxing-wasm camera reader calls `readBarcodes` on every frame and swallows
/// the errors, so a download that failed while the camera was running leaves
/// a rejected promise that no scan of ours ever saw. Merely dropping it would
/// fail the first gallery scan after the network comes back, and only the
/// second would work. Retrying once right away makes that first scan succeed,
/// and costs a genuinely offline scan one more immediate failed request.
///
/// Concurrent calls whose first attempts fail share a single retry, and only
/// the call that starts it drops the cached promise: dropping it while the
/// retry is in flight would discard the retry's own download. When the retry
/// fails too, the promise is dropped again, so the next scan — or the camera
/// — downloads the binary afresh instead of replaying this failure.
///
/// Keeping this apart from the read itself means an error from `readBarcodes`
/// never discards a module that works.
Future<void> _prepareModule(_ZXingWasm zxing) async {
  // zxing-wasm 3.x has this. A caller-supplied build without it is read as
  // before, and a failed download surfaces from the read instead.
  final prepare = zxing.getProperty<JSAny?>('prepareZXingModule'.toJS);
  if (prepare == null || !prepare.typeofEquals('function')) return;

  try {
    await zxing
        .instantiateModule(_PrepareOptions(fireImmediately: true))
        .toDart;
    return;
  } catch (_) {
    // Possibly a rejection someone else left in zxing-wasm's cache; the retry
    // below reports the error that matters, its own.
  }

  var retry = _pendingModuleRetry;
  if (retry == null) {
    // Cleared from a listener rather than inside `_retryModule`: a listener
    // always runs after this assignment, even if the retry fails
    // synchronously, so a settled retry is never left behind to be joined by
    // a later scan.
    late final Future<void> started;
    started = _retryModule(zxing).whenComplete(() {
      if (identical(_pendingModuleRetry, started)) _pendingModuleRetry = null;
    });
    _pendingModuleRetry = retry = started;
  }
  await retry;
}

/// Drops zxing-wasm's cached module promise and instantiates the module once
/// more, throwing [MobileScannerBarcodeException] if that fails as well.
Future<void> _retryModule(_ZXingWasm zxing) async {
  try {
    _dropModulePromise(zxing);
    await zxing
        .instantiateModule(_PrepareOptions(fireImmediately: true))
        .toDart;
  } catch (error) {
    _dropModulePromise(zxing);
    throw MobileScannerBarcodeException(
      'zxing-wasm could not load its WebAssembly binary ($error). It is '
      'downloaded from https://fastly.jsdelivr.net on first use: check the '
      "network connection, and make sure the page's Content Security Policy "
      "allows that host in connect-src and 'wasm-unsafe-eval' in script-src. "
      'The next scan downloads it again.',
    );
  }
}

/// Makes zxing-wasm forget its cached module promise, keeping its overrides.
///
/// Without `overrides`, zxing-wasm keeps the ones it has — including any the
/// page set to self-host the binary — and compares them with themselves. An
/// equality check that always fails makes it store them again without the
/// promise. `purgeZXingModule` would drop the promise too, but would also
/// reset those overrides to its defaults.
void _dropModulePromise(_ZXingWasm zxing) {
  zxing.configureModule(
    _PrepareOptions.withEqualityFn(
      equalityFn: ((JSAny? _, JSAny? _) => false).toJS,
    ),
  );
}

// -----------------------------------------------------------------------------
// Decoding
// -----------------------------------------------------------------------------

/// Lets the browser decode the file, honouring EXIF orientation.
///
/// Handing zxing the encoded bytes directly would skip this step, and zxing's
/// own file decoder is far narrower than a browser's: it silently finds
/// nothing in a WebP, and ignores orientation.
Future<web.ImageBitmap> _decodeImage(Uint8List bytes) async {
  final blob = web.Blob(<web.BlobPart>[bytes.toJS].toJS);

  try {
    // Current engines already default to `from-image`; saying so explicitly
    // covers those that shipped `createImageBitmap` before the default changed.
    return await web.window
        .createImageBitmap(
          blob,
          web.ImageBitmapOptions(imageOrientation: 'from-image'),
        )
        .toDart;
  } catch (_) {
    // Either the bytes are not an image, or an older engine rejected the
    // `from-image` value (added to the spec later) with a TypeError. Retry
    // without options to tell the two apart.
  }

  try {
    return await web.window.createImageBitmap(blob).toDart;
  } catch (error) {
    // dart2js surfaces a DOMException, dart2wasm a wrapped JS value: catch
    // everything and normalise it to what native platforms throw.
    throw MobileScannerBarcodeException(
      'The selected file could not be decoded as an image ($error).',
    );
  }
}

/// The raster sizes to try, smallest first.
///
/// Small images are read once, at full size. Large ones are read once
/// downscaled to [_firstPassLongEdge] and, only if that finds nothing, again at
/// full size within the [_maxLongEdge] and [_maxPixels] caps: a small or dense
/// barcode in a large photo can lose too much detail in the downscale.
List<({int width, int height})> _passSizes(int width, int height) {
  final longEdge = math.max(width, height);
  final fullScale = math.min(
    1.0,
    math.min(_maxLongEdge / longEdge, math.sqrt(_maxPixels / (width * height))),
  );

  ({int width, int height}) scaled(double scale) => (
    width: math.max(1, (width * scale).round()),
    height: math.max(1, (height * scale).round()),
  );

  var full = scaled(fullScale);
  // Rounding each edge on its own can leave an area-capped image just over
  // [_maxPixels] — 8000 × 6000, a 48 MP photo, comes out at 4730 × 3547, 94
  // pixels too many, and iOS Safari's limit leaves no slack. Trim the longer
  // edge until it fits: it takes a pixel or two, and `_readPass` maps corners
  // back with a separate scale per axis.
  while (full.width * full.height > _maxPixels) {
    full =
        full.width >= full.height
            ? (width: full.width - 1, height: full.height)
            : (width: full.width, height: full.height - 1);
  }
  if (longEdge <= _firstPassLongEdge) return [full];

  final first = scaled(_firstPassLongEdge / longEdge);
  if (full.width <= first.width && full.height <= first.height) return [first];
  return [first, full];
}

/// Draws [bitmap] at [width] × [height] and reads every barcode in it, with
/// corners mapped back to the bitmap's own coordinates.
Future<List<Barcode>> _readPass(
  _ZXingWasm zxing,
  web.ImageBitmap bitmap,
  int width,
  int height,
  _ReaderOptions options,
) async {
  debugOnImageDecoderPass?.call(width, height);

  final pixels = _rasterize(bitmap, width, height);

  final JSArray<_ReadResult> results;
  try {
    results = await zxing.readBarcodes(pixels, options).toDart;
  } catch (error) {
    // A failed download of the WebAssembly binary is reported by
    // `_prepareModule` before any read, so this is zxing itself failing.
    throw MobileScannerBarcodeException(
      'zxing-wasm could not read the image ($error).',
    );
  }

  // Per-axis ratios, because each edge was rounded to whole pixels separately.
  final scaleX = width / bitmap.width;
  final scaleY = height / bitmap.height;

  return <Barcode>[
    for (final result in results.toDart)
      // zxing only reports failed checks when asked to (`returnErrors`); this
      // guards against a caller-supplied build that defaults otherwise.
      if (result.isValid) _toBarcode(result, scaleX, scaleY),
  ];
}

/// Rasterizes [bitmap] at [width] × [height] into RGBA pixels.
web.ImageData _rasterize(web.ImageBitmap bitmap, int width, int height) {
  try {
    // Transparent pixels come out of a canvas as (0, 0, 0, 0), and zxing
    // ignores alpha — so the transparent background of a generated QR code
    // would read as black and swallow its dark modules. Paint the page white
    // first, as a gallery viewer effectively does.
    final context =
        _create2dContext(width, height)
          ..fillStyle = '#ffffff'
          ..fillRect(0, 0, width, height)
          ..imageSmoothingEnabled = true
          ..imageSmoothingQuality = 'high'
          ..drawImage(bitmap, 0, 0, width, height);
    return context.getImageData(0, 0, width, height);
  } on MobileScannerBarcodeException {
    rethrow;
  } catch (error) {
    throw MobileScannerBarcodeException(
      'Could not rasterize the image at $width × $height ($error).',
    );
  }
}

/// A 2D context of [width] × [height] optimised for a pixel read-back.
///
/// Prefers an `OffscreenCanvas`, which never touches the document, and falls
/// back to a detached `<canvas>` on engines without one (Safari before 16.4).
_Canvas2D _create2dContext(int width, int height) {
  // `willReadFrequently` keeps the backing store in memory rather than on the
  // GPU, which turns the single `getImageData` below from a GPU read-back into
  // a copy.
  final settings = web.CanvasRenderingContext2DSettings(
    willReadFrequently: true,
  );

  if (globalContext.has('OffscreenCanvas')) {
    final context = web.OffscreenCanvas(
      width,
      height,
    ).getContext('2d', settings);
    if (context != null) return _Canvas2D(context);
  }

  final canvas =
      web.HTMLCanvasElement()
        ..width = width
        ..height = height;
  final context = canvas.getContext('2d', settings);
  if (context == null) {
    throw MobileScannerBarcodeException(
      'The browser could not create a $width × $height canvas to read the '
      'image.',
    );
  }
  return _Canvas2D(context);
}

/// The reader options for [formats], as `mobile_scanner` builds them for the
/// camera — but slower and more thorough, since a still image is read once
/// rather than fifteen times a second.
_ReaderOptions _readerOptions(List<BarcodeFormat> formats) {
  final names = <JSString>[
    if (!formats.contains(BarcodeFormat.all))
      for (final format in formats)
        if (_zxingFormatName(format) case final name?) name.toJS,
  ];

  // Omit `formats` rather than passing an empty list or null: zxing-wasm
  // crashes on `formats: null`. When none of the requested formats exist in
  // zxing, this also detects everything instead of nothing, as
  // `mobile_scanner` does.
  if (names.isEmpty) {
    return _ReaderOptions(
      tryHarder: true,
      tryRotate: true,
      // Light-on-dark codes are rare on the camera but common in screenshots
      // of dark-mode apps, and a still image can afford the extra pass.
      tryInvert: true,
      maxNumberOfSymbols: _maxNumberOfSymbols,
    );
  }
  return _ReaderOptions.withFormats(
    formats: names.toJS,
    tryHarder: true,
    tryRotate: true,
    tryInvert: true,
    maxNumberOfSymbols: _maxNumberOfSymbols,
  );
}

/// Report every barcode in the picture, as the native decoders do.
///
/// 255 is zxing-wasm 3.x's default and the largest finite limit its 8-bit
/// option holds. It is set explicitly rather than left to the default so a
/// self-hosted build that defaults lower still reports every barcode; `0`
/// ("no limit" in 3.x) is avoided because it is not documented for older
/// builds.
const int _maxNumberOfSymbols = 255;

Barcode _toBarcode(_ReadResult result, double scaleX, double scaleY) {
  final position = result.position;
  final topLeft = position.topLeft;
  final topRight = position.topRight;
  final bottomRight = position.bottomRight;
  final bottomLeft = position.bottomLeft;

  final corners = <Offset>[
    if (topLeft != null &&
        topRight != null &&
        bottomRight != null &&
        bottomLeft != null)
      for (final point in [topLeft, topRight, bottomRight, bottomLeft])
        Offset(point.x / scaleX, point.y / scaleY),
  ];

  final rawBytes = result.bytes?.toDart;

  return Barcode(
    corners: corners,
    format: _barcodeFormatFromZXing(result.format),
    displayValue: result.text,
    rawValue: result.text,
    // Populated for parity with `mobile_scanner`'s camera results on the web,
    // which still fill the deprecated field for older callers.
    // ignore: deprecated_member_use
    rawBytes: rawBytes,
    rawDecodedBytes:
        rawBytes == null ? null : DecodedBarcodeBytes(bytes: rawBytes),
    size: _boundingBoxSize(corners),
    // zxing does not parse payloads into URLs, contacts and so on; neither does
    // `mobile_scanner` on the web.
    type: BarcodeType.text,
  );
}

Size _boundingBoxSize(List<Offset> corners) {
  if (corners.length != 4) return Size.zero;
  final xs = corners.map((corner) => corner.dx);
  final ys = corners.map((corner) => corner.dy);
  return Size(
    xs.reduce(math.max) - xs.reduce(math.min),
    ys.reduce(math.max) - ys.reduce(math.min),
  );
}

// -----------------------------------------------------------------------------
// Format names
// -----------------------------------------------------------------------------

/// The zxing-wasm 3.x name for [format], or `null` if zxing cannot read it.
///
/// Mirrors `mobile_scanner`'s own mapping, so the camera and a picked image
/// honour a format restriction identically.
///
/// The trailing wildcard is load-bearing even though every current value is
/// listed: this package accepts any `mobile_scanner` 7.x, and an exhaustive
/// switch over [BarcodeFormat] would stop compiling for the web the day a
/// minor release adds a format. An unknown one is simply not restricted to.
String? _zxingFormatName(BarcodeFormat format) => switch (format) {
  BarcodeFormat.aztec => 'Aztec',
  BarcodeFormat.codabar => 'Codabar',
  BarcodeFormat.code39 => 'Code39',
  BarcodeFormat.code93 => 'Code93',
  BarcodeFormat.code128 => 'Code128',
  BarcodeFormat.dataBar => 'DataBar',
  BarcodeFormat.dataBarExpanded => 'DataBarExp',
  BarcodeFormat.dataBarLimited => 'DataBarLtd',
  BarcodeFormat.dataMatrix => 'DataMatrix',
  BarcodeFormat.ean8 => 'EAN8',
  BarcodeFormat.ean13 => 'EAN13',
  // Deprecated in favour of `itf2of5`, but still what older callers pass.
  // ignore: deprecated_member_use
  BarcodeFormat.itf ||
  BarcodeFormat.itf2of5 ||
  BarcodeFormat.itf2of5WithChecksum => 'ITF',
  BarcodeFormat.itf14 => 'ITF14',
  BarcodeFormat.maxiCode => 'MaxiCode',
  BarcodeFormat.pdf417 => 'PDF417',
  BarcodeFormat.qrCode => 'QRCode',
  BarcodeFormat.microQrCode => 'MicroQRCode',
  BarcodeFormat.upcA => 'UPCA',
  BarcodeFormat.upcE => 'UPCE',
  BarcodeFormat.all || BarcodeFormat.unknown || _ => null,
};

/// Maps a format name reported by zxing-wasm to a [BarcodeFormat].
///
/// Names are compared with case and punctuation stripped, because they have
/// changed shape between releases — 2.x reported `EAN-13` and `UPC-A` where
/// 3.x reports `EAN13` and `UPCA`, and 3.x's human-readable labels read
/// `QR Code` — and a page may carry whichever build `mobile_scanner` or a
/// self-hosted mirror loaded. Variant names (`ISBN`, `AztecCode`, `Code39Ext`,
/// ...) fold into their family.
BarcodeFormat _barcodeFormatFromZXing(String name) {
  final key = name.toLowerCase().replaceAll(_nonAlphanumeric, '');
  return switch (key) {
    'aztec' || 'azteccode' || 'aztecrune' => BarcodeFormat.aztec,
    'codabar' => BarcodeFormat.codabar,
    'code39' ||
    'code39std' ||
    'code39ext' ||
    'code32' ||
    'pzn' ||
    'pharmazentralnummer' => BarcodeFormat.code39,
    'code93' => BarcodeFormat.code93,
    'code128' => BarcodeFormat.code128,
    'databar' ||
    'databaromni' ||
    'databarstk' ||
    'databarstacked' ||
    'databarstkomni' ||
    'databarstackedomni' => BarcodeFormat.dataBar,
    'databarexp' ||
    'databarexpanded' ||
    'databarexpstk' ||
    'databarexpandedstacked' => BarcodeFormat.dataBarExpanded,
    'databarltd' || 'databarlimited' => BarcodeFormat.dataBarLimited,
    'datamatrix' => BarcodeFormat.dataMatrix,
    'ean8' => BarcodeFormat.ean8,
    'ean13' || 'isbn' => BarcodeFormat.ean13,
    // `mobile_scanner` reports plain ITF from its web camera reader as this
    // value too; matching it keeps a code's format independent of whether it
    // was scanned live or from the gallery.
    // ignore: deprecated_member_use
    'itf' => BarcodeFormat.itf,
    'itf14' => BarcodeFormat.itf14,
    'maxicode' => BarcodeFormat.maxiCode,
    'pdf417' || 'compactpdf417' || 'micropdf417' => BarcodeFormat.pdf417,
    'qrcode' || 'qrcodemodel1' || 'qrcodemodel2' => BarcodeFormat.qrCode,
    'microqrcode' => BarcodeFormat.microQrCode,
    'upca' => BarcodeFormat.upcA,
    'upce' => BarcodeFormat.upcE,
    _ => BarcodeFormat.unknown,
  };
}

final RegExp _nonAlphanumeric = RegExp('[^a-z0-9]');

// -----------------------------------------------------------------------------
// JS interop
// -----------------------------------------------------------------------------
//
// Declared here rather than imported from `mobile_scanner`, whose bindings live
// under `lib/src/` and may change in any release. None of the extension types
// carry `@JS` annotations; the object-literal factories below rely on that.

@JS('ZXingWASM')
external _ZXingWasm? get _zxingWasmGlobal;

/// The `ZXingWASM` global defined by the IIFE reader build.
extension type _ZXingWasm._(JSObject _) implements JSObject {
  /// Resolves to every barcode zxing found in [input].
  external JSPromise<JSArray<_ReadResult>> readBarcodes(
    web.ImageData input,
    _ReaderOptions options,
  );

  /// `prepareZXingModule` with `fireImmediately: true`: resolves once the
  /// WebAssembly module is instantiated, starting that if needed.
  @JS('prepareZXingModule')
  external JSPromise<JSAny?> instantiateModule(_PrepareOptions options);

  /// `prepareZXingModule` without `fireImmediately`: only updates what the
  /// next instantiation uses, and returns nothing.
  @JS('prepareZXingModule')
  external void configureModule(_PrepareOptions options);
}

/// A zxing-wasm `PrepareZXingModuleOptions` object literal.
extension type _PrepareOptions._(JSObject _) implements JSObject {
  external factory _PrepareOptions({bool fireImmediately});

  external factory _PrepareOptions.withEqualityFn({JSFunction equalityFn});
}

/// A zxing-wasm `ReaderOptions` object literal. Unset keys keep their defaults.
extension type _ReaderOptions._(JSObject _) implements JSObject {
  external factory _ReaderOptions({
    bool tryHarder,
    bool tryRotate,
    bool tryInvert,
    int maxNumberOfSymbols,
  });

  external factory _ReaderOptions.withFormats({
    JSArray<JSString> formats,
    bool tryHarder,
    bool tryRotate,
    bool tryInvert,
    int maxNumberOfSymbols,
  });
}

/// One entry of the array `readBarcodes` resolves to.
extension type _ReadResult._(JSObject _) implements JSObject {
  external String? get text;
  external String get format;
  external JSUint8Array? get bytes;
  external bool get isValid;
  external _Position get position;
}

extension type _Position._(JSObject _) implements JSObject {
  external _Point? get topLeft;
  external _Point? get topRight;
  external _Point? get bottomRight;
  external _Point? get bottomLeft;
}

extension type _Point._(JSObject _) implements JSObject {
  external double get x;
  external double get y;
}

/// The members `CanvasRenderingContext2D` and
/// `OffscreenCanvasRenderingContext2D` share, so one code path drives either.
extension type _Canvas2D(JSObject _) implements JSObject {
  external set fillStyle(String value);
  external set imageSmoothingEnabled(bool value);
  external set imageSmoothingQuality(String value);
  external void fillRect(num x, num y, num width, num height);
  external void drawImage(
    web.ImageBitmap image,
    num dx,
    num dy,
    num width,
    num height,
  );
  external web.ImageData getImageData(int sx, int sy, int sw, int sh);
}
