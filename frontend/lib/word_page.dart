import 'package:dots_indicator/dots_indicator.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import 'common.dart';
import 'entries_types.dart';
import 'globals.dart';
import 'video_player_screen.dart';

class EntryPage extends StatefulWidget {
  EntryPage({Key? key, required this.entry, required this.showFavouritesButton})
      : super(key: key);

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
    return entryListManager.entryLists[KEY_FAVOURITES_ENTRIES]!.entries
        .contains(entry);
  }

  Future<void> addEntryToFavourites(Entry entry) async {
    await entryListManager.entryLists[KEY_FAVOURITES_ENTRIES]!.addEntry(entry);
  }

  Future<void> removeEntryFromFavourites(Entry entry) async {
    await entryListManager.entryLists[KEY_FAVOURITES_ENTRIES]!
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
    List<Widget> pages = [];
    for (int i = 0; i < entry.getSubEntries().length; i++) {
      SubEntry subEntry = entry.getSubEntries()[i];
      SubEntryPage subEntryPage = SubEntryPage(
        entry: entry,
        subEntry: subEntry,
      );
      pages.add(subEntryPage);
    }

    Icon starIcon;
    if (isFavourited) {
      starIcon = Icon(Icons.star,
          semanticLabel: AppLocalizations.of(context).wordAlreadyFavourited);
    } else {
      starIcon = Icon(Icons.star_outline,
          semanticLabel: AppLocalizations.of(context).wordFavouriteThisWord);
    }

    List<Widget> actions = [];
    if (showFavouritesButton) {
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
      /*
      getSwitchLanguageAppBarActionWidget((p0) {
        // todo, switch the stuff we're showing in the entry
        // don't change the app language though
      }),
      */
      getPlaybackSpeedDropdownWidget(
        (p) {
          setState(() {
            playbackSpeed = p!;
          });
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  "${AppLocalizations.of(context).setPlaybackSpeedTo} ${getPlaybackSpeedString(p!)}"),
              backgroundColor: MAIN_COLOR,
              duration: Duration(milliseconds: 1000)));
        },
      )
    ];

    // TODO: Make this overridable on the page.
    Locale currentLocale = Localizations.localeOf(context);

    return InheritedPlaybackSpeed(
        playbackSpeed: playbackSpeed,
        child: Scaffold(
          appBar: AppBar(
              // TODO: Handle when this is null.
              title: Text(entry.getPhrase(currentLocale)!),
              actions: buildActionButtons(actions)),
          bottomNavigationBar: Padding(
            padding: EdgeInsets.only(top: 5, bottom: 10),
            child: DotsIndicator(
              dotsCount: entry.getSubEntries().length,
              position: currentPage,
              decorator: DotsDecorator(
                color: Colors.black, // Inactive color
                activeColor: MAIN_COLOR,
              ),
            ),
          ),
          body: Center(
              child: PageView.builder(
                  itemCount: entry.getSubEntries().length,
                  itemBuilder: (context, index) => SubEntryPage(
                        entry: entry,
                        subEntry: entry.getSubEntries()[index],
                      ),
                  onPageChanged: onPageChanged)),
        ));
  }
}

Widget? getRelatedEntriesWidget(
    BuildContext context, SubEntry subEntry, bool shouldUseHorizontalDisplay) {
  int numRelatedWords = subEntry.getRelatedWords().length;
  if (numRelatedWords == 0) {
    return null;
  }

  List<TextSpan> textSpans = [];

  int idx = 0;
  for (String relatedWord in subEntry.getRelatedWords()) {
    Color color;
    void Function()? navFunction;
    Entry? relatedEntry;
    if (keyedEntriesGlobal.containsKey(relatedWord)) {
      relatedEntry = keyedEntriesGlobal[relatedWord];
      color = MAIN_COLOR;
      navFunction = () => navigateToEntryPage(context, relatedEntry!);
    } else {
      relatedEntry = null;
      color = Colors.black;
      navFunction = null;
    }
    String suffix;
    if (idx < numRelatedWords - 1) {
      suffix = ", ";
    } else {
      suffix = "";
    }
    textSpans.add(TextSpan(
      text: "$relatedWord$suffix",
      style: TextStyle(color: color),
      recognizer: TapGestureRecognizer()..onTap = navFunction,
    ));
    idx += 1;
  }

  var initial = TextSpan(
      text: "${AppLocalizations.of(context).relatedWords}: ",
      style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold));
  textSpans = [initial] + textSpans;
  var richText = RichText(
    text: TextSpan(children: textSpans),
    textAlign: TextAlign.center,
  );

  if (shouldUseHorizontalDisplay) {
    return Padding(
        padding: EdgeInsets.only(left: 10.0, right: 20.0, top: 5.0),
        child: richText);
  } else {
    return Padding(
        padding: EdgeInsets.only(left: 20.0, right: 20.0, top: 15.0),
        child: richText);
  }
}

Widget getRegionalInformationWidget(
    SubEntry subEntry, bool shouldUseHorizontalDisplay,
    {bool hide = false}) {
  String regionsStr = subEntry.getRegions().map((r) => r.pretty).join(", ");
  if (hide) {
    regionsStr = "";
  }
  if (shouldUseHorizontalDisplay) {
    return Padding(
        padding: EdgeInsets.only(top: 15.0),
        child: Text(
          regionsStr,
          textAlign: TextAlign.center,
        ));
  } else {
    return Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
            padding: EdgeInsets.only(top: 15.0),
            child: Text(
              regionsStr,
              textAlign: TextAlign.center,
            )));
  }
}

class SubEntryPage extends StatefulWidget {
  SubEntryPage({
    Key? key,
    required this.entry,
    required this.subEntry,
  }) : super(key: key);

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
    // TODO: Make this overridable on the page.
    Locale currentLocale = Localizations.localeOf(context);

    var videoPlayerScreen = VideoPlayerScreen(
      videoLinks: subEntry.getVideos(),
    );
    // If the display is wide enough, show the video beside the entries instead
    // of above the entries (as well as other layout changes).
    var shouldUseHorizontalDisplay = getShouldUseHorizontalLayout(context);

    Widget? keyentriesWidget =
        getRelatedEntriesWidget(context, subEntry, shouldUseHorizontalDisplay);
    Widget regionalInformationWidget =
        getRegionalInformationWidget(subEntry, shouldUseHorizontalDisplay);

    if (!shouldUseHorizontalDisplay) {
      List<Widget> children = [];
      children.add(videoPlayerScreen);
      if (keyentriesWidget != null) {
        children.add(keyentriesWidget);
      }
      children.add(Expanded(
        child: definitions(context, subEntry.getDefinitions(currentLocale)),
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
          new LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
            // TODO Make this less janky and hardcoded.
            // The issue is the parent has infinite width and height
            // and Expanded doesn't seem to be working.
            List<Widget> children = [];
            if (keyentriesWidget != null) {
              children.add(keyentriesWidget);
            }
            children.add(Expanded(
                child: definitions(
                    context, subEntry.getDefinitions(currentLocale))));
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

Widget definitions(BuildContext context, List<Definition> definitions) {
  return ListView.builder(
    itemCount: definitions.length,
    itemBuilder: (context, index) {
      return definition(context, definitions[index]);
    },
  );
}

Widget definition(BuildContext context, Definition definition) {
  return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 15.0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          definition.categoryPretty,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        Padding(
            padding: EdgeInsets.only(left: 10.0, top: 8.0),
            child: Text(definition.definition))
      ]));
}
