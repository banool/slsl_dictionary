import 'package:dictionarylib/common.dart';
import 'package:dictionarylib/entry_types.dart';
import 'package:dictionarylib/globals.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:slsl_dictionary/entries_loader.dart';
import 'package:intl/intl_standalone.dart';

import 'error_fallback.dart';
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

  // Do common setup stuff defined in dictionarylib.
  await setupPhaseOne();

  await Future.wait<void>([
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
  await setupPhaseTwo(
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
      locale = systemLocale;
      printAndLog("Using system locale: $locale");
    }
    runApp(RootApp(startingLocale: locale));
  } catch (error, stackTrace) {
    runApp(ErrorFallback(
      error: error,
      stackTrace: stackTrace,
    ));
  }
}
