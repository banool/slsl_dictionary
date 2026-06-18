import 'package:dictionarylib/common.dart';
import 'package:dictionarylib/entry_types.dart';
import 'package:dictionarylib/error_fallback.dart';
import 'package:dictionarylib/flashcards_logic.dart';
import 'package:dictionarylib/globals.dart';
import 'package:dictionarylib/page_force_upgrade.dart';
import 'package:dictionarylib/sharing/sharing_config.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit/media_kit.dart';
import 'package:slsl_dictionary/common.dart';
import 'package:slsl_dictionary/entries_loader.dart';
import 'package:intl/intl_standalone.dart';

import 'globals.dart';
import 'language_dropdown.dart';
import 'root.dart';

// TODO: More elegantly handle startup when there is no local data cache
// and loading data from the internet fails.

const String KNOB_URL_BASE =
    "https://raw.githubusercontent.com/banool/slsl_dictionary/main/frontend/assets/knobs/";

/// Debug-only override: fetch the dictionary **dump** from a locally-running
/// admin backend instead of the prod bucket. Set e.g.
/// `--dart-define=DEBUG_BACKEND_BASE_URL=http://127.0.0.1:8080`. When set (and
/// only in debug builds — it's ignored in release), the dump is fetched from
/// `<base>/dump` (the admin's dump endpoint). **Media is NOT redirected** — it
/// still resolves from the prod CDN / bucket, because (a) the local dev backend
/// doesn't serve media at all, and (b) that way the videos in your local data
/// actually play, as long as they reference real filenames that exist in the
/// bucket. Empty by default. Note: on iOS the simulator still needs an ATS
/// exception to allow the cleartext-HTTP dump fetch from localhost (see
/// VIDEO_VERSIONING_TESTING.md).
const String _kDebugBackendBaseUrlRaw =
    String.fromEnvironment("DEBUG_BACKEND_BASE_URL");

/// The above, normalised (trailing slash stripped) and gated on debug mode.
/// Empty string means "not set / release build" → use the prod URLs.
String get _debugBackendBaseUrl {
  if (!kDebugMode || _kDebugBackendBaseUrlRaw.isEmpty) return "";
  return _kDebugBackendBaseUrlRaw.endsWith("/")
      ? _kDebugBackendBaseUrlRaw.substring(
          0, _kDebugBackendBaseUrlRaw.length - 1)
      : _kDebugBackendBaseUrlRaw;
}

// Setup the app. Be careful when reordering things here, later functions
// implicitly depend on the side effects of earlier functions.
Future<void> setup({Set<Entry>? entriesGlobalReplacement}) async {
  var widgetsBinding = WidgetsFlutterBinding.ensureInitialized();

  // Initialize media_kit for video playback (native only; web plays via the
  // HTML5 video_player path in dictionarylib).
  if (!kIsWeb) {
    MediaKit.ensureInitialized();
  }

  // Preserve the splash screen while the app initializes. Native only —
  // there's no web splash configured, so calling this on web throws.
  if (!kIsWeb) {
    FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  }

  // This just loads the package info, which we need for the yanked version
  // checker.
  await setupPhaseOne();

  // It is okay to check for yanked versions and do phase two setup at the same
  // time because phase two setup never throws. We want to do them together
  // because they both make network calls, so we can do them concurrently.
  await Future.wait<void>([
    (() async {
      // Do common setup stuff defined in dictionarylib.
      await setupPhaseTwo(Uri.parse(
          "https://raw.githubusercontent.com/banool/slsl_dictionary/main/frontend/assets/advisories.md"));
    })(),
    (() async {
      // If the user needs to upgrade, this will throw a specific error that
      // main() can catch to show the ForceUpgradePage.
      await GitHubYankedVersionChecker(
              "https://raw.githubusercontent.com/banool/slsl_dictionary/main/frontend/assets/yanked_versions")
          .throwIfShouldUpgrade();
    })(),
    // Get knob values.
    (() async =>
        useCdnUrl = await readKnob(KNOB_URL_BASE, "use_cdn_url", true))(),
  ]);

  // Configure how saved-video paths resolve to playable URLs. A saved video's
  // identity is the media path (see MySubEntry.getMedia in entries_types.dart);
  // the playable URL is `mediaBaseUrls.first + path`. Order the bases by the
  // useCdnUrl knob so playback prefers the CDN when it's on, while keeping both
  // listed so a path saved under one host still resolves (and legacy full URLs
  // strip) under the other. Must be set before setupPhaseThree so the list
  // migration can resolve / strip it.
  mediaBaseUrls = useCdnUrl
      ? const [DATA_URL_PREFIX_CDN, DATA_URL_PREFIX_DIRECT]
      : const [DATA_URL_PREFIX_DIRECT, DATA_URL_PREFIX_CDN];

  // Debug-only: DEBUG_BACKEND_BASE_URL redirects ONLY the dump fetch to a local
  // backend; media keeps resolving from the bucket/CDN above (the local dev
  // backend doesn't serve media, and this lets real video filenames play).
  final debugBackend = _debugBackendBaseUrl;
  if (debugBackend.isNotEmpty) {
    printAndLog("DEBUG_BACKEND_BASE_URL set: fetching the dump from "
        "$debugBackend/dump (media still resolves from the prod CDN)");
  }
  MyEntryLoader myEntryLoader = MyEntryLoader(
    dumpFileUrl: debugBackend.isNotEmpty
        ? Uri.parse("$debugBackend/dump")
        : Uri.parse(buildUrl("dump/dump.json")),
  );

  // Do the rest of the common stuff defined in dictionarylib. This will set
  // the entryLoader global value with what we pass in so we don't have to do
  // it ourselves.
  await setupPhaseThree(
      paramEntryLoader: myEntryLoader,
      knobUrlBase: KNOB_URL_BASE,
      entriesGlobalReplacement: entriesGlobalReplacement);

  // One-shot migration of stored DolphinSR flashcard review history from the
  // older master-id shape to the current per-saved-video shape. No-op after the
  // first successful run. Must run after setupPhaseThree because it walks the
  // dictionary to resolve legacy master ids. SLSL just moved to the per-saved-
  // video flashcard engine, so existing users' review history needs this.
  await migrateLegacyReviewsIfNeeded();

  // Opt in to the shared-lists feature. Runs after phase three because the
  // synced-list manager resolves owner-share metadata against
  // userEntryListManager, which phase three initializes.
  //   apiBaseUrl     — Cloudflare Worker (JSON API)
  //   shareLinkHost  — static site (where share URLs land, where the App Link /
  //                    Universal Link manifests live)
  //   auth           — OAuth client ids per provider. Each must match the
  //                    corresponding Worker env (APPLE_AUDIENCES,
  //                    GOOGLE_AUDIENCES, MICROSOFT_CLIENT_ID). See
  //                    MANUAL_SETUP.md in the private backend repo. Values left
  //                    empty / commented are pending OAuth provisioning — until
  //                    then that provider's button errors or is hidden, but the
  //                    rest of sharing (including the debug test sign-in) works.
  await setupSharing(const SharingConfig(
    appId: 'slsl',
    appName: 'SLSL Dictionary',
    apiBaseUrl: 'https://api.srilankansignlanguage.org',
    shareLinkBaseUrl: 'https://share.srilankansignlanguage.org/l',
    shareLinkHost: 'share.srilankansignlanguage.org',
    urlScheme: 'slsl',
    auth: SharingAuthConfig(
      // iOS bundle id (the Apple `aud` on iOS Sign in with Apple). Must match
      // an entry in the Worker's APPLE_AUDIENCES. Apple sign-in additionally
      // needs the "Sign in with Apple" capability enabled in Xcode (manual).
      appleBundleId: 'com.banool.slsldictionary',
      // Apple Services ID + callback for the Android Sign in with Apple web
      // flow. Must match the Services ID registered in Apple Developer and the
      // entry added to the Worker's APPLE_AUDIENCES. iOS Apple sign-in is native
      // (uses appleBundleId above) and needs none of this.
      appleServicesId: 'com.banool.slslsignin',
      appleRedirectUri:
          'https://share.srilankansignlanguage.org/v1/apple-callback',
      // Google OAuth **Web** client id (the `aud` Android Credential Manager
      // mints ID tokens against; must be in the Worker's GOOGLE_AUDIENCES). iOS
      // additionally uses the iOS client via GIDClientID in Info.plist. The
      // Android OAuth clients (Play/upload/debug) only need to exist in the
      // console for attestation — never referenced in code.
      googleServerClientId:
          '587061140913-j0bunrlavqo2ds5et1ai1kq9rumgdngc.apps.googleusercontent.com',
      // Facebook is globally disabled (kill switch); kept empty.
      facebookAppId: '',
      // Microsoft Entra application (client) id + per-keystore Android redirect
      // URIs (URL-encoded base64 SHA-1; the raw form is in AndroidManifest's
      // BrowserTabActivity). The sign-in wrapper picks whichever matches the
      // running build's signature. Must match the Worker's MICROSOFT_CLIENT_ID
      // and the Azure app registration. See MANUAL_SETUP.md §4.
      microsoftClientId: 'ddf08a6a-a354-4122-8e72-e07f71f4355d',
      microsoftAndroidRedirectUri:
          'msauth://com.banool.slsl_dictionary/NteHMzzGTBV9TlUL3U7Iu2zFr6w%3D',
      microsoftAndroidUploadRedirectUri:
          'msauth://com.banool.slsl_dictionary/x7LGJXVDC1TRVjvRFCUCvufX%2FwQ%3D',
      microsoftAndroidDebugRedirectUri:
          'msauth://com.banool.slsl_dictionary/mLnUCgy8ygvZ%2B2jXJtHai%2FNmrCw%3D',
    ),
    // Debug-only "Sign in as test user" button (kDebugMode + non-empty token).
    // Pass --dart-define=TEST_AUTH_TOKEN=... matching the `wrangler dev`/staging
    // env so the full shared-lists flow can be driven without real accounts.
    testSignIn: TestSignInConfig(
      testAuthToken:
          String.fromEnvironment('TEST_AUTH_TOKEN', defaultValue: ''),
      defaultUserIdPrefix: 'test:slsl-dev',
      defaultDisplayName: 'SLSL Tester',
    ),
  ));

  // Remove the splash screen (native only; see preserve above).
  if (!kIsWeb) {
    FlutterNativeSplash.remove();
  }

  // Finally run the app.
  printAndLog("Setup complete, running app");
}

Future<void> main() async {
  // Clean web URLs (e.g. /share/<id>) instead of the default hash routing, so
  // the share-link deep routes resolve. No-op on mobile. The web boot/loading
  // indication lives in web/index.html, which Flutter replaces on its first
  // frame without touching routing (so we deliberately do a single runApp()).
  if (kIsWeb) {
    usePathUrlStrategy();
    // go_router only reflects go() in the browser URL by default; push /
    // replace (how an entry page opens) need this too.
    GoRouter.optionURLReflectsImperativeAPIs = true;
  }
  printAndLog("Start of main");
  try {
    await setup();

    systemLocale = Locale(await findSystemLocale());
    Locale locale;
    Locale? localeOverride = await LocaleOverride.getLocaleOverride();
    if (localeOverride != null) {
      locale = localeOverride;
      printAndLog("Using locale override: $locale");
    } else {
      printAndLog("Using system locale: $systemLocale");
      locale = systemLocale;
    }
    // We can only handle these 3 locales, if the system locale is something
    // else we fall back to English.
    if (!localeIsSupported(locale)) {
      locale = LOCALE_ENGLISH;
      printAndLog("Locale not supported, falling back to English: $locale");
    }
    runApp(RootApp(startingLocale: locale));
  } on YankedVersionError catch (e) {
    runApp(ForceUpgradePage(
        error: e, iOSAppId: IOS_APP_ID, androidAppId: ANDROID_APP_ID));
  } catch (error, stackTrace) {
    runApp(ErrorFallback(
      appName: APP_NAME,
      error: error,
      stackTrace: stackTrace,
    ));
  }
}
