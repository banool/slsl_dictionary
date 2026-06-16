import 'dart:async';

import 'package:dictionarylib/common.dart';
import 'package:dictionarylib/entry_types.dart';
import 'package:dictionarylib/globals.dart';
import 'package:dictionarylib/page_entry_list.dart';
import 'package:dictionarylib/page_entry_list_overview.dart';
import 'package:dictionarylib/page_flashcards_landing.dart';
import 'package:dictionarylib/page_search.dart';
import 'package:dictionarylib/page_settings.dart';
import 'package:dictionarylib/page_word.dart';
import 'package:dictionarylib/sharing/deep_link_handler.dart';
import 'package:dictionarylib/sharing/engine_notification_listener.dart';
import 'package:dictionarylib/sharing/shared_list_landing_page.dart';
import 'package:dictionarylib/sharing/sync_engine.dart' show SyncNotification;
import 'package:dictionarylib/theme.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dictionarylib/dictionarylib.dart' show DictLibLocalizations;

import 'common.dart';
import 'flashcards_landing_page.dart';
import 'language_dropdown.dart';
import 'legal_information.dart';
import 'word_page.dart';

const SEARCH_ROUTE = "/search";
const LISTS_ROUTE = "/lists";
const REVISION_ROUTE = "/revision";
const SETTINGS_ROUTE = "/settings";

// Debug-only launch overrides for testing a specific screen / theme without
// hand-editing this file. Set via --dart-define, default to empty when absent,
// and ignored entirely outside debug builds. Mirror auslan_dictionary's hooks.
// Examples:
//   flutter run --dart-define=DEBUG_INITIAL_LOCATION='/search?query=mother&navigate_to_first_match=true'
//   flutter run --dart-define=DEBUG_THEME_VARIANT=classic --dart-define=DEBUG_THEME_MODE=dark
const String _kDebugInitialLocation =
    String.fromEnvironment('DEBUG_INITIAL_LOCATION');
const String _kDebugThemeVariant =
    String.fromEnvironment('DEBUG_THEME_VARIANT');
const String _kDebugThemeMode = String.fromEnvironment('DEBUG_THEME_MODE');

// Defaults to English so anything that reads it before main() assigns the real
// device locale (e.g. the language dropdown in widget/integration tests that
// pump RootApp without going through main()) doesn't hit a LateInitializationError.
Locale systemLocale = LOCALE_ENGLISH;

class RootApp extends StatefulWidget {
  const RootApp({super.key, required this.startingLocale});

  final Locale startingLocale;

  @override
  _RootAppState createState() => _RootAppState(locale: startingLocale);

  static void applyLocaleOverride(BuildContext context, Locale newLocale) {
    _RootAppState state = context.findAncestorStateOfType<_RootAppState>()!;
    state._setLocale(newLocale);
  }

  static void clearLocaleOverride(BuildContext context) {
    _RootAppState state = context.findAncestorStateOfType<_RootAppState>()!;
    state._setLocale(systemLocale);
  }
}

class _RootAppState extends State<RootApp> {
  _RootAppState({required this.locale});

  Locale locale;

  void _setLocale(Locale newLocale) {
    setState(() {
      locale = newLocale;
    });
  }

  StreamSubscription<SharePayload>? _deepLinkSub;
  StreamSubscription<SyncNotification>? _engineNotificationSub;

  @override
  void initState() {
    super.initState();
    locale = widget.startingLocale;
    // Default to following the OS light/dark setting until the user pins one.
    themeNotifier.value = ThemeMode
        .values[sharedPreferences.getInt(KEY_THEME_MODE) ?? DEFAULT_THEME_MODE];
    // Which visual style (Hearth / Classic). The picker lives in dictionarylib's
    // SettingsPage and writes KEY_THEME_VARIANT + this notifier.
    themeVariantNotifier.value =
        appThemeVariantFromName(sharedPreferences.getString(KEY_THEME_VARIANT));
    // Debug-only theme overrides (see _kDebug* consts above). No-ops in release
    // and when the corresponding --dart-define isn't set.
    if (kDebugMode && _kDebugThemeMode.isNotEmpty) {
      themeNotifier.value =
          _kDebugThemeMode == 'dark' ? ThemeMode.dark : ThemeMode.light;
    }
    if (kDebugMode && _kDebugThemeVariant.isNotEmpty) {
      themeVariantNotifier.value = appThemeVariantFromName(_kDebugThemeVariant);
    }
    // Forward incoming share deep-links to the share landing route, carrying
    // the invite token through as a query parameter when present. `push` (not
    // `go`) so the current screen stays underneath as something to pop back to.
    _deepLinkSub = sharing.deepLinks.payloads.listen((payload) {
      router.push(payload.toRouteLocation());
    });
    // Surface the sync engine's one-shot events (session expired, removed as
    // editor, snapshot catch-up) as snackbars from any page.
    if (sharing.isEnabled) {
      _engineNotificationSub = installEngineNotificationSnackbars();
    }
  }

  @override
  void dispose() {
    _deepLinkSub?.cancel();
    _engineNotificationSub?.cancel();
    super.dispose();
  }

  final GoRouter router = GoRouter(
      navigatorKey: rootNavigatorKey,
      initialLocation: kDebugMode && _kDebugInitialLocation.isNotEmpty
          ? _kDebugInitialLocation
          : SEARCH_ROUTE,
      routes: [
        GoRoute(
          path: "/",
          redirect: (context, state) => SEARCH_ROUTE,
        ),
        GoRoute(
            path: SEARCH_ROUTE,
            pageBuilder: (BuildContext context, GoRouterState state) {
              String? initialQuery = state.uri.queryParameters["query"];
              bool navigateToFirstMatch =
                  state.uri.queryParameters["navigate_to_first_match"] ==
                      "true";
              return NoTransitionPage(
                  // https://stackoverflow.com/a/73458529/3846032
                  key: UniqueKey(),
                  child: SearchPage(
                    navigateToEntryPage: navigateToEntryPage,
                    initialQuery: initialQuery,
                    navigateToFirstMatch: navigateToFirstMatch,
                    includeEntryTypeButton: true,
                  ));
            }),
        GoRoute(
            path: LISTS_ROUTE,
            pageBuilder: (BuildContext context, GoRouterState state) {
              return NoTransitionPage(
                child: EntryListsOverviewPage(
                  buildEntryListWidgetCallback: (entryList) => EntryListPage(
                    entryList: entryList,
                    navigateToEntryPage: navigateToEntryPage,
                  ),
                ),
              );
            }),
        GoRoute(
            path: REVISION_ROUTE,
            pageBuilder: (BuildContext context, GoRouterState state) {
              var controller = MyFlashcardsLandingPageController();
              return NoTransitionPage(
                  child: FlashcardsLandingPage(
                controller: controller,
              ));
            }),
        GoRoute(
            path: '/share/:listId',
            pageBuilder: (BuildContext context, GoRouterState state) {
              final id = state.pathParameters['listId']!;
              final invite = state.uri.queryParameters['invite'];
              return NoTransitionPage(
                // Stable key per (listId, invite) so re-tapping the same share
                // link doesn't tear down + rebuild the page (re-triggering
                // subscribe / sign-in); distinct links still get fresh pages.
                key: ValueKey('share-$id-${invite ?? ''}'),
                child: SharedListLandingPage(
                  listId: id,
                  inviteToken:
                      invite != null && invite.isNotEmpty ? invite : null,
                  navigateToEntryPage: navigateToEntryPage,
                ),
              );
            }),
        GoRoute(
            path: SETTINGS_ROUTE,
            pageBuilder: (BuildContext context, GoRouterState state) {
              return NoTransitionPage(
                  child: SettingsPage(
                appName: APP_NAME,
                additionalTopWidgets: [
                  Padding(
                    padding: const EdgeInsets.only(left: 35, top: 15),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DictLibLocalizations.of(context)!.settingsLanguage,
                            style: const TextStyle(
                                fontSize: 13,
                                color: Color.fromARGB(255, 100, 100, 100)),
                            textAlign: TextAlign.start,
                          ),
                          const Center(child: LanguageDropdown()),
                        ]),
                  ),
                ],
                buildLegalInformationChildren: buildLegalInformationChildren,
                reportDataProblemUrl:
                    'https://github.com/banool/slsl_dictionary/issues/new/choose',
                reportAppProblemUrl:
                    'https://github.com/banool/slsl_dictionary/issues',
                privacyPolicyUrl:
                    'https://landing.srilankansignlanguage.org/privacy.html',
                termsOfServiceUrl:
                    'https://landing.srilankansignlanguage.org/terms.html',
                iOSAppId: IOS_APP_ID,
                androidAppId: ANDROID_APP_ID,
              ));
            }),
        GoRoute(
            path: "$WORD_ROUTE/:key",
            pageBuilder: (BuildContext context, GoRouterState state) {
              final key = Uri.decodeComponent(state.pathParameters['key']!);
              final entry = keyedByEnglishEntriesGlobal[key];
              // Unknown / not-yet-loaded word (a stale or hand-typed /word/<x>
              // URL) → fall back to search rather than a broken page.
              if (entry == null) {
                return NoTransitionPage(
                  child: SearchPage(
                    navigateToEntryPage: navigateToEntryPage,
                    includeEntryTypeButton: true,
                  ),
                );
              }
              final args = state.extra is EntryPageArgs
                  ? state.extra as EntryPageArgs
                  : null;
              return NoTransitionPage(
                // Stable key per entry so updating only the ?variation/?video
                // query as the user swipes preserves the page's state instead of
                // tearing it down and rebuilding (which resets the carousel).
                key: ValueKey('word-$key'),
                child: EntryPage(
                  entry: entry,
                  config: slslWordPageConfig,
                  showFavouritesButton: args?.showFavouritesButton ?? true,
                  focusVideo: args?.focusVideo,
                  saveToList: args?.saveToList,
                  initialVariation: int.tryParse(
                      state.uri.queryParameters['variation'] ?? ''),
                  initialVideo:
                      int.tryParse(state.uri.queryParameters['video'] ?? ''),
                ),
              );
            }),
      ]);

  @override
  Widget build(BuildContext context) {
    // Outer listener: the light/dark mode. Inner listener: which visual style
    // ("theme variant", Hearth or Classic). Both themes are built by the shared
    // library so all the theming lives in one place; Classic is seeded from the
    // SLSL orange.
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, themeMode, child) {
        return ValueListenableBuilder<AppThemeVariant>(
          valueListenable: themeVariantNotifier,
          builder: (context, themeVariant, child) {
            return GestureDetector(
                onTap: () {
                  FocusScopeNode currentFocus = FocusScope.of(context);
                  if (!currentFocus.hasPrimaryFocus &&
                      currentFocus.focusedChild != null) {
                    FocusManager.instance.primaryFocus!.unfocus();
                  }
                },
                child: MaterialApp.router(
                  title: APP_NAME,
                  // I set appTitle manually for now due to this issue:
                  // https://stackoverflow.com/q/77759180/3846032
                  onGenerateTitle: (context) => getAppTitle(locale),
                  scaffoldMessengerKey: rootScaffoldMessengerKey,
                  localizationsDelegates:
                      DictLibLocalizations.localizationsDelegates,
                  supportedLocales: LANGUAGE_CODE_TO_LOCALE.values,
                  locale: locale,
                  debugShowCheckedModeBanner: false,
                  themeMode: themeMode,
                  theme: buildAppTheme(
                    variant: themeVariant,
                    brightness: Brightness.light,
                    classicSeed: LIGHT_MAIN_COLOR,
                  ),
                  darkTheme: buildAppTheme(
                    variant: themeVariant,
                    brightness: Brightness.dark,
                    classicSeed: LIGHT_MAIN_COLOR,
                  ),
                  routerConfig: router,
                ));
          },
        );
      },
    );
  }
}

// See comment above onGenerateTitle for an explanation for why we have this.
String getAppTitle(Locale locale) {
  if (locale.languageCode.startsWith("en")) {
    return "SLSL Dictionary";
  } else if (locale.languageCode.startsWith("si")) {
    return "සිංහල ශබ්දකෝෂය";
  } else if (locale.languageCode.startsWith("ta")) {
    return "இலங்கை சைகை மொழி அகராதி";
  } else {
    throw Exception("Unsupported locale for title: $locale");
  }
}
