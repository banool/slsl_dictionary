import 'package:dictionarylib/dictionarylib.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
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

/// SLSL's plug-in points for the shared startup orchestration
/// (setupDictionaryApp / runDictionaryApp in dictionarylib).
final DictAppBootstrapConfig bootstrapConfig = DictAppBootstrapConfig(
  advisoriesUrl: Uri.parse(
      "https://raw.githubusercontent.com/banool/slsl_dictionary/main/frontend/assets/advisories.md"),
  yankedVersionsUrl:
      "https://raw.githubusercontent.com/banool/slsl_dictionary/main/frontend/assets/yanked_versions",
  knobUrlBase: KNOB_URL_BASE,
  extraStartupTasks: [
    // Get knob values (concurrently with the phase-two network calls).
    () async => useCdnUrl = await readKnob(KNOB_URL_BASE, "use_cdn_url", true),
  ],
  setupMediaAndEntryLoader: () async {
    // Configure how saved-video paths resolve to playable URLs. A saved
    // video's identity is the media path (see MySubEntry.getMedia in
    // entries_types.dart); the playable URL is `mediaBaseUrls.first + path`.
    // Order the bases by the useCdnUrl knob so playback prefers the CDN when
    // it's on, while keeping both listed so a path saved under one host still
    // resolves (and legacy full URLs strip) under the other. Must be set
    // before the entry load so the list migration can resolve / strip it.
    mediaBaseUrls = useCdnUrl
        ? const [DATA_URL_PREFIX_CDN, DATA_URL_PREFIX_DIRECT]
        : const [DATA_URL_PREFIX_DIRECT, DATA_URL_PREFIX_CDN];

    // Debug-only: DEBUG_BACKEND_BASE_URL redirects ONLY the dump fetch to a
    // local backend; media keeps resolving from the bucket/CDN above (the
    // local dev backend doesn't serve media, and this lets real video
    // filenames play).
    final debugBackend = _debugBackendBaseUrl;
    if (debugBackend.isNotEmpty) {
      printAndLog("DEBUG_BACKEND_BASE_URL set: fetching the dump from "
          "$debugBackend/dump (media still resolves from the prod CDN)");
    }
    return MyEntryLoader(
      dumpFileUrl: debugBackend.isNotEmpty
          ? Uri.parse("$debugBackend/dump")
          : Uri.parse(buildUrl("dump/dump.json")),
    );
  },
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
  sharingConfig: const SharingConfig(
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
  ),
);

/// Kept as an app-local entrypoint because the shared integration-test suites
/// call it (see integration_test/test_config.dart).
Future<void> setup({Set<Entry>? entriesGlobalReplacement}) =>
    setupDictionaryApp(bootstrapConfig,
        entriesGlobalReplacement: entriesGlobalReplacement);

Future<void> main() => runDictionaryApp(
      bootstrapConfig,
      appName: APP_NAME,
      iOSAppId: IOS_APP_ID,
      androidAppId: ANDROID_APP_ID,
      buildApp: (locale) => RootApp(startingLocale: locale),
      resolveStartingLocale: () async {
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
        // We can only handle these 3 locales, if the system locale is
        // something else we fall back to English.
        if (!localeIsSupported(locale)) {
          locale = LOCALE_ENGLISH;
          printAndLog("Locale not supported, falling back to English: $locale");
        }
        return locale;
      },
    );
