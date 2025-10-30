import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static const supportedLocales = [
    Locale('nb'),
    Locale('en'),
  ];

  static const localizationsDelegate = _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  late final Map<String, dynamic> _localizedStrings;

  Future<void> load() async {
    final bundle = rootBundle;
    final localeCode = locale.languageCode;
    final fallbackCode = localeCode == 'en' ? 'nb' : 'en';

    Future<Map<String, dynamic>> readJson(String code) async {
      final jsonString = await bundle.loadString('assets/translations/$code.json');
      return json.decode(jsonString) as Map<String, dynamic>;
    }

    final primary = await readJson(_resolveExistingLocale(localeCode));
    final fallback = await readJson(_resolveExistingLocale(fallbackCode));

    _localizedStrings = {...fallback, ...primary};
  }

  String translate(String key, {Map<String, String>? params}) {
    var value = _localizedStrings[key] as String? ?? key;
    if (params != null) {
      params.forEach((paramKey, paramValue) {
        value = value.replaceAll('{$paramKey}', paramValue);
      });
    }
    return value;
  }

  static String _resolveExistingLocale(String candidate) {
    return supportedLocales.any((locale) => locale.languageCode == candidate) ? candidate : 'nb';
  }
}

class AppLocalizationsDelegateHolder {
  static final ValueNotifier<Locale> notifier = ValueNotifier(const Locale('nb'));

  static Future<void> updateLocale(Locale locale) async {
    if (!AppLocalizations.supportedLocales
        .any((supported) => supported.languageCode == locale.languageCode)) {
      return;
    }
    Intl.defaultLocale = locale.languageCode;
    notifier.value = locale;
  }
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return AppLocalizations.supportedLocales
        .any((supported) => supported.languageCode == locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    final effectiveLocale = AppLocalizations.supportedLocales
        .firstWhere((supported) => supported.languageCode == locale.languageCode,
            orElse: () => const Locale('nb'));
    final localizations = AppLocalizations(effectiveLocale);
    await localizations.load();
    return localizations;
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) => false;
}
