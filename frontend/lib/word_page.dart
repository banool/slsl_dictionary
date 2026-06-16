import 'package:dictionarylib/entry_types.dart';
import 'package:dictionarylib/globals.dart';
import 'package:dictionarylib/page_word.dart';
import 'package:flutter/material.dart';
import 'package:slsl_dictionary/language_dropdown.dart';

import 'common.dart';
import 'entries_types.dart';
import 'globals.dart';

/// The region(s) a sub-entry's sign is used in, as a plain centred line.
/// Used by the flashcard back, which wants a centred label with a [hide]
/// toggle (the region stays hidden until the card is revealed). The word page
/// uses the shared footer (see [EntryPage]) for its richer styling.
Widget getRegionalInformationWidget(
    BuildContext context, SubEntry subEntry, bool shouldUseHorizontalDisplay,
    {bool hide = false}) {
  String regionsStr =
      subEntry.getRegions().map((r) => getRegionPretty(context, r)).join(", ");
  if (hide) {
    regionsStr = "";
  }
  return Padding(
    padding: const EdgeInsets.only(top: 15.0),
    child: Text(regionsStr, textAlign: TextAlign.center),
  );
}

/// SLSL's definition layout: the category name in bold, then the definition
/// text beneath it.
Widget slslDefinition(BuildContext context, dynamic d) {
  final definition = d as Definition;
  return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 15.0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          definition.categoryPretty,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        Padding(
            padding: const EdgeInsets.only(left: 10.0, top: 8.0),
            child: Text(definition.definition))
      ]));
}

/// SLSL's wiring for the shared [EntryPage]: related-word lookup across the
/// English / Tamil / Sinhala maps, region strings via [getRegionPretty], a
/// 16:12 video, and a language dropdown in the app bar that overrides the
/// displayed language for this entry.
final WordPageConfig slslWordPageConfig = WordPageConfig(
  getRelatedEntry: (keyword) {
    if (keyedByEnglishEntriesGlobal.containsKey(keyword)) {
      return keyedByEnglishEntriesGlobal[keyword];
    } else if (keyedByTamilEntriesGlobal.containsKey(keyword)) {
      return keyedByTamilEntriesGlobal[keyword];
    } else if (keyedBySinhalaEntriesGlobal.containsKey(keyword)) {
      return keyedBySinhalaEntriesGlobal[keyword];
    }
    return null;
  },
  navigateToEntryPage: navigateToEntryPage,
  buildDefinition: slslDefinition,
  regionsString: (context, subEntry) =>
      subEntry.getRegions().map((r) => getRegionPretty(context, r)).join(", "),
  videoAspectRatio: 16 / 12,
  buildExtraAppBarActions: (context, ctx) => [
    LanguageDropdown(
        asPopUpMenu: true,
        includeDeviceDefaultOption: false,
        onChanged: (languageCode) {
          final locale = LANGUAGE_CODE_TO_LOCALE[languageCode]!;
          ctx.setLocaleOverride(locale);
          return locale;
        }),
  ],
);
