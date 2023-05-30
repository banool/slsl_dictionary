import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:launch_review/launch_review.dart';
import 'package:mailto/mailto.dart';
import 'package:settings_ui/settings_ui.dart';
import 'package:slsl_dictionary/root.dart';
import 'package:url_launcher/url_launcher.dart';

import 'common.dart';
import 'entries_loader.dart';
import 'entries_types.dart';
import 'flashcards_logic.dart';
import 'globals.dart';
import 'settings_help_page.dart';
import 'top_level_scaffold.dart';

class SettingsPage extends StatefulWidget {
  @override
  SettingsPageState createState() => SettingsPageState();
}

class SettingsPageState extends State<SettingsPage> {
  void onChangeShouldCache(bool newValue) {
    setState(() {
      sharedPreferences.setBool(KEY_SHOULD_CACHE, newValue);
    });
  }

  void onChangeHideFlashcardsFeature(bool newValue) {
    setState(() {
      sharedPreferences.setBool(KEY_HIDE_FLASHCARDS_FEATURE, newValue);
      //myHomePageController.toggleFlashcards(newValue);
    });
  }

  @override
  Widget build(BuildContext context) {
    String appStoreTileString;
    if (Platform.isAndroid) {
      appStoreTileString =
          AppLocalizations.of(context).settingsPlayStoreFeedback;
    } else if (Platform.isIOS) {
      appStoreTileString =
          AppLocalizations.of(context).settingsAppStoreFeedback;
    } else {
      appStoreTileString = AppLocalizations.of(context).na;
    }

    EdgeInsetsDirectional margin =
        EdgeInsetsDirectional.only(start: 15, end: 15, top: 10, bottom: 10);

    SettingsSection? featuresSection;
    if (enableFlashcardsKnob && !getShouldUseHorizontalLayout(context)) {
      featuresSection = SettingsSection(
        title: Text(AppLocalizations.of(context).settingsRevision),
        tiles: [
          SettingsTile.switchTile(
            title: Text(
              AppLocalizations.of(context).settingsHideRevision,
              style: TextStyle(fontSize: 15),
            ),
            initialValue:
                sharedPreferences.getBool(KEY_HIDE_FLASHCARDS_FEATURE) ?? false,
            onToggle: onChangeHideFlashcardsFeature,
          ),
          SettingsTile.navigation(
              title: getText(
                AppLocalizations.of(context).settingsDeleteRevisionProgress,
              ),
              trailing: Container(),
              onPressed: (BuildContext context) async {
                bool confirmed = await confirmAlert(
                    context,
                    Text(AppLocalizations.of(context)
                        .settingsDeleteRevisionProgressExplanation));
                if (confirmed) {
                  await writeReviews([], [], force: true);
                  await sharedPreferences.setInt(KEY_RANDOM_REVIEWS_COUNTER, 0);
                  await sharedPreferences.remove(KEY_FIRST_RANDOM_REVIEW);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(
                        AppLocalizations.of(context).settingsProgressDeleted),
                    backgroundColor: MAIN_COLOR,
                  ));
                }
              }),
        ],
        margin: margin,
      );
    }

    List<AbstractSettingsSection?> sections = [
      SettingsSection(
        title: Text(AppLocalizations.of(context).settingsCache),
        tiles: [
          SettingsTile.switchTile(
            title: Text(
              AppLocalizations.of(context).settingsCacheVideos,
              style: TextStyle(fontSize: 15),
            ),
            initialValue: sharedPreferences.getBool(KEY_SHOULD_CACHE) ?? true,
            onToggle: onChangeShouldCache,
          ),
          SettingsTile.navigation(
              title: getText(AppLocalizations.of(context).settingsDropCache),
              trailing: Container(),
              onPressed: (BuildContext context) async {
                await videoCacheManager.emptyCache();
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content:
                      Text(AppLocalizations.of(context).settingsCacheDropped),
                  backgroundColor: MAIN_COLOR,
                ));
              }),
        ],
        margin: margin,
      ),
      SettingsSection(
        title: Text(AppLocalizations.of(context).settingsData),
        tiles: [
          SettingsTile.navigation(
            title: getText(AppLocalizations.of(context).settingsCheckNewData),
            trailing: Container(),
            onPressed: (BuildContext context) async {
              bool updated = await getNewData(true);
              String message;
              if (updated) {
                entriesGlobal = await loadEntries();
                updateKeyedEntriesGlobal();
                message = AppLocalizations.of(context).settingsDataUpdated;
              } else {
                message = AppLocalizations.of(context).settingsDataUpToDate;
              }
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(message), backgroundColor: MAIN_COLOR));
            },
          )
        ],
        margin: margin,
      ),
      featuresSection,
      SettingsSection(
        title: Text(AppLocalizations.of(context).settingsLegal),
        tiles: [
          SettingsTile.navigation(
            title: getText(AppLocalizations.of(context).settingsSeeLegal),
            trailing: Container(),
            onPressed: (BuildContext context) async {
              return await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => LegalInformationPage(),
                  ));
            },
          )
        ],
        margin: margin,
      ),
      SettingsSection(
          title: Text(AppLocalizations.of(context).settingsHelp),
          tiles: [
            SettingsTile.navigation(
              title: getText(AppLocalizations.of(context)
                  .settingsReportDictionaryDataIssue),
              trailing: Container(),
              onPressed: (BuildContext context) async {
                var url = 'https://www.auslan.org.au/feedback/';
                await launch(url, forceSafariVC: false);
              },
            ),
            SettingsTile.navigation(
              title: getText(
                  AppLocalizations.of(context).settingsReportAppIssueGithub),
              trailing: Container(),
              onPressed: (BuildContext context) async {
                var url = 'https://github.com/banool/auslan_dictionary/issues';
                await launch(url, forceSafariVC: false);
              },
            ),
            SettingsTile.navigation(
              title: getText(
                  AppLocalizations.of(context).settingsReportAppIssueEmail),
              trailing: Container(),
              onPressed: (BuildContext context) async {
                var mailto = Mailto(
                    to: ['danielporteous1@gmail.com'],
                    subject: 'Issue with SLSL Dictionary',
                    body:
                        'Please tell me what device you are using and describe the issue in detail. Thanks!');
                String url = "$mailto";
                if (await canLaunch(url)) {
                  await launch(url);
                } else {
                  print('Could not launch $url');
                }
              },
            ),
            SettingsTile.navigation(
              title: getText(appStoreTileString),
              trailing: Container(),
              onPressed: (BuildContext context) async {
                await LaunchReview.launch(iOSAppId: "todo", writeReview: true);
              },
            ),
          ],
          margin: margin),
    ];

    List<AbstractSettingsSection> nonNullSections = [];
    for (AbstractSettingsSection? section in sections) {
      if (section != null) {
        nonNullSections.add(section);
      }
    }

    Widget body =
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: EdgeInsets.only(left: 35, top: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            "Language",
            style: TextStyle(
                fontSize: 13, color: Color.fromARGB(255, 100, 100, 100)),
            textAlign: TextAlign.start,
          ),
          Center(child: LanguageDropdown()),
        ]),
      ),
      Expanded(child: SettingsList(sections: nonNullSections))
    ]);

    List<Widget> actions = [
      buildActionButton(
        context,
        Icon(Icons.help),
        () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => getSettingsHelpPage()),
          );
        },
      )
    ];

    return TopLevelScaffold(
        body: body,
        title: AppLocalizations.of(context).settingsTitle,
        actions: actions);
  }
}

Text getText(String s, {bool larger = false, Color? color}) {
  double size = 15;
  if (larger) {
    size = 18;
  }
  return Text(
    s,
    textAlign: TextAlign.center,
    style: TextStyle(fontSize: size, color: color),
  );
}

// TODO Translate this once we have legal information sorted out.
class LegalInformationPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(APP_NAME),
        ),
        body: Padding(
            padding: EdgeInsets.only(bottom: 10, left: 20, right: 32, top: 20),
            child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                mainAxisSize: MainAxisSize.max,
                children: [
                  Text(
                      "The Auslan information (including videos) displayed in this app is taken from Auslan Signbank (Johnston, T., & Cassidy, S. (2008). Auslan Signbank (auslan.org.au) Sydney: Macquarie University & Trevor Johnston).\n",
                      textAlign: TextAlign.center),
                  Text(
                      "Only some of the information relating to each sign that is found on Auslan Signbank is displayed here in this app. Please consult Auslan Signbank to see the information displayed as originally intended and endorsed by the author. There is a link to Auslan Signbank on each definition.",
                      textAlign: TextAlign.center),
                  Container(
                    padding: EdgeInsets.only(top: 10),
                  ),
                  TextButton(
                    child: Text(
                        "This content is licensed under\nCreative Commons BY-NC-ND 4.0.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: MAIN_COLOR)),
                    onPressed: () async {
                      const url =
                          'https://creativecommons.org/licenses/by-nc-nd/4.0/';
                      await launch(url, forceSafariVC: false);
                    },
                  ),
                ])));
  }
}

// TODO: Use this instead of the other one I created for word page.
class LanguageDropdown extends StatefulWidget {
  LanguageDropdown({Key? key}) : super(key: key);

  @override
  LanguageDropdownState createState() => LanguageDropdownState();
}

class LanguageDropdownState extends State<LanguageDropdown> {
  Locale? localeOverride;
  late Future<void> initStateAsyncFuture;

  static const String NO_OVERRIDE_KEY = "NO_OVERRIDE";

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
    languageDropdownOptions.addAll(LANGUAGE_TO_LOCALE.keys
        .map<DropdownMenuItem<String>>((String language) {
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
