import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../config/scanner_labels.dart';
import '../config/scanner_theme.dart';
import '../utils/barcode_extensions.dart';
import 'scanner_material_context.dart';
import 'scanner_sheet_route.dart';

/// A ready-made sheet that presents a scanned barcode.
///
/// It renders the structured payload `mobile_scanner` returns — a Wi-Fi
/// network's SSID and security, a contact's phone numbers, a calendar event's
/// times — rather than dumping the raw string, and offers copy and open
/// actions.
///
/// Show it however you like; [BarcodeResultSheet.show] is a convenience for
/// the common modal case:
///
/// ```dart
/// AiBarcodeScanner(
///   scanMode: ScanMode.single,
///   onDetect: (capture) => BarcodeResultSheet.show(
///     context,
///     barcode: capture.barcodes.first,
///     onOpen: (uri) => launchUrl(uri),
///   ),
/// )
/// ```
class BarcodeResultSheet extends StatelessWidget {
  /// Creates a result sheet for [barcode].
  const BarcodeResultSheet({
    required this.barcode,
    super.key,
    this.labels = const ScannerLabels(),
    this.theme,
    this.onOpen,
    this.onShare,
    this.revealObscuredFields = false,
  });

  /// The barcode to present.
  final Barcode barcode;

  /// Strings to render.
  final ScannerLabels labels;

  /// Palette override; defaults to the [ScannerTheme] in scope.
  ///
  /// The filled "Open" action is the exception in an app with a
  /// `flutter/material` [Theme]: there it keeps following the app's
  /// [ColorScheme], as it did before 8.1.0, even when this is set. Without
  /// such a [Theme] — an app on `material_ui`, or a bare `WidgetsApp` — it
  /// takes this palette's accent. The same holds for [ScannerErrorView]'s
  /// retry button.
  final ScannerTheme? theme;

  /// Called when the user taps "Open", with the barcode's natural action URI.
  ///
  /// The package has no `url_launcher` dependency, so hand this to whichever
  /// launcher your app already uses. The action is hidden when this is null or
  /// the barcode has no sensible URI.
  final void Function(Uri uri)? onOpen;

  /// Called when the user taps "Share", with the barcode's best value.
  /// The action is hidden when this is null.
  final void Function(String value)? onShare;

  /// Whether to show values marked sensitive — currently only the Wi-Fi
  /// password — instead of masking them.
  final bool revealObscuredFields;

  /// Shows this sheet as a modal bottom sheet.
  ///
  /// The returned future completes when the sheet is dismissed.
  ///
  /// In a classic `MaterialApp` this is `showModalBottomSheet`, exactly as it
  /// has always been. That helper needs `flutter/material`'s
  /// `MaterialLocalizations`, which an app built on `package:material_ui`
  /// (Flutter 3.47+) or on a bare `WidgetsApp` does not provide — it used to
  /// throw there. In those apps the sheet is presented on a lightweight route
  /// of its own instead, with the same slide-up entrance, a dimmed dismissible
  /// barrier labelled with [ScannerLabels.dismissSheetLabel], and
  /// drag-down-to-dismiss, so no `MaterialUiCompatibilityBridge` is required.
  static Future<void> show(
    BuildContext context, {
    required Barcode barcode,
    ScannerLabels labels = const ScannerLabels(),
    ScannerTheme? theme,
    void Function(Uri uri)? onOpen,
    void Function(String value)? onShare,
    bool revealObscuredFields = false,
  }) {
    Widget buildSheet(BuildContext context) => BarcodeResultSheet(
      barcode: barcode,
      labels: labels,
      theme: theme,
      onOpen: onOpen,
      onShare: onShare,
      revealObscuredFields: revealObscuredFields,
    );

    // A route's content is built under its navigator rather than under
    // [context], so both have to resolve Material localizations before
    // showModalBottomSheet is safe. Checking only the caller would be fooled by
    // a context inside the scanner, which supplies its own; checking only the
    // navigator would bypass the assertions showModalBottomSheet makes about a
    // caller that has no navigator at all.
    if (ScannerMaterialContext.hasMaterialLocalizations(context)) {
      final navigator = Navigator.maybeOf(context);
      if (navigator == null ||
          ScannerMaterialContext.hasMaterialLocalizations(navigator.context)) {
        return showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: buildSheet,
        );
      }
    }

    final navigator = Navigator.of(context);
    return navigator.push<void>(
      ScannerSheetRoute<void>(
        builder: buildSheet,
        barrierLabel: labels.dismissSheetLabel,
        capturedThemes: InheritedTheme.capture(
          from: context,
          to: navigator.context,
        ),
        // What the Material sheet's own surface would give its content.
        textStyle: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = (theme ?? ScannerTheme.of(context)).resolve();
    final fields = barcode.fields;
    final uri = barcode.actionUri;
    final value = barcode.bestValue;
    final hostTheme = ScannerMaterialContext.hostProvidesMaterialTheme(context);
    final secondaryActionStyle = _secondaryActionStyle(
      palette,
      hostTheme: hostTheme,
    );

    // The action buttons are `flutter/material` widgets that need Material
    // localizations, which an app built on `package:material_ui` or a bare
    // WidgetsApp lacks. This supplies them only in that case.
    return ScannerMaterialContext(
      child: SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          decoration: BoxDecoration(
            color: palette.surfaceColor,
            borderRadius: BorderRadius.circular(palette.borderRadius!),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(
                    barcode.typeIcon,
                    color: palette.onSurfaceColor,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      labels.typeLabel(barcode.type.name, barcode.typeLabel),
                      style: TextStyle(
                        color: palette.onSurfaceColor,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    barcode.format.displayName,
                    style: TextStyle(
                      color: palette.onSurfaceColor!.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (fields.isEmpty)
                // A long plain-text payload would otherwise push the action row
                // off the bottom of the screen.
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * 0.45,
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      value,
                      // The selection toolbar is built in the navigator's
                      // overlay, outside this sheet, so it resolves Material
                      // localizations for itself.
                      contextMenuBuilder: scannerContextMenuBuilder,
                      style: TextStyle(
                        color: palette.onSurfaceColor,
                        fontSize: 15,
                        height: 1.4,
                      ),
                    ),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * 0.45,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        for (final field in fields)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  labels.fieldLabel(field.key, field.label),
                                  style: TextStyle(
                                    color: palette.onSurfaceColor!.withValues(
                                      alpha: 0.6,
                                    ),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                SelectableText(
                                  field.obscure && !revealObscuredFields
                                      ? '•' * field.value.length.clamp(4, 16)
                                      : field.value,
                                  contextMenuBuilder: scannerContextMenuBuilder,
                                  style: TextStyle(
                                    color: palette.onSurfaceColor,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: <Widget>[
                  if (uri != null && onOpen != null)
                    FilledButton.icon(
                      onPressed: () => onOpen!(uri),
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: Text(labels.openAction),
                      // Follows the host's ColorScheme when it has a
                      // `flutter/material` Theme, as it always has. Without
                      // one, Theme.of would hand back the SDK's baseline
                      // purple, so the scanner's accent is used instead.
                      style:
                          hostTheme
                              ? null
                              : FilledButton.styleFrom(
                                backgroundColor:
                                    palette.controlActiveBackgroundColor,
                                foregroundColor:
                                    palette.controlActiveForegroundColor,
                              ),
                    ),
                  _CopyAction(
                    value: value,
                    labels: labels,
                    style: secondaryActionStyle,
                  ),
                  if (onShare != null)
                    OutlinedButton.icon(
                      onPressed: value.isEmpty ? null : () => onShare!(value),
                      icon: const Icon(Icons.ios_share, size: 18),
                      label: Text(labels.shareAction),
                      style: secondaryActionStyle,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The style shared by the copy and share actions.
  ///
  /// Their disabled foreground — shown when the barcode has no value — is left
  /// to the host's Theme when there is one, exactly as before. Without one it
  /// would be the SDK's near-black baseline on the sheet's dark surface, so it
  /// is derived from the palette instead.
  static ButtonStyle _secondaryActionStyle(
    ScannerTheme palette, {
    required bool hostTheme,
  }) {
    return OutlinedButton.styleFrom(
      foregroundColor: palette.onSurfaceColor,
      disabledForegroundColor:
          hostTheme ? null : palette.onSurfaceColor!.withValues(alpha: 0.38),
      side: BorderSide(color: palette.onSurfaceColor!.withValues(alpha: 0.3)),
    );
  }
}

/// The "Copy" action, which confirms the copy as well as performing it.
///
/// Under a `flutter/material` [ScaffoldMessenger] — any classic `MaterialApp`
/// — the confirmation is a [SnackBar], as it always has been. An app built on
/// `package:material_ui` or a bare `WidgetsApp` has no such messenger, and
/// there the snack bar used to be skipped silently, leaving the user unsure
/// anything happened. In that case the button itself briefly becomes the
/// confirmation instead, announced to screen readers as a live region.
class _CopyAction extends StatefulWidget {
  const _CopyAction({
    required this.value,
    required this.labels,
    required this.style,
  });

  final String value;

  final ScannerLabels labels;

  final ButtonStyle style;

  @override
  State<_CopyAction> createState() => _CopyActionState();
}

class _CopyActionState extends State<_CopyAction> {
  // About as long as it takes to read two words, without leaving the button
  // saying "copied" long after the fact.
  static const Duration _confirmationDuration = Duration(seconds: 2);

  Timer? _resetTimer;
  bool _copied = false;

  @override
  void dispose() {
    _resetTimer?.cancel();
    super.dispose();
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.value));
    if (!mounted) return;

    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger != null) {
      messenger.showSnackBar(
        SnackBar(content: Text(widget.labels.copiedConfirmation)),
      );
      return;
    }

    setState(() => _copied = true);
    _resetTimer?.cancel();
    _resetTimer = Timer(_confirmationDuration, () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: widget.value.isEmpty ? null : () => unawaited(_copy()),
      icon: Icon(_copied ? Icons.check_rounded : Icons.copy_rounded, size: 18),
      label:
          _copied
              ? Semantics(
                liveRegion: true,
                child: Text(widget.labels.copiedConfirmation),
              )
              : Text(widget.labels.copyAction),
      style: widget.style,
    );
  }
}
