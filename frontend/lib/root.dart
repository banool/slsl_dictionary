import 'package:dictionarylib/dictionarylib.dart' show DictLibLocalizations;
import 'package:dictionarylib/root_app.dart';
import 'package:flutter/material.dart';

import 'common.dart';
import 'flashcards_landing_page.dart';
import 'language_dropdown.dart';
import 'legal_information.dart';
import 'word_page.dart';

// See comment above onGenerateTitle (in dictionarylib's DictRootApp) for an
// explanation for why we have this.
String getAppTitle(Locale locale) {
  if (locale.languageCode.startsWith("en")) {
    return "SLSL Dictionary";
  } else if (locale.languageCode.startsWith("si")) {
    return "සිංහල ශබ්දකෝෂය";
  } else if (locale.languageCode.startsWith("ta")) {
    return "இலங்கை சைகை மொழி அகராதி";
  } else {
    throw Exception("Unsupported locale for title: $locale");
  }
}

/// Everything app-specific the shared root app needs. The route table, share
/// deep-link handling, engine-event snackbars, and theme plumbing all live in
/// dictionarylib's DictRootApp.
final DictRootAppConfig appRootConfig = DictRootAppConfig(
  appName: APP_NAME,
  appTitle: getAppTitle,
  classicSeed: LIGHT_MAIN_COLOR,
  wordPageConfig: slslWordPageConfig,
  navigateToEntryPage: navigateToEntryPage,
  includeEntryTypeButton: true,
  buildFlashcardsLandingPageController: () =>
      MyFlashcardsLandingPageController(),
  buildSettingsTopWidgets: (context) => [
    Padding(
      padding: const EdgeInsets.only(left: 35, top: 15),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          DictLibLocalizations.of(context)!.settingsLanguage,
          style: const TextStyle(
              fontSize: 13, color: Color.fromARGB(255, 100, 100, 100)),
          textAlign: TextAlign.start,
        ),
        const Center(child: LanguageDropdown()),
      ]),
    ),
  ],
  buildLegalInformationChildren: buildLegalInformationChildren,
  reportDataProblemUrl:
      'https://github.com/banool/slsl_dictionary/issues/new/choose',
  reportAppProblemUrl: 'https://github.com/banool/slsl_dictionary/issues',
  privacyPolicyUrl: 'https://landing.srilankansignlanguage.org/privacy.html',
  termsOfServiceUrl: 'https://landing.srilankansignlanguage.org/terms.html',
  iOSAppId: IOS_APP_ID,
  androidAppId: ANDROID_APP_ID,
);

/// Thin wrapper over the shared DictRootApp so main.dart and the integration
/// tests keep a stable app-local entrypoint (and so the app can diverge from
/// the shared scaffold later by growing this widget).
class RootApp extends StatelessWidget {
  const RootApp({super.key, required this.startingLocale});

  final Locale startingLocale;

  @override
  Widget build(BuildContext context) =>
      DictRootApp(startingLocale: startingLocale, config: appRootConfig);
}
