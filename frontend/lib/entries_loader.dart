import 'dart:io';

import 'package:dictionarylib/common.dart';
import 'package:dictionarylib/entry_loader.dart';
import 'package:dictionarylib/entry_types.dart';
import 'package:dictionarylib/globals.dart';
import 'package:http/http.dart' as http;
import 'package:http/http.dart';

import 'entries_types.dart';
import 'globals.dart';

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

class MyEntryLoader extends EntryLoader {
  MyEntryLoader({required super.dumpFileUrl});

  @override
  Future<NewData?> downloadNewData(int currentVersion) async {
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
        .get(dumpFileUrl, headers: headers)
        .timeout(Duration(seconds: 15)));

    if (response.statusCode == 304) {
      return null;
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

    return NewData(newData, newVersion);
  }

  @override
  Entry entryFromDataFn(dynamic data) {
    return MyEntry.fromJson(data);
  }
}
