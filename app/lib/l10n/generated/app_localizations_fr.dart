// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appName => 'Clash RS';

  @override
  String get navHome => 'Accueil';

  @override
  String get navProxies => 'Proxys';

  @override
  String get navSubscriptions => 'Abonnements';

  @override
  String get navConnections => 'Connexions';

  @override
  String get navRules => 'Règles';

  @override
  String get navLogs => 'Journaux';

  @override
  String get navTests => 'Tests';

  @override
  String get navSettings => 'Paramètres';

  @override
  String get proxyGroups => 'Groupes de proxys';

  @override
  String get commonDone => 'Terminé';

  @override
  String get commonCancel => 'Annuler';

  @override
  String get commonConfirm => 'Confirmer';

  @override
  String get commonSave => 'Enregistrer';

  @override
  String get commonClose => 'Fermer';

  @override
  String get commonDelete => 'Supprimer';

  @override
  String get commonRefresh => 'Actualiser';

  @override
  String get commonBrowse => 'Parcourir';

  @override
  String get commonCopy => 'Copier';

  @override
  String get commonEnabled => 'Activé';

  @override
  String get commonDisabled => 'Désactivé';

  @override
  String get commonOn => 'Activer';

  @override
  String get commonOff => 'Désactiver';

  @override
  String get commonLoading => 'Chargement…';

  @override
  String get commonNoData => 'Aucune donnée';

  @override
  String get languageSetting => 'Langue';

  @override
  String get languageSimplifiedChinese => 'Chinois simplifié';

  @override
  String get languageTraditionalChinese => 'Chinois traditionnel';

  @override
  String get languageEnglish => 'Anglais';

  @override
  String get languageJapanese => 'Japonais';

  @override
  String get languageKorean => 'Coréen';

  @override
  String get languageFrench => 'Français';

  @override
  String get settingsBasic => 'Paramètres de base RS';

  @override
  String get settingsAdvanced => 'Paramètres avancés RS';

  @override
  String get settingsSystem => 'Paramètres système';

  @override
  String get settingsClash => 'Paramètres Clash';

  @override
  String get settingsVersion => 'Version RS';

  @override
  String get proxyCheck => 'Tester';

  @override
  String get proxyChecking => 'Test en cours…';

  @override
  String get proxyError => 'Proxy indisponible';

  @override
  String get proxyModeRule => 'Règles';

  @override
  String get proxyModeGlobal => 'Global';

  @override
  String get proxyModeDirect => 'Direct';

  @override
  String get networkSystemProxy => 'Proxy système';

  @override
  String get networkTunMode => 'Mode TUN';

  @override
  String errorWithDetails(String message, String details) {
    return '$message : $details';
  }
}
