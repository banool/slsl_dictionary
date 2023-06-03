import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:slsl_dictionary/root.dart';

import 'common.dart';
import 'entries_types.dart';
import 'globals.dart';

const String NO_OVERRIDE_KEY = "NO_OVERRIDE";

class LanguageDropdown extends StatefulWidget {
  LanguageDropdown(
      {Key? key,
      this.asPopUpMenu = false,
      this.includeDeviceDefaultOption = true,
      this.initialLanguage,
      this.onChanged})
      : super(key: key);

  final bool asPopUpMenu;
  final bool includeDeviceDefaultOption;
  final String? initialLanguage;
  final Locale Function(String)? onChanged;

  @override
  LanguageDropdownState createState() => LanguageDropdownState(
      asPopUpMenu: asPopUpMenu,
      includeDeviceDefaultOption: includeDeviceDefaultOption,
      initialLanguage: initialLanguage,
      onChanged: onChanged);
}

class LanguageDropdownState extends State<LanguageDropdown> {
  final bool asPopUpMenu;
  final bool includeDeviceDefaultOption;

  // If given, this will be used as the initial value for the dropdown rather
  // than the device locale.
  final String? initialLanguage;

  // If given this will override the default functionality where it sets the
  // app and DB level locale settings. This is expected to take in a language
  // string and return a locale.
  final Locale Function(String)? onChanged;

  LanguageDropdownState(
      {required this.asPopUpMenu,
      required this.includeDeviceDefaultOption,
      this.initialLanguage,
      this.onChanged});

  Locale? widgetLocaleOverride;
  late Future<void> initStateAsyncFuture;

  @override
  void initState() {
    initStateAsyncFuture = initStateAsync();
    super.initState();
  }

  Future<void> initStateAsync() async {
    widgetLocaleOverride = await LocaleOverride.getLocaleOverride();
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
    if (asPopUpMenu) {
      return buildPopUpMenu(context);
    } else {
      return buildDropdown(context);
    }
  }

  Widget buildPopUpMenu(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.language,
      ),
      itemBuilder: (BuildContext context) {
        // Build list of possible languages.
        List<PopupMenuItem<String>> languageOptions = [];

        // Add system locale.
        if (includeDeviceDefaultOption) {
          languageOptions.add(PopupMenuItem<String>(
              value: NO_OVERRIDE_KEY,
              child: Text(AppLocalizations.of(context).deviceDefault)));
        }

        // Add the rest of the language options.
        languageOptions.addAll(LANGUAGE_TO_LOCALE.keys.map((String language) {
          return PopupMenuItem<String>(
            value: language,
            child: Text(language),
          );
        }).toList());

        return languageOptions;
      },
      onSelected: onChanged,
    );
  }

  Widget buildDropdown(BuildContext context) {
    // Build list of possible languages.
    List<DropdownMenuItem<String>> languageOptions = [];

    // Add system locale.
    if (includeDeviceDefaultOption) {
      languageOptions.add(DropdownMenuItem<String>(
          value: NO_OVERRIDE_KEY,
          child: Text(AppLocalizations.of(context).deviceDefault)));
    }

    // Add the rest of the language options.
    languageOptions.addAll(LANGUAGE_TO_LOCALE.keys.map((String language) {
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

          // Determine which option should be selected.
          String selectedLanguageOption;
          if (initialLanguage != null) {
            selectedLanguageOption = initialLanguage!;
          } else if (widgetLocaleOverride != null) {
            selectedLanguageOption = LOCALE_TO_LANGUAGE[widgetLocaleOverride]!;
          } else {
            selectedLanguageOption = NO_OVERRIDE_KEY;
          }

          return DropdownButton<String>(
            value: selectedLanguageOption,
            items: languageOptions,
            onChanged: (String? newValue) async {
              Locale? newLocale;
              if (onChanged != null) {
                newLocale = onChanged!(newValue!);
              } else {
                newLocale = await setLocale(newValue!);
              }
              setState(() {
                if (newLocale != null) {
                  widgetLocaleOverride = newLocale;
                } else {
                  widgetLocaleOverride = null;
                }
              });
            },
          );
        });
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
