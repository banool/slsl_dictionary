import 'package:dictionarylib/common.dart';
import 'package:dictionarylib/entry_types.dart';
import 'package:dictionarylib/flashcards_logic.dart';
import 'package:dictionarylib/globals.dart';
import 'package:dictionarylib/page_flashcards_landing.dart';
import 'package:dictionarylib/revision.dart';
import 'package:dolphinsr_dart/dolphinsr_dart.dart';
import 'package:flutter/material.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';
import 'package:settings_ui/settings_ui.dart';
import 'package:dictionarylib/dictionarylib.dart' show AppLocalizations;

import 'entries_types.dart';
import 'flashcards_help_page_en.dart';
import 'flashcards_page.dart';
import 'language_dropdown.dart';

class MyFlashcardsLandingPageController
    extends FlashcardsLandingPageController {
  @override
  Widget buildFlashcardsPage(
      {required DolphinInformation dolphinInformation,
      required RevisionStrategy revisionStrategy,
      required List<Review> existingReviews}) {
    return FlashcardsPage(
        di: dolphinInformation,
        revisionStrategy: revisionStrategy,
        existingReviews: existingReviews);
  }

  @override
  Widget buildHelpPage(BuildContext context) {
    return getFlashcardsHelpPageEn(context);
  }

  @override
  Map<Entry, List<SubEntry>> filterSubEntries(
      Map<Entry, List<SubEntry>> subEntries) {
    List<Region> allowedRegions =
        (sharedPreferences.getStringList(KEY_FLASHCARD_REGIONS) ?? [])
            .map((i) => Region.values[int.parse(i)])
            .toList();
    bool useUnknownRegionSigns =
        sharedPreferences.getBool(KEY_USE_UNKNOWN_REGION_SIGNS) ?? true;
    bool oneCardPerEntry =
        sharedPreferences.getBool(KEY_ONE_CARD_PER_WORD) ?? false;

    Map<Entry, List<SubEntry>> out = {};

    for (MapEntry<Entry, List<SubEntry>> e in subEntries.entries) {
      List<SubEntry> validSubEntries = [];
      for (SubEntry se in e.value) {
        if (validSubEntries.isNotEmpty && oneCardPerEntry) {
          break;
        }
        if (se.getRegions().contains(Region.ALL)) {
          validSubEntries.add(se);
          continue;
        }
        if (se.getRegions().isEmpty && useUnknownRegionSigns) {
          validSubEntries.add(se);
          continue;
        }
        for (Region r in se.getRegions()) {
          if (allowedRegions.contains(r)) {
            validSubEntries.add(se);
            break;
          }
        }
      }
      if (validSubEntries.isNotEmpty) {
        out[e.key] = validSubEntries;
      }
    }
    return out;
  }

  @override
  List<Widget> getExtraBottomWidgets(
      BuildContext context,
      void Function(void Function() fn) setState,
      void Function() updateRevisionSettings) {
    return [
      Padding(
        padding: const EdgeInsets.only(left: 35, top: 15),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            AppLocalizations.of(context)!.flashcardsRevisionLanguage,
            style: const TextStyle(
                fontSize: 16, color: Color.fromARGB(255, 100, 100, 100)),
            textAlign: TextAlign.start,
          ),
          Center(
              child: LanguageDropdown(
                  includeDeviceDefaultOption: false,
                  initialLanguageCode:
                      sharedPreferences.getString(KEY_REVISION_LANGUAGE_CODE),
                  onChanged: (languageCode) {
                    var selectedLocale = LANGUAGE_CODE_TO_LOCALE[languageCode]!;
                    sharedPreferences.setString(
                        KEY_REVISION_LANGUAGE_CODE, languageCode);
                    updateRevisionSettings();
                    return selectedLocale;
                  })),
        ]),
      )
    ];
  }

  @override
  List<SettingsTile> getExtraSettingsTiles(
      BuildContext context,
      void Function(void Function() fn) setState,
      void Function(String key, bool newValue, bool influencesStartValidity)
          onPrefSwitch,
      void Function() updateRevisionSettings) {
    List<int> regionsValues =
        (sharedPreferences.getStringList(KEY_FLASHCARD_REGIONS) ?? [])
            .map((e) => int.parse(e))
            .toList();
    return [
      SettingsTile.navigation(
        title:
            getText(AppLocalizations.of(context)!.flashcardsSelectSignRegions),
        trailing: Container(),
        onPressed: (BuildContext context) async {
          await showDialog(
            context: context,
            builder: (ctx) {
              return MultiSelectDialog(
                listType: MultiSelectListType.CHIP,
                title: Text(AppLocalizations.of(context)!.flashcardsRegions),
                items: Region.values
                    .map((e) =>
                        MultiSelectItem(e.index, getRegionPretty(context, e)))
                    .toList(),
                initialValue: regionsValues,
                onConfirm: (values) {
                  setState(() {
                    sharedPreferences.setStringList(KEY_FLASHCARD_REGIONS,
                        values.map((e) => e.toString()).toList());
                    updateRevisionSettings();
                  });
                },
              );
            },
          );
        },
      ),
    ];
  }
}
