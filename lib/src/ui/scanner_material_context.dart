import 'package:flutter/cupertino.dart'
    show CupertinoLocalizations, DefaultCupertinoLocalizations;
import 'package:flutter/material.dart';

/// Supplies the `flutter/material` localizations the scanner's chrome needs
/// when the host app does not.
///
/// The scanner is built from `package:flutter/material.dart` widgets, several
/// of which look up [MaterialLocalizations] and throw "No
/// MaterialLocalizations found" without them: [AppBar] asserts on them, and
/// the text selection toolbar behind every [SelectableText] reads its button
/// labels from them. A classic `MaterialApp` always provides them, so for most
/// apps this widget does nothing at all.
///
/// Two kinds of host do not:
///
/// * Apps built on `package:material_ui`. Flutter 3.47 decoupled Material and
///   Cupertino from the SDK into `material_ui` and `cupertino_ui`, and the
///   `MaterialApp` there installs *its own* `MaterialLocalizations` — a
///   distinct type that `flutter/material` widgets cannot see. Flutter's
///   answer is `MaterialUiCompatibilityBridge`, which the *app* has to
///   install, is deprecated on arrival, and is easy to miss until the scanner
///   crashes. Nor can the package simply migrate to `material_ui` in 8.x:
///   there is no reverse bridge, so every app still on `flutter/material`
///   would lose its theme and localizations inside the scanner instead.
/// * Apps built directly on `WidgetsApp`, which never had Material
///   localizations to begin with.
///
/// So when — and only when — [MaterialLocalizations] cannot be resolved, this
/// widget layers the SDK's English defaults over the host's own localizations
/// with [Localizations.override]. The host's delegates stay in the merged
/// list, so its locale, text direction and any app-specific localizations
/// keep resolving inside the scanner exactly as they do outside it.
/// [CupertinoLocalizations] are filled in the same way, because the adaptive
/// selection toolbar reads those instead on iOS and macOS; host-provided ones
/// are never replaced.
///
/// The labels this supplies are English regardless of locale: that is all the
/// SDK ships without `flutter_localizations`, and it only affects the text
/// selection toolbar and a handful of tooltips the scanner does not expose
/// through `ScannerLabels`. Every string the package itself renders still
/// comes from `ScannerLabels`.
///
/// [Localizations.override] creates a [Localizations] widget of its own, which
/// loads every inherited delegate again — exactly as
/// `MaterialUiCompatibilityBridge` does. A delegate whose `load` completes
/// synchronously, as `flutter_localizations` and `gen_l10n` ones do, notices
/// nothing. One that is genuinely asynchronous, such as a loader that reads
/// JSON, has its `load` run a second time when the scanner mounts, and the
/// scanner appears a frame later while that completes. Hosts that provide
/// [MaterialLocalizations] never reach the override.
///
/// This is a stop-gap for the 8.x line, which keeps importing
/// `flutter/material` so it stays compatible with hosts that have not
/// migrated. It is planned for removal in 9.0.0, when the package moves to
/// `material_ui` itself.
class ScannerMaterialContext extends StatefulWidget {
  /// Wraps [child], adding Material localizations only if they are missing.
  const ScannerMaterialContext({required this.child, super.key});

  /// The subtree that needs `flutter/material` localizations.
  final Widget child;

  /// Whether `flutter/material`'s [MaterialLocalizations] resolve from
  /// [context].
  ///
  /// This is `true` in every classic `MaterialApp` and `false` in a
  /// `material_ui` app without the compatibility bridge, or in a bare
  /// `WidgetsApp`.
  static bool hasMaterialLocalizations(BuildContext context) =>
      Localizations.of<MaterialLocalizations>(context, MaterialLocalizations) !=
      null;

  /// Whether the host app provides a `flutter/material` [Theme] above
  /// [context].
  ///
  /// The scanner uses this to decide who styles its few theme-dependent
  /// controls — the retry and open buttons, for example. When the host has a
  /// [Theme], those keep following its [ColorScheme] exactly as they always
  /// have. When it does not, [Theme.of] would silently return
  /// [ThemeData.fallback], whose baseline purple has nothing to do with the
  /// app, so the controls are styled from the `ScannerTheme` instead.
  ///
  /// The package never inserts a [Theme] of its own — [ScannerMaterialContext]
  /// deliberately adds only localizations — so any [Theme] found here came
  /// from the host, either directly or captured from the caller by a route.
  static bool hostProvidesMaterialTheme(BuildContext context) =>
      context.findAncestorWidgetOfExactType<Theme>() != null;

  @override
  State<ScannerMaterialContext> createState() => _ScannerMaterialContextState();
}

class _ScannerMaterialContextState extends State<ScannerMaterialContext> {
  // Should the host's localizations ever gain or lose MaterialLocalizations
  // while the scanner is on screen, the override is inserted or removed above
  // the child. Keying the child globally lets the framework move its subtree
  // instead of rebuilding it from scratch, so the camera preview's state and
  // platform view survive.
  final GlobalKey _subtreeKey = GlobalKey(
    debugLabel: 'ScannerMaterialContext subtree',
  );

  @override
  Widget build(BuildContext context) {
    final child = KeyedSubtree(key: _subtreeKey, child: widget.child);

    // Localizations.override extends the nearest Localizations ancestor and
    // asserts when there is none. A tree with no Localizations at all is not a
    // real app — every WidgetsApp installs one — so there is nothing to extend
    // and the subtree behaves exactly as it did before this widget existed.
    if (Localizations.maybeLocaleOf(context) == null) return child;

    if (ScannerMaterialContext.hasMaterialLocalizations(context)) return child;

    final hasCupertinoLocalizations =
        Localizations.of<CupertinoLocalizations>(
          context,
          CupertinoLocalizations,
        ) !=
        null;

    return Localizations.override(
      context: context,
      delegates: <LocalizationsDelegate<dynamic>>[
        const _AnyLocaleMaterialLocalizationsDelegate(),
        if (!hasCupertinoLocalizations)
          const _AnyLocaleCupertinoLocalizationsDelegate(),
      ],
      child: child,
    );
  }
}

/// Loads [DefaultMaterialLocalizations] for every locale.
///
/// `DefaultMaterialLocalizations.delegate` would be the obvious choice, but it
/// only reports support for English. Under any other locale it would be
/// skipped, [MaterialLocalizations] would still be missing, and the scanner
/// would crash for exactly the non-English apps this is meant to protect.
class _AnyLocaleMaterialLocalizationsDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const _AnyLocaleMaterialLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<MaterialLocalizations> load(Locale locale) =>
      DefaultMaterialLocalizations.load(locale);

  @override
  bool shouldReload(_AnyLocaleMaterialLocalizationsDelegate old) => false;
}

/// Loads [DefaultCupertinoLocalizations] for every locale, for the same reason
/// as [_AnyLocaleMaterialLocalizationsDelegate].
class _AnyLocaleCupertinoLocalizationsDelegate
    extends LocalizationsDelegate<CupertinoLocalizations> {
  const _AnyLocaleCupertinoLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<CupertinoLocalizations> load(Locale locale) =>
      DefaultCupertinoLocalizations.load(locale);

  @override
  bool shouldReload(_AnyLocaleCupertinoLocalizationsDelegate old) => false;
}

/// The default [SelectableText] context menu, built so that it can resolve
/// Material localizations in any host.
///
/// A selection toolbar is not built under the [SelectableText] that opened it:
/// it is inserted into the navigator's [Overlay], above any
/// [ScannerMaterialContext] the scanner installed. So the builder has to
/// supply the localizations itself. In a classic `MaterialApp` the wrapper is
/// a no-op and this is identical to [SelectableText]'s own default.
Widget scannerContextMenuBuilder(
  BuildContext context,
  EditableTextState editableTextState,
) {
  return ScannerMaterialContext(
    child: AdaptiveTextSelectionToolbar.editableText(
      editableTextState: editableTextState,
    ),
  );
}
