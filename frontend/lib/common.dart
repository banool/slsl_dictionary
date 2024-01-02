import 'package:dictionarylib/entry_types.dart';
import 'package:flutter/material.dart';

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

Future<void> navigateToEntryPage(BuildContext context, Entry entry,
    {bool showFavouritesButton = true}) {
  return Navigator.push(
    context,
    MaterialPageRoute(
        builder: (context) => EntryPage(
            entry: entry, showFavouritesButton: showFavouritesButton)),
  );
}
