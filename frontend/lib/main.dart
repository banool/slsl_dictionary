import 'dart:io' show HttpOverrides, Platform;

import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slsl_dictionary/entries_loader.dart';
import 'package:system_proxy/system_proxy.dart';
import 'package:intl/intl_standalone.dart';

import 'advisories.dart';
import 'common.dart';
import 'entries_types.dart';
import 'error_fallback.dart';
import 'globals.dart';
import 'language_dropdown.dart';
import 'root.dart';
import 'word_list_logic.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

// Setup the app. Be careful when reordering things here, later functions
// implicitly depend on the side effects of earlier functions.
Future<void> setup({Set<Entry>? entriesGlobalReplacement}) async {
  var widgetsBinding = WidgetsFlutterBinding.ensureInitialized();

  // Preserve the splash screen while the app initializes.
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // Load shared preferences. We do this first because the later futures,
  // such as loadFavourites and the knobs, depend on it being initialized.
  sharedPreferences = await SharedPreferences.getInstance();

  // Set the HTTP proxy if necessary.
  if (!kIsWeb) {
    Map<String, String> proxy = await SystemProxy.getProxySettings() ?? {};
    HttpOverrides.global =
        new ProxiedHttpOverrides(proxy["host"], proxy["port"]);
    printAndLog("Set HTTP proxy overrides to $proxy");
  }

  // Load up the advisories before doing anything else so it can be displayed
  // in the error page.
  advisoriesResponse = await getAdvisories();

  // Build the cache manager.
  myCacheManager = MyCacheManager();

  await Future.wait<void>([
    // Load up the words information once at startup from disk.
    // We do this first because loadFavourites depends on it later.
    (() async {
      if (entriesGlobalReplacement == null) {
        entriesGlobal = await loadEntriesFromCache();
      } else {
        entriesGlobal = entriesGlobalReplacement;
      }
    })(),

    // Get knob values.
    (() async =>
        enableFlashcardsKnob = await readKnob("enable_flashcards", true))(),
  ]);

  if (downloadWordsDataKnob && entriesGlobalReplacement == null) {
    if (entriesGlobal.isEmpty) {
      // If there is no entry data, wait for it before starting.
      printAndLog("No entry data, waiting for it before starting...");
      entriesGlobal = await loadEntriesFromCache();
      await updateWordsData();
    } else {
      // Otherwise, let it happen in the background.
      updateWordsData();
    }
  }

  // Build the word list manager.
  entryListManager = EntryListManager.fromStartup();

  // Resolve values based on knobs.
  showFlashcards = getShowFlashcards();

  // Get background color of settings pages.
  if (kIsWeb) {
    settingsBackgroundColor = Color.fromRGBO(240, 240, 240, 1);
  } else if (Platform.isAndroid) {
    settingsBackgroundColor = Color.fromRGBO(240, 240, 240, 1);
  } else if (Platform.isIOS) {
    settingsBackgroundColor = Color.fromRGBO(242, 242, 247, 1);
  } else {
    settingsBackgroundColor = Color.fromRGBO(240, 240, 240, 1);
  }

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

Future<void> updateWordsData() async {
  print("Trying to load data from the internet...");
  bool thereWasNewData = await getNewData(false);
  if (thereWasNewData) {
    printAndLog(
        "There was new data from the internet, loading it into memory...");
    entriesGlobal = await loadEntriesFromCache();
    updateKeyedEntriesGlobal();
    printAndLog("Updated entriesGlobal!");
  } else {
    printAndLog(
        "There was no new words data from the internet, not updating entriesGlobal");
  }
}
