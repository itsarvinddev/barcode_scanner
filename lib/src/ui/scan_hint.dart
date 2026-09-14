import 'package:flutter/material.dart';

import '../config/scanner_theme.dart';

/// The guidance pill shown near the scan window.
///
/// It fades between messages rather than snapping, and collapses to nothing
/// when [text] is null so the layout stays stable.
class ScanHint extends StatelessWidget {
  /// Creates a scan hint.
  const ScanHint({
    required this.text,
    super.key,
    this.theme,
    this.announce = false,
  });

  /// The message to show, or `null` to show nothing.
  final String? text;

  /// Palette override; defaults to the [ScannerTheme] in scope.
  final ScannerTheme? theme;

  /// Whether screen readers should read [text] out as soon as it appears.
  ///
  /// The message is marked as a live region, so TalkBack, VoiceOver and web
  /// screen readers announce it without the user moving focus to it. The
  /// scanner sets this for its transient feedback, such as
  /// `ScannerLabels.invalidBarcode`. Leave it `false` for steady guidance,
  /// which would otherwise be read out every time it changes.
  final bool announce;

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
                child: _announced(
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: palette.hintTextStyle,
                  ),
                ),
              ),
    );
  }

  /// Wraps [child] in its own live-region node when [announce] is set.
  ///
  /// A live region rather than `SemanticsService`: Android has deprecated
  /// announcement events, which interrupt whatever TalkBack is saying, and
  /// Flutter recommends semantics that announce implicitly instead. Each
  /// message is a new node, because the pill is keyed by its text, so every
  /// new message is announced once — and a message that is merely refreshed
  /// while it is up, such as a second rejection of the same code, is not
  /// repeated.
  Widget _announced(Widget child) {
    if (!announce) return child;
    return Semantics(container: true, liveRegion: true, child: child);
  }
}
