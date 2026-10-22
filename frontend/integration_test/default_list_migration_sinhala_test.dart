import 'package:dictionarylib/entry_types.dart';
import 'package:dictionarylib_test_support/suites/default_list_migration_suite.dart';

import 'test_config.dart';

void main() => runDefaultListMigrationSuite(
  appTestConfig,
  LegacyInstall.inAnotherLanguage,
  language: LOCALE_SINHALA,
);
