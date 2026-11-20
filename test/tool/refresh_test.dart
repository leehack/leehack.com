import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import '../../tool/refresh.dart';

void main() {
  late File siteFile;
  late File snapshot;
  late List<String> warnings;

  setUp(() {
    final directory = Directory.systemTemp.createTempSync('refresh-test-');
    addTearDown(() => directory.deleteSync(recursive: true));
    siteFile = File('${directory.path}/site.yaml')
      ..writeAsStringSync('''
sources:
  devto_user: example
  posts_shown: 2
answers:
  - type: packages
    packages:
      - {name: zebra, pub: zebra_pub}
  - type: links
  - type: packages
    packages:
      - {name: alpha, pub: alpha_pub}
''');
    snapshot = File('${directory.path}/live.json');
    warnings = [];
  });

  Future<void> refresh(Future<Object?> Function(Uri) fetchJson) =>
      refreshLiveData(siteFile: siteFile, snapshot: snapshot, fetchJson: fetchJson, warn: warnings.add);

  test('writes the snapshot contract in stable order with a trailing newline', () async {
    final requested = <String>[];
    await refresh((url) async {
      requested.add(url.toString());
      return switch (url.host) {
        'pub.dev' => {'downloadCount30Days': url.path.contains('zebra') ? 0 : 53},
        'dev.to' => [_article(1), _article(2)],
        _ => throw StateError('Unexpected request to $url'),
      };
    });

    expect(requested, [
      'https://pub.dev/api/packages/zebra_pub/score',
      'https://pub.dev/api/packages/alpha_pub/score',
      'https://dev.to/api/articles?username=example&per_page=100&page=1',
    ]);
    final contents = snapshot.readAsStringSync();
    expect(contents, matches(RegExp(r'"generatedAt": "\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z"')));
    expect(contents.replaceFirst(RegExp(r'"generatedAt": "[^"]+"'), '"generatedAt": "TIMESTAMP"'), '''
{
  "generatedAt": "TIMESTAMP",
  "packages": {
    "zebra": {
      "downloads30d": 0
    },
    "alpha": {
      "downloads30d": 53
    }
  },
  "posts": [
    {
      "title": "Post 2",
      "url": "https://dev.to/example/post-2",
      "date": "2026-01-02"
    },
    {
      "title": "Post 1",
      "url": "https://dev.to/example/post-1",
      "date": "2026-01-01"
    }
  ]
}
''');
    expect(warnings, isEmpty);
  });

  test('retains saved downloads and posts when requests fail or return malformed data', () async {
    const previousPosts = [
      {'title': 'Earlier post', 'url': 'https://dev.to/example/earlier', 'date': '2025-10-02'},
      {'title': 'Oldest post', 'url': 'https://dev.to/example/oldest', 'date': '2025-09-19'},
    ];
    snapshot.writeAsStringSync(
      jsonEncode({
        'packages': {
          'zebra': {'downloads30d': 45},
          'alpha': {'downloads30d': 70},
        },
        'posts': previousPosts,
      }),
    );

    await refresh((url) async {
      if (url.host == 'dev.to') {
        return [
          _article(1),
          {..._article(2), 'url': 'invalid URL'},
        ];
      }
      if (url.path.contains('zebra')) {
        throw const HttpException('HTTP 503');
      }
      return {'downloadCount30Days': '70'};
    });

    final data = jsonDecode(snapshot.readAsStringSync()) as Map<String, Object?>;
    expect(data['packages'], {
      'zebra': {'downloads30d': 45},
      'alpha': {'downloads30d': 70},
    });
    expect(data['posts'], previousPosts);
    expect(warnings, [
      allOf(
        contains('Warning: Could not refresh zebra.downloads30d'),
        contains('HTTP 503'),
        endsWith('Keeping the previous value.'),
      ),
      allOf(
        contains('Warning: Could not refresh alpha.downloads30d'),
        contains('non-negative integer'),
        endsWith('Keeping the previous value.'),
      ),
      allOf(
        contains('Warning: Could not refresh posts'),
        contains('Malformed or repeated article'),
        endsWith('Keeping the previous value.'),
      ),
    ]);
  });

  test('fails and leaves the snapshot untouched when a failed fetch has no saved value', () async {
    const previous = '{\n  "packages": {}\n}\n';
    snapshot.writeAsStringSync(previous);

    await expectLater(
      refresh((url) async {
        if (url.host == 'dev.to') return [_article(1), _article(2)];
        if (url.path.contains('zebra')) return {'downloadCount30Days': 80};
        throw const HttpException('HTTP 503');
      }),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('No previous value for alpha.downloads30d. ${snapshot.path} was left untouched.'),
        ),
      ),
    );

    expect(snapshot.readAsStringSync(), previous);
    expect(warnings, [
      allOf(contains('Warning: Could not refresh alpha.downloads30d'), endsWith('No previous value.')),
    ]);
  });

  test('stops on a short dev.to page and keeps the newest six posts across pages', () async {
    final pages = <String?>[];
    await refresh((url) async {
      if (url.host == 'pub.dev') return {'downloadCount30Days': 1};
      pages.add(url.queryParameters['page']);
      return switch (pages.length) {
        1 => List.generate(100, (index) => _article(index + 1)),
        2 => [_article(102), _article(101)],
        _ => throw StateError('Requested an extra page'),
      };
    });

    expect(pages, ['1', '2']);
    final data = jsonDecode(snapshot.readAsStringSync()) as Map<String, Object?>;
    final posts = data['posts'] as List;
    expect(posts.map((post) => post['title']), ['Post 102', 'Post 101', 'Post 100', 'Post 99', 'Post 98', 'Post 97']);
    expect(warnings, isEmpty);
  });
}

Map<String, String> _article(int index) => {
  'title': 'Post $index',
  'url': 'https://dev.to/example/post-$index',
  'published_at': DateTime.utc(2026, 1, index).toIso8601String(),
};
