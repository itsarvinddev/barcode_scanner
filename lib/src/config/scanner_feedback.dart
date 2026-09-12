import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The haptic patterns the scanner can fire.
enum ScannerHaptic {
  /// No haptic feedback.
  none,

  /// [HapticFeedback.selectionClick].
  selection,

  /// [HapticFeedback.lightImpact].
  light,

  /// [HapticFeedback.mediumImpact].
  medium,

  /// [HapticFeedback.heavyImpact].
  heavy,

  /// [HapticFeedback.vibrate].
  vibrate;

  /// Fires this haptic. Does nothing for [ScannerHaptic.none].
  Future<void> play() {
    switch (this) {
      case ScannerHaptic.none:
        return Future<void>.value();
      case ScannerHaptic.selection:
        return HapticFeedback.selectionClick();
      case ScannerHaptic.light:
        return HapticFeedback.lightImpact();
      case ScannerHaptic.medium:
        return HapticFeedback.mediumImpact();
      case ScannerHaptic.heavy:
        return HapticFeedback.heavyImpact();
      case ScannerHaptic.vibrate:
        return HapticFeedback.vibrate();
    }
  }
}

/// Controls the haptic and audible feedback the scanner produces.
///
/// The package intentionally has no audio dependency, so the built-in sound is
/// the platform UI click from [SystemSound]. If you want a proper scanner beep,
/// leave [playSystemSound] off and hook [onFeedback] up to your own audio
/// player.
@immutable
class ScannerFeedbackConfig {
  /// Creates a feedback configuration.
  const ScannerFeedbackConfig({
    this.detectHaptic = ScannerHaptic.medium,
    this.rejectHaptic = ScannerHaptic.heavy,
    this.controlHaptic = ScannerHaptic.selection,
    this.playSystemSound = true,
    this.detectSound = SystemSoundType.click,
    this.rejectSound = SystemSoundType.alert,
    this.onFeedback,
  });

  /// Silences every built-in haptic and sound.
  ///
  /// [onFeedback] is still called, so this is the configuration to use when
  /// you drive feedback entirely yourself.
  const ScannerFeedbackConfig.silent({this.onFeedback})
    : detectHaptic = ScannerHaptic.none,
      rejectHaptic = ScannerHaptic.none,
      controlHaptic = ScannerHaptic.none,
      playSystemSound = false,
      detectSound = SystemSoundType.click,
      rejectSound = SystemSoundType.alert;

  /// Haptic fired when a barcode is detected and accepted.
  final ScannerHaptic detectHaptic;

  /// Haptic fired when a barcode is detected but rejected by the validator.
  final ScannerHaptic rejectHaptic;

  /// Haptic fired when the user taps one of the scanner's controls.
  final ScannerHaptic controlHaptic;

  /// Whether to play a short platform sound alongside the haptic.
  final bool playSystemSound;

  /// The sound played on an accepted barcode.
  final SystemSoundType detectSound;

  /// The sound played on a rejected barcode.
  final SystemSoundType rejectSound;

  /// Called for every feedback event, before the built-in haptic and sound.
  ///
  /// Use it to play your own scanner beep, drive an external buzzer, or log
  /// scan events.
  final void Function(ScannerFeedbackEvent event)? onFeedback;

  /// Plays the feedback for [event].
  Future<void> play(ScannerFeedbackEvent event) async {
    onFeedback?.call(event);

    final ScannerHaptic haptic;
    final SystemSoundType? sound;
    switch (event) {
      case ScannerFeedbackEvent.detect:
        haptic = detectHaptic;
        sound = detectSound;
      case ScannerFeedbackEvent.reject:
        haptic = rejectHaptic;
        sound = rejectSound;
      case ScannerFeedbackEvent.control:
        haptic = controlHaptic;
        sound = null;
    }

    await haptic.play();
    if (playSystemSound && sound != null) {
      await SystemSound.play(sound);
    }
  }

  /// Returns a copy of this configuration with the given fields replaced.
  ScannerFeedbackConfig copyWith({
    ScannerHaptic? detectHaptic,
    ScannerHaptic? rejectHaptic,
    ScannerHaptic? controlHaptic,
    bool? playSystemSound,
    SystemSoundType? detectSound,
    SystemSoundType? rejectSound,
    void Function(ScannerFeedbackEvent event)? onFeedback,
  }) {
    return ScannerFeedbackConfig(
      detectHaptic: detectHaptic ?? this.detectHaptic,
      rejectHaptic: rejectHaptic ?? this.rejectHaptic,
      controlHaptic: controlHaptic ?? this.controlHaptic,
      playSystemSound: playSystemSound ?? this.playSystemSound,
      detectSound: detectSound ?? this.detectSound,
      rejectSound: rejectSound ?? this.rejectSound,
      onFeedback: onFeedback ?? this.onFeedback,
    );
  }
}

/// The kinds of feedback event the scanner emits.
enum ScannerFeedbackEvent {
  /// A barcode was detected and accepted.
  detect,

  /// A barcode was detected but rejected by the validator.
  reject,

  /// The user activated one of the scanner's controls.
  control,
}
