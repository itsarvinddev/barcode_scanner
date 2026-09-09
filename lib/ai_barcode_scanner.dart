/// A complete, customisable barcode and QR scanner for Flutter, built on
/// `mobile_scanner`.
///
/// The whole of `mobile_scanner` is re-exported, so importing this package is
/// enough to reach `BarcodeCapture`, `BarcodeFormat`, `MobileScannerController`
/// and everything else it provides.
library;

export 'package:mobile_scanner/mobile_scanner.dart';

export 'src/ai_barcode_scanner.dart' show AiBarcodeScanner;
export 'src/config/gallery_button_type.dart' show GalleryButtonType;
export 'src/config/overlay_config.dart'
    show
        ScannerAnimation,
        ScannerBorder,
        ScannerOverlayBackground,
        ScannerOverlayConfig;
export 'src/config/scan_mode.dart' show ScanMode;
export 'src/config/scan_window_config.dart'
    show ScanWindowConfig, ScanWindowShape;
export 'src/config/scanner_action.dart' show ScannerAction;
export 'src/config/scanner_feedback.dart'
    show ScannerFeedbackConfig, ScannerFeedbackEvent, ScannerHaptic;
export 'src/config/scanner_labels.dart' show ScannerLabels;
export 'src/config/scanner_theme.dart' show ScannerTheme, ScannerThemeScope;
export 'src/controller/ai_barcode_scanner_controller.dart'
    show AiBarcodeScannerController;
export 'src/show_scanner.dart'
    show showAiBarcodeScanner, showAiBarcodeScannerBatch;
export 'src/ui/barcode_result_sheet.dart' show BarcodeResultSheet;
export 'src/ui/focus_indicator.dart' show FocusIndicator;
export 'src/ui/scan_hint.dart' show ScanHint;
export 'src/ui/scanner_control_button.dart'
    show ScannerControlButton, ScannerCountBadge;
export 'src/ui/scanner_controls_bar.dart' show ScannerControlsBar;
export 'src/ui/scanner_error_view.dart'
    show ScannerErrorView, ScannerUnsupportedPlatformView;
export 'src/ui/scanner_overlay.dart' show ScannerOverlay;
export 'src/ui/zoom_slider.dart' show ScannerZoomSlider;
export 'src/utils/barcode_extensions.dart'
    show AiBarcodeCaptureX, AiBarcodeFormatX, AiBarcodeX, BarcodeField;
export 'src/utils/platform_support.dart' show ScannerPlatformSupport;
export 'src/utils/scan_validators.dart' show BarcodeFormatSets, ScanValidators;
