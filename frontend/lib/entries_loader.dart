import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:slsl_dictionary/entries_types.dart';

import 'common.dart';
import 'globals.dart';

const String DATA_URL =
    "https://storage.googleapis.com/slsl-media-bucket-d7f91f9/dump/dump.json";

// Returns the local path where we store the dictionary data we download.
Future<File> get _dictionaryDataFilePath async {
  final path = (await getApplicationDocumentsDirectory()).path;
  return File('$path/downloaded_entries.json');
}

Future<Set<Entry>> loadEntries() async {
  String data;
  try {
    // First try to read the data from local storage.
    final path = await _dictionaryDataFilePath;
    data = await path.readAsString();
    print("Loaded entries from local storage downloaded from the internet");
    return loadEntriesInner(data);
  } catch (e) {
    // Return nothing if there was no data in local storage.
    print("Failed to entries data from local storage: $e");
    return {};
  }
}

Set<MyEntry> loadEntriesInner(String data) {
  dynamic entriesJson = json.decode(data);
  Set<MyEntry> entries = {};
  for (dynamic entryData in entriesJson["data"]) {
    entries.add(MyEntry.fromJson(entryData));
  }
  print("Loaded ${entries.length} entries");
  return entries;
}

void updateKeyedEntriesGlobal() {
  for (Entry e in entriesGlobal) {
    keyedEntriesGlobal[e.getKey()] = e;
  }
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
    print("Not checking for new dictionary data, it hasn't been long enough");
    // todo undo this TODO. uncomment this once testing is done.
    //return false;
  }

  // Check for new dictionary data. The versions here are just unixtimes.
  int currentVersion =
      sharedPreferences.getInt(KEY_DICTIONARY_DATA_CURRENT_VERSION) ?? 0;
  var head = await http.head(Uri.parse(DATA_URL));
  var latestVersion =
      HttpDate.parse(head.headers['last-modified']!).millisecondsSinceEpoch ~/
          1000;

  // Exit out if the latest version is not newer than the current version.
  if (latestVersion <= currentVersion) {
    print(
        "Current version ($currentVersion) is >= latest version ($latestVersion), not downloading new data");
    // Record that we made this check so we don't check again too soon.
    await sharedPreferences.setInt(KEY_LAST_DICTIONARY_DATA_CHECK_TIME, now);
    return false;
  }

  // At this point, we know we need to download the new data. Let's do that.
  String newData = (await http.get(Uri.parse(DATA_URL))).body;

  // Assert that the data is valid. This will throw if it's not.
  loadEntriesInner(newData);

  // Write the data to file.
  final path = await _dictionaryDataFilePath;
  await path.writeAsString(newData);

  // Now, record the new version that we downloaded.
  await sharedPreferences.setInt(
      KEY_DICTIONARY_DATA_CURRENT_VERSION, latestVersion);
  print(
      "Set KEY_LAST_DICTIONARY_DATA_CHECK_TIME to $now and KEY_DICTIONARY_DATA_CURRENT_VERSION to $latestVersion. Done!");

  return true;
}
