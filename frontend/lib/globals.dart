import 'package:flutter/cupertino.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'advisories.dart';
import 'common.dart';
import 'entries_types.dart';
import 'word_list_logic.dart';

late Set<Entry> entriesGlobal;
late Map<String, Entry> keyedByEnglishEntriesGlobal = {};
late Map<String, Entry> keyedByTamilEntriesGlobal = {};
late Map<String, Entry> keyedBySinhalaEntriesGlobal = {};

// For logging of things that occur in the background.
MaxLengthQueue<String> backgroundLogs = MaxLengthQueue(200);

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

late Set<Entry> favouritesGlobal;

late EntryListManager entryListManager;

late SharedPreferences sharedPreferences;
late MyCacheManager myCacheManager;

// Values of the knobs.
late bool enableFlashcardsKnob;
bool downloadWordsDataKnob = true;

// This is whether to show the flashcard stuff as a result of the knob + switch.
late bool showFlashcards;

// The settings page background color.
late Color settingsBackgroundColor;

// Advisory if there is a new one.
AdvisoriesResponse? advisoriesResponse;
bool advisoryShownOnce = false;

class MyCacheManager extends CacheManager with ImageCacheManager {
  static const key = 'mySignLanguageCacheManager';

  static final MyCacheManager _instance = MyCacheManager._();
  factory MyCacheManager() {
    return _instance;
  }

  MyCacheManager._()
      : super(Config(
          key,
          stalePeriod: const Duration(days: NUM_DAYS_TO_CACHE),
          maxNrOfCacheObjects: 500,
        ));
}
