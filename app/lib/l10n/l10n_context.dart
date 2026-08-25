import 'package:flutter/widgets.dart';

import 'generated/app_localizations.dart';

extension L10nContext on BuildContext {
  /// Returns the active [AppLocalizations] or `null` if the widget tree does
  /// not have the generated delegate installed. Callers should fall back to
  /// the source copy via [RsText]/[RsUiText.translate] when null.
  AppLocalizations? get l10n => Localizations.of<AppLocalizations>(this, AppLocalizations);
}
