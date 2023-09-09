import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:slsl_dictionary/entries_types.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'common.dart';
import 'globals.dart';
import 'word_list_logic.dart';

const String DATA_URL =
    "https://storage.googleapis.com/slsl-media-bucket-d7f91f9/dump/dump.json";

// Returns the local path where we store the dictionary data we download.
Future<File> get _dictionaryDataFilePath async {
  final path = (await getApplicationDocumentsDirectory()).path;
  return File('$path/downloaded_entries.json');
}

// Try to load data from the local cache.
Future<Set<Entry>> loadEntriesFromCache() async {
  String? data;

  // First try to read the data from local storage.
  try {
    if (kIsWeb) {
      // If we're on web use local storage, in which we just store all the data
      // as a value in the kv store.
      data = sharedPreferences.getString(KEY_WEB_DICTIONARY_DATA);
    } else {
      // If we're not on web, read data from the application directory, in
      // which we store it as an actual file.
      final path = await _dictionaryDataFilePath;
      data = await path.readAsString();
    }
  } catch (e) {
    printAndLog("Failed to load cached entries data from local storage: $e");
  }

  if (data == null) {
    printAndLog("No cached data was found");
    return {};
  }

  try {
    printAndLog(
        "Loaded entries from local storage (the data cached locally after downloading it from from the internet)");
    return loadEntriesInner(data);
  } catch (e) {
    printAndLog("Failed to deserialize data from local storage: $e");
    return {};
  }
}

// Set entriesGlobal and all the stuff that depends on it.
setEntiresGlobal(Set<Entry> entries) {
  entriesGlobal = entries;

  // Update the global entries variants keyed by each language.
  updateKeyedEntriesGlobal();

  // Update the list manager.
  entryListManager = EntryListManager.fromStartup();

  printAndLog("Updated entriesGlobal and all its downstream variables!");
}

Future<void> writeEntries(String newData) async {
  if (kIsWeb) {
    // If we're on web use local storage. Currently the dump file is around
    // 1mb and local storage should support 5mb per site, so this should be
    // sufficient for now: https://stackoverflow.com/q/2989284/3846032.
    await sharedPreferences.setString(KEY_WEB_DICTIONARY_DATA, newData);
  } else {
    final path = await _dictionaryDataFilePath;
    await path.writeAsString(newData);
  }
}

Set<MyEntry> loadEntriesInner(String data) {
  dynamic entriesJson = json.decode(data);
  Set<MyEntry> entries = {};
  for (dynamic entryData in entriesJson["data"]) {
    entries.add(MyEntry.fromJson(entryData));
  }
  printAndLog("Loaded ${entries.length} entries");
  return entries;
}

void updateKeyedEntriesGlobal() {
  printAndLog("Updating keyed entriesGlobal variants");
  for (Entry e in entriesGlobal) {
    // The key is the word in English, which is always present.
    keyedByEnglishEntriesGlobal[e.getKey()] = e;
    var keyTamil = e.getPhrase(LOCALE_TAMIL);
    if (keyTamil != null) {
      keyedByTamilEntriesGlobal[keyTamil] = e;
    }
    var keySinhala = e.getPhrase(LOCALE_SINHALA);
    if (keySinhala != null) {
      keyedBySinhalaEntriesGlobal[keySinhala] = e;
    }
  }
  printAndLog("Updated keyed entriesGlobal variants");
}

// Run this at startup.
// Downloads new dictionary data if available.
// First it checks how recently it attempted to do this, so we don't spam
// the dictionary data server.
// Returns true if new data was downloaded.
Future<bool> getNewData(bool forceCheck) async {
  // Determine whether it is time to check for new dictionary data.
  int? lastCheckTime =
      sharedPreferences.getInt(KEY_LAST_DICTIONARY_DATA_CHECK_TIME);
  int now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  if (!(lastCheckTime == null ||
      now - DATA_CHECK_INTERVAL > lastCheckTime ||
      forceCheck)) {
    // No need to check again so soon.
    printAndLog(
        "Not checking for new dictionary data, it hasn't been long enough");
    // todo undo this TODO. uncomment this once testing is done.
    //return false;
  }

  // Check for new dictionary data. The versions here are just unixtimes.
  int currentVersion =
      sharedPreferences.getInt(KEY_DICTIONARY_DATA_CURRENT_VERSION) ?? 0;
  var head = await http.head(Uri.parse(DATA_URL)).timeout(Duration(seconds: 3));
  var latestVersion =
      HttpDate.parse(head.headers['last-modified']!).millisecondsSinceEpoch ~/
          1000;

  // Exit out if the latest version is not newer than the current version.
  if (latestVersion <= currentVersion) {
    printAndLog(
        "Current version ($currentVersion) is >= latest version ($latestVersion), not downloading new data");
    // Record that we made this check so we don't check again too soon.
    await sharedPreferences.setInt(KEY_LAST_DICTIONARY_DATA_CHECK_TIME, now);
    return false;
  }

  // At this point, we know we need to download the new data. Let's do that.
  String newData =
      (await http.get(Uri.parse(DATA_URL)).timeout(Duration(seconds: 4))).body;

  // Assert that the data is valid. This will throw if it's not.
  loadEntriesInner(newData);

  // Write the data to file, which we read again afterwards to load it into
  // memory.
  writeEntries(newData);

  // Now, record the new version that we downloaded.
  await sharedPreferences.setInt(
      KEY_DICTIONARY_DATA_CURRENT_VERSION, latestVersion);
  printAndLog(
      "Set KEY_LAST_DICTIONARY_DATA_CHECK_TIME to $now and KEY_DICTIONARY_DATA_CURRENT_VERSION to $latestVersion. Done!");

  return true;
}
