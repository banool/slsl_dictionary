import 'package:dictionarylib/flashcards_logic.dart';
import 'package:dictionarylib/page_flashcards_landing.dart';
import 'package:dictionarylib/revision.dart';
import 'package:dolphinsr_dart/dolphinsr_dart.dart';
import 'package:flutter/material.dart';

import 'flashcards_help_page_en.dart';
import 'flashcards_page.dart';

class MyFlashcardsLandingPageController
    extends FlashcardsLandingPageController {
  @override
  Widget buildFlashcardsPage(
      {required DolphinInformation dolphinInformation,
      required RevisionStrategy revisionStrategy,
      required List<Review> existingReviews}) {
    return FlashcardsPage(
        di: dolphinInformation,
        revisionStrategy: revisionStrategy,
        existingReviews: existingReviews);
  }

  @override
  Widget buildHelpPage(BuildContext context) {
    return getFlashcardsHelpPageEn(context);
  }

  /// Revise every saved video in the chosen lists. SLSL has only two regions
  /// (All of Sri Lanka / North East) and most signs are nationwide, so we
  /// don't filter the pool by region here.
  // TODO: optionally re-add an SLSL region filter (Region.ALL / NORTH_EAST).
  @override
  List<ResolvedSavedVideo> filterSavedVideos(List<ResolvedSavedVideo> videos) {
    return videos;
  }
}
