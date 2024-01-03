import 'package:dictionarylib/common.dart';
import 'package:dictionarylib/entry_types.dart';
import 'package:dictionarylib/globals.dart';
import 'package:flutter/material.dart';
import 'package:dictionarylib/dictionarylib.dart'
    show AppLocalizations, LANGUAGE_CODE_TO_LOCALE;
import 'package:slsl_dictionary/root.dart';


const String NO_OVERRIDE_KEY = "NO_OVERRIDE";

class LanguageDropdown extends StatefulWidget {
  const LanguageDropdown(
      {super.key,
      this.asPopUpMenu = false,
      this.includeDeviceDefaultOption = true,
      this.initialLanguageCode,
      this.onChanged});

  final bool asPopUpMenu;
  final bool includeDeviceDefaultOption;
  final String? initialLanguageCode;
  final Locale Function(String)? onChanged;

  @override
  LanguageDropdownState createState() => LanguageDropdownState(
      asPopUpMenu: asPopUpMenu,
      includeDeviceDefaultOption: includeDeviceDefaultOption,
      initialLanguageCode: initialLanguageCode,
      onChanged: onChanged);
}

class LanguageDropdownState extends State<LanguageDropdown> {
  final bool asPopUpMenu;
  final bool includeDeviceDefaultOption;

  // If given, this will be used as the initial value for the dropdown rather
  // than the device locale.
  final String? initialLanguageCode;

  // If given this will override the default functionality where it sets the
  // app and DB level locale settings. This is expected to take in a language
  // string and return a locale.
  final Locale Function(String)? onChanged;

  LanguageDropdownState(
      {required this.asPopUpMenu,
      required this.includeDeviceDefaultOption,
      this.initialLanguageCode,
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
    Locale localeOverride = LANGUAGE_CODE_TO_LOCALE[language]!;
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
      icon: const Icon(
        Icons.language,
      ),
      itemBuilder: (BuildContext context) {
        // Build list of possible languages.
        List<PopupMenuItem<String>> languageOptions = [];

        // Add system locale.
        if (includeDeviceDefaultOption) {
          languageOptions.add(PopupMenuItem<String>(
              value: NO_OVERRIDE_KEY,
              child: Text(AppLocalizations.of(context)!.deviceDefault)));
        }

        // Add the rest of the language options.
        languageOptions
            .addAll(LANGUAGE_CODE_TO_PRETTY.entries.map((MapEntry e) {
          return PopupMenuItem<String>(
            value: e.key,
            child: Text(e.value),
          );
        }).toList());

        return languageOptions;
      },
      onSelected: onChanged,
    );
  }

  Widget buildDropdown(BuildContext context) {
    Locale currentLocale = Localizations.localeOf(context);

    // Build list of possible languages.
    List<DropdownMenuItem<String>> languageOptions = [];

    // Add system locale.
    if (includeDeviceDefaultOption) {
      languageOptions.add(DropdownMenuItem<String>(
          value: NO_OVERRIDE_KEY,
          child: Text(AppLocalizations.of(context)!.deviceDefault)));
    }

    // Add the rest of the language options.
    languageOptions.addAll(LANGUAGE_CODE_TO_PRETTY.entries.map((MapEntry e) {
      return DropdownMenuItem<String>(
        value: e.key,
        child: Text(e.value),
      );
    }).toList());

    return FutureBuilder(
        future: initStateAsyncFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          // Determine which option should be selected. Either a language code
          // or NO_OVERRIDE_KEY.
          String selectedLanguageCode;
          if (initialLanguageCode != null) {
            selectedLanguageCode = initialLanguageCode!;
          } else if (widgetLocaleOverride != null) {
            selectedLanguageCode = widgetLocaleOverride!.languageCode;
          } else if (includeDeviceDefaultOption) {
            selectedLanguageCode = NO_OVERRIDE_KEY;
          } else {
            selectedLanguageCode = currentLocale.languageCode;
          }

          return DropdownButton<String>(
            value: selectedLanguageCode,
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
    sharedPreferences.setString(KEY_LOCALE_OVERRIDE, locale.languageCode);
  }

  static Future<void> clearLocaleOverride() async {
    sharedPreferences.remove(KEY_LOCALE_OVERRIDE);
  }

  static Future<Locale?> getLocaleOverride() async {
    var languageCode = sharedPreferences.getString(KEY_LOCALE_OVERRIDE);
    if (languageCode == null) {
      return null;
    }
    return Locale(languageCode);
  }
}
