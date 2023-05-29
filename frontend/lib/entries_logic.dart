// TODO define an interface like:

class Entry {
  // This could be a word or phrase.
  getPhrase(language)

  getSubEntries(language)
}

class SubEntry {
  getVideos()

  getDefinitions(language)

  // TODO: Decide if a word can have multiple regions?
  // Probably should for the sake of future proofing.
  getRegions()
}

enum Language {
  EN_US,
  // Use proper codes for other languages.
  SINHALA,
  TAMIL,
}

String getLanguageString(Language language) {
  switch (language) {
    case Language.EN_US:
      return "English";
    case Language.SINHALA:
      // Use word for Sinhala in Sinhala
      return "Sinhala";
    case Language.TAMIL:
      // Use word for Tamil in Tamil
      return "Tamil";
  }
}
