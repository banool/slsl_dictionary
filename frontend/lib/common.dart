import 'dart:collection';

import 'package:http/http.dart' as http;
import 'package:edit_distance/edit_distance.dart';
import 'package:flutter/material.dart';

import 'entries_types.dart';
import 'globals.dart';
import 'types.dart';
import 'word_page.dart';

const String APP_NAME = "SLSL Dictionary";

const MaterialColor MAIN_COLOR = const MaterialColor(
  0xFF7E1430,
  const <int, Color>{
    50: const Color(0xFF7E1430),
    100: const Color(0xFF7E1430),
    200: const Color(0xFF7E1430),
    300: const Color(0xFF7E1430),
    400: const Color(0xFF7E1430),
    500: const Color(0xFF7E1430),
    600: const Color(0xFF7E1430),
    700: const Color(0xFF7E1430),
    800: const Color(0xFF7E1430),
    900: const Color(0xFF7E1430),
  },
);
const Color APP_BAR_DISABLED_COLOR = Color.fromARGB(35, 35, 35, 0);

const String KEY_LOCALE_OVERRIDE = "locale_override";

const String KEY_SHOULD_CACHE = "should_cache";

const String KEY_WEB_DICTIONARY_DATA = "web_dictionary_data";

const String KEY_ADVISORY_VERSION = "advisory_version";

const String KEY_SEARCH_FOR_WORDS = "search_for_words";
const String KEY_SEARCH_FOR_PHRASES = "search_for_phrases";
const String KEY_SEARCH_FOR_FINGERSPELLING = "search_for_fingerspelling";

const String KEY_FAVOURITES_ENTRIES = "favourites_entries";
const String KEY_LAST_DICTIONARY_DATA_CHECK_TIME = "last_data_check_time";
const String KEY_DICTIONARY_DATA_CURRENT_VERSION = "current_data_version";
const String KEY_HIDE_FLASHCARDS_FEATURE = "hide_flashcards_feature";
const String KEY_FLASHCARD_REGIONS = "flashcard_regions";
const String KEY_REVISION_STRATEGY = "revision_strategy";
const String KEY_REVISION_LANGUAGE_CODE = "revision_language_code";

const int DATA_CHECK_INTERVAL = 60 * 60 * 1; // 1 hour.

const int NUM_DAYS_TO_CACHE = 14;

Future<void> navigateToEntryPage(BuildContext context, Entry entry,
    {bool showFavouritesButton = true}) {
  return Navigator.push(
    context,
    MaterialPageRoute(
        builder: (context) => EntryPage(
            entry: entry, showFavouritesButton: showFavouritesButton)),
  );
}

// Search a list of entries and return top matching items.
List<Entry> searchList(BuildContext context, String searchTerm,
    List<EntryType> entryTypes, Set<Entry> entries, Set<Entry> fallback) {
  final SplayTreeMap<double, List<Entry>> st =
      SplayTreeMap<double, List<Entry>>();
  if (searchTerm == "") {
    return List.from(fallback);
  }
  searchTerm = searchTerm.toLowerCase();
  JaroWinkler d = new JaroWinkler();
  RegExp noParenthesesRegExp = new RegExp(
    r"^[^ (]*",
    caseSensitive: false,
    multiLine: false,
  );
  print("Searching ${entries.length} entries with entryTypes $entryTypes");
  Locale currentLocale = Localizations.localeOf(context);
  for (Entry e in entries) {
    if (!entryTypes.contains(e.getEntryType())) {
      continue;
    }
    String? phrase = e.getPhrase(currentLocale);
    if (phrase == null) {
      continue;
    }
    String noPunctuation = phrase.replaceAll(" ", "").replaceAll(",", "");
    String lowerCase = noPunctuation.toLowerCase();
    String noParenthesesContent = noParenthesesRegExp.stringMatch(lowerCase)!;
    String normalisedEntry = noParenthesesContent;
    double difference = d.normalizedDistance(normalisedEntry, searchTerm);
    if (difference == 1.0) {
      continue;
    }
    st.putIfAbsent(difference, () => []).add(e);
  }
  List<Entry> out = [];
  for (List<Entry> entries in st.values) {
    out.addAll(entries);
    if (out.length > 10) {
      break;
    }
  }
  return out;
}

bool getShouldUseHorizontalLayout(BuildContext context) {
  var screenSize = MediaQuery.of(context).size;
  var shouldUseHorizontalDisplay = screenSize.width > screenSize.height * 1.2;
  return shouldUseHorizontalDisplay;
}

// Reaches out to check the value of the knob. If this succeeds, we store the
// value locally. If this fails, we first check the local store to attempt to
// use the value the value we last saw for the knob. If there is nothing there,
// we use the hardcoded `fallback` value.
Future<bool> readKnob(String key, bool fallback) async {
  String sharedPrefsKey = "knob_$key";
  try {
    String url =
        'https://raw.githubusercontent.com/banool/slsl_dictionary/main/frontend/assets/knobs/$key';
    var result = await http.get(Uri.parse(url)).timeout(Duration(seconds: 4));
    String raw = result.body.replaceAll("\n", "");
    bool out;
    if (raw == "true") {
      out = true;
    } else if (raw == "false") {
      out = false;
    } else {
      throw "Failed to check knob at $url, using fallback value: $fallback, due to ${result.body}";
    }
    await sharedPreferences.setBool(sharedPrefsKey, out);
    print("Value of knob $key is $out, stored at $sharedPrefsKey");
    return out;
  } catch (e, stacktrace) {
    print("$e:\n$stacktrace");
    var out = sharedPreferences.getBool(sharedPrefsKey) ?? fallback;
    print("Returning fallback value for knob $key: $out");
    return out;
  }
}

bool getShowFlashcards() {
  if (!enableFlashcardsKnob) {
    return false;
  }
  return !(sharedPreferences.getBool(KEY_HIDE_FLASHCARDS_FEATURE) ?? false);
}

Future<bool> confirmAlert(BuildContext context, Widget content,
    {String title = "Careful!",
    String cancelText = "Cancel",
    String confirmText = "Confirm"}) async {
  bool confirmed = false;
  Widget cancelButton = TextButton(
    child: Text(cancelText, style: TextStyle(color: Colors.black)),
    onPressed: () {
      Navigator.of(context).pop();
    },
  );
  Widget continueButton = TextButton(
    child: Text(confirmText, style: TextStyle(color: Colors.black)),
    onPressed: () {
      confirmed = true;
      Navigator.of(context).pop();
    },
  );
  AlertDialog alert = AlertDialog(
    title: Text(title),
    content: content,
    actions: [
      cancelButton,
      continueButton,
      Padding(padding: EdgeInsets.only(right: 0))
    ],
  );
  await showDialog(
    context: context,
    builder: (BuildContext context) {
      return alert;
    },
  );
  return confirmed;
}

Widget buildActionButton(
    BuildContext context, Icon icon, void Function() onPressed,
    {bool enabled = true,
    Color enabledColor = Colors.white,
    Color disabledColor = APP_BAR_DISABLED_COLOR}) {
  void Function()? onPressedFunc = onPressed;
  if (!enabled) {
    onPressedFunc = null;
  }
  return Container(
      width: 45,
      child: TextButton(
          onPressed: onPressedFunc,
          child: icon,
          style: ButtonStyle(
              padding: MaterialStateProperty.all(EdgeInsets.zero),
              shape: MaterialStateProperty.all(
                  CircleBorder(side: BorderSide(color: Colors.transparent))),
              fixedSize: MaterialStateProperty.all(Size.fromWidth(10)),
              foregroundColor: MaterialStateProperty.resolveWith(
                (states) {
                  if (states.contains(MaterialState.disabled)) {
                    return disabledColor;
                  } else {
                    return enabledColor;
                  }
                },
              ))));
}

List<Widget> buildActionButtons(List<Widget> actions) {
  actions = actions + <Widget>[Padding(padding: EdgeInsets.only(right: 5))];
  return actions;
}

RevisionStrategy loadRevisionStrategy() {
  int revisionStrategyIndex = sharedPreferences.getInt(KEY_REVISION_STRATEGY) ??
      RevisionStrategy.SpacedRepetition.index;
  RevisionStrategy revisionStrategy =
      RevisionStrategy.values[revisionStrategyIndex];
  return revisionStrategy;
}

extension StripString on String {
  String lstrip(String pattern) {
    return this.replaceFirst(new RegExp('^' + pattern + '*'), '');
  }

  String rstrip(String pattern) {
    return this.replaceFirst(new RegExp(pattern + r'*$'), '');
  }
}
