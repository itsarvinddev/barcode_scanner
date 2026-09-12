import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../config/scanner_labels.dart';
import '../config/scanner_theme.dart';
import '../utils/barcode_extensions.dart';

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
  static Future<void> show(
    BuildContext context, {
    required Barcode barcode,
    ScannerLabels labels = const ScannerLabels(),
    ScannerTheme? theme,
    void Function(Uri uri)? onOpen,
    void Function(String value)? onShare,
    bool revealObscuredFields = false,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => BarcodeResultSheet(
            barcode: barcode,
            labels: labels,
            theme: theme,
            onOpen: onOpen,
            onShare: onShare,
            revealObscuredFields: revealObscuredFields,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = (theme ?? ScannerTheme.of(context)).resolve();
    final fields = barcode.fields;
    final uri = barcode.actionUri;
    final value = barcode.bestValue;

    return SafeArea(
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
                Icon(barcode.typeIcon, color: palette.onSurfaceColor, size: 22),
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
                  ),
                OutlinedButton.icon(
                  onPressed:
                      value.isEmpty
                          ? null
                          : () async {
                            await Clipboard.setData(ClipboardData(text: value));
                            if (!context.mounted) return;
                            ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                              SnackBar(
                                content: Text(labels.copiedConfirmation),
                              ),
                            );
                          },
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: Text(labels.copyAction),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: palette.onSurfaceColor,
                    side: BorderSide(
                      color: palette.onSurfaceColor!.withValues(alpha: 0.3),
                    ),
                  ),
                ),
                if (onShare != null)
                  OutlinedButton.icon(
                    onPressed: value.isEmpty ? null : () => onShare!(value),
                    icon: const Icon(Icons.ios_share, size: 18),
                    label: Text(labels.shareAction),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: palette.onSurfaceColor,
                      side: BorderSide(
                        color: palette.onSurfaceColor!.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
