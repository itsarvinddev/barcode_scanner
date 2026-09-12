import 'package:ai_barcode_scanner/ai_barcode_scanner.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Resolves a config against a fixed box, using a real BuildContext.
Future<Rect> resolveWindow(
  WidgetTester tester,
  ScanWindowConfig config, {
  Size size = const Size(400, 600),
  bool prefersSquare = true,
  EdgeInsets safeArea = EdgeInsets.zero,
}) async {
  late Rect result;
  await tester.pumpWidget(
    Center(
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: LayoutBuilder(
          builder: (context, constraints) {
            result = config.resolve(
              context,
              constraints,
              prefersSquare: prefersSquare,
              safeArea: safeArea,
            );
            return const SizedBox.expand();
          },
        ),
      ),
    ),
  );
  return result;
}

void main() {
  group('ScanWindowConfig.resolve', () {
    testWidgets('is expressed in the preview box, not the screen', (
      tester,
    ) async {
      // The whole point of #166: the rect must fit inside the constraints it
      // was given, whatever the surrounding screen looks like.
      final rect = await resolveWindow(
        tester,
        const ScanWindowConfig(),
        size: const Size(400, 600),
      );

      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(400));
      expect(rect.bottom, lessThanOrEqualTo(600));
    });

    testWidgets('auto is square when only 2D formats are expected', (
      tester,
    ) async {
      final rect = await resolveWindow(tester, const ScanWindowConfig());
      expect(rect.width, closeTo(rect.height, 0.01));
    });

    testWidgets('auto is landscape when linear formats are expected', (
      tester,
    ) async {
      final rect = await resolveWindow(
        tester,
        const ScanWindowConfig(),
        prefersSquare: false,
      );
      expect(rect.width, greaterThan(rect.height));
    });

    testWidgets('tall shape produces a portrait window', (tester) async {
      // A vertically printed barcode needs a taller-than-wide window; the 7.x
      // default was always 80% x 36% of the screen, which could not describe
      // this at all.
      final rect = await resolveWindow(
        tester,
        const ScanWindowConfig(shape: ScanWindowShape.tall),
      );
      expect(rect.height, greaterThan(rect.width));
    });

    testWidgets('caps its size on a large viewport', (tester) async {
      final rect = await resolveWindow(
        tester,
        const ScanWindowConfig(maxWidth: 300, maxHeight: 300),
        size: const Size(800, 600),
      );
      expect(rect.width, lessThanOrEqualTo(300));
      expect(rect.height, lessThanOrEqualTo(300));
    });

    testWidgets('never overflows a short landscape preview', (tester) async {
      final rect = await resolveWindow(
        tester,
        const ScanWindowConfig(),
        size: const Size(900, 260),
      );
      expect(rect.width, lessThanOrEqualTo(900));
      expect(rect.height, lessThanOrEqualTo(260));
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(rect.bottom, lessThanOrEqualTo(260));
    });

    testWidgets('keeps clear of the safe area', (tester) async {
      final rect = await resolveWindow(
        tester,
        const ScanWindowConfig(padding: EdgeInsets.zero),
        safeArea: const EdgeInsets.only(top: 100),
      );
      expect(rect.top, greaterThanOrEqualTo(100));
    });

    testWidgets('survives a box narrower than minWidth', (tester) async {
      // `num.clamp` throws an ArgumentError — not a debug-only assert — when
      // its lower limit exceeds its upper one, which replaced the whole
      // scanner with an error widget on any small preview.
      final rect = await resolveWindow(
        tester,
        const ScanWindowConfig(),
        size: const Size(120, 400),
      );
      expect(rect.width, lessThanOrEqualTo(120));
      expect(rect.width, greaterThan(0));
    });

    testWidgets('survives a box shorter than minHeight', (tester) async {
      final rect = await resolveWindow(
        tester,
        const ScanWindowConfig(),
        size: const Size(400, 80),
      );
      expect(rect.height, lessThanOrEqualTo(80));
      expect(rect.height, greaterThan(0));
    });

    testWidgets('survives a safe area that eats most of the box', (
      tester,
    ) async {
      final rect = await resolveWindow(
        tester,
        const ScanWindowConfig(padding: EdgeInsets.zero),
        size: const Size(400, 400),
        safeArea: const EdgeInsets.symmetric(horizontal: 150),
      );
      expect(rect.width, greaterThan(0));
      expect(rect.left, greaterThanOrEqualTo(150));
    });

    testWidgets('survives every degenerate size in a sweep', (tester) async {
      for (final size in const <Size>[
        Size(1, 1),
        Size(60, 60),
        Size(120, 400),
        Size(187, 600),
        Size(188, 600),
        Size(400, 143),
        Size(400, 144),
        Size(800, 2),
      ]) {
        final rect = await resolveWindow(
          tester,
          const ScanWindowConfig(),
          size: size,
        );
        expect(rect.width, greaterThanOrEqualTo(0), reason: '$size');
        expect(rect.height, greaterThanOrEqualTo(0), reason: '$size');
      }
    });

    testWidgets('fullPreview covers the whole box', (tester) async {
      final rect = await resolveWindow(
        tester,
        const ScanWindowConfig.fullPreview(),
        size: const Size(400, 600),
      );
      expect(rect, const Rect.fromLTWH(0, 0, 400, 600));
    });

    testWidgets('builder wins over every other setting', (tester) async {
      const expected = Rect.fromLTWH(10, 20, 30, 40);
      final rect = await resolveWindow(
        tester,
        ScanWindowConfig.builder((context, constraints) => expected),
      );
      expect(rect, expected);
    });

    testWidgets('alignment moves the window within the padded area', (
      tester,
    ) async {
      final top = await resolveWindow(
        tester,
        const ScanWindowConfig(alignment: Alignment.topCenter),
      );
      final bottom = await resolveWindow(
        tester,
        const ScanWindowConfig(alignment: Alignment.bottomCenter),
      );
      expect(top.top, lessThan(bottom.top));
    });

    testWidgets('degenerate constraints fall back to the full box', (
      tester,
    ) async {
      final rect = await resolveWindow(
        tester,
        const ScanWindowConfig(padding: EdgeInsets.all(400)),
        size: const Size(100, 100),
      );
      expect(rect, const Rect.fromLTWH(0, 0, 100, 100));
    });
  });

  group('ScanWindowConfig', () {
    test('isFullPreview only for the fullPreview shape', () {
      expect(const ScanWindowConfig.fullPreview().isFullPreview, isTrue);
      expect(const ScanWindowConfig().isFullPreview, isFalse);
      expect(
        const ScanWindowConfig(shape: ScanWindowShape.square).isFullPreview,
        isFalse,
      );
    });

    test('copyWith replaces only what it is given', () {
      const original = ScanWindowConfig(maxWidth: 200);
      final copy = original.copyWith(shape: ScanWindowShape.wide);
      expect(copy.shape, ScanWindowShape.wide);
      expect(copy.maxWidth, 200);
    });

    test('copyWith can clear a builder', () {
      // `builder` wins over every other field in resolve(), so without an
      // explicit escape hatch a builder-based config could never go back to a
      // shape.
      final original = ScanWindowConfig.builder(
        (context, constraints) => Rect.zero,
      );
      expect(original.copyWith(shape: ScanWindowShape.wide).builder, isNotNull);
      expect(original.copyWith(clearBuilder: true).builder, isNull);
    });
  });
}
