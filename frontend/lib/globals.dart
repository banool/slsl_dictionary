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

late bool useCdnUrl;
