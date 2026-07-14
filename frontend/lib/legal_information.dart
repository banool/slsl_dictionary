import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

List<Widget> buildLegalInformationChildren() {
  return [
    const Text(
        "The Sri Lankan Sign Language data, including videos, images, and definitions, used in this app is provided by Nishani Shamila McCluskey and team.\n",
        textAlign: TextAlign.center),
    Container(
      padding: const EdgeInsets.only(top: 10),
    ),
    TextButton(
      child: Text("This data is licensed under\nCreative Commons BY-NC-ND 4.0.",
          textAlign: TextAlign.center),
      onPressed: () async {
        final url =
            Uri.parse('https://creativecommons.org/licenses/by-nc-nd/4.0/');
        await launchUrl(url, mode: LaunchMode.externalApplication);
      },
    ),
    Container(
      padding: const EdgeInsets.only(top: 10),
    ),
    TextButton(
      child: Text("All app code is licensed under\nGPL v3.",
          textAlign: TextAlign.center),
      onPressed: () async {
        final url = Uri.parse(
            'https://github.com/banool/slsl_dictionary/blob/main/LICENSE');
        await launchUrl(url, mode: LaunchMode.externalApplication);
      },
    ),
  ];
}
