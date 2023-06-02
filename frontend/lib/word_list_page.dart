import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'common.dart';
import 'entries_types.dart';
import 'globals.dart';
import 'word_list_help_page_en.dart';
import 'word_list_logic.dart';

class EntryListPage extends StatefulWidget {
  final EntryList entryList;

  EntryListPage({Key? key, required this.entryList}) : super(key: key);

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
      enableSortButton = currentSearchTerm.length == 0;
    });
  }

  void search() {
    setState(() {
      if (currentSearchTerm.length > 0) {
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
        inEditMode ? Icon(Icons.edit) : Icon(Icons.edit_outlined),
        () async {
          setState(() {
            inEditMode = !inEditMode;
            if (!inEditMode) {
              clearSearch();
            }
            search();
          });
        },
      ),
      buildActionButton(
        context,
        Icon(Icons.help),
        () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => getWordListHelpPageEn()),
          );
        },
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
        child: Icon(Icons.sort));

    String hintText;
    if (inEditMode) {
      hintText = AppLocalizations.of(context).listSearchAdd;
      bool keyboardIsShowing = MediaQuery.of(context).viewInsets.bottom > 0;
      if (currentSearchTerm.length > 0 || keyboardIsShowing) {
        floatingActionButton = null;
      } else {
        floatingActionButton = FloatingActionButton(
            backgroundColor: Colors.green,
            onPressed: () {
              textFieldFocus.requestFocus();
            },
            child: Icon(Icons.add));
      }
    } else {
      hintText = "${AppLocalizations.of(context).listSearchPrefix} $listName";
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(entryList.getName()),
        centerTitle: true,
        actions: buildActionButtons(actions),
      ),
      floatingActionButton: floatingActionButton,
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 0.0, vertical: 8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          mainAxisSize: MainAxisSize.max,
          children: [
            Padding(
              padding: EdgeInsets.only(bottom: 10, left: 32, right: 32, top: 0),
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
                      icon: Icon(Icons.clear),
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
              padding: EdgeInsets.only(left: 8),
              child: listWidget(
                  context, entriesSearched, entriesGlobal, refreshEntries,
                  showFavouritesButton: entryList.key == KEY_FAVOURITES_ENTRIES,
                  deleteEntryFn: inEditMode && currentSearchTerm.length == 0
                      ? removeEntry
                      : null,
                  addEntryFn: inEditMode && currentSearchTerm.length > 0
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
  Set<Entry> allEntries,
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
          padding: EdgeInsets.only(left: 8, right: 16, top: 8, bottom: 8),
          icon: Icon(
            Icons.remove_circle,
            color: Colors.red,
          ),
          onPressed: () async => await deleteEntryFn(entry),
        );
      }
      if (addEntryFn != null) {
        trailing = IconButton(
          padding: EdgeInsets.only(left: 8, right: 16, top: 8, bottom: 8),
          icon: Icon(
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
  return TextButton(
    child: Align(
        alignment: Alignment.topLeft,
        child: Text(
          "${entry.getKey()}",
          style: TextStyle(color: Colors.black),
        )),
    onPressed: () async => {
      await navigateToEntryPage(context, entry,
          showFavouritesButton: showFavouritesButton),
      await refreshEntriesFn(),
    },
  );
}
