import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import 'client/site_interactions.dart';
import 'format.dart';
import 'site_data.dart';
import 'site_themes.dart';

class App extends StatelessComponent {
  const App(this.site, {super.key});

  final SiteData site;

  @override
  Component build(BuildContext context) {
    final profile = site.profile;
    return Component.fragment([
      div(classes: 'site', [
        header(classes: 'site-header', [
          span(classes: 'meta', [Component.text(profile.domain)]),
          nav(
            classes: 'meta',
            attributes: const {'aria-label': 'Social links'},
            [
              for (final link in site.nav) _externalLink(link.url, 'nav-link', [Component.text(link.label)]),
            ],
          ),
        ]),
        main_([
          div(classes: 'hero', [
            div([
              h1([Component.text(profile.name)]),
              div(classes: 'meta tags', [
                for (final tag in profile.tags)
                  if (tag.url case final url?)
                    _externalLink(url, null, [Component.text(tag.label)])
                  else
                    span([Component.text(tag.label)]),
              ]),
            ]),
            Component.element(
              tag: 'canvas',
              id: 'figures',
              classes: 'figures',
              attributes: const {
                'aria-hidden': 'true',
                'data-image': 'images/llama.svg',
                'data-companion': 'images/dash.png',
              },
            ),
          ]),
          p(classes: 'facts', [for (final fact in site.facts) _fact(fact.value, fact.label)]),
          div(classes: 'chat', [
            div(id: 'question', classes: 'intro-question', [
              span([Component.text(profile.question)]),
            ]),
            p(id: 'intro', classes: 'intro', _intro(profile.intro)),
            if (site.answers.isNotEmpty) ...[
              div(id: 'questions', classes: 'answer-chips', [
                const span(attributes: {'aria-hidden': 'true'}, [Component.text('>')]),
                for (final answer in site.answers) ...[
                  button(
                    classes: 'chip',
                    type: ButtonType.button,
                    attributes: {
                      'aria-pressed': 'false',
                      'aria-controls': 'answer-${answer.id}',
                      'data-answer': answer.id,
                    },
                    [Component.text(answer.chip)],
                  ),
                  a(classes: 'chip fallback-chip', href: '#answer-${answer.id}', [Component.text(answer.chip)]),
                ],
              ]),
              div(classes: 'answers', [
                for (final answer in site.answers) _answer(answer),
              ]),
            ],
          ]),
        ]),
        footer(classes: 'site-footer', [
          span(classes: 'meta', [Component.text('© ${DateTime.now().year} ${profile.name} · Built with Jaspr')]),
          span(classes: 'meta', [Component.text(profile.footerNote)]),
          button(
            id: 'theme',
            classes: 'chip',
            type: ButtonType.button,
            attributes: {'data-themes': themeNames.join(' ')},
            [Component.text('theme: ${themeNames.first}')],
          ),
        ]),
      ]),
      if (site.measurementId.isNotEmpty) _consentBanner(),
      const SiteInteractions(),
    ]);
  }
}

List<Component> _intro(String intro) => [
  for (final match in _emphasis.allMatches(intro))
    if (match[1] case final emphasis?) em(classes: 'emphasis', _streamText(emphasis)) else ..._streamText(match[0]!),
];

final _emphasis = RegExp(r'\*([^*]+)\*|[^*]+|\*');
final _tokens = RegExp(r'\S+|\s+');

List<Component> _streamText(String text) => [
  for (final match in _tokens.allMatches(text))
    if (match[0]!.trim().isEmpty)
      Component.text(match[0]!)
    else
      span(classes: 'stream-word', [Component.text(match[0]!)]),
];

Component _fact(String value, String label) {
  return span([
    b([Component.text(value)]),
    Component.text(' $label'),
  ]);
}

Component _answer(Answer answer) {
  final rows = switch (answer.body) {
    PackageRows(:final entries) => [for (final entry in entries) _packageRow(entry)],
    ListRows(:final entries) => [
      for (final entry in entries)
        _listRow(entry.tag, entry.title, entry.url, highlight: entry.highlight, note: entry.note),
    ],
    PostRows(:final posts) => [for (final post in posts) _listRow(postDate(post.date), post.title, post.url)],
    LinkGrid(:final links) => [
      div(classes: 'link-grid', [
        for (final link in links)
          _externalLink(link.url, 'link-row stream-item', [
            Component.text(link.label),
            span([Component.text(link.handle)]),
          ]),
      ]),
    ],
  };
  return section(
    id: 'answer-${answer.id}',
    attributes: {'aria-label': answer.chip},
    [
      p(classes: 'lead', _streamText(answer.lead)),
      ...rows,
      if (answer.extras.isNotEmpty)
        div(classes: 'extra-links stream-item', [
          if (answer.extrasLabel case final label?) span(classes: 'meta', [Component.text(label)]),
          for (final extra in answer.extras) _externalLink(extra.url, null, [Component.text(extra.label)]),
        ]),
    ],
  );
}

Component _packageRow(PackageEntry package) {
  return _externalLink(package.url, 'package-row stream-item', [
    div([
      h2([Component.text(package.name)]),
      p([Component.text(package.blurb)]),
    ]),
    div(classes: 'download-count', [
      b([Component.text(groupedNumber(package.downloads))]),
      const Component.text('downloads a month'),
    ]),
  ]);
}

Component _listRow(String tag, String title, String url, {bool highlight = false, String? note}) {
  return _externalLink(url, 'list-row stream-item', [
    span(classes: highlight ? 'meta highlight' : 'meta', [Component.text(tag)]),
    span([
      Component.text(title),
      if (note != null) small([Component.text(note)]),
    ]),
  ]);
}

Component _externalLink(String url, String? classes, List<Component> children) {
  return a(href: url, classes: classes, target: Target.blank, attributes: const {'rel': 'noopener'}, children);
}

Component _consentBanner() {
  return aside(
    id: 'analytics-consent',
    classes: 'consent',
    attributes: const {'hidden': '', 'aria-label': 'Analytics consent'},
    const [
      p([Component.text('Allow analytics cookies?')]),
      button(id: 'analytics-accept', classes: 'chip', type: ButtonType.button, [Component.text('Accept')]),
      button(id: 'analytics-decline', classes: 'chip', type: ButtonType.button, [Component.text('Decline')]),
    ],
  );
}
