import 'package:dictionarylib_test_support/config.dart';

import 'package:slsl_dictionary/entries_loader.dart';
import 'package:slsl_dictionary/main.dart' show KNOB_URL_BASE;
import 'package:slsl_dictionary/root.dart';

/// SLSL's plug-in points for the shared multi-device sharing suite.
///
/// SLSL ships no bundled dictionary; it's fetched at runtime. The loader is
/// pinned at the direct bucket dump URL for determinism rather than going
/// through the useCdnUrl knob.
final MdSuiteConfig mdSuiteConfig = MdSuiteConfig(
  appId: 'slsl',
  appName: 'SLSL Dictionary',
  advisoriesUrl: Uri.parse(
      'https://raw.githubusercontent.com/banool/slsl_dictionary/main/frontend/assets/advisories.md'),
  knobUrlBase: KNOB_URL_BASE,
  mediaBaseUrls: const [DATA_URL_PREFIX_DIRECT, DATA_URL_PREFIX_CDN],
  buildEntryLoader: () => MyEntryLoader(
      dumpFileUrl: Uri.parse('$DATA_URL_PREFIX_DIRECT/dump/dump.json')),
  shareLinkBaseUrl: 'https://share.srilankansignlanguage.org/l',
  shareLinkHost: 'share.srilankansignlanguage.org',
  urlScheme: 'slsl',
  appleBundleId: 'com.banool.slsldictionary',
  buildApp: (locale) => RootApp(startingLocale: locale),
);
