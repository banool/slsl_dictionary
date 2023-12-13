import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:slsl_dictionary/entries_types.dart';

import 'common.dart';
import 'flashcards_landing_page.dart';
import 'search_page.dart';
import 'settings_page.dart';
import 'word_list_overview_page.dart';

const SEARCH_ROUTE = "/search";
const LISTS_ROUTE = "/lists";
const REVISION_ROUTE = "/revision";
const SETTINGS_ROUTE = "/settings";

final GlobalKey<NavigatorState> rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');

late Locale systemLocale;

class RootApp extends StatefulWidget {
  RootApp({required this.startingLocale});

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
              String? initialQuery = state.queryParams["query"];
              bool navigateToFirstMatch =
                  state.queryParams["navigate_to_first_match"] == "true";
              return NoTransitionPage(
                  // https://stackoverflow.com/a/73458529/3846032
                  key: UniqueKey(),
                  child: SearchPage(
                    initialQuery: initialQuery,
                    navigateToFirstMatch: navigateToFirstMatch,
                  ));
            }),
        GoRoute(
            path: LISTS_ROUTE,
            pageBuilder: (BuildContext context, GoRouterState state) {
              return NoTransitionPage(child: EntryListsOverviewPage());
            }),
        GoRoute(
            path: REVISION_ROUTE,
            pageBuilder: (BuildContext context, GoRouterState state) {
              return NoTransitionPage(child: FlashcardsLandingPage());
            }),
        GoRoute(
            path: SETTINGS_ROUTE,
            pageBuilder: (BuildContext context, GoRouterState state) {
              return NoTransitionPage(child: SettingsPage());
            }),
      ]);

  @override
  Widget build(BuildContext context) {
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
          onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: LANGUAGE_CODE_TO_LOCALE.values,
          locale: locale,
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
              appBarTheme: AppBarTheme(
                backgroundColor: MAIN_COLOR,
                foregroundColor: Colors.white,
                actionsIconTheme: IconThemeData(color: Colors.white),
                iconTheme: IconThemeData(color: Colors.white),
              ),
              primarySwatch: MAIN_COLOR,
              visualDensity: VisualDensity.adaptivePlatformDensity,
              // Make swiping to pop back the navigation work.
              pageTransitionsTheme: PageTransitionsTheme(builders: {
                TargetPlatform.android: CupertinoPageTransitionsBuilder(),
                TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
              })),
          routerConfig: router,
        ));
  }
}
