import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'common.dart';
import 'entries_types.dart';
import 'globals.dart';
import 'top_level_scaffold.dart';

class SearchPage extends StatefulWidget {
  final String? initialQuery;
  final bool? navigateToFirstMatch;

  SearchPage({Key? key, this.initialQuery, this.navigateToFirstMatch})
      : super(key: key);

  @override
  _SearchPageState createState() => _SearchPageState(
      initialQuery: initialQuery, navigateToFirstMatch: navigateToFirstMatch);
}

class _SearchPageState extends State<SearchPage> {
  // This will only ever be set if this page was opened via a deeplink.
  final String? initialQuery;

  // If this is set we'll navigate to the first match immediately upon load.
  final bool? navigateToFirstMatch;

  _SearchPageState({this.initialQuery, this.navigateToFirstMatch});

  List<Entry?> entriesSearched = [];
  int currentNavBarIndex = 0;

  final _searchFieldController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (initialQuery != null) {
      _searchFieldController.text = initialQuery!;
      search(initialQuery!);
    }
  }

  void search(String searchTerm) {
    setState(() {
      entriesSearched = searchList(context, searchTerm, entriesGlobal, {});
    });
  }

  void clearSearch() {
    setState(() {
      entriesSearched = [];
      _searchFieldController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (advisoriesResponse != null &&
        advisoriesResponse!.newAdvisories &&
        !advisoryShownOnce) {
      Future.delayed(Duration(milliseconds: 500), () => showAdvisoryDialog());
      advisoryShownOnce = true;
    }

    // Navigate to the first match if words have been searched and the page
    // was built with that setting enabled.
    if (navigateToFirstMatch ?? false) {
      if (entriesSearched.length > 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          print(
              "Navigating to first match because navigateToFirstMatch was set");
          navigateToEntryPage(context, entriesSearched[0]!);
        });
      }
    }

    Widget body = Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 0.0, vertical: 8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          mainAxisSize: MainAxisSize.max,
          children: [
            Padding(
              padding: EdgeInsets.only(bottom: 10, left: 32, right: 32, top: 0),
              child: Form(
                  key: ValueKey("searchPage.searchForm"),
                  child: Column(children: <Widget>[
                    TextField(
                      controller: _searchFieldController,
                      decoration: InputDecoration(
                        hintText: AppLocalizations.of(context).searchHintText,
                        suffixIcon: IconButton(
                          onPressed: () {
                            clearSearch();
                          },
                          icon: Icon(Icons.clear),
                        ),
                      ),
                      // The validator receives the text that the user has entered.
                      onChanged: (String value) {
                        search(value);
                      },
                      autofocus: true,
                      textInputAction: TextInputAction.search,
                      keyboardType: TextInputType.visiblePassword,
                      autocorrect: false,
                    ),
                  ])),
            ),
            new Expanded(
              child: Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: listWidget(context, entriesSearched)),
            ),
          ],
        ),
      ),
    );

    List<Widget> actions = [];
    if (advisoriesResponse != null) {
      actions.add(buildActionButton(
        context,
        Icon(Icons.article),
        () async {
          showAdvisoryDialog();
        },
      ));
    }

    return TopLevelScaffold(
        body: body,
        title: AppLocalizations.of(context).searchTitle,
        actions: actions);
  }

  void showAdvisoryDialog() {
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
              title: Text(AppLocalizations.of(context).newsTitle),
              content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: advisoriesResponse!.advisories
                      .map((e) => Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  e.date,
                                  textAlign: TextAlign.start,
                                ),
                                e.asMarkdown()
                              ]))
                      .toList()),
            ));
  }
}

Widget listWidget(BuildContext context, List<Entry?> entriesSearched) {
  return ListView.builder(
    itemCount: entriesSearched.length,
    itemBuilder: (context, index) {
      return ListTile(title: listItem(context, entriesSearched[index]!));
    },
  );
}

Widget listItem(BuildContext context, Entry entry) {
  Locale currentLocale = Localizations.localeOf(context);
  return TextButton(
    child: Align(
        alignment: Alignment.topLeft,
        child: Text("${entry.getPhrase(currentLocale)}",
            style: TextStyle(color: Colors.black))),
    onPressed: () => navigateToEntryPage(context, entry),
  );
}
