import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'common.dart';
import 'globals.dart';
import 'top_level_scaffold.dart';
import 'word_list_logic.dart';
import 'word_list_overview_help_page_en.dart';
import 'word_list_page.dart';

class EntryListsOverviewPage extends StatefulWidget {
  @override
  _EntryListsOverviewPageState createState() => _EntryListsOverviewPageState();
}

class _EntryListsOverviewPageState extends State<EntryListsOverviewPage> {
  bool inEditMode = false;

  @override
  Widget build(BuildContext context) {
    List<Widget> tiles = [];
    int i = 0;
    for (MapEntry<String, EntryList> e in entryListManager.entryLists.entries) {
      String key = e.key;
      EntryList el = e.value;
      String name = el.getName();
      Widget? trailing;
      if (inEditMode && el.canBeDeleted()) {
        trailing = IconButton(
            icon: Icon(
              Icons.remove_circle,
              color: Colors.red,
            ),
            onPressed: () async {
              bool confirmed = await confirmAlert(
                  context, Text("Are you sure you want to delete this list?"));
              if (confirmed) {
                await entryListManager.deleteEntryList(key);
                setState(() {
                  inEditMode = false;
                });
              }
            });
      }
      Card card = Card(
        key: ValueKey(name),
        child: ListTile(
          leading: el.getLeadingIcon(inEditMode: inEditMode),
          trailing: trailing,
          minLeadingWidth: 10,
          title: Text(
            name,
            textAlign: TextAlign.start,
            style: TextStyle(fontSize: 16),
          ),
          onTap: () async {
            await Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => EntryListPage(
                          entryList: el,
                        )));
          },
        ),
      );
      Widget toAdd = card;
      if (el.key == KEY_FAVOURITES_ENTRIES && inEditMode) {
        toAdd = IgnorePointer(
          key: ValueKey(name),
          child: toAdd,
        );
      }
      if (inEditMode) {
        toAdd = ReorderableDragStartListener(
            key: ValueKey(name), child: toAdd, index: i);
      }
      tiles.add(toAdd);
      i += 1;
    }
    Widget body;
    if (inEditMode) {
      body = ReorderableListView(
          children: tiles,
          onReorder: (prev, updated) async {
            setState(() {
              entryListManager.reorder(prev, updated);
            });
            await entryListManager.writeEntryListKeys();
          });
    } else {
      body = ListView(
        children: tiles,
      );
    }

    FloatingActionButton? floatingActionButton;
    if (inEditMode) {
      floatingActionButton = FloatingActionButton(
          backgroundColor: Colors.green,
          onPressed: () async {
            bool confirmed = await applyCreateListDialog(context);
            if (confirmed) {
              setState(() {
                inEditMode = false;
              });
            }
          },
          child: Icon(Icons.add));
    }

    List<Widget> actions = [
      buildActionButton(
        context,
        inEditMode ? Icon(Icons.edit) : Icon(Icons.edit_outlined),
        () async {
          setState(() {
            inEditMode = !inEditMode;
          });
        },
      ),
      buildActionButton(
        context,
        Icon(Icons.help),
        () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => getWordListOverviewHelpPageEn()),
          );
        },
      )
    ];

    return TopLevelScaffold(
        body: body,
        title: AppLocalizations.of(context).listsTitle,
        actions: actions,
        floatingActionButton: floatingActionButton);
  }
}

// Returns true if a new list was created.
Future<bool> applyCreateListDialog(BuildContext context) async {
  TextEditingController controller = TextEditingController();

  List<Widget> children = [
    Text(
      "No special characters besides these are allowed: , . - _ !",
    ),
    Padding(padding: EdgeInsets.only(top: 10)),
    TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: AppLocalizations.of(context).listEnterNewName,
      ),
      autofocus: true,
      inputFormatters: [
        FilteringTextInputFormatter.allow(EntryList.validNameCharacters),
      ],
      textInputAction: TextInputAction.send,
      keyboardType: TextInputType.visiblePassword,
      textCapitalization: TextCapitalization.words,
    )
  ];

  Widget body = Column(
    children: children,
    mainAxisSize: MainAxisSize.min,
  );
  bool confirmed = await confirmAlert(context, body,
      title: AppLocalizations.of(context).listNewList);
  if (confirmed) {
    String name = controller.text;
    try {
      String key = EntryList.getKeyFromName(name);
      await entryListManager.createEntryList(key);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text("${AppLocalizations.of(context).listFailedToMake}: $e."),
          backgroundColor: Colors.red));
      confirmed = false;
    }
  }
  return confirmed;
}
