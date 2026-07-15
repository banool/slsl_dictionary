import 'package:dictionarylib/entry_types.dart';
import 'package:dictionarylib/globals.dart';
import 'package:flutter/cupertino.dart';

Map<String, Entry> keyedByTamilEntriesGlobal = {};
Map<String, Entry> keyedBySinhalaEntriesGlobal = {};

Map<String, Entry> getEntriesGlobal(Locale locale) {
  if (locale == LOCALE_ENGLISH) {
    return keyedByEnglishEntriesGlobal;
  } else if (locale == LOCALE_TAMIL) {
    return keyedByTamilEntriesGlobal;
  } else if (locale == LOCALE_SINHALA) {
    return keyedBySinhalaEntriesGlobal;
  } else {
    throw Exception("Unknown locale $locale");
  }
}

// use_cdn_url has read `true` for everyone for years, so the app no longer
// fetches it at startup — it's hardcoded here. The knob mechanism (readKnob,
// KNOB_URL_BASE, extraStartupTasks) is kept for future use: to make this a live
// knob again, restore the readKnob call in main.dart's extraStartupTasks. The
// GitHub knob file is left in place so old app versions that still fetch it
// keep working.
bool useCdnUrl = true;
