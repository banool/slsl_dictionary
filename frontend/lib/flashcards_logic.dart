import 'package:dictionarylib/entry_types.dart';

import 'entries_types.dart';

Map<Entry, List<SubEntry>> filterSubEntries(
    Map<Entry, List<SubEntry>> subEntries,
    List<Region> allowedRegions,
    bool useUnknownRegionSigns,
    bool oneCardPerEntry) {
  Map<Entry, List<SubEntry>> out = Map();

  for (MapEntry<Entry, List<SubEntry>> e in subEntries.entries) {
    List<SubEntry> validSubEntries = [];
    for (SubEntry se in e.value) {
      if (validSubEntries.length > 0 && oneCardPerEntry) {
        break;
      }
      if (se.getRegions().contains(Region.ALL)) {
        validSubEntries.add(se);
        continue;
      }
      if (se.getRegions().length == 0 && useUnknownRegionSigns) {
        validSubEntries.add(se);
        continue;
      }
      for (Region r in se.getRegions()) {
        if (allowedRegions.contains(r)) {
          validSubEntries.add(se);
          break;
        }
      }
    }
    if (validSubEntries.length > 0) {
      out[e.key] = validSubEntries;
    }
  }
  return out;
}
