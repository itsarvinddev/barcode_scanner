import 'package:flutter/material.dart';

import '../config/scanner_theme.dart';

/// The guidance pill shown near the scan window.
///
/// It fades between messages rather than snapping, and collapses to nothing
/// when [text] is null so the layout stays stable.
class ScanHint extends StatelessWidget {
  /// Creates a scan hint.
  const ScanHint({required this.text, super.key, this.theme});

  /// The message to show, or `null` to show nothing.
  final String? text;

  /// Palette override; defaults to the [ScannerTheme] in scope.
  final ScannerTheme? theme;

  @override
  Widget build(BuildContext context) {
    final palette = (theme ?? ScannerTheme.of(context)).resolve();
    final message = text;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child:
          message == null || message.isEmpty
              ? const SizedBox.shrink()
              : Container(
                key: ValueKey<String>(message),
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: palette.hintBackgroundColor,
                  borderRadius: BorderRadius.circular(
                    palette.borderRadius! / 1.6,
                  ),
                ),
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: palette.hintTextStyle,
                ),
              ),
    );
  }
}
