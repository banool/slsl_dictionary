import 'package:dictionarylib/common.dart';
import 'package:dictionarylib/entry_types.dart';
import 'package:dictionarylib/globals.dart';
import 'package:dictionarylib/dictionarylib.dart' show DictLibLocalizations;
import 'package:dictionarylib/video_player_screen.dart';
import 'package:dots_indicator/dots_indicator.dart';
import 'package:flutter/material.dart';
import 'package:slsl_dictionary/language_dropdown.dart';

import 'common.dart';
import 'entries_types.dart';
import 'globals.dart';

class EntryPage extends StatefulWidget {
  const EntryPage(
      {super.key, required this.entry, required this.showFavouritesButton});

  final Entry entry;
  final bool showFavouritesButton;

  @override
  _EntryPageState createState() =>
      _EntryPageState(entry: entry, showFavouritesButton: showFavouritesButton);
}

class _EntryPageState extends State<EntryPage> {
  _EntryPageState({required this.entry, required this.showFavouritesButton});

  final Entry entry;
  final bool showFavouritesButton;

  int currentPage = 0;

  bool isFavourited = false;

  PlaybackSpeed playbackSpeed = PlaybackSpeed.One;

  // On the word page we let people override the language.
  Locale? localeOverride;

  @override
  void initState() {
    if (entryIsFavourited(entry)) {
      isFavourited = true;
    } else {
      isFavourited = false;
    }
    super.initState();
  }

  bool entryIsFavourited(Entry entry) {
    return userEntryListManager
        .getEntryLists()[KEY_FAVOURITES_ENTRIES]!
        .entries
        .contains(entry);
  }

  Future<void> addEntryToFavourites(Entry entry) async {
    await userEntryListManager
        .getEntryLists()[KEY_FAVOURITES_ENTRIES]!
        .addEntry(entry);
  }

  Future<void> removeEntryFromFavourites(Entry entry) async {
    await userEntryListManager
        .getEntryLists()[KEY_FAVOURITES_ENTRIES]!
        .removeEntry(entry);
  }

  void onPageChanged(int index) {
    setState(() {
      playbackSpeed = PlaybackSpeed.One;
      currentPage = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    Brightness brightness = Theme.of(context).brightness;
    Icon starIcon;
    if (isFavourited) {
      starIcon = Icon(Icons.star,
          semanticLabel:
              DictLibLocalizations.of(context)!.wordAlreadyFavourited);
    } else {
      starIcon = Icon(Icons.star_outline,
          semanticLabel:
              DictLibLocalizations.of(context)!.wordFavouriteThisWord);
    }

    List<Widget> actions = [];
    if (showFavouritesButton && getShowLists()) {
      actions.add(buildActionButton(
        context,
        starIcon,
        () async {
          setState(() {
            isFavourited = !isFavourited;
          });
          if (isFavourited) {
            await addEntryToFavourites(entry);
          } else {
            await removeEntryFromFavourites(entry);
          }
        },
      ));
    }

    actions += [
      LanguageDropdown(
          asPopUpMenu: true,
          includeDeviceDefaultOption: false,
          onChanged: (languageCode) {
            setState(() {
              localeOverride = LANGUAGE_CODE_TO_LOCALE[languageCode]!;
            });
            return localeOverride!;
          }),
      getPlaybackSpeedDropdownWidget(
        (p) {
          setState(() {
            playbackSpeed = p!;
          });
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  "${DictLibLocalizations.of(context)!.setPlaybackSpeedTo} ${getPlaybackSpeedString(p!)}"),
              backgroundColor: brightness == Brightness.light
                  ? LIGHT_MAIN_COLOR
                  : DARK_MAIN_COLOR,
              duration: const Duration(milliseconds: 1000)));
        },
      )
    ];

    // If there is no locale override just use the app-level locale.
    Locale locale = localeOverride ?? Localizations.localeOf(context);

    return InheritedPlaybackSpeed(
        playbackSpeed: playbackSpeed,
        child: Localizations.override(
            context: context,
            locale: locale,
            child: Builder(builder: (context) {
              var phrase = entry.getPhrase(locale) ??
                  DictLibLocalizations.of(context)!.wordDataMissing;
              return Scaffold(
                  appBar: AppBar(
                      title: Text(phrase),
                      actions: buildActionButtons(actions)),
                  body: Column(children: [
                    Expanded(
                        child: PageView.builder(
                            itemCount: entry.getSubEntries().length,
                            itemBuilder: (context, index) => SubEntryPage(
                                  entry: entry,
                                  subEntry: entry.getSubEntries()[index],
                                ),
                            onPageChanged: onPageChanged)),
                    Padding(
                      padding: const EdgeInsets.only(top: 5, bottom: 15),
                      child: DotsIndicator(
                        dotsCount: entry.getSubEntries().length,
                        position: currentPage.toDouble(),
                        decorator: DotsDecorator(
                          activeColor: brightness == Brightness.light
                              ? LIGHT_MAIN_COLOR
                              : DARK_MAIN_COLOR,
                        ),
                      ),
                    ),
                  ]));
            })));
  }
}

Widget? getRelatedEntriesWidget(
    BuildContext context, SubEntry subEntry, bool shouldUseHorizontalDisplay) {
  return getInnerRelatedEntriesWidget(
      context: context,
      subEntry: subEntry,
      shouldUseHorizontalDisplay: shouldUseHorizontalDisplay,
      getRelatedEntry: (keyword) {
        Entry? relatedEntry;
        if (keyedByEnglishEntriesGlobal.containsKey(keyword)) {
          relatedEntry = keyedByEnglishEntriesGlobal[keyword];
        } else if (keyedByTamilEntriesGlobal.containsKey(keyword)) {
          relatedEntry = keyedByTamilEntriesGlobal[keyword];
        } else if (keyedBySinhalaEntriesGlobal.containsKey(keyword)) {
          relatedEntry = keyedBySinhalaEntriesGlobal[keyword];
        }
        return relatedEntry;
      },
      navigateToEntryPage: (context, entry, showFavouritesButton) =>
          navigateToEntryPage(context, entry, showFavouritesButton));
}

Widget getRegionalInformationWidget(
    BuildContext context, SubEntry subEntry, bool shouldUseHorizontalDisplay,
    {bool hide = false}) {
  String regionsStr =
      subEntry.getRegions().map((r) => getRegionPretty(context, r)).join(", ");
  if (hide) {
    regionsStr = "";
  }
  if (shouldUseHorizontalDisplay) {
    return Padding(
        padding: const EdgeInsets.only(top: 15.0),
        child: Text(
          regionsStr,
          textAlign: TextAlign.center,
        ));
  } else {
    return Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
            padding: const EdgeInsets.only(top: 15.0),
            child: Text(
              regionsStr,
              textAlign: TextAlign.center,
            )));
  }
}

class SubEntryPage extends StatefulWidget {
  const SubEntryPage({
    super.key,
    required this.entry,
    required this.subEntry,
  });

  final Entry entry;
  final SubEntry subEntry;

  @override
  _SubEntryPageState createState() =>
      _SubEntryPageState(entry: entry, subEntry: subEntry);
}

class _SubEntryPageState extends State<SubEntryPage> {
  _SubEntryPageState({required this.entry, required this.subEntry});

  final Entry entry;
  final SubEntry subEntry;

  @override
  Widget build(BuildContext context) {
    Locale locale = Localizations.localeOf(context);

    var videoPlayerScreen = VideoPlayerScreen(
      mediaLinks: subEntry.getMedia(),
      fallbackAspectRatio: 16 / 12,
    );
    // If the display is wide enough, show the video beside the entries instead
    // of above the entries (as well as other layout changes).
    var shouldUseHorizontalDisplay = getShouldUseHorizontalLayout(context);

    Widget? relatedWordsWidget =
        getRelatedEntriesWidget(context, subEntry, shouldUseHorizontalDisplay);
    Widget regionalInformationWidget = getRegionalInformationWidget(
        context, subEntry, shouldUseHorizontalDisplay);

    if (!shouldUseHorizontalDisplay) {
      List<Widget> children = [];
      children.add(videoPlayerScreen);
      if (relatedWordsWidget != null) {
        children.add(Center(child: relatedWordsWidget));
      }
      children.add(Expanded(
        child: Definitions(
            context, subEntry.getDefinitions(locale) as List<Definition>),
      ));
      children.add(regionalInformationWidget);
      return Column(
        mainAxisAlignment: MainAxisAlignment.start,
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      );
    } else {
      var size = MediaQuery.of(context).size;
      var screenWidth = size.width;
      var screenHeight = size.height;
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            videoPlayerScreen,
            regionalInformationWidget,
          ]),
          LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
            // TODO Make this less janky and hardcoded.
            // The issue is the parent has infinite width and height
            // and Expanded doesn't seem to be working.
            List<Widget> children = [];
            if (relatedWordsWidget != null) {
              children.add(relatedWordsWidget);
            }
            children.add(Expanded(
                child: Definitions(context,
                    subEntry.getDefinitions(locale) as List<Definition>)));
            return ConstrainedBox(
                constraints: BoxConstraints(
                    maxWidth: screenWidth * 0.4, maxHeight: screenHeight * 0.7),
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: children));
          })
        ],
      );
    }
  }
}

Widget Definitions(BuildContext context, List<Definition> definitions) {
  if (definitions.isEmpty) {
    return Center(
        child: Text(
      DictLibLocalizations.of(context)!.wordNoDefinitions,
      textAlign: TextAlign.center,
    ));
  }
  return ListView.builder(
    itemCount: definitions.length,
    itemBuilder: (context, index) {
      return definition(context, definitions[index]);
    },
  );
}

Widget definition(BuildContext context, Definition definition) {
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
