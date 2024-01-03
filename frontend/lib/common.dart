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

Future<void> navigateToEntryPage(
    BuildContext context, Entry entry, bool showFavouritesButton) {
  return Navigator.push(
    context,
    MaterialPageRoute(
        builder: (context) => EntryPage(
            entry: entry, showFavouritesButton: showFavouritesButton)),
  );
}
