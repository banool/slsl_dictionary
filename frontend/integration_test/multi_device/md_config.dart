import 'package:dictionarylib_test_support/config.dart';

import 'package:slsl_dictionary/entries_loader.dart';
import 'package:slsl_dictionary/main.dart' show KNOB_URL_BASE;
import 'package:slsl_dictionary/root.dart';

/// SLSL's plug-in points for the shared multi-device sharing suite.
///
/// SLSL ships no bundled dictionary; it's fetched at runtime from the R2 mirror
/// at cdn. (the sole origin since the GCS migration).
final MdSuiteConfig mdSuiteConfig = MdSuiteConfig(
  appId: 'slsl',
  appName: 'SLSL Dictionary',
  advisoriesUrl: Uri.parse(
      'https://raw.githubusercontent.com/banool/slsl_dictionary/main/frontend/assets/advisories.md'),
  knobUrlBase: KNOB_URL_BASE,
  mediaBaseUrls: const [DATA_URL_PREFIX_CDN],
  buildEntryLoader: () => MyEntryLoader(
      dumpFileUrl: Uri.parse('$DATA_URL_PREFIX_CDN/dump/dump.json')),
  shareLinkBaseUrl: 'https://share.srilankansignlanguage.org/l',
  shareLinkHost: 'share.srilankansignlanguage.org',
  urlScheme: 'slsl',
  appleBundleId: 'com.banool.slsldictionary',
  buildApp: (locale) => RootApp(startingLocale: locale),
);
