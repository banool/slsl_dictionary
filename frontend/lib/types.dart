import 'dart:convert';

Set<Word> loadWordsInner(String data) {
  dynamic wordsJson = json.decode(data);
  Set<Word> words = {};
  for (dynamic wordData in wordsJson["data"]) {
    words.add(Word.fromJson(wordData));
  }
  print("Loaded ${words.length} words");
  return words;
}

class Word implements Comparable<Word> {
  Word({required this.word, required this.subWords});

  late String word;
  late List<SubWord> subWords;

  Word.fromJson(dynamic wordJson) {
    this.word = wordJson["word_in_english"];

    List<SubWord> subWords = [];
    for (var subWordData in wordJson["sub_entries"]) {
      SubWord subWord = SubWord.fromJson(subWordData);
      if (subWord.videoLinks.length == 0) {
        continue;
      }
      subWord.keywords.remove(word);
      subWords.add(subWord);
    }
    ;

    this.subWords = subWords;
  }

  @override
  int compareTo(Word other) {
    return this.word.compareTo(other.word);
  }

  @override
  String toString() {
    return this.word;
  }
}

class SubWord {
  SubWord(
      {required this.keywords,
      required this.videoLinksInner,
      required this.definitions,
      required this.regions});

  late List<String> keywords;
  late List<String> videoLinksInner;
  late List<Definition> definitions;
  late List<Region> regions;

  List<String> get videoLinks {
    return this.videoLinksInner.toList();
  }

  SubWord.fromJson(dynamic wordJson) {
    this.keywords = [];

    this.videoLinksInner = wordJson["videos"].cast<String>();

    List<Definition> definitions = [];
    for (var definitionData in wordJson["definitions"] ?? []) {
      definitions.add(Definition(
          heading: definitionData["category"],
          subdefinitions: [definitionData["definition"]]));
    }
    ;
    this.definitions = definitions;

    this.regions = [];
  }

  String getRegionsString() {
    if (this.regions.length == 0) {
      return "Regional information unknown";
    }
    if (this.regions.contains(Region.EVERYWHERE)) {
      return Region.EVERYWHERE.pretty;
    }
    return this.regions.map((r) => r.pretty).join(", ");
  }

  // This is for DolphinSR. The video attached to a subword is the best we have
  // to globally identify it. If the video changes for a subword, the subword
  // itself has effectively changed for review purposes and it'd make sense to
  // consider it a new master anyway.
  String getKey(String word) {
    var videoLinks = List.from(this.videoLinksInner);
    videoLinks.sort();
    String firstVideoLink;
    try {
      firstVideoLink = videoLinks[0].split("/auslan/")[1];
    } catch (_e) {
      try {
        firstVideoLink = videoLinks[0].split("/mp4video/")[1];
      } catch (_e) {
        firstVideoLink = videoLinks[0];
      }
    }
    return "$word-$firstVideoLink";
  }

  @override
  String toString() {
    return "SubWord($videoLinks)";
  }
}

class Definition {
  Definition({this.heading, this.subdefinitions});

  final String? heading;
  final List<String>? subdefinitions;
}

// IMPORTANT:
// Keep this in sync with Region in scripts/scrape_signbank.py, the order is important.
enum Region {
  EVERYWHERE,
  SOUTHERN,
  NORTHERN,
  WA,
  NT,
  SA,
  QLD,
  NSW,
  ACT,
  VIC,
  TAS,
}

extension PrintRegion on Region {
  String get pretty {
    switch (this) {
      case Region.EVERYWHERE:
        return "All states of Australia";
      case Region.SOUTHERN:
        return "Southern";
      case Region.NORTHERN:
        return "Northern";
      case Region.WA:
        return "WA";
      case Region.NT:
        return "NT";
      case Region.SA:
        return "SA";
      case Region.QLD:
        return "QLD";
      case Region.NSW:
        return "NSW";
      case Region.ACT:
        return "ACT";
      case Region.VIC:
        return "VIC";
      case Region.TAS:
        return "TAS";
    }
  }
}

final List<Region> regionsWithoutEverywhere =
    List.from(Region.values.where((r) => r != Region.EVERYWHERE).toList());

Region regionFromLegacyString(String s) {
  switch (s.toLowerCase()) {
    case "everywhere":
      return Region.EVERYWHERE;
    case "southern":
      return Region.SOUTHERN;
    case "northern":
      return Region.NORTHERN;
    case "wa":
      return Region.WA;
    case "nt":
      return Region.NT;
    case "sa":
      return Region.SA;
    case "qld":
      return Region.QLD;
    case "nsw":
      return Region.NSW;
    case "act":
      return Region.ACT;
    case "vic":
      return Region.VIC;
    case "tas":
      return Region.TAS;
    default:
      throw "Unexpected legacy region string $s";
  }
}

enum RevisionStrategy {
  SpacedRepetition,
  Random,
}

extension PrettyPrint on RevisionStrategy {
  String get pretty {
    switch (this) {
      case RevisionStrategy.SpacedRepetition:
        return "Spaced Repetition";
      case RevisionStrategy.Random:
        return "Random";
    }
  }
}
