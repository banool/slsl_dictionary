import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/http.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'common.dart';
import 'entries_types.dart';
import 'globals.dart';
import 'word_list_logic.dart';

const String DATA_URL_PREFIX_DIRECT =
    "https://storage.googleapis.com/slsl-media-bucket-d7f91f9";
const String DATA_URL_PREFIX_CDN = "https://cdn.srilankansignlanguage.org";

String buildUrl(String path) {
  if (useCdnUrl) {
    return "$DATA_URL_PREFIX_CDN/$path";
  } else {
    return "$DATA_URL_PREFIX_DIRECT/$path";
  }
}

// Returns the local path where we store the dictionary data we download.
Future<File> get _dictionaryDataFilePath async {
  final path = (await getApplicationDocumentsDirectory()).path;
  return File('$path/downloaded_entries.json');
}

// Try to load data from the local cache.
Future<Set<Entry>> loadEntriesFromLocalStorage() async {
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
setEntriesGlobal(Set<Entry> entries) {
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
    return false;
  }

  if (forceCheck) {
    printAndLog("Forcing a check for new dictionary data");
  }

  Uri dump_file_url = Uri.parse(buildUrl("dump/dump.json"));

  // Uncomment this to get the dump from a server running locally.
  // dump_file_url = Uri.parse("http://127.0.0.1:8080/dump");

  printAndLog("Fetching dump file at $dump_file_url");

  int currentVersion =
      sharedPreferences.getInt(KEY_DICTIONARY_DATA_CURRENT_VERSION) ?? 0;

  // Previously we used to check if we needed to download the data again by
  // making two requests. First we'd make one request for just the headers, in
  // which we check the value of the Last-Modified header. If that time was
  // newer than the time we last downloaded the data, we'd make a second
  // request to actually download the data. This is not necessary if you're
  // downloading the data from a server that supports the If-Modified-Since
  // header. With this, we can just make a single request in which we say the
  // the data must be newer than the given time. If it is, we'll get a 200
  // containing the data. If not, we'll get a 304 with no body.
  var headers = {
    "If-Modified-Since": convertUnixTimeToHttpDate(currentVersion)
  };
  Response response = (await http
      .get(dump_file_url, headers: headers)
      .timeout(Duration(seconds: 15)));

  if (response.statusCode == 304) {
    printAndLog("Current version ($currentVersion) is the newest data");
    // Record that we made this check so we don't check again too soon.
    await sharedPreferences.setInt(KEY_LAST_DICTIONARY_DATA_CHECK_TIME, now);
    return false;
  }

  if (response.statusCode != 200) {
    throw "Failed to download dictionary data: ${response.statusCode}: ${response.body}";
  }

  // At this point we know we got a 200, we can look at the body of the response.
  String newData = response.body;

  // Take note of when this data was last modified. If the header isn't set,
  // use the latest unix time. This should only happen when developing locally
  // where you pull the dump file from a local server.
  int newVersion = HttpDate.parse(response.headers['last-modified'] ??
              DateTime.now().millisecondsSinceEpoch.toString())
          .millisecondsSinceEpoch ~/
      1000;

  // Assert that the data is valid. This will throw if it's not.
  loadEntriesInner(newData);

  // Write the data to file, which we read again afterwards to load it into
  // memory.
  await writeEntries(newData);

  // Now, record the new version that we downloaded.
  await sharedPreferences.setInt(
      KEY_DICTIONARY_DATA_CURRENT_VERSION, newVersion);
  printAndLog(
      "Set KEY_LAST_DICTIONARY_DATA_CHECK_TIME to $now and KEY_DICTIONARY_DATA_CURRENT_VERSION to $newVersion. Done!");

  return true;
}

Future<bool> updateWordsData(bool forceCheck) async {
  print("Trying to load data from the internet...");
  bool thereWasNewData = await getNewData(forceCheck);
  if (thereWasNewData) {
    printAndLog(
        "There was new data from the internet, loading it into memory...");
    var entries = await loadEntriesFromLocalStorage();
    setEntriesGlobal(entries);
  } else {
    printAndLog(
        "There was no new words data from the internet, not updating entriesGlobal");
  }
  return thereWasNewData;
}

String convertUnixTimeToHttpDate(int unixTime) {
  // Convert the Unix time to a DateTime object
  DateTime dateTime =
      DateTime.fromMillisecondsSinceEpoch(unixTime * 1000, isUtc: true);

  // Use the HttpDate class to format the DateTime object to an HTTP date
  String httpDate = HttpDate.format(dateTime);

  return httpDate;
}
