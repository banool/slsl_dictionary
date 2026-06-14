import 'package:dictionarylib/common.dart';
import 'package:dictionarylib/entry_list.dart';
import 'package:dictionarylib/entry_types.dart';
import 'package:dictionarylib/globals.dart';
import 'package:dictionarylib/lists_service.dart';
import 'package:dictionarylib/save_video_sheet.dart';
import 'package:dictionarylib/saved_video.dart';
import 'package:dictionarylib/dictionarylib.dart' show DictLibLocalizations;
import 'package:dictionarylib/video_player_screen.dart';
import 'package:dots_indicator/dots_indicator.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:slsl_dictionary/language_dropdown.dart';

import 'common.dart';
import 'entries_types.dart';
import 'globals.dart';

class EntryPage extends StatefulWidget {
  const EntryPage({
    super.key,
    required this.entry,
    required this.showFavouritesButton,
    this.focusVideo,
    this.saveToList,
  });

  final Entry entry;

  /// Whether to render the per-video save button. Named `showFavouritesButton`
  /// for source-compat with the pre-per-video-saves callers — it's no longer a
  /// favourites star but a per-video bookmark that opens the all-lists picker.
  final bool showFavouritesButton;

  /// If supplied, the page lands on the sub-entry + video matching this saved
  /// video (used by the list view's tap-to-jump flow).
  final SavedVideo? focusVideo;

  /// If supplied, the save button toggles membership of this one list directly
  /// instead of opening the picker (the list-edit "add videos" flow).
  final EntryList? saveToList;

  @override
  State<EntryPage> createState() => _EntryPageState();
}

class _EntryPageState extends State<EntryPage> {
  int currentPage = 0;

  /// Within-sub-entry video index to land on when [EntryPage.focusVideo] points
  /// into the first-shown sub-entry. Null otherwise.
  int? _focusedVideoInitialIndex;

  PlaybackSpeed playbackSpeed = PlaybackSpeed.One;

  // On the word page we let people override the displayed language.
  Locale? localeOverride;

  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _applyFocusVideo();
    _pageController = PageController(initialPage: currentPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _applyFocusVideo() {
    final focus = widget.focusVideo;
    if (focus == null) return;
    final subEntries = widget.entry.getSubEntries();
    for (var i = 0; i < subEntries.length; i++) {
      final idx = subEntries[i].getMedia().indexOf(focus.mediaPath);
      if (idx >= 0) {
        currentPage = i;
        _focusedVideoInitialIndex = idx;
        return;
      }
    }
  }

  void onPageChanged(int index) {
    setState(() {
      playbackSpeed = PlaybackSpeed.One;
      currentPage = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> actions = [
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
          showSnack(
              context,
              "${DictLibLocalizations.of(context)!.setPlaybackSpeedTo} ${getPlaybackSpeedString(p!)}",
              duration: const Duration(milliseconds: 1000));
        },
        current: playbackSpeed,
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
              var phrase = widget.entry.getPhrase(locale) ??
                  DictLibLocalizations.of(context)!.wordDataMissing;
              final subEntries = widget.entry.getSubEntries();
              return Scaffold(
                  appBar: AppBar(
                      title: Text(phrase),
                      actions: buildActionButtons(actions)),
                  body: Column(children: [
                    Expanded(
                        child: PageView.builder(
                            controller: _pageController,
                            itemCount: subEntries.length,
                            itemBuilder: (context, index) => SubEntryPage(
                                  entry: widget.entry,
                                  subEntry: subEntries[index],
                                  initialVideoIndex: index == currentPage
                                      ? _focusedVideoInitialIndex
                                      : null,
                                  // No saving on web (no account there).
                                  showSaveButton:
                                      widget.showFavouritesButton && !kIsWeb,
                                  saveToList: widget.saveToList,
                                ),
                            onPageChanged: onPageChanged)),
                    Padding(
                      padding: const EdgeInsets.only(top: 5, bottom: 15),
                      child: DotsIndicator(
                        dotsCount: subEntries.length,
                        position: currentPage.toDouble(),
                        decorator: DotsDecorator(
                          activeColor: Theme.of(context).colorScheme.primary,
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
      navigateToEntryPage: navigateToEntryPage);
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
    this.initialVideoIndex,
    this.showSaveButton = true,
    this.saveToList,
  });

  final Entry entry;
  final SubEntry subEntry;

  /// Within-sub-entry video index to land on (first build only).
  final int? initialVideoIndex;

  /// Whether to render the per-video bookmark button.
  final bool showSaveButton;

  /// When set, the bookmark toggles membership of this one list directly.
  final EntryList? saveToList;

  @override
  _SubEntryPageState createState() => _SubEntryPageState();
}

class _SubEntryPageState extends State<SubEntryPage>
    with AutomaticKeepAliveClientMixin {
  late int _currentVideo;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _currentVideo = widget.initialVideoIndex ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    // Required by AutomaticKeepAliveClientMixin.
    super.build(context);
    Locale locale = Localizations.localeOf(context);

    // getMedia() returns paths (the saved-video identity); resolve each to a
    // playable URL. VideoPlayerScreen handles both videos (.mp4) and images
    // (.jpg).
    final paths = widget.subEntry.getMedia();
    var videoPlayerScreen = VideoPlayerScreen(
      mediaLinks: paths.map(mediaUrlForPath).toList(),
      fallbackAspectRatio: 16 / 12,
      initialPage: paths.isEmpty ? 0 : _currentVideo.clamp(0, paths.length - 1),
      onPageChanged: (index) {
        if (index != _currentVideo) setState(() => _currentVideo = index);
      },
    );

    Widget? bookmarkRow;
    if (widget.showSaveButton && getShowLists() && paths.isNotEmpty) {
      final path = paths[_currentVideo.clamp(0, paths.length - 1)];
      bookmarkRow = _BookmarkButton(
        key: const ValueKey('wordPage.saveButton'),
        entry: widget.entry,
        mediaPath: path,
        saveToList: widget.saveToList,
      );
    }

    // If the display is wide enough, show the video beside the entries instead
    // of above the entries (as well as other layout changes).
    var shouldUseHorizontalDisplay = getShouldUseHorizontalLayout(context);

    Widget? relatedWordsWidget =
        getRelatedEntriesWidget(context, widget.subEntry, shouldUseHorizontalDisplay);
    Widget regionalInformationWidget = getRegionalInformationWidget(
        context, widget.subEntry, shouldUseHorizontalDisplay);

    if (!shouldUseHorizontalDisplay) {
      List<Widget> children = [];
      // Loose Flexible: the video keeps its natural size when there's room, but
      // yields height under pressure (e.g. a short transition frame during a
      // route pop) so the column — video + bookmark + definitions + region —
      // never overflows. Definitions below is the Expanded that takes the slack.
      children.add(Flexible(child: videoPlayerScreen));
      if (bookmarkRow != null) {
        children.add(bookmarkRow);
      }
      if (relatedWordsWidget != null) {
        children.add(Center(child: relatedWordsWidget));
      }
      children.add(Expanded(
        child: Definitions(
            context, widget.subEntry.getDefinitions(locale) as List<Definition>),
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
            if (bookmarkRow != null) bookmarkRow,
            regionalInformationWidget,
          ]),
          LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
            // TODO Make this less janky and hardcoded.
            List<Widget> children = [];
            if (relatedWordsWidget != null) {
              children.add(relatedWordsWidget);
            }
            children.add(Expanded(
                child: Definitions(context,
                    widget.subEntry.getDefinitions(locale) as List<Definition>)));
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

/// Per-video save toggle rendered beneath the video player. Owns its own state
/// so swiping to a new video — or toggling the picker sheet — repaints just
/// this button rather than the whole entry page.
class _BookmarkButton extends StatefulWidget {
  final Entry entry;

  /// The media **path** (stable identity) of the video this button saves.
  final String mediaPath;

  /// When set, the button toggles this video's membership in [saveToList]
  /// directly; when null it opens the all-lists picker sheet.
  final EntryList? saveToList;

  const _BookmarkButton({
    super.key,
    required this.entry,
    required this.mediaPath,
    this.saveToList,
  });

  @override
  State<_BookmarkButton> createState() => _BookmarkButtonState();
}

class _BookmarkButtonState extends State<_BookmarkButton> {
  @override
  Widget build(BuildContext context) {
    final v = SavedVideo(
        entryKey: widget.entry.getKey(), mediaPath: widget.mediaPath);
    final l = DictLibLocalizations.of(context)!;

    // Direct mode: came from a specific list, so just toggle membership of it.
    final target = widget.saveToList;
    if (target != null) {
      final saved = target.containsVideo(v);
      final messenger = ScaffoldMessenger.of(context);
      Future<void> toggle() async {
        try {
          if (saved) {
            await target.removeVideo(v);
          } else {
            await target.addVideo(v);
          }
        } catch (e) {
          printAndLog("Failed to toggle video in list ${target.key}: $e");
          if (mounted) {
            showSnackVia(messenger, l.saveVideoFailed);
          }
        }
        if (mounted) setState(() {});
      }

      final name = target.getName(context);
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: SizedBox(
          width: double.infinity,
          child: saved
              ? FilledButton.icon(
                  onPressed: toggle,
                  icon: const Icon(Icons.bookmark, size: 20),
                  label: Text(l.savedToNamedList(name)),
                )
              : OutlinedButton.icon(
                  onPressed: toggle,
                  icon: const Icon(Icons.bookmark_border, size: 20),
                  label: Text(l.saveToNamedList(name)),
                ),
        ),
      );
    }

    // Picker mode: count against the same set the save sheet shows.
    var savedCount = 0;
    for (final list in listsService.writableLists) {
      if (list.containsVideo(v)) savedCount++;
    }
    final saved = savedCount > 0;

    Future<void> openSheet() async {
      await showSaveVideoSheet(context, video: v);
      if (mounted) setState(() {});
    }

    final label = saved ? l.savedToListCount(savedCount) : l.saveVideoButton;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: SizedBox(
        width: double.infinity,
        child: saved
            ? FilledButton.icon(
                onPressed: openSheet,
                icon: const Icon(Icons.bookmark, size: 20),
                label: Text(label),
              )
            : OutlinedButton.icon(
                onPressed: openSheet,
                icon: const Icon(Icons.bookmark_border, size: 20),
                label: Text(label),
              ),
      ),
    );
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
