import 'dart:io';

import 'package:test/test.dart';

import '../../tool/not_found.dart';

void main() {
  late Directory output;

  setUp(() {
    output = Directory.systemTemp.createTempSync('not-found-test-');
    addTearDown(() => output.deleteSync(recursive: true));
  });

  String generate(String base) {
    generateNotFoundPage(output: output, base: base);
    return File('${output.path}/404.html').readAsStringSync();
  }

  test('writes a noindex page with a link to the root homepage', () {
    final html = generate('/');
    expect(html, contains('<title>Page not found | leehack.com</title>'));
    expect(html, contains('<meta name="robots" content="noindex">'));
    expect(html, contains('<base href="/">'));
    expect(html, contains('<a href="/">Back to home</a>'));
  });

  test('uses the project base path for the homepage and relative font', () {
    final html = generate('/leehack.com/');
    expect(html, contains('<base href="/leehack.com/">'));
    expect(html, contains('<a href="/leehack.com/">Back to home</a>'));
    expect(html, contains("url('fonts/newsreader-latin.woff2')"));
  });

  test('rejects a missing output directory', () {
    final missing = Directory('${output.path}/missing');
    expect(() => generateNotFoundPage(output: missing, base: '/'), throwsFormatException);
    expect(missing.existsSync(), isFalse);
  });
}
