import 'dart:convert';
import 'dart:io';

import 'package:leehack_site/site_themes.dart';

void main() {
  try {
    generateNotFoundPage(output: Directory('build/jaspr'), base: Platform.environment['SITE_BASE'] ?? '/');
  } catch (error) {
    stderr.writeln('Error generating 404 page: $error');
    exitCode = 1;
  }
}

void generateNotFoundPage({required Directory output, required String base}) {
  if (!output.existsSync()) throw FormatException('Output directory does not exist: ${output.path}');

  const escape = HtmlEscape(HtmlEscapeMode.attribute);
  final href = escape.convert(base);
  File('${output.path}/404.html').writeAsStringSync('''<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="robots" content="noindex">
  <base href="$href">
  <title>Page not found | leehack.com</title>
  <style>
$defaultSiteThemeCss
    @font-face {
      font-family: 'Newsreader';
      font-weight: 400 500;
      font-display: swap;
      src: url('fonts/newsreader-latin.woff2') format('woff2');
    }
    body {
      margin: 0;
      background: var(--bg);
      color: var(--tx);
      font: 18px/1.5 'Newsreader', Georgia, serif;
    }
    main {
      box-sizing: border-box;
      max-width: 700px;
      margin: 0 auto;
      padding: 64px clamp(20px, 6vw, 40px);
    }
    h1 {
      margin: 0;
      font-size: clamp(50px, 11vw, 76px);
      font-weight: 500;
      line-height: 1;
    }
    p { color: var(--mu); }
    a { color: var(--ac); text-underline-offset: 3px; }
    a:focus-visible { outline: 2px solid var(--ac); outline-offset: 3px; }
  </style>
</head>
<body>
  <main>
    <h1>404</h1>
    <p>This page could not be found.</p>
    <a href="$href">Back to home</a>
  </main>
</body>
</html>
''');
}
