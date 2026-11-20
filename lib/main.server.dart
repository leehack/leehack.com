import 'dart:convert';
import 'dart:io';

import 'package:jaspr/dom.dart';
import 'package:jaspr/server.dart';

import 'app.dart';
import 'main.server.options.dart';
import 'site_data.dart';
import 'site_themes.dart';

const _canonical = 'https://leehack.com/';

void main() {
  final site = SiteData.load();
  Jaspr.initializeApp(options: defaultServerOptions);
  runApp(
    Document(
      lang: 'en',
      base: Platform.environment['SITE_BASE'] ?? '/',
      title: site.seo.title,
      meta: {'description': site.seo.description, 'twitter:card': 'summary'},
      head: [
        const script(
          content:
              "document.documentElement.classList.add('js');"
              "try{var t=localStorage.getItem('leehack-theme');if(t)document.documentElement.dataset.theme=t}catch(_){}",
        ),
        const link(href: _canonical, rel: 'canonical'),
        meta(attributes: {'property': 'og:title', 'content': site.seo.title}),
        meta(attributes: {'property': 'og:description', 'content': site.seo.description}),
        const meta(attributes: {'property': 'og:url', 'content': _canonical}),
        const meta(attributes: {'property': 'og:type', 'content': 'website'}),
        const link(href: 'images/llama.svg', rel: 'icon', type: 'image/svg+xml'),
        siteThemeStyles(),
        const link(href: 'site.css', rel: 'stylesheet'),
        if (site.measurementId.isNotEmpty) ...[
          script(content: _analyticsSnippet(site.measurementId)),
          script(
            src: Uri.https('www.googletagmanager.com', '/gtag/js', {'id': site.measurementId}).toString(),
            async: true,
          ),
        ],
      ],
      body: App(site),
    ),
  );
}

String _analyticsSnippet(String measurementId) =>
    '''
window.dataLayer = window.dataLayer || [];
function gtag(){dataLayer.push(arguments);}
gtag('consent', 'default', {
  analytics_storage: 'denied',
  ad_storage: 'denied',
  ad_user_data: 'denied',
  ad_personalization: 'denied'
});
try {
  if (localStorage.getItem('leehack-analytics-consent') === 'granted') {
    gtag('consent', 'update', {analytics_storage: 'granted'});
  }
} catch (_) {}
gtag('js', new Date());
gtag('config', ${jsonEncode(measurementId).replaceAll('<', r'\u003c')});
''';
