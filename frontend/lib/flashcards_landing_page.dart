import 'package:dictionarylib/common.dart';
import 'package:dictionarylib/entry_list.dart';
import 'package:dictionarylib/entry_types.dart';
import 'package:dictionarylib/flashcards_logic.dart';
import 'package:dictionarylib/globals.dart';
import 'package:dictionarylib/revision.dart';
import 'package:dolphinsr_dart/dolphinsr_dart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';
import 'package:settings_ui/settings_ui.dart';
import 'package:dictionarylib/dictionarylib.dart' show AppLocalizations;

import 'common.dart';
import 'entries_types.dart';
import 'flashcards_help_page_en.dart';
import 'flashcards_logic.dart';
import 'flashcards_page.dart';
import 'language_dropdown.dart';
import 'revision_history_page.dart';
import 'settings_page.dart';
import 'top_level_scaffold.dart';

const String KEY_SIGN_TO_WORD = "sign_to_word";
const String KEY_WORD_TO_SIGN = "word_to_sign";
const String KEY_USE_UNKNOWN_REGION_SIGNS = "use_unknown_region_signs";
const String KEY_ONE_CARD_PER_WORD = "one_card_per_word";

const String KEY_LISTS_TO_REVIEW = "lists_chosen_to_review";

class FlashcardsLandingPage extends StatefulWidget {
  @override
  _FlashcardsLandingPageState createState() => _FlashcardsLandingPageState();
}

class _FlashcardsLandingPageState extends State<FlashcardsLandingPage> {
  late int numEnabledFlashcardTypes;

  late final bool initialValueSignToEntry;
  late final bool initialValueEntryToSign;

  late List<String> listsToReview;
  late Set<Entry> entriesFromLists;

  Map<Entry, List<SubEntry>> filteredSubEntries = Map();

  late DolphinInformation dolphinInformation;
  List<Review>? existingReviews;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addObserver(LifecycleEventHandler(resumeCallBack: () async {
      updateRevisionSettings();
      printAndLog("Updated revision settings on foregrounding");
    }));
    updateRevisionSettings();
    initialValueSignToEntry =
        sharedPreferences.getBool(KEY_SIGN_TO_WORD) ?? true;
    initialValueEntryToSign =
        sharedPreferences.getBool(KEY_WORD_TO_SIGN) ?? true;
    numEnabledFlashcardTypes = 0;
    if (initialValueSignToEntry) {
      numEnabledFlashcardTypes += 1;
    }
    if (initialValueEntryToSign) {
      numEnabledFlashcardTypes += 1;
    }
  }

  void updateFilteredSubentries() {
    // Get lists we intend to review.
    listsToReview = sharedPreferences.getStringList(KEY_LISTS_TO_REVIEW) ??
        [KEY_FAVOURITES_ENTRIES];

    // Filter out lists that no longer exist.
    listsToReview.removeWhere(
        (element) => !entryListManager.entryLists.containsKey(element));

    // Get the entries from all these lists.
    entriesFromLists = getEntriesFromLists(listsToReview);

    // Get the subentries from all these entries.
    Map<Entry, List<SubEntry>> subEntriesToReview =
        getSubEntriesFromEntries(entriesFromLists);

    // Load up all the data needed to filter the subentries.
    List<Region> allowedRegions =
        (sharedPreferences.getStringList(KEY_FLASHCARD_REGIONS) ?? [])
            .map((i) => Region.values[int.parse(i)])
            .toList();

    bool useUnknownRegionSigns =
        sharedPreferences.getBool(KEY_USE_UNKNOWN_REGION_SIGNS) ?? true;
    bool oneCardPerEntry =
        sharedPreferences.getBool(KEY_ONE_CARD_PER_WORD) ?? false;

    // Finally get the final list of filtered subentries.
    setState(() {
      filteredSubEntries = filterSubEntries(subEntriesToReview, allowedRegions,
          useUnknownRegionSigns, oneCardPerEntry);
    });
  }

  void onPrefSwitch(String key, bool newValue,
      {bool influencesStartValidity = true}) {
    setState(() {
      sharedPreferences.setBool(key, newValue);
      if (influencesStartValidity) {
        if (newValue) {
          numEnabledFlashcardTypes += 1;
        } else {
          numEnabledFlashcardTypes -= 1;
        }
      }
    });
  }

  int getNumValidSubEntries() {
    if (filteredSubEntries.values.length == 0) {
      return 0;
    }
    if (filteredSubEntries.values.length == 1) {
      return filteredSubEntries.values.toList()[0].length;
    }
    return filteredSubEntries.values
        .map((v) => v.length)
        .reduce((a, b) => a + b);
  }

  bool startValid() {
    var revisionStrategy = loadRevisionStrategy();
    bool flashcardTypesValid = numEnabledFlashcardTypes > 0;
    bool numfilteredSubEntriesValid = getNumValidSubEntries() > 0;
    bool numCardsValid =
        getNumDueCards(dolphinInformation.dolphin, revisionStrategy) > 0;
    bool validBasedOnRevisionStrategy = true;
    return flashcardTypesValid &&
        numfilteredSubEntriesValid &&
        numCardsValid &&
        validBasedOnRevisionStrategy;
  }

  DolphinInformation getDolphin({RevisionStrategy? revisionStrategy}) {
    revisionStrategy = revisionStrategy ?? loadRevisionStrategy();
    var wordToSign = sharedPreferences.getBool(KEY_WORD_TO_SIGN) ?? true;
    var signToEntry = sharedPreferences.getBool(KEY_SIGN_TO_WORD) ?? true;
    // If they haven't selected a revision language before default to English.
    // It'd be better to get the device language but it's a pain to get access
    // to it here.
    var revisionLocale = LANGUAGE_CODE_TO_LOCALE[
            sharedPreferences.getString(KEY_REVISION_LANGUAGE_CODE)] ??
        LOCALE_ENGLISH;
    var masters =
        getMasters(revisionLocale, filteredSubEntries, wordToSign, signToEntry);
    switch (revisionStrategy) {
      case RevisionStrategy.Random:
        return getDolphinInformation(filteredSubEntries, masters);
      case RevisionStrategy.SpacedRepetition:
        if (existingReviews == null) {
          setState(() {
            existingReviews = readReviews();
          });
          printAndLog(
              "Start: Read ${existingReviews!.length} reviews from storage");
        }
        return getDolphinInformation(filteredSubEntries, masters,
            reviews: existingReviews);
    }
  }

  void updateDolphin() {
    setState(() {
      dolphinInformation = getDolphin();
    });
  }

  void updateRevisionSettings() {
    setState(() {
      updateFilteredSubentries();
      updateDolphin();
    });
  }

  @override
  Widget build(BuildContext context) {
    EdgeInsetsDirectional margin =
        EdgeInsetsDirectional.only(start: 15, end: 15, top: 10, bottom: 10);

    List<int> additionalRegionsValues =
        (sharedPreferences.getStringList(KEY_FLASHCARD_REGIONS) ?? [])
            .map((e) => int.parse(e))
            .toList();

    // TODO: What to do with this??
    String regionsString =
        AppLocalizations.of(context)!.flashcardsAllOfSriLanka;

    String additionalRegionsValuesString = additionalRegionsValues
        .map((i) => getRegionPretty(context, Region.values[i]))
        .toList()
        .join(", ");

    if (additionalRegionsValuesString.length > 0) {
      regionsString += " + " + additionalRegionsValuesString;
    }

    var revisionStrategy = loadRevisionStrategy();

    int cardsToDo =
        getNumDueCards(dolphinInformation.dolphin, revisionStrategy);
    String cardNumberString;
    switch (revisionStrategy) {
      case RevisionStrategy.Random:
        cardNumberString =
            AppLocalizations.of(context)!.nFlashcardsSelected(cardsToDo);
        break;
      case RevisionStrategy.SpacedRepetition:
        cardNumberString =
            AppLocalizations.of(context)!.nFlashcardsDue(cardsToDo);
        break;
    }
    cardNumberString = "${cardsToDo} " + cardNumberString;

    SettingsSection? sourceListSection;
    sourceListSection = SettingsSection(
        title: Padding(
            padding: EdgeInsets.only(bottom: 5),
            child: Text(
              AppLocalizations.of(context)!.flashcardsRevisionSources,
              style: TextStyle(fontSize: 16),
            )),
        tiles: [
          SettingsTile.navigation(
            title: getText(
                AppLocalizations.of(context)!.flashcardsSelectListsToRevise),
            trailing: Container(),
            onPressed: (BuildContext context) async {
              await showDialog(
                context: context,
                builder: (ctx) {
                  List<MultiSelectItem<String>> items = [];
                  for (MapEntry<String, EntryList> e
                      in entryListManager.entryLists.entries) {
                    items.add(MultiSelectItem(e.key, e.value.getName()));
                  }
                  return MultiSelectDialog<String>(
                    listType: MultiSelectListType.CHIP,
                    title: Text(
                        AppLocalizations.of(context)!.flashcardsSelectLists),
                    items: items,
                    initialValue: listsToReview,
                    onConfirm: (List<String> values) async {
                      await sharedPreferences.setStringList(
                          KEY_LISTS_TO_REVIEW, values);
                      setState(() {
                        updateRevisionSettings();
                      });
                    },
                  );
                },
              );
            },
            description: Text(
              listsToReview
                  .map((key) => EntryList.getNameFromKey(key))
                  .toList()
                  .join(", "),
              textAlign: TextAlign.center,
            ),
          ),
        ]);

    List<AbstractSettingsSection?> sections = [
      sourceListSection,
      SettingsSection(
          title: Padding(
              padding: EdgeInsets.only(bottom: 5),
              child: Text(
                AppLocalizations.of(context)!.flashcardsTypes,
                style: TextStyle(fontSize: 16),
              )),
          tiles: [
            SettingsTile.switchTile(
                title: Text(
                  AppLocalizations.of(context)!.flashcardsSignToWord,
                  style: TextStyle(fontSize: 15),
                ),
                initialValue:
                    sharedPreferences.getBool(KEY_SIGN_TO_WORD) ?? true,
                onToggle: (newValue) {
                  onPrefSwitch(KEY_SIGN_TO_WORD, newValue);
                  updateRevisionSettings();
                }),
            SettingsTile.switchTile(
                title: Text(
                  AppLocalizations.of(context)!.flashcardsWordToSign,
                  style: TextStyle(fontSize: 15),
                ),
                initialValue:
                    sharedPreferences.getBool(KEY_WORD_TO_SIGN) ?? true,
                onToggle: (newValue) {
                  onPrefSwitch(KEY_WORD_TO_SIGN, newValue);
                  updateRevisionSettings();
                }),
          ]),
      SettingsSection(
        title: Padding(
            padding: EdgeInsets.only(bottom: 5),
            child: Text(
              AppLocalizations.of(context)!.flashcardsRevisionSettings,
              style: TextStyle(fontSize: 16),
            )),
        tiles: [
          SettingsTile.navigation(
            title: getText(
                AppLocalizations.of(context)!.flashcardsSelectRevisionStrategy),
            trailing: Container(),
            onPressed: (BuildContext context) async {
              await showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    SimpleDialog dialog = SimpleDialog(
                      title: Text(
                          AppLocalizations.of(context)!.flashcardsStrategy),
                      children: RevisionStrategy.values
                          .map((e) => SimpleDialogOption(
                                child: Container(
                                  padding: EdgeInsets.all(10),
                                  child: Text(
                                    e.pretty,
                                    textAlign: TextAlign.center,
                                  ),
                                  decoration: BoxDecoration(
                                      border: Border.all(
                                          color: settingsBackgroundColor),
                                      color: settingsBackgroundColor,
                                      borderRadius: BorderRadius.circular(20)),
                                ),
                                onPressed: () async {
                                  await sharedPreferences.setInt(
                                      KEY_REVISION_STRATEGY, e.index);
                                  setState(() {
                                    updateRevisionSettings();
                                  });
                                  Navigator.of(context).pop();
                                },
                              ))
                          .toList(),
                    );
                    return dialog;
                  });
            },
            description: Text(
              revisionStrategy.pretty,
              textAlign: TextAlign.center,
            ),
          ),
          SettingsTile.navigation(
            title: getText(
                AppLocalizations.of(context)!.flashcardsSelectSignRegions),
            trailing: Container(),
            onPressed: (BuildContext context) async {
              await showDialog(
                context: context,
                builder: (ctx) {
                  return MultiSelectDialog(
                    listType: MultiSelectListType.CHIP,
                    title:
                        Text(AppLocalizations.of(context)!.flashcardsRegions),
                    items: Region.values
                        .map((e) => MultiSelectItem(
                            e.index, getRegionPretty(context, e)))
                        .toList(),
                    initialValue: additionalRegionsValues,
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
          SettingsTile.switchTile(
            title: Text(
              AppLocalizations.of(context)!.flashcardsOnlyOneCard,
              style: TextStyle(fontSize: 15),
            ),
            initialValue:
                sharedPreferences.getBool(KEY_ONE_CARD_PER_WORD) ?? false,
            onToggle: (newValue) {
              onPrefSwitch(KEY_ONE_CARD_PER_WORD, newValue,
                  influencesStartValidity: false);
              updateRevisionSettings();
            },
          )
        ],
        margin: margin,
      ),
    ];

    List<AbstractSettingsSection> nonNullSections = [];
    for (AbstractSettingsSection? section in sections) {
      if (section != null) {
        nonNullSections.add(section);
      }
    }

    Widget settings = SettingsList(
      sections: nonNullSections,
    );

    Function()? onPressedStart;
    if (startValid()) {
      onPressedStart = () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => FlashcardsPage(
                    di: dolphinInformation,
                    revisionStrategy: revisionStrategy,
                    existingReviews: existingReviews,
                  )),
        );
        setState(() {
          existingReviews = readReviews();
        });
        printAndLog(
            "Pop: Read ${existingReviews!.length} reviews from storage");
        updateRevisionSettings();
      };
    }

    Widget body = Container(
      child: Center(
          child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Padding(
              padding: EdgeInsets.only(top: 30, bottom: 10),
              child: TextButton(
                key: ValueKey("startButton"),
                child: Text(
                  AppLocalizations.of(context)!.flashcardsStart,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20),
                ),
                style: ButtonStyle(
                  backgroundColor: MaterialStateProperty.resolveWith(
                    (states) {
                      if (states.contains(MaterialState.disabled)) {
                        return Colors.grey;
                      } else {
                        return MAIN_COLOR;
                      }
                    },
                  ),
                  foregroundColor:
                      MaterialStateProperty.all<Color>(Colors.white),
                  minimumSize: MaterialStateProperty.all<Size>(Size(120, 50)),
                ),
                onPressed: onPressedStart,
              )),
          Text(
            cardNumberString,
            textAlign: TextAlign.center,
          ),
          Expanded(child: settings),
          Padding(
            padding: EdgeInsets.only(left: 35, top: 15),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                AppLocalizations.of(context)!.flashcardsRevisionLanguage,
                style: TextStyle(
                    fontSize: 16, color: Color.fromARGB(255, 100, 100, 100)),
                textAlign: TextAlign.start,
              ),
              Center(
                  child: LanguageDropdown(
                      includeDeviceDefaultOption: false,
                      initialLanguageCode: sharedPreferences
                          .getString(KEY_REVISION_LANGUAGE_CODE),
                      onChanged: (languageCode) {
                        var selectedLocale =
                            LANGUAGE_CODE_TO_LOCALE[languageCode]!;
                        sharedPreferences.setString(
                            KEY_REVISION_LANGUAGE_CODE, languageCode);
                        updateRevisionSettings();
                        return selectedLocale;
                      })),
            ]),
          )
        ],
      )),
      color: settingsBackgroundColor,
    );

    List<Widget> actions = [
      buildActionButton(
        context,
        Icon(Icons.timeline),
        () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => RevisionHistoryPage()),
          );
        },
      ),
      buildActionButton(
        context,
        Icon(Icons.help),
        () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => getFlashcardsHelpPageEn(context)),
          );
        },
      )
    ];

    return TopLevelScaffold(
        body: body,
        title: AppLocalizations.of(context)!.revisionTitle,
        actions: actions);
  }
}

class LifecycleEventHandler extends WidgetsBindingObserver {
  final AsyncCallback resumeCallBack;

  LifecycleEventHandler({
    required this.resumeCallBack,
  });

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    switch (state) {
      case AppLifecycleState.resumed:
        await resumeCallBack();
        break;
      case AppLifecycleState.hidden:
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        break;
    }
  }
}
