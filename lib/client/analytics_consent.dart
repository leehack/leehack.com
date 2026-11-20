import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'event_listeners.dart';

@JS('gtag')
external void _gtag(JSString command, JSString name, JSObject parameters);

const _consentKey = 'leehack-analytics-consent';

class AnalyticsConsent {
  final _banner = web.document.getElementById('analytics-consent');

  void mount(EventListeners listeners) {
    final banner = _banner;
    if (banner == null) return;

    String? saved;
    try {
      saved = web.window.localStorage.getItem(_consentKey);
    } catch (_) {
      // Storage can be blocked by the browser even when scripts are enabled.
    }
    if (saved == 'granted' || saved == 'denied') return;

    void remember(String choice) {
      try {
        web.window.localStorage.setItem(_consentKey, choice);
      } catch (_) {
        // The choice still applies to the current page when storage is blocked.
      }
      _gtag('consent'.toJS, 'update'.toJS, {'analytics_storage': choice}.jsify()! as JSObject);
      banner.setAttribute('hidden', '');
    }

    listeners.add(web.document.getElementById('analytics-accept')!, 'click', (_) => remember('granted'));
    listeners.add(web.document.getElementById('analytics-decline')!, 'click', (_) => remember('denied'));
    banner.removeAttribute('hidden');
  }

  void trackAnswer(String id) {
    if (_banner == null) return;
    _gtag('event'.toJS, 'select_content'.toJS, {'content_type': 'question', 'item_id': id}.jsify()! as JSObject);
  }
}
