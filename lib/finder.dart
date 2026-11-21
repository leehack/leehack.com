import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import 'site_data.dart';

class Finder extends StatelessComponent {
  const Finder(this.site, {super.key});

  final SiteData site;

  @override
  Component build(BuildContext context) => div(id: 'finder', [
    const form(
      id: 'finder-form',
      attributes: {'hidden': '', 'role': 'search'},
      [
        label(htmlFor: 'finder-query', classes: 'meta', [Component.text('Search talks, projects, and posts')]),
        div(classes: 'finder-search-row', [
          input(
            id: 'finder-query',
            type: InputType.search,
            attributes: {'maxlength': '240', 'placeholder': 'e.g. Offline AI in Flutter'},
          ),
          button(id: 'finder-submit', type: ButtonType.submit, [Component.text('Search')]),
        ]),
        div(
          id: 'finder-local-details',
          attributes: {'hidden': ''},
          [
            p(classes: 'finder-description', [
              Component.text('Search by meaning with a model that runs in your browser. Powered by '),
              a(href: 'https://llamadart.leehack.com', [Component.text('llamadart')]),
              Component.text(', an open-source Dart library for on-device AI.'),
            ]),
            p(id: 'finder-model-status', classes: 'meta', [Component.text('37 MB model')]),
          ],
        ),
      ],
    ),
    const p(id: 'finder-status', classes: 'meta', attributes: {'role': 'status'}, []),
    ul(
      id: 'finder-results',
      attributes: const {'hidden': ''},
      [
        for (final entry in _entries(site))
          li([
            a(href: entry.url, classes: 'list-row', [
              span(classes: 'meta highlight', [Component.text(entry.type)]),
              span([
                Component.text(entry.title),
                if (entry.detail.isNotEmpty) small([Component.text(entry.detail)]),
              ]),
            ]),
          ]),
      ],
    ),
  ]);
}

typedef _Resource = ({String title, String detail, String type, String url});

Iterable<_Resource> _entries(SiteData site) sync* {
  final seen = <String>{};
  for (final answer in site.answers) {
    final (type, entries) = switch (answer.body) {
      PackageRows(:final entries) => (
        'Project',
        entries.map((entry) => (title: entry.name, detail: entry.blurb, url: entry.url)),
      ),
      ListRows(:final entries) => (
        answer.id == 'speak' ? 'Talk' : 'Community',
        entries.map(
          (entry) => (
            title: entry.title,
            detail: [if (entry.summary case final summary?) summary, if (entry.note case final note?) note].join(' · '),
            url: entry.url,
          ),
        ),
      ),
      PostRows(:final posts) => ('Article', posts.map((post) => (title: post.title, detail: '', url: post.url))),
      LinkGrid(:final links) => (
        'Link',
        links.map((entry) => (title: entry.label, detail: entry.handle, url: entry.url)),
      ),
    };

    for (final entry in entries) {
      if (seen.add(entry.url)) yield (title: entry.title, detail: entry.detail, type: type, url: entry.url);
    }
    for (final extra in answer.extras) {
      if (seen.add(extra.url)) yield (title: extra.label, detail: '', type: type, url: extra.url);
    }
  }
}
