import 'dart:ui';


// TODO define an interface like:

abstract class Entry {
  // This could be a word or phrase.
  String getPhrase(Locale locale);

  // Language is only passed down here to pass it to getDefinitions,
  // the sub entries available do not depend on language choice.
  List<SubEntry> getSubEntries(Locale locale);
}

abstract class SubEntry {
  // Returns the video URLs.
  List<String> getVideos();

  // Gets definitions.
  // todo define return type
  getDefinitions(Locale locale);

  // TODO: Decide if a word can have multiple regions?
  // Probably should for the sake of future proofing.
  getRegions();
}

const Map<String, Locale> LANGUAGE_TO_LOCALE = {
  "English": Locale('en', ''),
  // Use word for Sinhala in Sinhala
  "Sinhala": Locale('si', ''),
  // Use word for Tamil in Tamil
  "Tamil": Locale('ta', ''),
};

Map<Locale, String> LOCALE_TO_LANGUAGE = Map.fromEntries(
    LANGUAGE_TO_LOCALE.entries.map((e) => MapEntry(e.value, e.key)));
