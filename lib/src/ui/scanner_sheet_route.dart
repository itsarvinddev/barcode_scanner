import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// A modal bottom-sheet route built only from widgets-layer primitives.
///
/// `BarcodeResultSheet.show` calls `showModalBottomSheet` whenever it can.
/// That helper asserts that `flutter/material`'s `MaterialLocalizations` are
/// in scope and reads them for the sheet's semantics labels, which holds in
/// every classic `MaterialApp` but not in an app built on `package:material_ui`
/// (whose localizations are a different type: Flutter publishes Material as
/// that separate package, alongside the SDK's own copy) or on a bare
/// [WidgetsApp]. In those hosts the result sheet
/// is pushed on this route instead, so it opens rather than crashing, without
/// asking the app to install `MaterialUiCompatibilityBridge`.
///
/// It reproduces the parts of a modal bottom sheet the result sheet relies on:
///
/// * a slide-up entrance and slide-down exit, with the same durations as
///   `showModalBottomSheet`;
/// * a dimmed, dismissible barrier carrying [barrierLabel] for screen readers;
/// * a width cap on large screens and a top [SafeArea] (the sheet pads its own
///   bottom inset);
/// * dragging the sheet down to dismiss it, with `BottomSheet`'s fling and
///   distance thresholds;
/// * the caller's inherited themes, captured the way `showModalBottomSheet`
///   captures them.
///
/// Like the rest of the 8.x Material hardening, this is planned for removal in
/// 9.0.0, when the package migrates to `material_ui`.
class ScannerSheetRoute<T> extends PopupRoute<T> {
  /// Creates a sheet route that builds its content with [builder].
  ScannerSheetRoute({
    required this.builder,
    required this.barrierLabel,
    this.capturedThemes,
    this.textStyle,
    super.settings,
  });

  /// Builds the sheet's content.
  final WidgetBuilder builder;

  /// Inherited themes captured from the context that opened the sheet, so the
  /// content sees the same themes it would have seen there.
  final CapturedThemes? capturedThemes;

  /// The default text style for the sheet's content.
  ///
  /// The page of a route is not inside any `Material`, and an app's
  /// `MaterialApp` — classic or `material_ui` — deliberately sets a garish red,
  /// double-underlined text style there to flag text that is missing one. A
  /// real bottom sheet supplies its own through its `Material`; this route
  /// supplies this style instead. `null` leaves the ambient style alone.
  final TextStyle? textStyle;

  @override
  final String barrierLabel;

  // Colors.black54, the barrier colour of showModalBottomSheet.
  @override
  Color get barrierColor => const Color(0x8A000000);

  @override
  bool get barrierDismissible => true;

  // The enter and exit durations of showModalBottomSheet.
  @override
  Duration get transitionDuration => const Duration(milliseconds: 250);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 200);

  // BottomSheet's own maximum width on large screens.
  static const double _maxWidth = 640;

  static final Animatable<Offset> _slideUp = Tween<Offset>(
    begin: const Offset(0, 1),
    end: Offset.zero,
  ).chain(CurveTween(curve: Curves.easeOutCubic));

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    Widget page = Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxWidth),
        child: _DragToDismiss(
          onDismissed: _dismissFromDrag,
          child: Semantics(
            scopesRoute: true,
            explicitChildNodes: true,
            child: Builder(builder: builder),
          ),
        ),
      ),
    );

    // The sheet handles the bottom inset itself; only a tall sheet reaching
    // the status bar needs keeping clear of it.
    page = SafeArea(bottom: false, child: page);

    final style = textStyle;
    if (style != null) {
      page = DefaultTextStyle(style: style, child: page);
    }

    return capturedThemes?.wrap(page) ?? page;
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // `drive` rather than a CurvedAnimation: a CurvedAnimation created here
    // would add a status listener to the route's animation on every rebuild.
    return SlideTransition(position: animation.drive(_slideUp), child: child);
  }

  void _dismissFromDrag() {
    // Only pop if this sheet is still on top; otherwise a late drag end would
    // pop whatever the user opened from the sheet.
    if (isCurrent) navigator?.pop();
  }
}

/// Lets the user drag its child down, and reports a drag that should dismiss.
///
/// The drag moves the child with a local offset rather than scrubbing the
/// route's animation. The route's slide is eased, and scrubbing an eased
/// animation makes the sheet lag the finger; an offset tracks it exactly, and
/// when the route then pops, its exit slide continues from wherever the drag
/// left the sheet.
class _DragToDismiss extends StatefulWidget {
  const _DragToDismiss({required this.onDismissed, required this.child});

  final VoidCallback onDismissed;

  final Widget child;

  @override
  State<_DragToDismiss> createState() => _DragToDismissState();
}

class _DragToDismissState extends State<_DragToDismiss>
    with SingleTickerProviderStateMixin {
  // BottomSheet's thresholds, so the fallback and the Material sheet feel the
  // same under the finger.
  static const double _minFlingVelocity = 700;
  static const double _closeProgressThreshold = 0.5;

  late final AnimationController _offset = AnimationController.unbounded(
    vsync: this,
  );

  bool _dismissed = false;

  @override
  void dispose() {
    _offset.dispose();
    super.dispose();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (_dismissed) return;
    _offset.value = math.max(0, _offset.value + details.delta.dy);
  }

  void _handleDragEnd(DragEndDetails details) {
    if (_dismissed) return;
    final height = context.size?.height ?? 0;
    final flung = details.velocity.pixelsPerSecond.dy > _minFlingVelocity;
    final draggedFarEnough =
        height > 0 && _offset.value > height * _closeProgressThreshold;

    if (flung || draggedFarEnough) {
      _dismissed = true;
      widget.onDismissed();
      return;
    }

    unawaited(
      _offset.animateTo(
        0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Opaque, so a tap in the sheet's margin does not fall through to the
      // barrier and close it — the Material sheet absorbs those too.
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      onVerticalDragUpdate: _handleDragUpdate,
      onVerticalDragEnd: _handleDragEnd,
      child: AnimatedBuilder(
        animation: _offset,
        builder:
            (context, child) => Transform.translate(
              offset: Offset(0, _offset.value),
              child: child,
            ),
        child: widget.child,
      ),
    );
  }
}
