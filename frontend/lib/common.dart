import 'package:dictionarylib/entry_list.dart';
import 'package:dictionarylib/entry_types.dart';
import 'package:dictionarylib/saved_video.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'word_page.dart';

const String APP_NAME = "SLSL Dictionary";

/*
const MaterialColor LIGHT_MAIN_COLOR = MaterialColor(
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
*/

const MaterialColor DARK_MAIN_COLOR = MaterialColor(
  0xFFeb7400,
  <int, Color>{
    50: Color(0xFFFEF2E7),
    100: Color(0xFFFDE0C3),
    200: Color(0xFFFBCB94),
    300: Color(0xFFF9B665),
    400: Color(0xFFF7A741),
    500: Color(0xFFeb7400),
    600: Color(0xFFD96B00),
    700: Color(0xFFB35800),
    800: Color(0xFF8C4600),
    900: Color(0xFF663300),
  },
);

const MaterialColor LIGHT_MAIN_COLOR = DARK_MAIN_COLOR;

const Color APP_BAR_DISABLED_COLOR = Color.fromARGB(35, 35, 35, 0);

const String IOS_APP_ID = "6445848879";
const String ANDROID_APP_ID = "com.banool.slsl_dictionary";

/// Route path for an entry page. The entry's key (its English phrase) is the
/// `:key` path segment; `?variation=N&video=M` optionally deep-link to a
/// specific sub-entry / video within it.
const String WORD_ROUTE = "/word";

/// Non-URL-serialisable args carried to the [WORD_ROUTE] page by an in-app
/// navigation (the entry object is re-resolved from the URL key, but these
/// can't be). Absent on a cold deep link, where the route falls back to
/// sensible defaults (full UI, no focused video, no save-to-list target).
class EntryPageArgs {
  const EntryPageArgs({
    this.showFavouritesButton = true,
    this.focusVideo,
    this.saveToList,
  });

  final bool showFavouritesButton;
  final SavedVideo? focusVideo;
  final EntryList? saveToList;
}

/// Open an entry. Matches dictionarylib's NavigateToEntryPageFn typedef.
///
/// Web: pushes a real `/word/<key>` go_router route so the URL reflects the
/// entry and it's deep-linkable (a pasted link resolves the entry from the key).
/// Native: keeps the proven imperative push — URLs are invisible there anyway,
/// and going through go_router would clobber a raw-pushed parent (e.g. the list
/// view) and break its back button. The non-serialisable bits ([focusVideo],
/// [saveToList]) ride along as `extra`.
Future<void> navigateToEntryPage(
    BuildContext context, Entry entry, bool showFavouritesButton,
    {SavedVideo? focusVideo, EntryList? saveToList}) async {
  if (kIsWeb) {
    await context.push(
      "$WORD_ROUTE/${Uri.encodeComponent(entry.getKey())}",
      extra: EntryPageArgs(
        showFavouritesButton: showFavouritesButton,
        focusVideo: focusVideo,
        saveToList: saveToList,
      ),
    );
  } else {
    await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => EntryPage(
              entry: entry,
              showFavouritesButton: showFavouritesButton,
              focusVideo: focusVideo,
              saveToList: saveToList)),
    );
  }
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
