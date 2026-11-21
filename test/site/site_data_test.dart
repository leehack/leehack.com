import 'package:leehack_site/site_data.dart';
import 'package:test/test.dart';

const _yaml = '''
profile:
  name: Pat Example
  domain: example.com
  tags:
    - Montréal
    - {label: Flutter, url: 'https://example.com/flutter'}
  question: Who is Pat?
  intro: Hello from Montréal.
  footer_note: Thanks for reading.
  facts:
    - {value: 'Over {downloads}', label: downloads a month}
    - {value: '3', label: talks}
seo:
  title: Pat Example
  description: Pat's website.
analytics:
  ga_measurement_id: ' G-123 '
sources:
  posts_shown: 1
links:
  blog: {label: Blog, handle: '@pat', url: 'https://example.com/blog'}
nav: [blog]
answers:
  - id: build
    chip: Packages
    lead: What I build
    type: packages
    packages:
      - {name: test_package, blurb: A test package, url: 'https://example.com/package'}
    extras_label: More
    extras:
      - {label: More packages, url: 'https://example.com/packages'}
  - id: speak
    chip: Talks
    lead: Where I speak
    type: list
    items:
      - {tag: '2026', title: Flutter in Montréal, summary: A talk on Flutter, url: 'https://example.com/talk', highlight: true}
  - id: write
    chip: Posts
    lead: What I write
    type: posts
  - id: links
    chip: Links
    lead: Where to find me
    type: links
    items: [blog]
''';

const _json = '''
{
  "packages": {
    "test_package": {"downloads30d": 1999},
    "another_package": {"downloads30d": 1501}
  },
  "posts": [
    {"title": "New post", "url": "https://example.com/new", "date": "2026-11-20"},
    {"title": "Old post", "url": "https://example.com/old", "date": "2026-11-19"}
  ]
}
''';

void main() {
  test('parses a site with all answer layouts', () {
    final site = SiteData.parse(_yaml, _json);

    expect(site.profile.name, 'Pat Example');
    expect(site.profile.domain, 'example.com');
    expect(site.profile.question, 'Who is Pat?');
    expect(site.profile.intro, 'Hello from Montréal.');
    expect(site.profile.footerNote, 'Thanks for reading.');
    expect(site.seo, (title: 'Pat Example', description: "Pat's website."));
    expect(site.measurementId, 'G-123');
    expect(site.nav, [(label: 'Blog', handle: '@pat', url: 'https://example.com/blog')]);

    final [packages, talks, posts, links] = site.answers;
    expect((packages.id, packages.chip, packages.lead), ('build', 'Packages', 'What I build'));
    expect((packages.body as PackageRows).entries.single, (
      name: 'test_package',
      blurb: 'A test package',
      url: 'https://example.com/package',
      downloads: 1999,
    ));
    expect(packages.extrasLabel, 'More');
    expect(packages.extras, [(label: 'More packages', url: 'https://example.com/packages')]);

    expect((talks.body as ListRows).entries.single, (
      tag: '2026',
      title: 'Flutter in Montréal',
      note: null,
      summary: 'A talk on Flutter',
      url: 'https://example.com/talk',
      highlight: true,
    ));
    expect(talks.extrasLabel, isNull);
    expect(talks.extras, isEmpty);
    expect((posts.body as PostRows).posts.single, (
      title: 'New post',
      url: 'https://example.com/new',
      date: DateTime(2026, 11, 20),
    ));
    expect((links.body as LinkGrid).links, site.nav);
  });

  test('substitutes the combined downloads total in thousands', () {
    expect(SiteData.parse(_yaml, _json).facts, [
      (value: 'Over 3k', label: 'downloads a month'),
      (value: '3', label: 'talks'),
    ]);
  });

  test('parses plain and linked tags', () {
    expect(SiteData.parse(_yaml, _json).profile.tags, [
      (label: 'Montréal', url: null),
      (label: 'Flutter', url: 'https://example.com/flutter'),
    ]);
  });

  group('validation', () {
    Matcher formatError(String message) => isA<FormatException>().having((error) => error.message, 'message', message);

    test('rejects an unknown answer type', () {
      expect(
        () => SiteData.parse(_yaml.replaceFirst('type: posts', 'type: articles'), _json),
        throwsA(formatError('content/site.yaml: unknown answer type "articles" in answer "write"')),
      );
    });

    test('rejects an undefined link key in the navigation', () {
      expect(
        () => SiteData.parse(_yaml.replaceFirst('nav: [blog]', 'nav: [missing]'), _json),
        throwsA(formatError('content/site.yaml: unknown link key "missing" in nav')),
      );
    });

    test('rejects an undefined link key in an answer', () {
      expect(
        () => SiteData.parse(_yaml.replaceFirst('items: [blog]', 'items: [missing]'), _json),
        throwsA(formatError('content/site.yaml: unknown link key "missing" in answer "links"')),
      );
    });

    test('rejects duplicate answer IDs', () {
      expect(
        () => SiteData.parse(_yaml.replaceFirst('id: write', 'id: build'), _json),
        throwsA(formatError('content/site.yaml: empty or duplicate answer ID "build"')),
      );
    });

    test('rejects an empty answer ID', () {
      expect(
        () => SiteData.parse(_yaml.replaceFirst('id: write', 'id: ""'), _json),
        throwsA(formatError('content/site.yaml: empty or duplicate answer ID ""')),
      );
    });

    test('rejects fewer posts than requested', () {
      expect(
        () => SiteData.parse(_yaml.replaceFirst('posts_shown: 1', 'posts_shown: 3'), _json),
        throwsA(formatError('content/live.json: expected at least 3 posts from sources.posts_shown')),
      );
    });

    test('rejects a negative post count', () {
      expect(
        () => SiteData.parse(_yaml.replaceFirst('posts_shown: 1', 'posts_shown: -1'), _json),
        throwsA(formatError('content/live.json: expected at least -1 posts from sources.posts_shown')),
      );
    });

    test('rejects missing package stats', () {
      expect(
        () => SiteData.parse(_yaml, _json.replaceFirst('test_package', 'unlisted_package')),
        throwsA(formatError('content/live.json: missing stats for package "test_package" in answer "build"')),
      );
    });
  });
}
