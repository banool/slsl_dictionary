import 'dart:ui';

import 'package:dolphinsr_dart/dolphinsr_dart.dart';

import 'entries_types.dart';
import 'globals.dart';
import 'types.dart';

const String VIDEO_LINKS_MARKER = "videolinks";
const String KEY_RANDOM_REVIEWS_COUNTER = "mykey_random_reviews_counter";
const String KEY_FIRST_RANDOM_REVIEW = "mykey_first_random_review";

class DolphinInformation {
  DolphinInformation({
    required this.dolphin,
    required this.keyToSubEntryMap,
  });

  DolphinSR dolphin;
  Map<String, SubEntry> keyToSubEntryMap;
}

Set<Entry> getEntriesFromLists(List<String> listsToUse) {
  Set<Entry> out = {};
  for (String key in listsToUse) {
    out.addAll(entryListManager.entryLists[key]!.entries);
  }
  return out;
}

Map<Entry, List<SubEntry>> getSubEntriesFromEntries(Set<Entry> favourites) {
  Map<Entry, List<SubEntry>> subEntries = Map();
  for (Entry e in favourites) {
    subEntries[e] = [];
    for (SubEntry sw in e.getSubEntries()) {
      subEntries[e]!.add(sw);
    }
  }
  return subEntries;
}

int getNumSubEntries(Map<String, List<SubEntry>> subEntries) {
  if (subEntries.values.length == 0) {
    return 0;
  }
  if (subEntries.values.length == 1) {
    return subEntries.values.toList()[0].length;
  }
  return subEntries.values.map((v) => v.length).reduce((a, b) => a + b);
}

Map<Entry, List<SubEntry>> filterSubEntries(
    Map<Entry, List<SubEntry>> subEntries,
    List<Region> allowedRegions,
    bool useUnknownRegionSigns,
    bool oneCardPerEntry) {
  Map<Entry, List<SubEntry>> out = Map();

  for (MapEntry<Entry, List<SubEntry>> e in subEntries.entries) {
    List<SubEntry> validSubEntries = [];
    for (SubEntry se in e.value) {
      if (validSubEntries.length > 0 && oneCardPerEntry) {
        break;
      }
      if (se.getRegions().contains(Region.ALL)) {
        validSubEntries.add(se);
        continue;
      }
      if (se.getRegions().length == 0 && useUnknownRegionSigns) {
        validSubEntries.add(se);
        continue;
      }
      for (Region r in se.getRegions()) {
        if (allowedRegions.contains(r)) {
          validSubEntries.add(se);
          break;
        }
      }
    }
    if (validSubEntries.length > 0) {
      out[e.key] = validSubEntries;
    }
  }
  return out;
}

// You should provide this function the filtered list of SubEntries.
List<Master> getMasters(Locale revisionLocale,
    Map<Entry, List<SubEntry>> subEntries, bool entryToSign, bool signToEntry) {
  print("Making masters from ${subEntries.length} entries");
  List<Master> masters = [];
  Set<String> keys = {};
  for (MapEntry<Entry, List<SubEntry>> e in subEntries.entries) {
    Entry entry = e.key;
    // If there is no word / phrase for the entry in the requested revision
    // language don't use the entry.
    String? phrase = entry.getPhrase(revisionLocale);
    if (phrase == null) {
      print(
          "Skipping entry that doesn't have a phrase in the requested language");
      continue;
    }
    for (SubEntry se in e.value) {
      List<Combination> combinations = [];
      if (entryToSign) {
        combinations.add(Combination(front: [0], back: [1]));
      }
      if (signToEntry) {
        combinations.add(Combination(front: [1], back: [0]));
      }
      var masterKey = se.getKey(entry);
      var m = Master(
        id: masterKey,
        fields: [phrase, VIDEO_LINKS_MARKER],
        combinations: combinations,
      );
      if (!keys.contains(masterKey)) {
        masters.add(m);
      } else {
        print("Skipping master $m with duplicate key: $masterKey");
      }
      keys.add(masterKey);
    }
  }
  masters.shuffle();
  print("Built ${masters.length} masters");
  return masters;
}

int getNumCards(DolphinSR dolphin) {
  return dolphin.cardsLength();
}

DolphinInformation getDolphinInformation(
    Map<Entry, List<SubEntry>> subEntries, List<Master> masters,
    {List<Review>? reviews}) {
  reviews = reviews ?? [];
  Map<String, SubEntry> keyToSubEntryMap = Map();
  for (MapEntry<Entry, List<SubEntry>> e in subEntries.entries) {
    for (SubEntry se in e.value) {
      // TODO: Make sure this is okay vs the key needing to have entry.key in it.
      keyToSubEntryMap[se.getKey(e.key)] = se;
    }
  }
  DolphinSR dolphin = DolphinSR();
  dolphin.addMasters(masters);

  // For each master + combination in random order, seed a review with an
  // increasing timestamp near the epoch with Rating.Again. This way, ignoring
  // the effect of other reviews added after, the masters will come out in a
  // random order. I use MapEntry just because of the absence of a pair / tuple
  // type.
  List<MapEntry<String, Combination>> mastersEntries = [];
  for (Master m in masters) {
    for (Combination c in m.combinations!) {
      mastersEntries.add(MapEntry(m.id!, c));
    }
  }
  mastersEntries.shuffle();
  List<Review> seedReviews = [];
  int epoch = 1000000;
  for (MapEntry<String, Combination> e in mastersEntries) {
    seedReviews.add(Review(
        master: e.key,
        combination: e.value,
        ts: DateTime.fromMillisecondsSinceEpoch(epoch),
        rating: Rating.Again));
    epoch += 100000000;
  }
  dolphin.addReviews(seedReviews);

  // Dolphin cannot handle reviews for masters it doesn't know about, so we
  // filter those out. This can happen if you have reviews for a card but then
  // choose to filter it out / remove it from your favourites. Be careful not
  // to somehow retrieve the reviews from within the DolphinSR object and store
  // them, since you'd be wiping reviews that are valid if not for the masters
  // we ended up adding to this particular DolphinSR object.
  Map<String, Master> masterLookup = Map.fromEntries(masters.map(
    (e) => MapEntry(e.id!, e),
  ));
  List<Review> filteredReviews = [];
  for (Review r in reviews) {
    Master? m = masterLookup[r.master!];
    if (m == null) {
      print(
          "Filtered out review for ${r.master!} because the master wasn't present");
      continue;
    }
    if (!m.combinations!.contains(r.combination!)) {
      print(
          "Filtered out review for ${r.master!} because the master was present but not with the needed combination");
      continue;
    }
    filteredReviews.add(r);
  }
  print(
      "Added ${filteredReviews.length} total reviews to Dolphin (excluding seed reviews)");
  dolphin.addReviews(filteredReviews);
  return DolphinInformation(
      dolphin: dolphin, keyToSubEntryMap: keyToSubEntryMap);
}

const String KEY_STORED_REVIEWS = "stored_reviews";
const String REVIEW_DELIMITER = "===";
const String COMBINATION_DELIMETER = "@@@";

String encodeReview(Review review) {
  String combination =
      "${review.combination!.front![0]}$COMBINATION_DELIMETER${review.combination!.back![0]}";
  return "${review.master}$REVIEW_DELIMITER$combination$REVIEW_DELIMITER${review.rating!.index}$REVIEW_DELIMITER${review.ts!.microsecondsSinceEpoch}";
}

Review decodeReview(String s) {
  List<String> split = s.split(REVIEW_DELIMITER);
  List<String> combinationSplit = split[1].split(COMBINATION_DELIMETER);
  int front = int.parse(combinationSplit[0]);
  int back = int.parse(combinationSplit[1]);
  Combination combination = Combination(front: [front], back: [back]);
  Rating rating = Rating.values[int.parse(split[2])];
  DateTime ts = DateTime.fromMicrosecondsSinceEpoch(int.parse(split[3]));
  return Review(
    master: split[0],
    combination: combination,
    rating: rating,
    ts: ts,
  );
}

List<Review> readReviews() {
  List<String> encoded =
      sharedPreferences.getStringList(KEY_STORED_REVIEWS) ?? [];
  return encoded
      .map(
        (e) => decodeReview(e),
      )
      .toList();
}

Future<void> writeReviews(List<Review> existing, List<Review> additional,
    {bool force = false}) async {
  if (!force && additional.isEmpty) {
    print("No reviews to write and force = $force");
    return;
  }
  List<Review> toWrite = existing + additional;
  List<String> encoded = toWrite
      .map(
        (e) => encodeReview(e),
      )
      .toList();
  await sharedPreferences.setStringList(KEY_STORED_REVIEWS, encoded);
  print(
      "Wrote ${additional.length} new reviews (making ${toWrite.length} in total) to storage");
}

int getNumDueCards(DolphinSR dolphin, RevisionStrategy revisionStrategy) {
  switch (revisionStrategy) {
    case RevisionStrategy.Random:
      return getNumCards(dolphin);
    case RevisionStrategy.SpacedRepetition:
      SummaryStatics summary = dolphin.summary();
      // Everything but "later", that seems to match up with what Dolphin
      // will spit out from nextCard. Note, this is only true if the user
      // gets all the cards correct. If the user gets them wrong, those cards
      // will immediately reappear in nextCard. Currently I just make it that
      // you have to re-enter the review flow once it's all done.
      int due =
          (summary.due ?? 0) + (summary.overdue ?? 0) + (summary.learning ?? 0);
      return due;
  }
}

Future<void> bumpRandomReviewCounter(int bumpAmount) async {
  int current = sharedPreferences.getInt(KEY_RANDOM_REVIEWS_COUNTER) ?? 0;
  int updated = current + bumpAmount;
  await sharedPreferences.setInt(KEY_RANDOM_REVIEWS_COUNTER, updated);
  print(
      "Incremented random review counter by $bumpAmount ($current to $updated)");
  int? firstUnixtime = sharedPreferences.getInt(KEY_FIRST_RANDOM_REVIEW);
  if (firstUnixtime == null) {
    await sharedPreferences.setInt(
        KEY_FIRST_RANDOM_REVIEW, DateTime.now().millisecondsSinceEpoch ~/ 1000);
  }
}
