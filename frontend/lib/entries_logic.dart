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
