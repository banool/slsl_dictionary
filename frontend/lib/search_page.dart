import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'advisories.dart';
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

  String? searchTerm;

  final _searchFieldController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (initialQuery != null) {
      searchTerm = initialQuery;
      _searchFieldController.text = initialQuery!;
      search(initialQuery!, getEntryTypes());
    }
  }

  void search(String searchTerm, List<EntryType> entryTypes) {
    setState(() {
      entriesSearched =
          searchList(context, searchTerm, entryTypes, entriesGlobal, {});
    });
  }

  void clearSearch() {
    setState(() {
      searchTerm = null;
      entriesSearched = [];
      _searchFieldController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (advisoriesResponse != null &&
        advisoriesResponse!.newAdvisories &&
        !advisoryShownOnce) {
      Future.delayed(
          Duration(milliseconds: 500), () => showAdvisoryDialog(context));
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
                padding:
                    EdgeInsets.only(bottom: 10, left: 32, right: 10, top: 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Form(
                        key: ValueKey("searchPage.searchForm"),
                        child: TextField(
                          controller: _searchFieldController,
                          decoration: InputDecoration(
                            hintText:
                                AppLocalizations.of(context).searchHintText,
                            suffixIcon: IconButton(
                              onPressed: () {
                                clearSearch();
                              },
                              icon: Icon(Icons.clear),
                            ),
                          ),
                          // The validator receives the text that the user has entered.
                          onChanged: (String value) {
                            setState(() {
                              searchTerm = value;
                            });
                            search(value, getEntryTypes());
                          },
                          autofocus: true,
                          textInputAction: TextInputAction.search,
                          keyboardType: TextInputType.visiblePassword,
                          autocorrect: false,
                        ),
                      ),
                    ),
                    Padding(
                        padding: EdgeInsets.only(left: 4),
                        child: EntryTypeMultiPopUpMenu(
                            onChanged: (_entryTypes) async {
                          for (EntryType type in EntryType.values) {
                            var key;
                            if (type == EntryType.WORD) {
                              key = KEY_SEARCH_FOR_WORDS;
                            } else {
                              key = KEY_SEARCH_FOR_PHRASES;
                            }
                            // It would be best to wait for this to complete but
                            // given this generally happens lightning fast I'll
                            // leave it as a todo.
                            if (_entryTypes.contains(type)) {
                              await sharedPreferences.setBool(key, true);
                            } else {
                              await sharedPreferences.setBool(key, false);
                            }
                            setState(() {
                              if (searchTerm != null) {
                                search(searchTerm!, getEntryTypes());
                              }
                            });
                          }
                        })),
                  ],
                )),
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
          showAdvisoryDialog(context);
        },
      ));
    }

    return TopLevelScaffold(
        body: body,
        title: AppLocalizations.of(context).searchTitle,
        actions: actions);
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

// This widget lets users select which entry types they want to see.
class EntryTypeMultiPopUpMenu extends StatefulWidget {
  final Future<void> Function(List<EntryType>) onChanged;

  const EntryTypeMultiPopUpMenu({Key? key, required this.onChanged})
      : super(key: key);

  @override
  EntryTypeMultiPopUpMenuState createState() => EntryTypeMultiPopUpMenuState();
}

class EntryTypeMultiPopUpMenuState extends State<EntryTypeMultiPopUpMenu> {
  List<EntryType> _selectedEntryTypes = [];

  @override
  void initState() {
    super.initState();
    _selectedEntryTypes = getEntryTypes();
  }

  Future<void> _showDialog(BuildContext context) async {
    await showDialog(
        context: context,
        builder: (BuildContext context) {
          return StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: Text(AppLocalizations.of(context).entrySelectEntryTypes),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: EntryType.values
                    .map((entryType) => CheckboxListTile(
                          title: Text(getEntryTypePretty(context, entryType)),
                          value: _selectedEntryTypes.contains(entryType),
                          onChanged: (bool? value) {
                            setState(() {
                              if (value == true) {
                                setState(() {
                                  _selectedEntryTypes.add(entryType);
                                });
                              } else {
                                // Ensure at least one entry type is selected.
                                if (_selectedEntryTypes.length == 1) {
                                  return;
                                }
                                setState(() {
                                  _selectedEntryTypes.remove(entryType);
                                });
                              }
                            });
                          },
                        ))
                    .toList(),
              ),
            );
          });
        });
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.filter_list),
      onPressed: () async {
        await _showDialog(context);
        await widget.onChanged(_selectedEntryTypes);
      },
    );
  }
}

List<EntryType> getEntryTypes() {
  List<EntryType> entryTypes = [];
  if (sharedPreferences.getBool(KEY_SEARCH_FOR_WORDS) ?? true) {
    entryTypes.add(EntryType.WORD);
  }
  if (sharedPreferences.getBool(KEY_SEARCH_FOR_PHRASES) ?? false) {
    entryTypes.add(EntryType.PHRASE);
  }
  return entryTypes;
}
