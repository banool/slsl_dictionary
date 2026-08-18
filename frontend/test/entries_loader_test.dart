import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:slsl_dictionary/entries_loader.dart';

final dumpUrl = Uri.parse(
  'https://cdn.srilankansignlanguage.org/dump/dump.json',
);

MyEntryLoader loaderWith(
  Future<http.Response> Function(http.Request) handler,
) => MyEntryLoader(dumpFileUrl: dumpUrl, client: MockClient(handler));

void main() {
  test('304 means no new data', () async {
    final loader = loaderWith((request) async => http.Response('', 304));
    expect(await loader.downloadNewData(1000, false), null);
  });

  test('200 with Last-Modified yields that version', () async {
    final loader = loaderWith(
      (request) async => http.Response(
        '{"data": []}',
        200,
        headers: {'last-modified': 'Wed, 01 Jan 2025 00:00:00 GMT'},
      ),
    );
    final newData = await loader.downloadNewData(1000, false);
    expect(newData!.data, '{"data": []}');
    // 2025-01-01T00:00:00Z as unix seconds.
    expect(newData.newVersion, 1735689600);
  });

  test('200 without Last-Modified is versioned as roughly now', () async {
    final loader = loaderWith(
      (request) async => http.Response('{"data": []}', 200),
    );
    final newData = await loader.downloadNewData(1000, false);
    final nowSecs = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    expect((newData!.newVersion - nowSecs).abs(), lessThan(60));
  });

  test('other statuses throw', () async {
    final loader = loaderWith((request) async => http.Response('boom', 500));
    await expectLater(loader.downloadNewData(1000, false), throwsException);
  });

  test('If-Modified-Since is sent exactly when not forcing', () async {
    late Map<String, String> seenHeaders;
    final loader = loaderWith((request) async {
      seenHeaders = request.headers;
      return http.Response('{"data": []}', 200);
    });

    await loader.downloadNewData(1735689600, false);
    expect(seenHeaders['If-Modified-Since'], 'Wed, 01 Jan 2025 00:00:00 GMT');

    await loader.downloadNewData(1735689600, true);
    expect(seenHeaders.containsKey('If-Modified-Since'), false);
  });
}
