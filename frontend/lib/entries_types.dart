import 'dart:ui';
import 'package:json_annotation/json_annotation.dart';
import 'package:slsl_dictionary/common.dart';

part 'entries_types.g.dart';

abstract class Entry implements Comparable<Entry> {
  // Used for comparing entries.
  String getKey();

  // This could be a word or phrase. This can return null if there is nothing
  // available for the given locale.
  String? getPhrase(Locale locale);

  List<SubEntry> getSubEntries();
}

abstract class SubEntry {
  // Used for comparing sub-entries.
  String getKey();

  // Return the video URLs.
  List<String> getVideos();

  List<String> getRelatedWords();

  // Gets definitions.
  // todo define return type
  List<Definition> getDefinitions(Locale locale);

  // Return what regions this entry is appropriate for.
  List<Region> getRegions();
}

const LANGUAGE_ENGLISH = "English";
const LANGUAGE_SINHALA = "සිංහල";
const LANGUAGE_TAMIL = "தமிழ்";

const Map<String, Locale> LANGUAGE_TO_LOCALE = {
  LANGUAGE_ENGLISH: Locale('en', ''),
  // Use word for Sinhala in Sinhala
  LANGUAGE_SINHALA: Locale('si', ''),
  // Use word for Tamil in Tamil
  LANGUAGE_TAMIL: Locale('ta', ''),
};

Map<Locale, String> LOCALE_TO_LANGUAGE = Map.fromEntries(
    LANGUAGE_TO_LOCALE.entries.map((e) => MapEntry(e.value, e.key)));

@JsonSerializable()
class MyEntry implements Entry {
  final String word_in_english;
  final String? word_in_tamil;
  final String? word_in_sinhala;

  final String? category;

  final List<MySubEntry> sub_entries;

  MyEntry(
      {required this.word_in_english,
      this.word_in_tamil,
      this.word_in_sinhala,
      this.category,
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
    if (locale == LANGUAGE_TO_LOCALE[LANGUAGE_ENGLISH]!) {
      return word_in_english;
    } else if (locale == LANGUAGE_TO_LOCALE[LANGUAGE_TAMIL]) {
      return word_in_tamil;
    } else if (locale == LANGUAGE_TO_LOCALE[LANGUAGE_SINHALA]) {
      return word_in_sinhala;
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
    return this.getKey().compareTo(other.getKey());
  }
}

@JsonSerializable()
class MySubEntry implements SubEntry {
  // Even though the backend allows sub entries without videos (against which
  // I should add validation), the dump function skips sub entries that don't
  // have them, so we can assume that there will be a list of videos here and
  // that it will be non empty.
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
  // consider it a new master anyway.
  @override
  String getKey() {
    var videoLinks = List.from(this.videos);
    videoLinks.sort();
    return videoLinks[0];
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
  List<String> getVideos() {
    return videos;
  }

  @override
  List<Definition> getDefinitions(Locale locale) {
    List<Definition> out = [];
    print("yoooooooooooo definitions $definitions");
    for (Definition definition in definitions ?? []) {
      print(definition.language);
      print(locale.languageCode);
      if (definition.language.toLowerCase() == locale.languageCode) {
        out.add(definition);
      }
    }
    print("yoooooooooooo out $out");
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

extension PrintRegion on Region {
  String get pretty {
    switch (this) {
      case Region.ALL:
        return "All of Sri Lanka";
      case Region.NORTH_EAST:
        return "North East";
    }
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
