import 'dart:convert';
import 'dart:io';

import 'package:yaml/yaml.dart';

typedef Profile = ({
  String name,
  String domain,
  List<Tag> tags,
  String question,
  String intro,
  String footerNote,
});

typedef Tag = ({String label, String? url});
typedef Seo = ({String title, String description});
typedef SiteLink = ({String label, String handle, String url});
typedef ExtraLink = ({String label, String url});
typedef PackageEntry = ({String name, String blurb, String url, int downloads});
typedef ListEntry = ({String tag, String title, String? note, String? summary, String url, bool highlight});
typedef Fact = ({String value, String label});
typedef Post = ({String title, String url, DateTime date});

class SiteData {
  const SiteData({
    required this.profile,
    required this.seo,
    required this.measurementId,
    required this.facts,
    required this.nav,
    required this.answers,
  });

  final Profile profile;
  final Seo seo;
  final String measurementId;
  final List<Fact> facts;
  final List<SiteLink> nav;
  final List<Answer> answers;

  factory SiteData.load() => SiteData.parse(_read('content/site.yaml'), _read('content/live.json'));

  factory SiteData.parse(String yaml, String json) {
    final site = loadYaml(yaml) as YamlMap;
    final live = jsonDecode(json) as Map<String, dynamic>;
    final profile = site['profile'] as YamlMap;
    final seo = site['seo'] as YamlMap;
    final sources = site['sources'] as YamlMap;
    final measurementId = (site['analytics']['ga_measurement_id'] as String).trim();

    final packageDownloads = (live['packages'] as Map<String, dynamic>).map<String, int>(
      (name, stats) => MapEntry(name, stats['downloads30d'] as int),
    );
    final postCount = sources['posts_shown'] as int;
    final livePosts = live['posts'] as List<dynamic>;
    if (postCount < 0 || livePosts.length < postCount) {
      throw FormatException('content/live.json: expected at least $postCount posts from sources.posts_shown');
    }
    final posts = [
      for (final post in livePosts.take(postCount))
        (title: post['title'] as String, url: post['url'] as String, date: DateTime.parse(post['date'] as String)),
    ];

    final links = (site['links'] as YamlMap).map<String, SiteLink>(
      (key, link) => MapEntry(key as String, (
        label: link['label'] as String,
        handle: link['handle'] as String,
        url: link['url'] as String,
      )),
    );

    SiteLink resolveLink(String key, String field) =>
        links[key] ?? (throw FormatException('content/site.yaml: unknown link key "$key" in $field'));

    PackageEntry packageEntry(YamlMap package, String answerId) {
      final name = package['name'] as String;
      final downloads = packageDownloads[name];
      if (downloads == null) {
        throw FormatException('content/live.json: missing stats for package "$name" in answer "$answerId"');
      }
      return (name: name, blurb: package['blurb'] as String, url: package['url'] as String, downloads: downloads);
    }

    final downloads = packageDownloads.values.fold(0, (sum, downloads) => sum + downloads);

    final answers = <Answer>[];
    final ids = <String>{};
    for (final answer in site['answers'] as YamlList) {
      final id = answer['id'] as String;
      if (id.isEmpty || !ids.add(id)) {
        throw FormatException('content/site.yaml: empty or duplicate answer ID "$id"');
      }
      final type = answer['type'];
      final body = switch (type) {
        'packages' => PackageRows([
          for (final package in answer['packages'] as YamlList) packageEntry(package as YamlMap, id),
        ]),
        'list' => ListRows([
          for (final item in answer['items'] as YamlList)
            (
              tag: item['tag'] as String,
              title: item['title'] as String,
              note: item['note'] as String?,
              summary: item['summary'] as String?,
              url: item['url'] as String,
              highlight: item['highlight'] as bool? ?? false,
            ),
        ]),
        'posts' => PostRows(posts),
        'links' => LinkGrid([
          for (final key in (answer['items'] as YamlList).cast<String>()) resolveLink(key, 'answer "$id"'),
        ]),
        _ => throw FormatException('content/site.yaml: unknown answer type "$type" in answer "$id"'),
      };
      answers.add(
        Answer(
          id: id,
          chip: answer['chip'] as String,
          lead: answer['lead'] as String,
          body: body,
          extrasLabel: answer['extras_label'] as String?,
          extras: [
            for (final extra in (answer['extras'] as YamlList? ?? const []))
              (label: extra['label'] as String, url: extra['url'] as String),
          ],
        ),
      );
    }

    return SiteData(
      profile: (
        name: profile['name'] as String,
        domain: profile['domain'] as String,
        tags: [
          for (final tag in profile['tags'] as YamlList)
            if (tag is String) (label: tag, url: null) else (label: tag['label'] as String, url: tag['url'] as String?),
        ],
        question: profile['question'] as String,
        intro: profile['intro'] as String,
        footerNote: profile['footer_note'] as String,
      ),
      seo: (title: seo['title'] as String, description: seo['description'] as String),
      measurementId: measurementId,
      facts: [
        for (final fact in profile['facts'] as YamlList)
          (
            value: (fact['value'] as String).replaceAll('{downloads}', '${downloads ~/ 1000}k'),
            label: fact['label'] as String,
          ),
      ],
      nav: [for (final key in (site['nav'] as YamlList).cast<String>()) resolveLink(key, 'nav')],
      answers: answers,
    );
  }
}

class Answer {
  const Answer({
    required this.id,
    required this.chip,
    required this.lead,
    required this.body,
    required this.extrasLabel,
    required this.extras,
  });

  final String id;
  final String chip;
  final String lead;
  final AnswerBody body;
  final String? extrasLabel;
  final List<ExtraLink> extras;
}

sealed class AnswerBody {
  const AnswerBody();
}

final class PackageRows extends AnswerBody {
  const PackageRows(this.entries);
  final List<PackageEntry> entries;
}

final class ListRows extends AnswerBody {
  const ListRows(this.entries);
  final List<ListEntry> entries;
}

final class PostRows extends AnswerBody {
  const PostRows(this.posts);
  final List<Post> posts;
}

final class LinkGrid extends AnswerBody {
  const LinkGrid(this.links);
  final List<SiteLink> links;
}

String _read(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    throw StateError('Missing required site content file: $path');
  }
  return file.readAsStringSync();
}
