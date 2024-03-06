import 'package:dictionarylib/common.dart';
import 'package:dictionarylib/entry_types.dart';
import 'package:dictionarylib/error_fallback.dart';
import 'package:dictionarylib/globals.dart';
import 'package:dictionarylib/page_force_upgrade.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:slsl_dictionary/common.dart';
import 'package:slsl_dictionary/entries_loader.dart';
import 'package:intl/intl_standalone.dart';

import 'globals.dart';
import 'language_dropdown.dart';
import 'root.dart';

// TODO: More elegantly handle startup when there is no local data cache
// and loading data from the internet fails.

const String KNOB_URL_BASE =
    "https://raw.githubusercontent.com/banool/slsl_dictionary/main/frontend/assets/knobs/";

// Setup the app. Be careful when reordering things here, later functions
// implicitly depend on the side effects of earlier functions.
Future<void> setup({Set<Entry>? entriesGlobalReplacement}) async {
  var widgetsBinding = WidgetsFlutterBinding.ensureInitialized();

  // Preserve the splash screen while the app initializes.
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // This just loads the package info, which we need for the yanked version
  // checker.
  await setupPhaseOne();

  // It is okay to check for yanked versions and do phase two setup at the same
  // time because phase two setup never throws. We want to do them together
  // because they both make network calls, so we can do them concurrently.
  await Future.wait<void>([
    (() async {
      // Do common setup stuff defined in dictionarylib.
      await setupPhaseTwo(Uri.parse(
          "https://raw.githubusercontent.com/banool/slsl_dictionary/main/frontend/assets/advisories.md"));
    })(),
    (() async {
      // If the user needs to upgrade, this will throw a specific error that
      // main() can catch to show the ForceUpgradePage.
      await GitHubYankedVersionChecker(
              "https://raw.githubusercontent.com/banool/slsl_dictionary/main/assets/yanked_versions")
          .throwIfShouldUpgrade();
    })(),
    // Get knob values.
    (() async =>
        useCdnUrl = await readKnob(KNOB_URL_BASE, "use_cdn_url", true))(),
  ]);

  MyEntryLoader myEntryLoader = MyEntryLoader(
    dumpFileUrl: Uri.parse(buildUrl("dump/dump.json")),
  );

  // Do the rest of the common stuff defined in dictionarylib. This will set
  // the entryLoader global value with what we pass in so we don't have to do
  // it ourselves.
  await setupPhaseThree(
      paramEntryLoader: myEntryLoader,
      knobUrlBase: KNOB_URL_BASE,
      entriesGlobalReplacement: entriesGlobalReplacement);

  // Remove the splash screen.
  FlutterNativeSplash.remove();

  // Finally run the app.
  printAndLog("Setup complete, running app");
}

Future<void> main() async {
  printAndLog("Start of main");
  try {
    await setup();

    systemLocale = Locale(await findSystemLocale());
    Locale locale;
    Locale? localeOverride = await LocaleOverride.getLocaleOverride();
    if (localeOverride != null) {
      locale = localeOverride;
      printAndLog("Using locale override: $locale");
    } else {
      printAndLog("Using system locale: $systemLocale");
      locale = systemLocale;
    }
    // We can only handle these 3 locales, if the system locale is something
    // else we fall back to English.
    if (!localeIsSupported(locale)) {
      locale = LOCALE_ENGLISH;
      printAndLog("Locale not supported, falling back to English: $locale");
    }
    runApp(RootApp(startingLocale: locale));
  } on YankedVersionError catch (e) {
    runApp(ForceUpgradePage(
        error: e, iOSAppId: IOS_APP_ID, androidAppId: ANDROID_APP_ID));
  } catch (error, stackTrace) {
    runApp(ErrorFallback(
      appName: APP_NAME,
      error: error,
      stackTrace: stackTrace,
    ));
  }
}
