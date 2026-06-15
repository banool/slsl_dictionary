import 'package:dictionarylib/common.dart';
import 'package:dictionarylib/entry_list.dart';
import 'package:dictionarylib/entry_types.dart';
import 'package:dictionarylib/globals.dart';
import 'package:dictionarylib/hearth.dart';
import 'package:dictionarylib/lists_service.dart';
import 'package:dictionarylib/save_video_sheet.dart';
import 'package:dictionarylib/saved_video.dart';
import 'package:dictionarylib/dictionarylib.dart' show DictLibLocalizations;
import 'package:dictionarylib/video_player_screen.dart';
import 'package:dictionarylib/web_drag_scroll_behavior.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
    this.initialVariation,
    this.initialVideo,
  });

  final Entry entry;

  /// Whether to render the per-video save UI. Named `showFavouritesButton`
  /// for source-compat with the pre-per-video-saves callers — the button is no
  /// longer a favourites star; it's a per-video bookmark that opens the
  /// all-lists picker.
  final bool showFavouritesButton;

  /// If supplied, the page lands on the sub-entry containing this video and
  /// starts the sub-entry's video carousel on that video (the list view's
  /// tap-to-jump flow).
  final SavedVideo? focusVideo;

  /// If supplied, the per-video save button adds the video straight to this
  /// list (toggling membership) instead of opening the all-lists picker.
  final EntryList? saveToList;

  /// Deep-link starting position from the URL (`?variation=N&video=M`). Used only
  /// on first build, and only when [focusVideo] isn't driving the initial
  /// position instead. Null when absent.
  final int? initialVariation;
  final int? initialVideo;

  @override
  State<EntryPage> createState() => _EntryPageState();
}

class _EntryPageState extends State<EntryPage> {
  int currentPage = 0;

  /// Within-sub-entry video index used when first building the focused
  /// sub-entry. Null when [EntryPage.focusVideo] is unset or its path isn't in
  /// the entry's data. After first build, per-sub-entry video position is owned
  /// by [SubEntryPage]'s own state (kept alive across sub-entry swipes).
  int? _focusedVideoInitialIndex;

  PlaybackSpeed playbackSpeed = PlaybackSpeed.One;

  /// On the word page we let people override the displayed language.
  Locale? localeOverride;

  /// Created once in [initState] (not per build) so it isn't recreated on every
  /// rebuild and an in-progress swipe isn't interrupted.
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _applyFocusVideo();
    // No jump-to-video focus? Honour the deep-link position from the URL.
    if (widget.focusVideo == null) {
      final subEntries = widget.entry.getSubEntries();
      if (widget.initialVariation != null && subEntries.isNotEmpty) {
        currentPage = widget.initialVariation!.clamp(0, subEntries.length - 1);
      }
      if (widget.initialVideo != null) {
        _focusedVideoInitialIndex = widget.initialVideo;
      }
    }
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
    // Don't reset the playback speed: a user-chosen speed should survive swiping
    // between sub-entries. Flipping currentPage flips each SubEntryPage's
    // isActive flag, which pauses the now-offscreen sub-entry's video and
    // resumes the newly-visible one.
    setState(() {
      currentPage = index;
    });
    _syncUrlToVariation(index);
  }

  /// Reflect the current sub-entry in the URL so the entry stays deep-linkable
  /// as you swipe. Web only — a no-op route update on mobile the user never
  /// sees. Re-passes [EntryPageArgs] so the page's non-URL state (focused video,
  /// save target, save-button flag) survives the in-place replace; the route's
  /// stable page key keeps the carousel from resetting.
  void _syncUrlToVariation(int variation) {
    if (!kIsWeb) return;
    final key = Uri.encodeComponent(widget.entry.getKey());
    final loc = variation == 0
        ? "$WORD_ROUTE/$key"
        : "$WORD_ROUTE/$key?variation=$variation";
    GoRouter.of(context).replace(
      loc,
      extra: EntryPageArgs(
        showFavouritesButton: widget.showFavouritesButton,
        focusVideo: widget.focusVideo,
        saveToList: widget.saveToList,
      ),
    );
  }

  /// On web, allow a mouse to drag the variation pager. Native is unchanged.
  Widget _maybeWebDrag(Widget child) {
    if (!kIsWeb) return child;
    return ScrollConfiguration(
        behavior: const WebDragScrollBehavior(), child: child);
  }

  @override
  Widget build(BuildContext context) {
    // If there is no locale override just use the app-level locale.
    final locale = localeOverride ?? Localizations.localeOf(context);

    return InheritedPlaybackSpeed(
        playbackSpeed: playbackSpeed,
        child: Localizations.override(
            context: context,
            locale: locale,
            child: Builder(builder: (context) {
              final subEntries = widget.entry.getSubEntries();
              final phrase = widget.entry.getPhrase(locale) ??
                  DictLibLocalizations.of(context)!.wordDataMissing;

              final actions = <Widget>[
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
                    showSnack(context,
                        "${DictLibLocalizations.of(context)!.setPlaybackSpeedTo} ${getPlaybackSpeedString(p!)}",
                        duration: const Duration(milliseconds: 1000));
                  },
                  current: playbackSpeed,
                ),
              ];

              return Scaffold(
                appBar: AppBar(
                  title: Text(phrase),
                  actions: buildActionButtons(actions),
                  // A cold-start web deep link to /word/<key> is the navigation
                  // root with nothing to pop back to; give it an explicit way
                  // back to search. Normal in-app navigation keeps the default
                  // back arrow.
                  leading: kIsWeb && !Navigator.of(context).canPop()
                      ? IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () => context.go('/'),
                        )
                      : null,
                ),
                body: _maybeWebDrag(PageView.builder(
                  controller: _pageController,
                  itemCount: subEntries.length,
                  itemBuilder: (context, index) => SubEntryPage(
                    entry: widget.entry,
                    subEntry: subEntries[index],
                    subEntryIndex: index,
                    subEntryCount: subEntries.length,
                    initialVideoIndex:
                        index == currentPage ? _focusedVideoInitialIndex : null,
                    // No saving on web (no account / favourites there).
                    showSaveButton: widget.showFavouritesButton && !kIsWeb,
                    saveToList: widget.saveToList,
                    // Only the on-screen sub-entry's video should play; kept-alive
                    // off-screen pages pause via this flag.
                    isActive: index == currentPage,
                    // Web-only nav arrows beside the variation label (no swipe
                    // affordance there); null on native so they never render.
                    onPrevVariation: kIsWeb
                        ? () => _pageController.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut)
                        : null,
                    onNextVariation: kIsWeb
                        ? () => _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut)
                        : null,
                  ),
                  onPageChanged: onPageChanged,
                )),
              );
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
  return Padding(
    padding: const EdgeInsets.only(top: 15.0),
    child: Text(regionsStr, textAlign: TextAlign.center),
  );
}

class SubEntryPage extends StatefulWidget {
  const SubEntryPage({
    super.key,
    required this.entry,
    required this.subEntry,
    this.subEntryIndex = 0,
    this.subEntryCount = 1,
    this.initialVideoIndex,
    this.showSaveButton = true,
    this.saveToList,
    this.isActive = true,
    this.onPrevVariation,
    this.onNextVariation,
  });

  final Entry entry;
  final SubEntry subEntry;

  /// This sub-entry's position among the entry's variations, for the dots.
  final int subEntryIndex;
  final int subEntryCount;

  /// Within-sub-entry video index to land on (first build only).
  final int? initialVideoIndex;

  /// Whether to render the per-video bookmark button.
  final bool showSaveButton;

  /// When set, the bookmark toggles membership of this one list directly.
  final EntryList? saveToList;

  /// Whether this sub-entry is the one currently on screen. Forwarded to
  /// [VideoPlayerScreen] so off-screen kept-alive pages pause their video.
  final bool isActive;

  /// Web-only: move to the previous / next variation. These drive the arrows
  /// flanking the variation label, since web has no touch-swipe affordance.
  /// Null on native (you swipe there), so the arrows never render on mobile.
  final VoidCallback? onPrevVariation;
  final VoidCallback? onNextVariation;

  @override
  SubEntryPageState createState() => SubEntryPageState();
}

class SubEntryPageState extends State<SubEntryPage>
    with AutomaticKeepAliveClientMixin {
  late int _currentVideo;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _currentVideo = widget.initialVideoIndex ?? 0;
  }

  void _onVideoChanged(int index) {
    if (index == _currentVideo) return;
    setState(() => _currentVideo = index);
  }

  /// Inner tier: which video *within* this variation you're on. Subdued, muted
  /// dots directly under the video. Null when there's only one recording —
  /// unless [reserveSpace] is set, in which case a single-recording page gets an
  /// invisible, same-height placeholder so the video and save button sit at
  /// exactly the same spot as on multi-video pages instead of shifting.
  Widget? _videoIndicator(BuildContext context, {bool reserveSpace = false}) {
    final videoCount = widget.subEntry.getMedia().length;
    if (videoCount == 0 || (videoCount == 1 && !reserveSpace)) return null;
    final cs = Theme.of(context).colorScheme;
    final l = DictLibLocalizations.of(context)!;
    final currentVideo = _currentVideo.clamp(0, videoCount - 1);
    final indicator = Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 2),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            HearthDots(
              count: videoCount,
              index: currentVideo,
              size: 5,
              activeColor: cs.onSurfaceVariant,
            ),
            const SizedBox(height: 5),
            Text(
              l.videoIndicator(currentVideo + 1, videoCount),
              style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
    if (videoCount == 1) {
      return Visibility(
        visible: false,
        maintainSize: true,
        maintainAnimation: true,
        maintainState: true,
        child: indicator,
      );
    }
    return indicator;
  }

  /// Outer tier: which variation of the word you're on. Prominent clay dots + a
  /// "Variation n of m · swipe to compare" label. On web the label is flanked
  /// by prev/next arrows (no touch swipe affordance there).
  Widget? _variationIndicator(BuildContext context) {
    if (widget.subEntryCount <= 1) return null;
    final cs = Theme.of(context).colorScheme;
    final l = DictLibLocalizations.of(context)!;
    final label = Text(
      l.wordVariationWithHint(widget.subEntryIndex + 1, widget.subEntryCount),
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant),
    );
    final Widget labelRow = kIsWeb
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Disabled at the ends for a clear "can't go further" cue.
              _variationArrow(context, Icons.chevron_left,
                  widget.subEntryIndex > 0 ? widget.onPrevVariation : null),
              Flexible(child: label),
              _variationArrow(
                  context,
                  Icons.chevron_right,
                  widget.subEntryIndex < widget.subEntryCount - 1
                      ? widget.onNextVariation
                      : null),
            ],
          )
        : label;
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 18),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            HearthDots(
                count: widget.subEntryCount, index: widget.subEntryIndex),
            const SizedBox(height: 8),
            labelRow,
          ],
        ),
      ),
    );
  }

  /// Web-only compact arrow beside the variation label. `onTap` is null at the
  /// first/last variation, which disables (greys out) the button.
  Widget _variationArrow(
      BuildContext context, IconData icon, VoidCallback? onTap) {
    final cs = Theme.of(context).colorScheme;
    final l = DictLibLocalizations.of(context)!;
    return IconButton(
      icon: Icon(icon),
      iconSize: 20,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      color: cs.onSurfaceVariant,
      onPressed: onTap,
      tooltip:
          icon == Icons.chevron_left ? l.variationPrevious : l.variationNext,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final locale = Localizations.localeOf(context);

    // getMedia() returns paths (the saved-video identity); resolve each to a
    // playable URL. Tapping the video expands it over a dimmed backdrop
    // (handled inside VideoPlayerScreen); image (.jpg) recordings are skipped.
    final tappableVideo = VideoPlayerScreen(
      mediaLinks: widget.subEntry.getMedia().map(mediaUrlForPath).toList(),
      fallbackAspectRatio: 16 / 12,
      initialPage: _currentVideo,
      onPageChanged: _onVideoChanged,
      expandOnTap: true,
      isActive: widget.isActive,
    );

    Widget? bookmarkRow;
    final paths = widget.subEntry.getMedia();
    if (widget.showSaveButton && getShowLists() && paths.isNotEmpty) {
      final path = paths[_currentVideo.clamp(0, paths.length - 1)];
      bookmarkRow = _BookmarkButton(
          key: const ValueKey('wordPage.saveButton'),
          entry: widget.entry,
          mediaPath: path,
          saveToList: widget.saveToList);
    }

    final shouldUseHorizontalDisplay = getShouldUseHorizontalLayout(context);
    final relatedWordsWidget = getRelatedEntriesWidget(
        context, widget.subEntry, shouldUseHorizontalDisplay);
    final regionalInformationWidget = getRegionalInformationWidget(
        context, widget.subEntry, shouldUseHorizontalDisplay);
    final videoIndicator = _videoIndicator(context);
    final variationIndicator = _variationIndicator(context);
    final definitionsWidget = Definitions(
        context, widget.subEntry.getDefinitions(locale) as List<Definition>);

    if (!shouldUseHorizontalDisplay) {
      final children = <Widget>[];
      // Loose Flexible: the video keeps its natural size when there's room but
      // yields under pressure (e.g. a short transition frame during a route
      // pop) so the column never overflows. Definitions below is the Expanded.
      children.add(Flexible(child: tappableVideo));
      if (bookmarkRow != null) children.add(bookmarkRow);
      if (videoIndicator != null) children.add(videoIndicator);
      if (relatedWordsWidget != null) {
        children.add(Center(child: relatedWordsWidget));
      }
      children.add(Expanded(child: definitionsWidget));
      children.add(regionalInformationWidget);
      if (variationIndicator != null) children.add(variationIndicator);
      return Column(
        mainAxisAlignment: MainAxisAlignment.start,
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      );
    } else {
      // Landscape / wide: video (with the save button + video dots under it, in
      // the same order as the vertical layout) on the left; the definitions,
      // "see also", region and variation indicator in a scrollable panel on the
      // right so nothing is clipped. The indicator slot reserves its height even
      // for single-video pages so the video and save button don't shift.
      final videoIndicatorSlot = _videoIndicator(context, reserveSpace: true);
      return SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 5,
              child: LayoutBuilder(builder: (context, pane) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: ConstrainedBox(
                        constraints:
                            BoxConstraints(maxHeight: pane.maxWidth * 12 / 16),
                        child: tappableVideo,
                      ),
                    ),
                    if (bookmarkRow != null) bookmarkRow,
                    if (videoIndicatorSlot != null) videoIndicatorSlot,
                  ],
                );
              }),
            ),
            Expanded(
              flex: 4,
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 12),
                children: [
                  if (relatedWordsWidget != null)
                    Center(child: relatedWordsWidget),
                  ...widget.subEntry
                      .getDefinitions(locale)
                      .cast<Definition>()
                      .map((d) => definition(context, d)),
                  regionalInformationWidget,
                  if (variationIndicator != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Center(child: variationIndicator),
                    ),
                ],
              ),
            ),
          ],
        ),
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
