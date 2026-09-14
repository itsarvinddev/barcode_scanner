import 'dart:io';
import 'dart:ui' as ui;

import 'package:ai_barcode_scanner/ai_barcode_scanner.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_camera.dart';

/// The phone every scene is rendered on: an iPhone 15 Pro's logical size,
/// pixel ratio and safe area.
abstract final class Phone {
  static const Size logicalSize = Size(393, 852);
  static const double pixelRatio = 3;
  static const double statusBar = 59;
  static const double homeIndicator = 34;
}

/// Where rendered screens are written: `build/screens/<name>.png`.
final Directory outputDir = Directory('build/screens');

final GlobalKey _boundaryKey = GlobalKey();

/// Locates the Flutter SDK the test is running under.
///
/// `flutter test` runs `flutter_tester` out of
/// `<sdk>/bin/cache/artifacts/engine/<platform>/`, so the SDK can be found
/// from the executable even when `FLUTTER_ROOT` is not in the environment.
String _flutterRoot() {
  final fromEnv = Platform.environment['FLUTTER_ROOT'];
  if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;
  var dir = File(Platform.resolvedExecutable).parent;
  while (dir.parent.path != dir.path) {
    if (File('${dir.path}/bin/flutter').existsSync()) return dir.path;
    dir = dir.parent;
  }
  throw StateError(
    'Could not locate the Flutter SDK from FLUTTER_ROOT or '
    '${Platform.resolvedExecutable}.',
  );
}

bool _fontsLoaded = false;

/// Loads Roboto and the Material Icons font from the Flutter SDK's cache.
///
/// Tests otherwise render every glyph with the box-drawing test font.
Future<void> loadFonts() async {
  if (_fontsLoaded) return;
  final dir = '${_flutterRoot()}/bin/cache/artifacts/material_fonts';

  Future<ByteData> read(String file) async =>
      ByteData.sublistView(await File('$dir/$file').readAsBytes());

  const weights = <String>[
    'Roboto-Light.ttf',
    'Roboto-Regular.ttf',
    'Roboto-Medium.ttf',
    'Roboto-Bold.ttf',
  ];
  // Roboto also stands in for the families Flutter's iOS typography asks
  // for. Text that names no family at all still gets the test font — the
  // tester does not let that be replaced — which is why no scene turns on
  // `showBarcodeHighlights`: mobile_scanner paints its value label that way.
  for (final family in <String>[
    'Roboto',
    'CupertinoSystemText',
    'CupertinoSystemDisplay',
    '.SF Pro Text',
    '.SF Pro Display',
    '.SF UI Text',
    '.SF UI Display',
  ]) {
    final loader = FontLoader(family);
    for (final file in weights) {
      loader.addFont(read(file));
    }
    await loader.load();
  }
  await (FontLoader('MaterialIcons')
    ..addFont(read('MaterialIcons-Regular.otf'))).load();
  _fontsLoaded = true;
}

/// Sizes the test view like [Phone] and installs [platform] as the camera.
void setUpPhone(
  WidgetTester tester,
  FakeCameraPlatform platform, {
  Size logicalSize = Phone.logicalSize,
}) {
  final padding = FakeViewPadding(
    top: Phone.statusBar * Phone.pixelRatio,
    bottom: Phone.homeIndicator * Phone.pixelRatio,
  );
  final view =
      tester.view
        ..devicePixelRatio = Phone.pixelRatio
        ..physicalSize = logicalSize * Phone.pixelRatio
        ..padding = padding
        ..viewPadding = padding;
  addTearDown(view.reset);

  MobileScannerPlatform.instance = platform;
  addTearDown(MobileScannerController.resetPlatformSessionOwner);
}

/// Wraps [home] in the app every scene shares, inside the boundary that
/// [capture] reads back.
Widget sceneApp({required Widget home, ThemeData? theme}) {
  return RepaintBoundary(
    key: _boundaryKey,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme ?? appTheme(Brightness.dark),
      home: home,
    ),
  );
}

/// The host app's Material 3 theme, seeded like the package's example app.
ThemeData appTheme(
  Brightness brightness, {
  Color seed = const Color(0xFF0A84FF),
}) {
  return ThemeData(
    useMaterial3: true,
    colorSchemeSeed: seed,
    brightness: brightness,
    fontFamily: 'Roboto',
  );
}

/// Loads a camera scene from `assets/`.
Future<CameraScene> loadScene(WidgetTester tester, String name) async {
  final scene = await tester.runAsync(() => CameraScene.load(name));
  return scene!;
}

/// Lets the fake camera "start": the scanner awaits a few platform futures
/// before its state flips to running.
Future<void> startCamera(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// Advances the clock by [duration] a frame at a time, as a running app
/// would, so animations that start part-way through still play out.
Future<void> advance(WidgetTester tester, Duration duration) async {
  const frame = Duration(milliseconds: 16);
  var elapsed = Duration.zero;
  while (elapsed < duration) {
    final step = duration - elapsed < frame ? duration - elapsed : frame;
    await tester.pump(step);
    elapsed += step;
  }
}

/// Writes the current frame to `build/screens/<name>.png` at the phone's
/// pixel ratio.
Future<void> capture(
  WidgetTester tester,
  String name, {
  double? pixelRatio,
}) async {
  final boundary =
      _boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(
      pixelRatio: pixelRatio ?? Phone.pixelRatio,
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    final file = File('${outputDir.path}/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
  });
}

/// Keeps the scanner's haptics and sounds from reaching a platform channel the
/// test binding does not implement.
void silencePlatformChannels(WidgetTester tester) {
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async => null,
  );
}
