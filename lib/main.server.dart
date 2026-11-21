import 'dart:convert';
import 'dart:io';

import 'package:jaspr/dom.dart';
import 'package:jaspr/server.dart';

import 'app.dart';
import 'main.server.options.dart';
import 'site_data.dart';
import 'site_themes.dart';

const _canonical = 'https://leehack.com/';
const _previewImage = '${_canonical}images/og.png';

void main() {
  final site = SiteData.load();
  Jaspr.initializeApp(options: defaultServerOptions);
  runApp(
    Document(
      lang: 'en',
      base: Platform.environment['SITE_BASE'] ?? '/',
      title: site.seo.title,
      meta: {
        'description': site.seo.description,
        'twitter:card': 'summary_large_image',
        'twitter:image': _previewImage,
      },
      head: [
        const script(
          content:
              "document.documentElement.classList.add('js');"
              // The js class hides the answers until the client script reveals them, so it is
              // dropped again when that script never starts.
              "setTimeout(function(){var e=document.documentElement;"
              "if(!e.hasAttribute('data-live'))e.classList.remove('js')},4000);"
              "try{var t=localStorage.getItem('leehack-theme');if(t)document.documentElement.dataset.theme=t}catch(_){}",
        ),
        const link(href: _canonical, rel: 'canonical'),
        meta(attributes: {'property': 'og:title', 'content': site.seo.title}),
        meta(attributes: {'property': 'og:description', 'content': site.seo.description}),
        const meta(attributes: {'property': 'og:url', 'content': _canonical}),
        const meta(attributes: {'property': 'og:type', 'content': 'website'}),
        const meta(attributes: {'property': 'og:image', 'content': _previewImage}),
        const meta(attributes: {'property': 'og:image:width', 'content': '1200'}),
        const meta(attributes: {'property': 'og:image:height', 'content': '630'}),
        meta(attributes: {'property': 'og:image:alt', 'content': site.seo.title}),
        const link(href: 'images/apple-touch-icon.png', rel: 'apple-touch-icon'),
        const link(href: 'images/favicon-32.png', rel: 'icon', type: 'image/png', attributes: {'sizes': '32x32'}),
        const link(href: 'images/llama.svg', rel: 'icon', type: 'image/svg+xml'),
        for (final font in const ['newsreader-latin.woff2', 'ibm-plex-mono-400-latin.woff2'])
          link(
            href: 'fonts/$font',
            rel: 'preload',
            as: 'font',
            type: 'font/woff2',
            attributes: const {'crossorigin': ''},
          ),
        siteThemeStyles(),
        const link(href: 'site.css', rel: 'stylesheet'),
        const link(href: 'finder.css', rel: 'stylesheet'),
        const script(src: 'finder.js', defer: true),
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
