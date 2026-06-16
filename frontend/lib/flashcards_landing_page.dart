import 'package:dictionarylib/common.dart';
import 'package:dictionarylib/dictionarylib.dart' show DictLibLocalizations;
import 'package:dictionarylib/entry_types.dart';
import 'package:dictionarylib/flashcards_logic.dart';
import 'package:dictionarylib/globals.dart';
import 'package:dictionarylib/hearth.dart';
import 'package:dictionarylib/page_flashcards.dart';
import 'package:dictionarylib/page_flashcards_landing.dart';
import 'package:flutter/material.dart';

import 'common.dart';
import 'flashcards_help_page_en.dart';
import 'language_dropdown.dart';
import 'word_page.dart';

/// SLSL's wiring for the shared [FlashcardsPage]: a 16:12 video, region info
/// via [getRegionalInformationWidget], no Signbank link, and the app's own
/// entry-page navigation.
final FlashcardsConfig slslFlashcardsConfig = FlashcardsConfig(
  videoAspectRatio: 16 / 12,
  regionRowHeight: 56,
  navigateToEntryPage: navigateToEntryPage,
  buildRegionInfo: (context, resolved, shouldUseHorizontalDisplay, revealed) =>
      getRegionalInformationWidget(
          context, resolved.subEntry, shouldUseHorizontalDisplay,
          hide: !revealed),
);

class MyFlashcardsLandingPageController
    extends FlashcardsLandingPageController {
  @override
  FlashcardsConfig get flashcardsConfig => slslFlashcardsConfig;

  @override
  Widget buildHelpPage(BuildContext context) {
    return getFlashcardsHelpPageEn(context);
  }

  /// Revise every saved video in the chosen lists. SLSL has only two regions
  /// (All of Sri Lanka / North East) and most signs are nationwide, so we
  /// don't filter the pool by region here.
  // TODO: optionally re-add an SLSL region filter (Region.ALL / NORTH_EAST).
  @override
  List<ResolvedSavedVideo> filterSavedVideos(List<ResolvedSavedVideo> videos) {
    return videos;
  }

  /// SLSL signs are shown in English, Sinhala, or Tamil, so let the user choose
  /// which language the flashcard prompts use. The chosen code is persisted to
  /// [KEY_REVISION_LANGUAGE_CODE], which the base landing page reads when it
  /// builds the masters (an English-only app like Auslan has no such setting).
  @override
  List<Widget> getExtraBottomWidgets(
      BuildContext context,
      void Function(void Function() fn) setState,
      void Function() updateRevisionSettings) {
    return [
      const SizedBox(height: 16),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: HearthRowGroup(rows: [
          HearthRow(
            icon: Icons.translate,
            title: DictLibLocalizations.of(context)!.settingsLanguage,
            trailing: LanguageDropdown(
              asPopUpMenu: true,
              includeDeviceDefaultOption: false,
              initialLanguageCode:
                  sharedPreferences.getString(KEY_REVISION_LANGUAGE_CODE),
              onChanged: (languageCode) {
                final selectedLocale = LANGUAGE_CODE_TO_LOCALE[languageCode]!;
                sharedPreferences.setString(
                    KEY_REVISION_LANGUAGE_CODE, languageCode);
                updateRevisionSettings();
                return selectedLocale;
              },
            ),
          ),
        ]),
      ),
    ];
  }
}
