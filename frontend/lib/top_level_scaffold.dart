import 'package:dictionarylib/common.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dictionarylib/dictionarylib.dart' show DictLibLocalizations;

import 'common.dart';
import 'root.dart';

class TopLevelScaffold extends StatelessWidget {
  const TopLevelScaffold({
    required this.body,
    required this.title,
    this.actions,
    this.floatingActionButton,
    super.key,
  });

  /// The widget to display in the body of the Scaffold.
  final Widget body;

  /// What title to show in the top app bar.
  final String title;

  /// Actions to show in the top app bar, if any.
  final List<Widget>? actions;

  /// Floating action button to show, if any.
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    var items = <BottomNavigationBarItem>[
      BottomNavigationBarItem(
        icon: const Icon(Icons.search),
        label: DictLibLocalizations.of(context)!.searchTitle,
      ),
      BottomNavigationBarItem(
        icon: const Icon(Icons.view_list),
        label: DictLibLocalizations.of(context)!.listsTitle,
      ),
    ];

    if (getShowFlashcards()) {
      items.add(
        BottomNavigationBarItem(
          icon: const Icon(Icons.style),
          label: DictLibLocalizations.of(context)!.revisionTitle,
        ),
      );
    }

    items.add(BottomNavigationBarItem(
      icon: const Icon(Icons.settings),
      label: DictLibLocalizations.of(context)!.settingsTitle,
    ));

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: buildActionButtons(actions ?? []),
        centerTitle: true,
      ),
      body: body,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: BottomNavigationBar(
        items: items,
        currentIndex: calculateSelectedIndex(context),
        selectedItemColor: MAIN_COLOR,
        onTap: (index) => onItemTapped(index, context),
        type: BottomNavigationBarType.fixed,
      ),
    );
  }

  static int calculateSelectedIndex(BuildContext context) {
    final GoRouter route = GoRouter.of(context);
    final String location = route.location;
    final int showFlashcardsOffset = getShowFlashcards() ? 0 : 1;
    if (location.startsWith(SEARCH_ROUTE)) {
      return 0;
    }
    if (location.startsWith(LISTS_ROUTE)) {
      return 1;
    }
    if (location.startsWith(REVISION_ROUTE)) {
      return 2 - showFlashcardsOffset;
    }
    if (location.startsWith(SETTINGS_ROUTE)) {
      return 3 - showFlashcardsOffset;
    }
    return 0;
  }

  void onItemTapped(int index, BuildContext context) {
    final bool showFlashcards = getShowFlashcards();
    switch (index) {
      case 0:
        GoRouter.of(context).go(SEARCH_ROUTE);
        break;
      case 1:
        GoRouter.of(context).go(LISTS_ROUTE);
        break;
      case 2:
        if (showFlashcards) {
          GoRouter.of(context).go(REVISION_ROUTE);
        } else {
          GoRouter.of(context).go(SETTINGS_ROUTE);
        }
        break;
      case 3:
        if (showFlashcards) {
          GoRouter.of(context).go(SETTINGS_ROUTE);
        } else {
          // Also just go to the settings route, though we shouldn't get to
          // this point.
          GoRouter.of(context).go(SETTINGS_ROUTE);
        }
        break;
    }
  }
}
