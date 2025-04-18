import 'package:dictionarylib/common.dart';
import 'package:dictionarylib/entry_types.dart';
import 'package:dictionarylib/globals.dart';
import 'package:dictionarylib/page_entry_list.dart';
import 'package:dictionarylib/page_entry_list_overview.dart';
import 'package:dictionarylib/page_flashcards_landing.dart';
import 'package:dictionarylib/page_search.dart';
import 'package:dictionarylib/page_settings.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dictionarylib/dictionarylib.dart' show DictLibLocalizations;

// import 'l10n/app_localizations.dart' show AppLocalizations;
import 'common.dart';
import 'flashcards_landing_page.dart';
import 'language_dropdown.dart';
import 'legal_information.dart';

const SEARCH_ROUTE = "/search";
const LISTS_ROUTE = "/lists";
const REVISION_ROUTE = "/revision";
const SETTINGS_ROUTE = "/settings";

late Locale systemLocale;

class RootApp extends StatefulWidget {
  const RootApp({super.key, required this.startingLocale});

  final Locale startingLocale;

  @override
  _RootAppState createState() => _RootAppState(locale: startingLocale);

  static void applyLocaleOverride(BuildContext context, Locale newLocale) {
    _RootAppState state = context.findAncestorStateOfType<_RootAppState>()!;

    state.setState(() {
      state.locale = newLocale;
    });
  }

  static void clearLocaleOverride(BuildContext context) {
    _RootAppState state = context.findAncestorStateOfType<_RootAppState>()!;

    state.setState(() {
      state.locale = systemLocale;
    });
  }
}

class _RootAppState extends State<RootApp> {
  _RootAppState({required this.locale});

  Locale locale;

  @override
  void initState() {
    super.initState();
    locale = widget.startingLocale;
    themeNotifier.value = ThemeMode.values[
        sharedPreferences.getInt(KEY_THEME_MODE) ?? ThemeMode.light.index];
  }

  final GoRouter router = GoRouter(
      navigatorKey: rootNavigatorKey,
      initialLocation: SEARCH_ROUTE,
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
            path: SETTINGS_ROUTE,
            pageBuilder: (BuildContext context, GoRouterState state) {
              bool showPrivacyPolicy =
                  state.uri.queryParameters["showPrivacyPolicy"] == "true";
              return NoTransitionPage(
                  child: SettingsPage(
                showPrivacyPolicy: showPrivacyPolicy,
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
                iOSAppId: IOS_APP_ID,
                androidAppId: ANDROID_APP_ID,
              ));
            }),
      ]);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
        valueListenable: themeNotifier,
        builder: (context, themeMode, child) {
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
                // AppLocalizations.delegate,
                onGenerateTitle: (context) => getAppTitle(locale),
                localizationsDelegates:
                    DictLibLocalizations.localizationsDelegates,
                //
                // localizationsDelegates: const [
                //   DictLibLocalizations.delegate,
                // ],
                supportedLocales: LANGUAGE_CODE_TO_LOCALE.values,
                locale: locale,
                debugShowCheckedModeBanner: false,
                themeMode: themeMode,
                theme: ThemeData(
                  colorScheme: ColorScheme.fromSeed(
                    seedColor: LIGHT_MAIN_COLOR,
                    brightness: Brightness.light,
                  ),
                  appBarTheme: const AppBarTheme(
                    backgroundColor: LIGHT_MAIN_COLOR,
                    foregroundColor: Colors.white,
                    elevation: 0,
                  ),
                  scaffoldBackgroundColor: Colors.white,
                  cardTheme: CardTheme(
                    color: Colors.white,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  typography: Typography.material2021(
                      colorScheme: ColorScheme.fromSeed(
                          seedColor: LIGHT_MAIN_COLOR,
                          brightness: Brightness.light)),
                  textButtonTheme: TextButtonThemeData(
                    style: ButtonStyle(
                      foregroundColor: WidgetStatePropertyAll(Colors.black),
                    ),
                  ),
                  iconButtonTheme: IconButtonThemeData(
                    style: ButtonStyle(
                      foregroundColor: WidgetStateProperty.resolveWith<Color>(
                        (Set<WidgetState> states) =>
                            states.contains(WidgetState.disabled)
                                ? Colors.black38
                                : Colors.black,
                      ),
                    ),
                  ),
                  // Update InputDecoration theme for search field underline and placeholder
                  inputDecorationTheme: const InputDecorationTheme(
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: LIGHT_MAIN_COLOR),
                    ),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: LIGHT_MAIN_COLOR),
                    ),
                    hintStyle: TextStyle(color: Colors.black54),
                  ),
                  // Update TabBar theme
                  tabBarTheme: TabBarTheme(
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white,
                    labelStyle: TextStyle(
                      fontSize: 16.0,
                      fontWeight: FontWeight.bold,
                    ),
                    unselectedLabelStyle: TextStyle(
                      fontSize: 16.0,
                    ),
                  ),
                  snackBarTheme: SnackBarThemeData(
                    backgroundColor: LIGHT_MAIN_COLOR,
                    contentTextStyle: TextStyle(color: Colors.white),
                  ),
                  // Update BottomNavigationBar theme
                  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
                    selectedItemColor: LIGHT_MAIN_COLOR,
                    unselectedItemColor: Colors.grey,
                    backgroundColor: Colors.white,
                  ),
                  visualDensity: VisualDensity.adaptivePlatformDensity,
                  pageTransitionsTheme: const PageTransitionsTheme(builders: {
                    TargetPlatform.android: CupertinoPageTransitionsBuilder(),
                    TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
                  }),
                ),
                darkTheme: ThemeData(
                  colorScheme: ColorScheme.fromSeed(
                    seedColor: DARK_MAIN_COLOR,
                    brightness: Brightness.dark,
                  ),
                  appBarTheme: const AppBarTheme(
                    backgroundColor: Color(0xFF1F1F1F),
                    foregroundColor: Colors.white,
                    elevation: 0,
                  ),
                  scaffoldBackgroundColor: const Color(0xFF121212),
                  cardTheme: CardTheme(
                    color: const Color(0xFF2C2C2C),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  typography: Typography.material2021(
                      colorScheme: ColorScheme.fromSeed(
                          seedColor: DARK_MAIN_COLOR,
                          brightness: Brightness.dark)),
                  // Update TextButton theme
                  textButtonTheme: TextButtonThemeData(
                    style: ButtonStyle(
                      foregroundColor: WidgetStatePropertyAll(Colors.white),
                    ),
                  ),
                  iconButtonTheme: IconButtonThemeData(
                    style: ButtonStyle(
                      foregroundColor: WidgetStateProperty.resolveWith<Color>(
                        (Set<WidgetState> states) =>
                            states.contains(WidgetState.disabled)
                                ? Colors.white24
                                : Colors.white,
                      ),
                    ),
                  ),
                  // Update InputDecoration theme for search field underline and placeholder
                  inputDecorationTheme: const InputDecorationTheme(
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: DARK_MAIN_COLOR),
                    ),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: DARK_MAIN_COLOR),
                    ),
                    hintStyle: TextStyle(color: Colors.white60),
                  ),
                  // Update TabBar theme
                  tabBarTheme: TabBarTheme(
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white,
                    labelStyle: TextStyle(
                      fontSize: 16.0,
                      fontWeight: FontWeight.bold,
                    ),
                    unselectedLabelStyle: TextStyle(
                      fontSize: 16.0,
                    ),
                  ),
                  snackBarTheme: SnackBarThemeData(
                    backgroundColor: DARK_MAIN_COLOR,
                    contentTextStyle: TextStyle(color: Colors.white),
                  ),
                  // Update BottomNavigationBar theme
                  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
                    selectedItemColor: Colors.white,
                    unselectedItemColor: Colors.grey,
                    backgroundColor: Color(0xFF121212),
                  ),
                  visualDensity: VisualDensity.adaptivePlatformDensity,
                  pageTransitionsTheme: const PageTransitionsTheme(builders: {
                    TargetPlatform.android: CupertinoPageTransitionsBuilder(),
                    TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
                  }),
                ),
                routerConfig: router,
              ));
        });
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
