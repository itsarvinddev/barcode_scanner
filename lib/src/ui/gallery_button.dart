import 'package:flutter/material.dart';

import '../config/gallery_button_type.dart';
import '../config/scanner_theme.dart';
import 'scanner_control_button.dart';

/// The gallery affordance.
///
/// This widget only renders the button; picking and analysing the image is
/// driven by the scanner so that a gallery scan runs through exactly the same
/// validation, feedback and overlay pipeline as a live scan.
class GalleryButton extends StatelessWidget {
  /// Creates a gallery button of the given [type].
  const GalleryButton({
    required this.type,
    required this.onPressed,
    required this.label,
    required this.tooltip,
    super.key,
    this.icon = Icons.photo_library_outlined,
    this.theme,
    this.isBusy = false,
  });

  /// Whether to render an icon button, a filled button, or nothing.
  final GalleryButtonType type;

  /// Called when the button is tapped.
  final VoidCallback? onPressed;

  /// Label of the filled variant.
  final String label;

  /// Tooltip and semantics label.
  final String tooltip;

  /// Glyph shown on both variants.
  final IconData icon;

  /// Palette override; defaults to the [ScannerTheme] in scope.
  final ScannerTheme? theme;

  /// Whether an image is currently being analysed. Shows a spinner and
  /// disables the button.
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final palette = (theme ?? ScannerTheme.of(context)).resolve();
    final callback = isBusy ? null : onPressed;

    switch (type) {
      case GalleryButtonType.none:
        return const SizedBox.shrink();
      case GalleryButtonType.icon:
        if (isBusy) {
          return SizedBox(
            width: palette.controlSize,
            height: palette.controlSize,
            child: Center(
              child: SizedBox.square(
                dimension: palette.controlSize! * 0.4,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: palette.controlForegroundColor,
                ),
              ),
            ),
          );
        }
        return ScannerControlButton(
          icon: icon,
          onPressed: callback,
          tooltip: tooltip,
          theme: palette,
        );
      case GalleryButtonType.filled:
        return Semantics(
          button: true,
          label: tooltip,
          child: FilledButton.icon(
            onPressed: callback,
            icon:
                isBusy
                    ? SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: palette.controlForegroundColor,
                      ),
                    )
                    : Icon(icon),
            label: Text(label),
            style: FilledButton.styleFrom(
              backgroundColor: palette.controlBackgroundColor,
              foregroundColor: palette.controlForegroundColor,
              disabledBackgroundColor: palette.controlBackgroundColor,
              disabledForegroundColor: palette.controlForegroundColor,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(palette.borderRadius!),
              ),
            ),
          ),
        );
    }
  }
}
