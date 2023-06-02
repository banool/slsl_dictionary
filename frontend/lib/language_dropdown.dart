import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:slsl_dictionary/root.dart';

import 'common.dart';
import 'entries_types.dart';
import 'globals.dart';

const String NO_OVERRIDE_KEY = "NO_OVERRIDE";

class LanguageDropdown extends StatefulWidget {
  LanguageDropdown({Key? key}) : super(key: key);

  @override
  LanguageDropdownState createState() => LanguageDropdownState();
}

class LanguageDropdownState extends State<LanguageDropdown> {
  Locale? localeOverride;
  late Future<void> initStateAsyncFuture;

  @override
  void initState() {
    initStateAsyncFuture = initStateAsync();
    super.initState();
  }

  Future<void> initStateAsync() async {
    localeOverride = await getLocaleOverride();
  }

// If there is an override, return the override.
// Otherwise return the current locale.
  Future<Locale?> getLocaleOverride() async {
    return await LocaleOverride.getLocaleOverride();
  }

// Returns the locale if an override was set, or null if the user just chose
// to use the system locale (no override).
  Future<Locale?> setLocale(String language) async {
    if (language == NO_OVERRIDE_KEY) {
      // Unset locale override.
      RootApp.clearLocaleOverride(context);
      await LocaleOverride.clearLocaleOverride();
      return null;
    }
    // Set locale override, both in the DB and in the app live right now.
    Locale localeOverride = LANGUAGE_TO_LOCALE[language]!;
    RootApp.applyLocaleOverride(context, localeOverride);
    await LocaleOverride.writeLocaleOverride(localeOverride);
    return localeOverride;
  }

  @override
  Widget build(BuildContext context) {
    String noOverride = AppLocalizations.of(context).deviceDefault;

    // Build list of possible language.
    List<DropdownMenuItem<String>> languageDropdownOptions = [];

    // Add system locale.
    languageDropdownOptions.add(DropdownMenuItem<String>(
        value: NO_OVERRIDE_KEY, child: Text(noOverride)));

    // Add the rest of the language options.
    languageDropdownOptions
        .addAll(LANGUAGE_TO_LOCALE.keys.map((String language) {
      return DropdownMenuItem<String>(
        value: language,
        child: Text(language),
      );
    }).toList());

    return FutureBuilder(
        future: initStateAsyncFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return new Center(
              child: new CircularProgressIndicator(),
            );
          }

          // Determine which locale option should be selected.
          String selectedLanguageOption;
          if (localeOverride != null) {
            selectedLanguageOption = LOCALE_TO_LANGUAGE[localeOverride]!;
          } else {
            selectedLanguageOption = NO_OVERRIDE_KEY;
          }
          return DropdownButton<String>(
            value: selectedLanguageOption,
            items: languageDropdownOptions,
            onChanged: (String? newValue) async {
              Locale? newLocale = await setLocale(newValue!);
              setState(() {
                if (newLocale != null) {
                  localeOverride = newLocale;
                } else {
                  localeOverride = null;
                }
              });
            },
          );
        });
  }
}

class LanguagePopUpMenu extends StatelessWidget {
  final void Function(String?) onChanged;

  const LanguagePopUpMenu({super.key, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.language,
      ),
      itemBuilder: (BuildContext context) {
        return LANGUAGE_TO_LOCALE.keys.map((String language) {
          return PopupMenuItem<String>(
            value: language,
            child: Text(language),
          );
        }).toList();
      },
      onSelected: onChanged,
    );
  }
}

// Records the locale override, if any.
// This class stores the locale as a string internally but the interface
// requires and returns Locale objects.
class LocaleOverride {
  static Future<void> writeLocaleOverride(Locale locale) async {
    sharedPreferences.setString(KEY_LOCALE_OVERRIDE, locale.toString());
  }

  static Future<void> clearLocaleOverride() async {
    sharedPreferences.remove(KEY_LOCALE_OVERRIDE);
  }

  static Future<Locale?> getLocaleOverride() async {
    var localeRaw = sharedPreferences.getString(KEY_LOCALE_OVERRIDE);
    if (localeRaw == null) {
      return null;
    }
    return Locale(localeRaw);
  }
}
