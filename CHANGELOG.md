## 7.1.0

- Added child parameter to AiBarcodeScanner
- Bump version to 7.1.0 and update dependencies: mobile_scanner to ^7.1.2 and image_picker to ^1.2.0.
- Introduce a new GalleryButtonType.none option for the gallery button.
- Add support for custom image picker functionality in AiBarcodeScanner and GalleryButton.
- Update your iOS deployment target from 12.0 to 13.0 across multiple files.

## 7.0.0

**Improvements:**

- Added comprehensive documentation for supported barcode formats including PDF417
- Updated example to demonstrate PDF417 format configuration
- Enhanced README with format configuration examples
- Added Windows platform support documentation and runtime checks
- Added scanning accuracy and best practices documentation
- Added troubleshooting sections for common issues:
  - iOS CocoaPods dependency conflicts
  - Scanner crashes and black screen issues
  - Web mobile compatibility limitations
  - Distance scanning accuracy limitations
- Updated example to show proper navigation patterns for auto-closing scanner
- Added orientation handling improvements with `restoreOrientationsOnClose` parameter
- Fixed RenderFlex overflow in DraggableSheet widget

**Documentation:**

- Added comprehensive troubleshooting guide
- Added platform support limitations documentation
- Enhanced usage examples with best practices
- Added known limitations section for dependency-related issues
- [Major changes in AiBarcodeScanner class with new parameters and ui improvements, read the migration guide for more details](https://github.com/itsarvinddev/barcode_scanner/blob/master/MIGRATION_GUIDE.md).

## 6.0.1

**BREAKING CHANGES BY [MOBILE_SCANNER](https://pub.dev/packages/mobile_scanner):**

```
- [iOS] iOS 15.5.0 is now the minimum supported iOS version.
- [iOS] Updates MLKit to version 7.0.0.
- [iOS] Updates the minimum supported XCode version to 15.3.0.

Improvements:

- [MacOS] Added the corners and size information to barcode results.
- [MacOS] Added support for `analyzeImage`.
- [MacOS] Added a Privacy Manifest.
- [web] Added the size information to barcode results.
- [web] Added the video output size information to barcode capture.
- Added support for barcode formats to image analysis.
- Updated the scanner to report any scanning errors that were encountered during processing.
- Introduced a new getter `hasCameraPermission` for the `MobileScannerState`.
- Fixed a bug in the lifecycle handling sample. Now instead of checking `isInitialized`,
  the sample recommends using `hasCameraPermission`, which also guards against camera permission errors.
- Updated the behavior of `returnImage` to only determine if the camera output bytes should be sent.
- Updated the behavior of `BarcodeCapture.size` to always be provided when available, regardless of `returnImage`.
- [iOS] Excluded the `armv7` architecture, which is unsupported by MLKit 7.0.0.
- Added a new `onDetectError` error handler to the `MobileScanner` widget, for use with `onDetect`.

Bugs fixed:

- Fixed a bug that would cause the scanner to emit an error when it was already started. Now it ignores any calls to start while it is starting.
- [MacOS] Fixed a bug that prevented the `anaylzeImage()` sample from working properly.
- Fixed a bug that would cause onDetect to not handle errors.
```

## 6.0.0

- Dependency updates
- mobile_scanner: ^6.0.1
- setPortraitOrientation bool added. Now you can set the orientation.

## 5.2.2

- dependency updates

## 5.2.1

- dependency updates

## 5.1.1+1

- Readme updated
- gallery button hide option added

## 5.1.1

**BREAKING CHANGES:**

- mobile_scanner: ^5.1.1

## 3.4.1

- Jump to 3.4.1 to match the version of mobile_scanner
- Dependency updates
- mobile_scanner: ^3.4.1
- readme updated
- topics added
- Major changes in AiBarcodeScanner class
- allowDuplicates, hintMargin, hintPadding, hintBackgroundColor, errorText and successText removed
- hintWidget => bottomBar
- hintText => bottomBarText
- hintTextStyle => bottomBarTextStyle
- appBar added

## 0.0.7-dev.1

- error widget fixed

## 0.0.7

- Dependency updates
- validateText and validateType deprecated removed

## 0.0.6

- Readme updated

## 0.0.5

- [#43](https://github.com/mohesu/barcode_scanner/pull/43) added, Thanks to @MahmoudKhalid
- Readme updated
- mobile_scanner: ^3.2.0 added
- Added validator property, Deprecated validateText and validateType by @MahmoudKhalid
- Added onDispose property by @MahmoudKhalid

## 0.0.4

- mobile_scanner: ^3.0.0 added
- [#25](https://github.com/mohesu/barcode_scanner/issues/25) fixed
- [#32](https://github.com/mohesu/barcode_scanner/issues/32) added, Thanks to @Abhinav-Satija

## 0.0.2+1

- multi scan bug fixed

## 0.0.2

- Dependency updates
- mobile_scanner: ^3.0.0-beta.1

## 0.0.1+1

- Documentation updated

## 0.0.1

- Initial release.
- Added a button to turn the LED on and off.
- Added a button to flip the camera.
- Added a hint text.
- Added a barcode validator.
- Added a QR overlay.
