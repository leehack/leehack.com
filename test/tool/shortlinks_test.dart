import 'dart:io';

import 'package:test/test.dart';

import '../../tool/shortlinks.dart';

void main() {
  late File siteFile;
  late Directory output;

  setUp(() {
    final directory = Directory.systemTemp.createTempSync('shortlinks-test-');
    addTearDown(() => directory.deleteSync(recursive: true));
    siteFile = File('${directory.path}/site.yaml');
    output = Directory('${directory.path}/output')..createSync();
  });

  void generate(String entries) {
    siteFile.writeAsStringSync('shortlinks:\n$entries\n');
    generateShortLinks(siteFile: siteFile, output: output);
  }

  test('writes a redirect page with an escaped destination', () {
    const url = "https://example.com/talk?q='dart'&next=%3Ctag%3E";
    const escaped = 'https://example.com/talk?q=&#39;dart&#39;&amp;next=%3Ctag%3E';
    generate('  talk-1: "$url"');

    final html = File('${output.path}/talk-1/index.html').readAsStringSync();
    expect(html, contains('<meta http-equiv="refresh" content="0; url=$escaped">'));
    expect(html, contains('<link rel="canonical" href="$escaped">'));
    expect(html, contains('<a href="$escaped">$escaped</a>'));
    expect(html, contains('<script>location.replace("$url");</script>'));
  });

  test('rejects an invalid key', () {
    expect(() => generate('  ../bad: https://example.com'), throwsFormatException('Invalid short-link key "../bad"'));
    expect(output.listSync(), isEmpty);
  });

  test('rejects a URL with a scheme other than HTTP or HTTPS', () {
    expect(() => generate('  talk: ftp://example.com/talk'), throwsFormatException('Invalid URL for "talk"'));
    expect(output.listSync(), isEmpty);
  });

  test('rejects a missing output directory', () {
    output.deleteSync();
    expect(
      () => generate('  talk: https://example.com'),
      throwsFormatException('Output directory does not exist: ${output.path}'),
    );
    expect(output.existsSync(), isFalse);
  });

  test('rejects an existing path before writing redirects', () {
    final existing = File('${output.path}/used')..writeAsStringSync('existing file');
    expect(
      () => generate('''
  first: https://example.com/first
  used: https://example.com/used
'''),
      throwsFormatException('Short-link path already exists: ${existing.path}'),
    );
    expect(existing.readAsStringSync(), 'existing file');
    expect(Directory('${output.path}/first').existsSync(), isFalse);
  });
}

Matcher throwsFormatException(String message) =>
    throwsA(isA<FormatException>().having((error) => error.message, 'message', contains(message)));
