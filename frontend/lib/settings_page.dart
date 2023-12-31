import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:launch_review/launch_review.dart';
import 'package:mailto/mailto.dart';
import 'package:settings_ui/settings_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import 'common.dart';
import 'entries_loader.dart';
import 'flashcards_logic.dart';
import 'globals.dart';
import 'language_dropdown.dart';
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
    String? appStoreTileString;
    if (kIsWeb) {
      appStoreTileString = null;
    } else if (Platform.isAndroid) {
      appStoreTileString =
          AppLocalizations.of(context)!.settingsPlayStoreFeedback;
    } else if (Platform.isIOS) {
      appStoreTileString =
          AppLocalizations.of(context)!.settingsAppStoreFeedback;
    }

    EdgeInsetsDirectional margin =
        EdgeInsetsDirectional.only(start: 15, end: 15, top: 10, bottom: 10);

    SettingsSection? featuresSection;
    if (enableFlashcardsKnob && !getShouldUseHorizontalLayout(context)) {
      featuresSection = SettingsSection(
        title: Text(AppLocalizations.of(context)!.settingsRevision),
        tiles: [
          SettingsTile.switchTile(
            title: Text(
              AppLocalizations.of(context)!.settingsHideRevision,
              style: TextStyle(fontSize: 15),
            ),
            initialValue:
                sharedPreferences.getBool(KEY_HIDE_FLASHCARDS_FEATURE) ?? false,
            onToggle: onChangeHideFlashcardsFeature,
          ),
          SettingsTile.navigation(
              title: getText(
                AppLocalizations.of(context)!.settingsDeleteRevisionProgress,
              ),
              trailing: Container(),
              onPressed: (BuildContext context) async {
                bool confirmed = await confirmAlert(
                    context,
                    Text(AppLocalizations.of(context)!
                        .settingsDeleteRevisionProgressExplanation));
                if (confirmed) {
                  await writeReviews([], [], force: true);
                  await sharedPreferences.setInt(KEY_RANDOM_REVIEWS_COUNTER, 0);
                  await sharedPreferences.remove(KEY_FIRST_RANDOM_REVIEW);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(
                        AppLocalizations.of(context)!.settingsProgressDeleted),
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
        title: Text(AppLocalizations.of(context)!.settingsCache),
        tiles: [
          SettingsTile.switchTile(
            title: Text(
              AppLocalizations.of(context)!.settingsCacheVideos,
              style: TextStyle(fontSize: 15),
            ),
            initialValue: sharedPreferences.getBool(KEY_SHOULD_CACHE) ?? true,
            onToggle: onChangeShouldCache,
          ),
          SettingsTile.navigation(
              title: getText(AppLocalizations.of(context)!.settingsDropCache),
              trailing: Container(),
              onPressed: (BuildContext context) async {
                await myCacheManager.emptyCache();
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content:
                      Text(AppLocalizations.of(context)!.settingsCacheDropped),
                  backgroundColor: MAIN_COLOR,
                ));
              }),
        ],
        margin: margin,
      ),
      SettingsSection(
        title: Text(AppLocalizations.of(context)!.settingsData),
        tiles: [
          SettingsTile.navigation(
            title: getText(AppLocalizations.of(context)!.settingsCheckNewData),
            trailing: Container(),
            onPressed: (BuildContext context) async {
              bool thereWasNewData = await updateWordsData(true);
              String message;
              if (thereWasNewData) {
                message = AppLocalizations.of(context)!.settingsDataUpdated;
              } else {
                message = AppLocalizations.of(context)!.settingsDataUpToDate;
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
        title: Text(AppLocalizations.of(context)!.settingsLegal),
        tiles: [
          SettingsTile.navigation(
            title: getText(AppLocalizations.of(context)!.settingsSeeLegal),
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
          title: Text(AppLocalizations.of(context)!.settingsHelp),
          tiles: [
            SettingsTile.navigation(
              title: getText(AppLocalizations.of(context)!
                  .settingsReportDictionaryDataIssue),
              trailing: Container(),
              onPressed: (BuildContext context) async {
                var url =
                    'https://github.com/banool/slsl_dictionary/issues/new/choose';
                await launch(url, forceSafariVC: false);
              },
            ),
            SettingsTile.navigation(
              title: getText(
                  AppLocalizations.of(context)!.settingsReportAppIssueGithub),
              trailing: Container(),
              onPressed: (BuildContext context) async {
                var url = 'https://github.com/banool/slsl_dictionary/issues';
                await launch(url, forceSafariVC: false);
              },
            ),
            SettingsTile.navigation(
              title: getText(
                  AppLocalizations.of(context)!.settingsReportAppIssueEmail),
              trailing: Container(),
              onPressed: (BuildContext context) async {
                var mailto = Mailto(
                    to: ['d@dport.me'],
                    subject: 'Issue with SLSL Dictionary',
                    body:
                        'Please describe the issue in detail.\n\n--> Replace with description of issue <--\n\n${getBugInfo()}\nBackground logs:\n${backgroundLogs.items.join("\n")}\n');
                String url = "$mailto";
                if (await canLaunch(url)) {
                  await launch(url);
                } else {
                  printAndLog('Could not launch $url');
                }
              },
            ),
            appStoreTileString != null
                ? SettingsTile.navigation(
                    title: getText(appStoreTileString),
                    trailing: Container(),
                    onPressed: (BuildContext context) async {
                      await LaunchReview.launch(
                          iOSAppId: "6445848879", writeReview: true);
                    },
                  )
                : null,
            SettingsTile.navigation(
                title: getText(
                    AppLocalizations.of(context)!.settingsBackgroundLogs),
                trailing: Container(),
                onPressed: (BuildContext context) async {
                  return await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BackgroundLogsPage(),
                      ));
                }),
          ].where((element) => element != null).cast<SettingsTile>().toList(),
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
        padding: EdgeInsets.only(left: 35, top: 15),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            AppLocalizations.of(context)!.settingsLanguage,
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
        title: AppLocalizations.of(context)!.settingsTitle,
        actions: actions);
  }
}

String getBugInfo() {
  String info = "Package and device info:\n";
  if (packageInfo != null) {
    info += "App version: ${packageInfo!.version}\n";
    info += "Build number: ${packageInfo!.buildNumber}\n";
  }
  if (iosDeviceInfo != null) {
    info += "Device: ${iosDeviceInfo!.name}\n";
    info += "Model: ${iosDeviceInfo!.model}\n";
    info += "System name: ${iosDeviceInfo!.systemName}\n";
    info += "System version: ${iosDeviceInfo!.systemVersion}\n";
  }
  if (androidDeviceInfo != null) {
    info += "Device: ${androidDeviceInfo!.device}\n";
    info += "Model: ${androidDeviceInfo!.model}\n";
    info += "System name: ${androidDeviceInfo!.version.release}\n";
    info += "System version: ${androidDeviceInfo!.version.sdkInt}\n";
  }
  return info;
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
                      "The Sri Lankan Sign Language data displayed in this app is provided by Nishani Shamila McCluskey and team.\n",
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

class BackgroundLogsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text("Background Logs"),
        ),
        body: Padding(
            padding: EdgeInsets.only(bottom: 10, left: 20, right: 32, top: 20),
            child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                mainAxisSize: MainAxisSize.max,
                children: [
                  TextButton(
                    child: Text("Copy logs to clipboard",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: MAIN_COLOR)),
                    onPressed: () async {
                      await Clipboard.setData(
                          ClipboardData(text: backgroundLogs.items.join("\n")));
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text("Logs copied to clipboard"),
                          backgroundColor: MAIN_COLOR));
                    },
                  ),
                  Container(
                    padding: EdgeInsets.only(top: 10),
                  ),
                  Expanded(
                      child: SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          child: Text(backgroundLogs.items.join("\n"),
                              style: TextStyle(
                                  height:
                                      1.8 //You can set your custom height here
                                  )))),
                ])));
  }
}
