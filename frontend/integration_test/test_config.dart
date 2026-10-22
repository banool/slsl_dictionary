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
  // The first read off a device running a released build, the others
  // written the same way from the dictionary data.
  storedVideos: const [
    'apple|/media/SLCFDFruits_Apple.mp4',
    'dog|/media/SLCFDAnimals_Dog_fz3q2O0.mp4',
    'cat|/media/SLCFDAnimals_Cat.mp4',
  ],
);

const ScreenshotSuiteConfig screenshotConfig = ScreenshotSuiteConfig(
  localeDirName: 'en',
  animalsSeedWords: ["bear", "fish", "rabbit", "elephant", "tiger", "wolf"],
  searchQuery: 'sri',
  heroEntryKey: 'Sri Lanka',
);
