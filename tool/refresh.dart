import 'dart:convert';
import 'dart:io';

import 'package:yaml/yaml.dart';

const _timeout = Duration(seconds: 15);
const _pageSize = 100;
const _postsToKeep = 6;
typedef _Posts = ({int count, List<Map<String, Object?>> posts});

Future<void> main() async {
  final client = HttpClient()..connectionTimeout = _timeout;
  try {
    await _refresh(client);
  } catch (error) {
    stderr.writeln('Error refreshing live data: $error');
    exitCode = 1;
  } finally {
    client.close(force: true);
  }
}

Future<void> _refresh(HttpClient client) async {
  final site = loadYaml(File('content/site.yaml').readAsStringSync()) as YamlMap;
  final sources = site['sources'] as YamlMap;
  final postsShown = sources['posts_shown'] as int;
  if (postsShown < 0 || postsShown > _postsToKeep) {
    throw const FormatException('sources.posts_shown must be between 0 and $_postsToKeep.');
  }

  final snapshot = File('content/live.json');
  final previous = _readSnapshot(snapshot);
  final previousPackages = previous['packages'];
  final missing = <String>[];
  final packages = <String, Object?>{};
  final token = Platform.environment['GITHUB_TOKEN'];

  for (final answer in site['answers'] as YamlList) {
    if (answer['type'] != 'packages') continue;
    for (final package in answer['packages'] as YamlList) {
      final name = package['name'] as String;
      final pub = package['pub'] as String;
      final repo = package['repo'] as String;
      final saved = previousPackages is Map ? previousPackages[name] : null;
      final downloads = await _withFallback(
        '$name.downloads30d',
        () => _fetchCount(client, Uri.https('pub.dev', '/api/packages/$pub/score'), 'downloadCount30Days'),
        _count(saved is Map ? saved['downloads30d'] : null),
        missing,
      );
      final stars = await _withFallback(
        '$name.stars',
        () => _fetchCount(client, Uri.https('api.github.com', '/repos/$repo'), 'stargazers_count', token: token),
        _count(saved is Map ? saved['stars'] : null),
        missing,
      );
      packages[name] = {'downloads30d': downloads, 'stars': stars};
    }
  }

  final posts = await _withFallback(
    'postCount and posts',
    () => _fetchPosts(client, sources['devto_user'] as String, postsShown),
    _savedPosts(previous, postsShown),
    missing,
  );
  if (missing.isNotEmpty) {
    throw FormatException('No previous value for ${missing.join(', ')}. ${snapshot.path} was left untouched.');
  }

  final data = {
    'generatedAt': '${DateTime.now().toUtc().toIso8601String().split('.').first}Z',
    'packages': packages,
    'postCount': posts!.count,
    'posts': posts.posts,
  };
  final temporary = snapshot.parent.createTempSync('.live-');
  try {
    final staged = File('${temporary.path}/live.json');
    staged.writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(data)}\n', flush: true);
    staged.renameSync(snapshot.path);
  } finally {
    temporary.deleteSync(recursive: true);
  }
  stdout.writeln('Refreshed ${snapshot.path}.');
}

Map<String, Object?> _readSnapshot(File snapshot) {
  if (!snapshot.existsSync()) return {};
  try {
    final data = jsonDecode(snapshot.readAsStringSync());
    if (data is Map<String, Object?>) return data;
    throw const FormatException('Expected a JSON object.');
  } on FormatException catch (error) {
    stderr.writeln('Warning: Could not read ${snapshot.path}: $error');
    return {};
  }
}

Future<T?> _withFallback<T>(String field, Future<T> Function() fetch, T? previous, List<String> missing) async {
  try {
    return await fetch();
  } catch (error) {
    final status = previous == null ? 'No previous value.' : 'Keeping the previous value.';
    stderr.writeln('Warning: Could not refresh $field: $error. $status');
    if (previous == null) missing.add(field);
    return previous;
  }
}

int? _count(Object? value) => value is int && value >= 0 ? value : null;

Future<int> _fetchCount(HttpClient client, Uri url, String field, {String? token}) async {
  final data = await _getJson(client, url, token: token);
  final count = data is Map ? _count(data[field]) : null;
  if (count == null) throw FormatException('Expected a non-negative integer for $field from $url');
  return count;
}

Future<_Posts> _fetchPosts(HttpClient client, String user, int postsShown) async {
  final articles = <({DateTime publishedAt, Map<String, Object?> post})>[];
  final urls = <String>{};
  for (var page = 1; ; page++) {
    final url = Uri.https('dev.to', '/api/articles', {
      'username': user,
      'per_page': '$_pageSize',
      'page': '$page',
    });
    final data = await _getJson(client, url);
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
  return (count: articles.length, posts: articles.take(_postsToKeep).map((entry) => entry.post).toList());
}

_Posts? _savedPosts(Map<String, Object?> previous, int postsShown) {
  final count = _count(previous['postCount']);
  final entries = previous['posts'];
  if (count == null || entries is! List || entries.length < postsShown || entries.length > count) return null;
  final posts = <Map<String, Object?>>[];
  for (final entry in entries.take(_postsToKeep)) {
    final post = _post(entry, entry is Map ? entry['date'] : null);
    if (post == null) return null;
    posts.add(post);
  }
  return (count: count, posts: posts);
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

Future<Object?> _getJson(HttpClient client, Uri url, {String? token}) async {
  final request = await client.getUrl(url).timeout(_timeout);
  request.headers.set(HttpHeaders.userAgentHeader, 'leehack-site-refresh');
  if (token != null && token.isNotEmpty) {
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
  }
  final response = await request.close().timeout(_timeout);
  if (response.statusCode != HttpStatus.ok) {
    await response.drain<void>().timeout(_timeout);
    throw HttpException('HTTP ${response.statusCode}', uri: url);
  }
  return jsonDecode(await utf8.decoder.bind(response).join().timeout(_timeout));
}
