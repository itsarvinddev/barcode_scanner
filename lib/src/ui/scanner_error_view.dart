import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../config/scanner_labels.dart';
import '../config/scanner_theme.dart';
import '../utils/platform_support.dart';
import 'scanner_material_context.dart';

/// The screen shown when the camera cannot start.
///
/// It distinguishes the three failures a user can actually do something about
/// — permission denied, no usable camera, and everything else — instead of
/// showing one generic message. The previous implementation read only
/// `error.errorDetails?.message`, which is null for a permission denial, so
/// the most common failure rendered as "An unknown error occurred."
class ScannerErrorView extends StatelessWidget {
  /// Creates an error view for [error].
  const ScannerErrorView({
    required this.error,
    super.key,
    this.labels = const ScannerLabels(),
    this.theme,
    this.onRetry,
    this.onOpenSettings,
  });

  /// The exception reported by the scanner.
  final MobileScannerException error;

  /// Strings to render.
  final ScannerLabels labels;

  /// Palette override; defaults to the [ScannerTheme] in scope.
  ///
  /// The filled retry button is the exception in an app with a
  /// `flutter/material` [Theme]: there it keeps following the app's
  /// [ColorScheme], as it did before 8.1.0, even when this is set. Without
  /// such a [Theme] — an app on `material_ui`, or a bare `WidgetsApp` — it
  /// takes this palette's accent.
  final ScannerTheme? theme;

  /// Called when the user asks to try starting the camera again.
  final VoidCallback? onRetry;

  /// Called when the user asks to open the app's settings.
  ///
  /// The package does not depend on a permissions plugin, so wire this up to
  /// whichever one your app already uses — for example
  /// `openAppSettings()` from `permission_handler`. The button is hidden when
  /// this is null.
  final VoidCallback? onOpenSettings;

  bool get _isPermissionDenied =>
      error.errorCode == MobileScannerErrorCode.permissionDenied;

  bool get _isUnsupported =>
      error.errorCode == MobileScannerErrorCode.unsupported;

  @override
  Widget build(BuildContext context) {
    final palette = (theme ?? ScannerTheme.of(context)).resolve();

    final IconData icon;
    final String title;
    final String message;

    if (_isPermissionDenied) {
      icon = Icons.no_photography_outlined;
      title = labels.permissionDeniedTitle;
      message = labels.permissionDeniedMessage;
    } else if (_isUnsupported) {
      icon = Icons.videocam_off_outlined;
      title = labels.cameraUnsupportedTitle;
      message = labels.cameraUnsupportedMessage;
    } else {
      icon = Icons.error_outline;
      title = labels.cameraErrorTitle;
      // Prefer the platform's own detail, then the error code's message, then
      // the generic copy — so a real diagnostic is never swallowed. The detail
      // is displayed trimmed, matching the emptiness test: platform messages
      // are not guaranteed to arrive without surrounding whitespace.
      final detail = error.errorDetails?.message?.trim();
      message =
          detail != null && detail.isNotEmpty
              ? detail
              : (error.errorCode.message.isNotEmpty
                  ? error.errorCode.message
                  : labels.cameraErrorMessage);
    }

    return ColoredBox(
      color: palette.surfaceColor!,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 56, color: palette.onSurfaceColor),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: palette.onSurfaceColor,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: palette.onSurfaceColor!.withValues(alpha: 0.75),
                  fontSize: 15,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: <Widget>[
                  if (onRetry != null && !_isUnsupported)
                    FilledButton(
                      onPressed: onRetry,
                      // A host with a `flutter/material` Theme has always
                      // coloured this from its ColorScheme, and still does.
                      // Without one — a `material_ui` app or a bare
                      // WidgetsApp — Theme.of would return the SDK's baseline
                      // purple, so the scanner's own accent is used instead.
                      style:
                          ScannerMaterialContext.hostProvidesMaterialTheme(
                                context,
                              )
                              ? null
                              : FilledButton.styleFrom(
                                backgroundColor:
                                    palette.controlActiveBackgroundColor,
                                foregroundColor:
                                    palette.controlActiveForegroundColor,
                              ),
                      child: Text(labels.retryButton),
                    ),
                  if (onOpenSettings != null && _isPermissionDenied)
                    OutlinedButton(
                      onPressed: onOpenSettings,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: palette.onSurfaceColor,
                        side: BorderSide(
                          color: palette.onSurfaceColor!.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(labels.openSettingsButton),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The screen shown on platforms where `mobile_scanner` has no camera
/// implementation: Windows and Linux.
class ScannerUnsupportedPlatformView extends StatelessWidget {
  /// Creates the unsupported-platform view.
  const ScannerUnsupportedPlatformView({
    super.key,
    this.labels = const ScannerLabels(),
    this.theme,
  });

  /// Strings to render.
  final ScannerLabels labels;

  /// Palette override; defaults to the [ScannerTheme] in scope.
  final ScannerTheme? theme;

  @override
  Widget build(BuildContext context) {
    final palette = (theme ?? ScannerTheme.of(context)).resolve();
    final platform = ScannerPlatformSupport.currentPlatformName;

    return ColoredBox(
      color: palette.surfaceColor!,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.desktop_access_disabled_outlined,
                size: 56,
                color: palette.onSurfaceColor,
              ),
              const SizedBox(height: 16),
              Text(
                labels.unsupportedPlatformTitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: palette.onSurfaceColor,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              SelectableText(
                labels.unsupportedPlatformMessage(platform),
                contextMenuBuilder: scannerContextMenuBuilder,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: palette.onSurfaceColor!.withValues(alpha: 0.75),
                  fontSize: 15,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
