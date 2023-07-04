import 'dart:io' show HttpClient, HttpOverrides, SecurityContext;

import 'package:flutter/material.dart';
import 'package:slsl_dictionary/advisories.dart';

import 'common.dart';
import 'globals.dart';

// When the app fails to load we show this widget instead.
class ErrorFallback extends StatelessWidget {
  final Object error;
  final StackTrace stackTrace;

  ErrorFallback({required this.error, required this.stackTrace});

  @override
  Widget build(BuildContext context) {
    Widget advisoryWidget;
    if (advisoriesResponse == null) {
      advisoryWidget = Container();
    } else {
      advisoryWidget = getAdvisoriesInner();
    }
    List<Widget> children = [
      Text(
        // AppLocalizations.of(context).startupFailureMessage,
        "Failed to start the app correctly. First, please confirm you are using the latest version of the app. If you are, please email daniel@dport.me with a screenshot showing this error.",
        textAlign: TextAlign.center,
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      Padding(padding: EdgeInsets.only(top: 20)),
      advisoryWidget,
      Text(
        "$error",
        textAlign: TextAlign.center,
      ),
      Text(
        "$stackTrace",
      ),
    ];
    try {
      String s = "";
      for (String key in sharedPreferences.getKeys()) {
        s += "$key: ${sharedPreferences.get(key).toString()}\n";
      }
      children.add(Text(
        s,
        textAlign: TextAlign.left,
      ));
    } catch (e) {
      children.add(Text("Failed to get shared prefs: $e"));
    }
    return MaterialApp(
        title: APP_NAME,
        debugShowCheckedModeBanner: false,
        home: Scaffold(
            body: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: children,
        )));
  }
}

class ProxiedHttpOverrides extends HttpOverrides {
  String? _port;
  String? _host;
  ProxiedHttpOverrides(this._host, this._port);

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      // Set proxy
      ..findProxy = (uri) {
        return _host != null ? "PROXY $_host:$_port;" : 'DIRECT';
      };
  }
}
