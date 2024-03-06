import 'package:dictionarylib/entry_types.dart';
import 'package:flutter/material.dart';

import 'word_page.dart';

const String APP_NAME = "SLSL Dictionary";

const MaterialColor MAIN_COLOR = MaterialColor(
  0xFF7E1430,
  <int, Color>{
    50: Color(0xFF7E1430),
    100: Color(0xFF7E1430),
    200: Color(0xFF7E1430),
    300: Color(0xFF7E1430),
    400: Color(0xFF7E1430),
    500: Color(0xFF7E1430),
    600: Color(0xFF7E1430),
    700: Color(0xFF7E1430),
    800: Color(0xFF7E1430),
    900: Color(0xFF7E1430),
  },
);

const Color APP_BAR_DISABLED_COLOR = Color.fromARGB(35, 35, 35, 0);

const String IOS_APP_ID = "6445848879";
const String ANDROID_APP_ID = "com.banool.slsl_dictionary";

Future<void> navigateToEntryPage(
    BuildContext context, Entry entry, bool showFavouritesButton) {
  return Navigator.push(
    context,
    MaterialPageRoute(
        builder: (context) => EntryPage(
            entry: entry, showFavouritesButton: showFavouritesButton)),
  );
}

// For example, en_US -> en. I'm pretty sure this isn't necessary because the
// languageCode is already just en but let's do this just in case.
String normalizeLanguageCode(String languageCode) {
  return languageCode.split("_")[0];
}

bool localeIsSupported(Locale locale) {
  var lang = normalizeLanguageCode(locale.languageCode);
  return lang == LANGUAGE_CODE_ENGLISH ||
      lang == LANGUAGE_CODE_SINHALA ||
      lang == LANGUAGE_CODE_TAMIL;
}
