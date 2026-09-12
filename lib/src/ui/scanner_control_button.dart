import 'package:flutter/material.dart';

import '../config/scanner_theme.dart';

/// A round, translucent control button sized and coloured for use on top of a
/// live camera preview.
///
/// Both states of the button are pre-laid-out so toggling the torch does not
/// shift the row, and every instance carries a semantics label.
class ScannerControlButton extends StatelessWidget {
  /// Creates a scanner control button.
  const ScannerControlButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    super.key,
    this.isActive = false,
    this.theme,
    this.badge,
  });

  /// The glyph to show.
  final IconData icon;

  /// Called when the button is tapped. A null callback disables the button.
  final VoidCallback? onPressed;

  /// Tooltip and semantics label. Required, because a bare icon on a camera
  /// preview is otherwise unreadable to a screen reader.
  final String tooltip;

  /// Whether the control is "on" (used by the torch).
  final bool isActive;

  /// Palette override; defaults to the [ScannerTheme] in scope.
  final ScannerTheme? theme;

  /// Optional badge shown at the top-right of the button, e.g. a scan count.
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final palette = (theme ?? ScannerTheme.of(context)).resolve();
    final size = palette.controlSize!;

    final button = Semantics(
      button: true,
      enabled: onPressed != null,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: SizedBox(
          width: size,
          height: size,
          child: Material(
            type: MaterialType.circle,
            clipBehavior: Clip.antiAlias,
            color:
                isActive
                    ? palette.controlActiveBackgroundColor
                    : palette.controlBackgroundColor,
            child: InkWell(
              onTap: onPressed,
              child: Icon(
                icon,
                size: size * 0.46,
                color:
                    isActive
                        ? palette.controlActiveForegroundColor
                        : palette.controlForegroundColor,
              ),
            ),
          ),
        ),
      ),
    );

    if (badge == null) return button;

    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[button, Positioned(right: -2, top: -2, child: badge!)],
    );
  }
}

/// A small count badge, used on the batch-mode control.
class ScannerCountBadge extends StatelessWidget {
  /// Creates a badge showing [count].
  const ScannerCountBadge({required this.count, super.key, this.theme});

  /// The number to display. Values above 99 render as `99+`.
  final int count;

  /// Palette override; defaults to the [ScannerTheme] in scope.
  final ScannerTheme? theme;

  @override
  Widget build(BuildContext context) {
    final palette = (theme ?? ScannerTheme.of(context)).resolve();
    return Container(
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: palette.reticleSuccessColor,
        shape: BoxShape.rectangle,
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Text(
        count > 99 ? '99+' : '$count',
        style: TextStyle(
          color: palette.controlActiveForegroundColor,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
    );
  }
}
