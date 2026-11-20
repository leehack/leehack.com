import 'dart:convert';
import 'dart:io';

import 'package:yaml/yaml.dart';

const _timeout = Duration(seconds: 15);
const _pageSize = 100;
const _postsToKeep = 6;

Future<void> main() async {
  final client = HttpClient()..connectionTimeout = _timeout;
  try {
    final snapshot = File('content/live.json');
    await refreshLiveData(
      siteFile: File('content/site.yaml'),
      snapshot: snapshot,
      fetchJson: (url) => _getJson(client, url),
      warn: stderr.writeln,
    );
    stdout.writeln('Refreshed ${snapshot.path}.');
  } catch (error) {
    stderr.writeln('Error refreshing live data: $error');
    exitCode = 1;
  } finally {
    client.close(force: true);
  }
}

Future<void> refreshLiveData({
  required File siteFile,
  required File snapshot,
  required Future<Object?> Function(Uri url) fetchJson,
  required void Function(String message) warn,
}) async {
  final site = loadYaml(siteFile.readAsStringSync()) as YamlMap;
  final sources = site['sources'] as YamlMap;
  final postsShown = sources['posts_shown'] as int;
  if (postsShown < 0 || postsShown > _postsToKeep) {
    throw const FormatException('sources.posts_shown must be between 0 and $_postsToKeep.');
  }

  final previous = _readSnapshot(snapshot, warn);
  final previousPackages = previous['packages'];
  final missing = <String>[];
  final packages = <String, Object?>{};

  for (final answer in site['answers'] as YamlList) {
    if (answer['type'] != 'packages') continue;
    for (final package in answer['packages'] as YamlList) {
      final name = package['name'] as String;
      final pub = package['pub'] as String;
      final saved = previousPackages is Map ? previousPackages[name] : null;
      final downloads = await _withFallback(
        '$name.downloads30d',
        () => _fetchDownloads(fetchJson, pub),
        _count(saved is Map ? saved['downloads30d'] : null),
        missing,
        warn,
      );
      packages[name] = {'downloads30d': downloads};
    }
  }

  final posts = await _withFallback(
    'posts',
    () => _fetchPosts(fetchJson, sources['devto_user'] as String, postsShown),
    _savedPosts(previous, postsShown),
    missing,
    warn,
  );
  if (missing.isNotEmpty) {
    throw FormatException('No previous value for ${missing.join(', ')}. ${snapshot.path} was left untouched.');
  }

  final data = {
    'generatedAt': '${DateTime.now().toUtc().toIso8601String().split('.').first}Z',
    'packages': packages,
    'posts': posts!,
  };
  final temporary = snapshot.parent.createTempSync('.live-');
  try {
    final staged = File('${temporary.path}/live.json');
    staged.writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(data)}\n', flush: true);
    staged.renameSync(snapshot.path);
  } finally {
    temporary.deleteSync(recursive: true);
  }
}

Map<String, Object?> _readSnapshot(File snapshot, void Function(String) warn) {
  if (!snapshot.existsSync()) return {};
  try {
    final data = jsonDecode(snapshot.readAsStringSync());
    if (data is Map<String, Object?>) return data;
    throw const FormatException('Expected a JSON object.');
  } on FormatException catch (error) {
    warn('Warning: Could not read ${snapshot.path}: $error');
    return {};
  }
}

Future<T?> _withFallback<T>(
  String field,
  Future<T> Function() fetch,
  T? previous,
  List<String> missing,
  void Function(String) warn,
) async {
  try {
    return await fetch();
  } catch (error) {
    final status = previous == null ? 'No previous value.' : 'Keeping the previous value.';
    warn('Warning: Could not refresh $field: $error. $status');
    if (previous == null) missing.add(field);
    return previous;
  }
}

int? _count(Object? value) => value is int && value >= 0 ? value : null;

Future<int> _fetchDownloads(Future<Object?> Function(Uri) fetchJson, String pub) async {
  final url = Uri.https('pub.dev', '/api/packages/$pub/score');
  final data = await fetchJson(url);
  const field = 'downloadCount30Days';
  final count = data is Map ? _count(data[field]) : null;
  if (count == null) throw FormatException('Expected a non-negative integer for $field from $url');
  return count;
}

Future<List<Map<String, Object?>>> _fetchPosts(
  Future<Object?> Function(Uri) fetchJson,
  String user,
  int postsShown,
) async {
  final articles = <({DateTime publishedAt, Map<String, Object?> post})>[];
  final urls = <String>{};
  for (var page = 1; ; page++) {
    final url = Uri.https('dev.to', '/api/articles', {
      'username': user,
      'per_page': '$_pageSize',
      'page': '$page',
    });
    final data = await fetchJson(url);
    if (data is! List || data.length > _pageSize) throw FormatException('Expected a page of articles from $url');
    for (final article in data) {
      final timestamp = article is Map ? article['published_at'] : null;
      final publishedAt = timestamp is String ? DateTime.tryParse(timestamp) : null;
      if (publishedAt == null || timestamp is! String || timestamp.length <= 10 || timestamp[10] != 'T') {
        throw FormatException('Invalid published_at on $url');
      }
      final post = _post(article, timestamp.substring(0, 10));
      if (post == null || !urls.add(post['url'] as String)) {
        throw FormatException('Malformed or repeated article on $url');
      }
      articles.add((publishedAt: publishedAt, post: post));
    }
    if (data.length < _pageSize) break;
  }
  if (articles.length < postsShown) throw FormatException('Expected at least $postsShown posts from dev.to');
  articles.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
  return articles.take(_postsToKeep).map((entry) => entry.post).toList();
}

List<Map<String, Object?>>? _savedPosts(Map<String, Object?> previous, int postsShown) {
  final entries = previous['posts'];
  if (entries is! List || entries.length < postsShown) return null;
  final posts = <Map<String, Object?>>[];
  for (final entry in entries.take(_postsToKeep)) {
    final post = _post(entry, entry is Map ? entry['date'] : null);
    if (post == null) return null;
    posts.add(post);
  }
  return posts;
}

Map<String, Object?>? _post(Object? entry, Object? date) {
  if (entry is! Map || date is! String) return null;
  final title = entry['title'];
  final url = entry['url'];
  final target = url is String ? Uri.tryParse(url) : null;
  final day = DateTime.tryParse('${date}T00:00:00Z');
  if (title is! String ||
      title.trim().isEmpty ||
      target == null ||
      !{'http', 'https'}.contains(target.scheme) ||
      target.host.isEmpty ||
      day == null ||
      day.toIso8601String().split('T').first != date) {
    return null;
  }
  return {'title': title, 'url': url, 'date': date};
}

Future<Object?> _getJson(HttpClient client, Uri url) async {
  final request = await client.getUrl(url).timeout(_timeout);
  request.headers.set(HttpHeaders.userAgentHeader, 'leehack-site-refresh');
  final response = await request.close().timeout(_timeout);
  if (response.statusCode != HttpStatus.ok) {
    await response.drain<void>().timeout(_timeout);
    throw HttpException('HTTP ${response.statusCode}', uri: url);
  }
  return jsonDecode(await utf8.decoder.bind(response).join().timeout(_timeout));
}
