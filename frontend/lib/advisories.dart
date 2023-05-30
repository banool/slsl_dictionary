import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:http/http.dart' as http;

import 'common.dart';
import 'globals.dart';

class Advisory {
  String date;
  List<String> lines;

  MarkdownBody asMarkdown() {
    return MarkdownBody(data: lines.join("\n"));
  }

  Advisory({
    required this.date,
    required this.lines,
  });
}

class AdvisoriesResponse {
  List<Advisory> advisories;
  bool newAdvisories;

  AdvisoriesResponse({
    required this.advisories,
    required this.newAdvisories,
  });
}

// Returns the advisories and whether there is a new advisory. It returns them
// in order from old to new. If we failed to lookup the advisories we return
// null.
Future<AdvisoriesResponse?> getAdvisories() async {
  // Pull the number of advisories we've seen in the past from storage.
  int numKnownAdvisories = sharedPreferences.getInt(KEY_ADVISORY_VERSION) ?? 0;

  // Get the advisories file.
  String? rawData;
  try {
    String url =
        'https://raw.githubusercontent.com/banool/slsl_dictionary/main/frontend/assets/advisories.md';
    var result = await http.get(Uri.parse(url)).timeout(Duration(seconds: 4));
    rawData = result.body;
  } catch (e) {
    print("Failed to get advisory: $e");
    return null;
  }

  // Each advisory is a list of strings, the lines from within the section.
  List<Advisory> advisories = [];
  var inSection = false;
  List<String> currentLines = [];
  String? currentDate;
  for (var line in rawData.split("\n")) {
    // Skip comment lines.
    if (line.startsWith("////")) {
      continue;
    }

    // Skip empty lines if we're not in a action.
    if (line.length == 1 && line.endsWith("\n") && !inSection) {
      continue;
    }

    // Handle the start of a section.
    if (line.startsWith("START===")) {
      inSection = true;
      continue;
    }

    // Handle the end of a section.
    if (line.startsWith("END===")) {
      advisories.add(new Advisory(date: currentDate!, lines: currentLines));
      currentLines = [];
      currentDate = null;
      inSection = false;
      continue;
    }

    // Handle the date.
    if (line.startsWith("DATE===")) {
      currentDate = line.substring("DATE===".length);
      continue;
    }

    if (inSection) {
      currentLines.add(line);
    }
  }

  bool newAdvisories = numKnownAdvisories < advisories.length;

  // Write back the new latest advisories version we'v seen.
  await sharedPreferences.setInt(KEY_ADVISORY_VERSION, advisories.length);

  return new AdvisoriesResponse(
      advisories: advisories, newAdvisories: newAdvisories);
}
