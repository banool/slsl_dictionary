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
