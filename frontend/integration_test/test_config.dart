import 'package:dictionarylib_test_support/config.dart';

import 'package:slsl_dictionary/common.dart' as app;
import 'package:slsl_dictionary/main.dart';
import 'package:slsl_dictionary/root.dart';

/// SLSL's plug-in points for the shared integration-test suites in
/// dictionarylib_test_support.
final DictAppTestConfig appTestConfig = DictAppTestConfig(
  setup: () => setup(),
  buildApp: (locale) => RootApp(startingLocale: locale),
  navigateToEntryPage: app.navigateToEntryPage,
  // SLSL doesn't filter the flashcard pool by region, so there's nothing to
  // seed or clear.
  seedFlashcardSettings: null,
  clearFlashcardSettings: null,
);

const ScreenshotSuiteConfig screenshotConfig = ScreenshotSuiteConfig(
  localeDirName: 'en',
  animalsSeedWords: ["bear", "fish", "rabbit", "elephant", "tiger", "wolf"],
  searchQuery: 'sri',
  heroEntryKey: 'Sri Lanka',
);
