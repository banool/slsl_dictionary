import 'package:dictionarylib/common.dart';
import 'package:dictionarylib/entry_list.dart';
import 'package:dictionarylib/entry_types.dart';
import 'package:dictionarylib/globals.dart';
import 'package:dictionarylib/page_entry_list_help_en.dart';
import 'package:flutter/material.dart';
import 'package:dictionarylib/dictionarylib.dart' show AppLocalizations;

import 'common.dart';

class EntryListPage extends StatefulWidget {
  final EntryList entryList;

  const EntryListPage({super.key, required this.entryList});

  @override
  _EntryListPageState createState() =>
      _EntryListPageState(entryList: entryList);
}

class _EntryListPageState extends State<EntryListPage> {
  _EntryListPageState({required this.entryList});

  EntryList entryList;

  // The entries that match the user's search term.
  late List<Entry> entriesSearched;

  bool viewSortedList = false;
  bool enableSortButton = true;
  bool inEditMode = false;

  String currentSearchTerm = "";

  final textFieldFocus = FocusNode();
  final _searchFieldController = TextEditingController();

  @override
  void initState() {
    entriesSearched = List.from(entryList.entries);
    super.initState();
  }

  void toggleSort() {
    setState(() {
      viewSortedList = !viewSortedList;
      search();
    });
  }

  Color getFloatingActionButtonColor() {
    return enableSortButton ? MAIN_COLOR : Colors.grey;
  }

  void updateCurrentSearchTerm(String term) {
    setState(() {
      currentSearchTerm = term;
      enableSortButton = currentSearchTerm.isEmpty;
    });
  }

  void search() {
    setState(() {
      if (currentSearchTerm.isNotEmpty) {
        if (inEditMode) {
          Set<Entry> entriesGlobalWithoutEntriesAlreadyInList =
              entriesGlobal.difference(entryList.entries);
          entriesSearched = searchList(context, currentSearchTerm,
              EntryType.values, entriesGlobalWithoutEntriesAlreadyInList, {});
        } else {
          entriesSearched = searchList(context, currentSearchTerm,
              EntryType.values, entryList.entries, entryList.entries);
        }
      } else {
        entriesSearched = List.from(entryList.entries);
        if (viewSortedList) {
          entriesSearched.sort();
        }
      }
    });
  }

  void clearSearch() {
    setState(() {
      entriesSearched = [];
      _searchFieldController.clear();
      updateCurrentSearchTerm("");
      search();
    });
  }

  Future<void> addEntry(Entry entry) async {
    await entryList.addEntry(entry);
    setState(() {
      search();
    });
  }

  Future<void> removeEntry(Entry entry) async {
    await entryList.removeEntry(entry);
    setState(() {
      search();
    });
  }

  Future<void> refreshEntries() async {
    setState(() {
      search();
    });
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> actions = [
      buildActionButton(
        context,
        inEditMode ? const Icon(Icons.edit) : const Icon(Icons.edit_outlined),
        () async {
          setState(() {
            inEditMode = !inEditMode;
            if (!inEditMode) {
              clearSearch();
            }
            search();
          });
        },
        APP_BAR_DISABLED_COLOR,
      ),
      buildActionButton(
        context,
        const Icon(Icons.help),
        () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => getEntryListHelpPageEn()),
          );
        },
        APP_BAR_DISABLED_COLOR,
      ),
    ];

    String listName = entryList.getName();

    FloatingActionButton? floatingActionButton = FloatingActionButton(
        backgroundColor: getFloatingActionButtonColor(),
        onPressed: () {
          if (!enableSortButton) {
            return;
          }
          toggleSort();
        },
        child: const Icon(Icons.sort));

    String hintText;
    if (inEditMode) {
      hintText = AppLocalizations.of(context)!.listSearchAdd;
      bool keyboardIsShowing = MediaQuery.of(context).viewInsets.bottom > 0;
      if (currentSearchTerm.isNotEmpty || keyboardIsShowing) {
        floatingActionButton = null;
      } else {
        floatingActionButton = FloatingActionButton(
            backgroundColor: Colors.green,
            onPressed: () {
              textFieldFocus.requestFocus();
            },
            child: const Icon(Icons.add));
      }
    } else {
      hintText = "${AppLocalizations.of(context)!.listSearchPrefix} $listName";
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(entryList.getName()),
        centerTitle: true,
        actions: buildActionButtons(actions),
      ),
      floatingActionButton: floatingActionButton,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 0.0, vertical: 8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          mainAxisSize: MainAxisSize.max,
          children: [
            Padding(
              padding: const EdgeInsets.only(
                  bottom: 10, left: 32, right: 32, top: 0),
              child: Form(
                  child: Column(children: <Widget>[
                TextField(
                  controller: _searchFieldController,
                  focusNode: textFieldFocus,
                  decoration: InputDecoration(
                    hintText: hintText,
                    suffixIcon: IconButton(
                      onPressed: () {
                        clearSearch();
                      },
                      icon: const Icon(Icons.clear),
                    ),
                  ),
                  // The validator receives the text that the user has entered.
                  onChanged: (String value) {
                    updateCurrentSearchTerm(value);
                    search();
                  },
                  autofocus: false,
                  textInputAction: TextInputAction.search,
                  keyboardType: TextInputType.visiblePassword,
                  autocorrect: false,
                ),
              ])),
            ),
            Expanded(
                child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: listWidget(context, entriesSearched, refreshEntries,
                  showFavouritesButton: entryList.key == KEY_FAVOURITES_ENTRIES,
                  deleteEntryFn: inEditMode && currentSearchTerm.isEmpty
                      ? removeEntry
                      : null,
                  addEntryFn: inEditMode && currentSearchTerm.isNotEmpty
                      ? addEntry
                      : null),
            )),
          ],
        ),
      ),
    );
  }
}

Widget listWidget(
  BuildContext context,
  List<Entry?> entriesSearched,
  Function refreshEntriesFn, {
  bool showFavouritesButton = true,
  Future<void> Function(Entry)? deleteEntryFn,
  Future<void> Function(Entry)? addEntryFn,
}) {
  return ListView.builder(
    itemCount: entriesSearched.length,
    itemBuilder: (context, index) {
      Entry entry = entriesSearched[index]!;
      Widget? trailing;
      if (deleteEntryFn != null) {
        trailing = IconButton(
          padding: const EdgeInsets.only(left: 8, right: 16, top: 8, bottom: 8),
          icon: const Icon(
            Icons.remove_circle,
            color: Colors.red,
          ),
          onPressed: () async => await deleteEntryFn(entry),
        );
      }
      if (addEntryFn != null) {
        trailing = IconButton(
          padding: const EdgeInsets.only(left: 8, right: 16, top: 8, bottom: 8),
          icon: const Icon(
            Icons.add_circle,
            color: Colors.green,
          ),
          onPressed: () async => await addEntryFn(entry),
        );
      }
      return ListTile(
        key: ValueKey(entry.getKey()),
        title: listItem(context, entry, refreshEntriesFn,
            showFavouritesButton: showFavouritesButton),
        trailing: trailing,
      );
    },
  );
}

// We can pass in showFavouritesButton and set it to false for lists that
// aren't the the favourites list, since that star icon might be confusing
// and lead people to beleive they're interacting with the non-favourites
// list they just came from.
Widget listItem(BuildContext context, Entry entry, Function refreshEntriesFn,
    {bool showFavouritesButton = true}) {
  // Try to show the text in the selected locale but if not possible,
  // fallback to the key, which in this case is the word in English.
  Locale currentLocale = Localizations.localeOf(context);
  var text = entry.getPhrase(currentLocale) ?? entry.getKey();
  return TextButton(
    child: Align(
        alignment: Alignment.topLeft,
        child: Text(
          text,
          style: const TextStyle(color: Colors.black),
        )),
    onPressed: () async => {
      await navigateToEntryPage(context, entry, showFavouritesButton),
      await refreshEntriesFn(),
    },
  );
}
