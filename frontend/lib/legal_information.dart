import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

List<Widget> buildLegalInformationChildren(Color mainColor) {
  return [
    const Text(
        "The Sri Lankan Sign Language data, including videos, images, and definitions, used in this app is provided by Nishani Shamila McCluskey and team.\n",
        textAlign: TextAlign.center),
    Container(
      padding: const EdgeInsets.only(top: 10),
    ),
    TextButton(
      child: Text("This data is licensed under\nCreative Commons BY-NC-ND 4.0.",
          textAlign: TextAlign.center, style: TextStyle(color: mainColor)),
      onPressed: () async {
        const url = 'https://creativecommons.org/licenses/by-nc-nd/4.0/';
        await launch(url, forceSafariVC: false);
      },
    ),
    Container(
      padding: const EdgeInsets.only(top: 10),
    ),
    TextButton(
      child: Text("All app code is licensed under\nApache 2.0.",
          textAlign: TextAlign.center, style: TextStyle(color: mainColor)),
      onPressed: () async {
        const url =
            'https://github.com/banool/slsl_dictionary/blob/main/LICENSE.md';
        await launch(url, forceSafariVC: false);
      },
    ),
  ];
}
