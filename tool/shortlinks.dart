import 'dart:convert';
import 'dart:io';

import 'package:yaml/yaml.dart';

void main(List<String> args) {
  try {
    final output = Directory(args.isEmpty ? 'build/jaspr' : args.first);
    if (!output.existsSync()) throw FormatException('Output directory does not exist: ${output.path}');

    final site = loadYaml(File('content/site.yaml').readAsStringSync()) as YamlMap;
    final shortlinks = site['shortlinks'] as YamlMap;
    final redirects = <String, String>{};
    final invalidKey = RegExp(r'[^a-z0-9-]');
    for (final entry in shortlinks.entries) {
      final key = entry.key;
      if (key is! String || key.isEmpty || invalidKey.hasMatch(key)) {
        throw FormatException('Invalid short-link key "$key". Use lowercase letters, digits or hyphens.');
      }
      final url = entry.value;
      final target = url is String ? Uri.tryParse(url) : null;
      if (target == null || !{'http', 'https'}.contains(target.scheme) || target.host.isEmpty) {
        throw FormatException('Invalid URL for "$key". Use an absolute HTTP or HTTPS URL.');
      }
      final path = '${output.path}/$key';
      if (FileSystemEntity.typeSync(path, followLinks: false) != FileSystemEntityType.notFound) {
        throw FormatException('Short-link path already exists: $path');
      }
      redirects[path] = target.toString();
    }

    for (final entry in redirects.entries) {
      Directory(entry.key).createSync();
      File('${entry.key}/index.html').writeAsStringSync(_redirectPage(entry.value));
    }
  } catch (error) {
    stderr.writeln('Error generating short links: $error');
    exitCode = 1;
  }
}

String _redirectPage(String url) {
  const escape = HtmlEscape(HtmlEscapeMode(escapeLtGt: true, escapeQuot: true, escapeApos: true));
  final htmlUrl = escape.convert(url);
  final scriptUrl = jsonEncode(url).replaceAll('<', r'\u003c');
  return '''<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="robots" content="noindex">
  <meta http-equiv="refresh" content="0; url=$htmlUrl">
  <link rel="canonical" href="$htmlUrl">
  <title>Redirecting</title>
  <script>location.replace($scriptUrl);</script>
</head>
<body>
  <p>Continue to <a href="$htmlUrl">$htmlUrl</a>.</p>
</body>
</html>
''';
}
