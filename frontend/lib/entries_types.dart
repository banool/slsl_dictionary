import 'package:dictionarylib/common.dart';
import 'package:dictionarylib/entry_types.dart';
import 'package:flutter/material.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:dictionarylib/dictionarylib.dart' show DictLibLocalizations;

import 'entries_loader.dart';

part 'entries_types.g.dart';

@JsonSerializable()
class MyEntry implements Entry {
  final String word_in_english;
  final String? word_in_sinhala;
  final String? word_in_tamil;

  final String? category;
  final String entry_type;

  final List<MySubEntry> sub_entries;

  MyEntry(
      {required this.word_in_english,
      this.word_in_sinhala,
      this.word_in_tamil,
      this.category,
      required this.entry_type,
      required this.sub_entries});

  factory MyEntry.fromJson(Map<String, dynamic> json) =>
      _$MyEntryFromJson(json);

  Map<String, dynamic> toJson() => _$MyEntryToJson(this);

  @override
  String getKey() {
    return word_in_english;
  }

  @override
  String? getPhrase(Locale locale) {
    if (locale == LOCALE_ENGLISH) {
      return word_in_english;
    } else if (locale == LOCALE_SINHALA) {
      return word_in_sinhala;
    } else if (locale == LOCALE_TAMIL) {
      return word_in_tamil;
    } else {
      throw Exception("Unknown locale $locale");
    }
  }

  @override
  List<SubEntry> getSubEntries() {
    return sub_entries;
  }

  @override
  int compareTo(Entry other) {
    return getKey().compareTo(other.getKey());
  }

  @override
  EntryType getEntryType() {
    if (entry_type == "WORD") {
      return EntryType.WORD;
    } else if (entry_type == "PHRASE") {
      return EntryType.PHRASE;
    } else if (entry_type == "FINGERSPELLING") {
      return EntryType.FINGERSPELLING;
    } else {
      throw Exception("Unknown entry type $entry_type");
    }
  }
}

@JsonSerializable()
class MySubEntry implements SubEntry {
  // Even though the backend allows sub entries without videos (against which
  // I should add validation), the dump function skips sub entries that don't
  // have them, so we can assume that there will be a list of videos here and
  // that it will be non empty. Don't access this directly, use getMedia.
  final List<String> videos;
  final List<Definition>? definitions;
  final String region;
  final String? related_words;

  MySubEntry({
    required this.videos,
    this.definitions,
    required this.region,
    this.related_words,
  });

  factory MySubEntry.fromJson(Map<String, dynamic> json) =>
      _$MySubEntryFromJson(json);

  Map<String, dynamic> toJson() => _$MySubEntryToJson(this);

  // This is for DolphinSR. The video attached to a subword is the best we have
  // to globally identify it. If the video changes for a subword, the subword
  // itself has effectively changed for review purposes and it'd make sense to
  // consider it a new master anyway. In addition to the video we accept the
  // Entry that this SubEntry comes from; we need the key from _that_ to
  // uniquely identify the subentry (some subentries from different entries
  // might use the same video).
  @override
  String getKey(Entry parentEntry) {
    var videoLinks = List.from(videos);
    videoLinks.sort();
    return videoLinks[0] + parentEntry.getKey();
  }

  Region get regionType {
    switch (region.toLowerCase()) {
      case "all":
        return Region.ALL;
      case "ne":
        return Region.NORTH_EAST;
      default:
        throw Exception("Unknown region $region");
    }
  }

  @override
  String toString() {
    return "SubWord($videos)";
  }

  @override
  List<String> getMedia() {
    // The dump only contains the final filename + ext, we have to build the
    // full URL. We do it here. buildUrl depends on the useCdnUrl knob having
    // a value.
    return videos.map((e) => buildUrl("media/$e")).toList();
  }

  @override
  List<Definition> getDefinitions(Locale locale) {
    List<Definition> out = [];
    for (Definition definition in definitions ?? []) {
      if (definition.language.toLowerCase() == locale.languageCode) {
        out.add(definition);
      }
    }
    return out;
  }

  @override
  List<String> getRelatedWords() {
    return related_words
            ?.split(",")
            .map((e) => e.lstrip(" ").rstrip(" "))
            .toList() ??
        [];
  }

  @override
  List<Region> getRegions() {
    return [region].map((e) => regionFromString(e)).toList();
  }
}

@JsonSerializable()
class Definition {
  final String language;
  final String category;
  final String definition;

  String get categoryPretty {
    return getCategoryPretty(category);
  }

  Definition(
      {required this.language,
      required this.category,
      required this.definition});
  factory Definition.fromJson(Map<String, dynamic> json) =>
      _$DefinitionFromJson(json);

  Map<String, dynamic> toJson() => _$DefinitionToJson(this);
}

// IMPORTANT:
// Keep this in sync with Region in scripts/scrape_signbank.py, the order is important.
enum Region {
  ALL,
  NORTH_EAST,
}

String getRegionPretty(BuildContext context, Region region) {
  switch (region) {
    case Region.ALL:
      return DictLibLocalizations.of(context)!.flashcardsAllOfSriLanka;
    case Region.NORTH_EAST:
      return DictLibLocalizations.of(context)!.flashcardsNorthEast;
  }
}

Region regionFromString(String s) {
  switch (s.toLowerCase()) {
    case "all":
      return Region.ALL;
    case "ne":
      return Region.NORTH_EAST;
    default:
      throw Exception("Unknown region $s");
  }
}

String getCategoryPretty(String s) {
  switch (s) {
    case "AS_A_NOUN":
      return "As a noun";
    case "AS_A_VERB_OR_ADJECTIVE":
      return "As a verb or adjective";
    case "AS_MODIFIER":
      return "As modifier";
    case "AS_QUESTION":
      return "As question";
    case "INTERACTIVE":
      return "Interactive";
    case "GENERAL_DEFINITION":
      return "General definition";
    case "NOTE":
      return "Note";
    case "AUGMENTED_MEANING":
      return "Augmented meaning";
    case "AS_A_POINTING_SIGN":
      return "As a pointing sign";
    default:
      return s;
  }
}
