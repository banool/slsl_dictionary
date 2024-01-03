import 'package:dictionarylib/entry_types.dart';
import 'package:dictionarylib/globals.dart';
import 'package:flutter/material.dart';
import 'package:slsl_dictionary/entries_types.dart';
import 'package:slsl_dictionary/root.dart';
import 'package:dolphinsr_dart/dolphinsr_dart.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:slsl_dictionary/globals.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  entriesGlobal = {
    MyEntry(word_in_english: "friend", entry_type: "WORD", sub_entries: [
      MySubEntry(
          videos: ["video.mp4"],
          region: "ALL",
          definitions: [
            Definition(
                language: "en",
                category: "Relationships",
                definition: "Someone you love :)")
          ])
    ])
  };

  SharedPreferences.setMockInitialValues({});
  sharedPreferences = await SharedPreferences.getInstance();

  enableFlashcardsKnob = true;
  useCdnUrl = true;

  showFlashcards = true;

  testWidgets('Pump app test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const RootApp(
      startingLocale: Locale("en"),
    ));
    print("Pump successful!");
  });

  test('Dolphin test', () async {
    DolphinSR dolphin = DolphinSR();

    List<Master> masters = [];
    for (Entry e in entriesGlobal) {
      for (SubEntry se in e.getSubEntries()) {
        var m = Master(id: se.getKey(e), fields: [
          e.getKey(),
          se.getMedia().join("=====")
        ], combinations: const [
          Combination(front: [0], back: [1]),
          Combination(front: [1], back: [0]),
        ]);
        masters.add(m);
      }
    }

    dolphin.addMasters(masters);

    DRCard card = dolphin.nextCard()!;

    print(card);
  });
}
