import 'dart:async';
import 'dart:js_interop';
import 'dart:math';

import 'package:web/web.dart' as web;

import 'particle_figures.dart';

@JS('gtag')
external void _gtag(JSString command, JSString name, JSObject parameters);

const _consentKey = 'leehack-analytics-consent';
const _themeKey = 'leehack-theme';
const _themes = ['navy', 'amber', 'sky', 'coral', 'paper'];

// Pointer events can report fractional CSS pixels, unlike package:web's MouseEvent getters.
extension type _PointerCoordinates(JSObject _) implements JSObject {
  external double get clientX;
  external double get clientY;
}

void Function() mountSiteInteractions() {
  final interactions = _SiteInteractions()..mount();
  return interactions.dispose;
}

class _SiteInteractions {
  final _document = web.document;
  final _window = web.window;
  final _random = Random();
  final _startupTimers = <Timer>[];
  final _listeners = <void Function()>[];

  late final _root = _document.documentElement!;
  late final _motion = _window.matchMedia('(prefers-reduced-motion: reduce)');
  bool get _calm => _motion.matches;
  late final _cursor = (_document.createElement('i') as web.HTMLElement)
    ..className = 'cur'
    ..setAttribute('aria-hidden', 'true');
  late final _question = _document.getElementById('question')!;
  late final _intro = _document.getElementById('intro')!;
  late final _questions = _document.getElementById('questions');
  late final _answers = [
    for (final chip in _elements(_document.querySelectorAll('.chip[data-answer]')))
      (
        chip: chip,
        id: chip.getAttribute('data-answer')!,
        panel: _document.getElementById(chip.getAttribute('aria-controls')!)!,
      ),
  ];
  late final _banner = _document.getElementById('analytics-consent') as web.HTMLElement?;
  late final _figures = ParticleFigures(_document.getElementById('figures') as web.HTMLCanvasElement, calm: _calm);

  Timer? _sequenceTimer;
  Timer? _autoAnswerTimer;
  int? _selected;

  void mount() {
    for (var index = 0; index < _answers.length; index++) {
      final answer = _answers[index];
      _listen(answer.chip, 'click', (_) {
        _autoAnswerTimer?.cancel();
        _pick(index);
        if (_banner != null) {
          _gtag(
            'event'.toJS,
            'select_content'.toJS,
            {'content_type': 'question', 'item_id': answer.id}.jsify()! as JSObject,
          );
        }
      });
    }

    _figures.mount();
    _mountConsent();
    _mountThemeSwitch();

    _listen(_root, 'pointermove', (event) {
      if (_calm) return;
      final pointer = _PointerCoordinates(event);
      _figures.pointer = (x: pointer.clientX, y: pointer.clientY);
    });
    _listen(_root, 'pointerleave', (_) => _figures.pointer = null);
    _listen(_window, 'blur', (_) => _figures.pointer = null);
    _listen(_motion, 'change', (_) {
      _figures.calm = _calm;
      if (_calm) _showFinalState();
    });

    if (_calm) {
      _showFinalState();
    } else {
      _startupTimers.addAll([
        Timer(const Duration(milliseconds: 900), () => _question.classList.add('in')),
        Timer(const Duration(milliseconds: 1500), () {
          _stream(_intro, 55, () {
            _questions?.classList.add('in');
            if (_answers.isNotEmpty) {
              _autoAnswerTimer = Timer(const Duration(milliseconds: 450), () => _pick(0));
            }
          });
        }),
      ]);
    }

    _root.classList.add('js-ready');
  }

  void _showFinalState() {
    _stopTimers();
    _cursor.remove();
    _question.classList.add('in');
    _questions?.classList.add('in');
    for (final word in _elements(_intro.querySelectorAll('.t'))) {
      word.classList.add('on');
    }
    if (_answers.isNotEmpty) _pick(_selected ?? 0);
  }

  void _pick(int index) {
    _sequenceTimer?.cancel();
    _selected = index;
    for (var other = 0; other < _answers.length; other++) {
      final selected = other == index;
      final answer = _answers[other];
      answer.chip.setAttribute('aria-pressed', '$selected');
      answer.panel.classList.toggle('on', selected);
    }
    final panel = _answers[index].panel;
    if (_calm) {
      for (final element in _elements(panel.querySelectorAll('.t, .it'))) {
        element.classList.add('on');
      }
      return;
    }

    final items = _elements(panel.querySelectorAll('.it'));
    for (final item in items) {
      item.classList.remove('on');
    }

    _stream(panel.querySelector('.lead')!, 26, () {
      var nextItem = 0;
      void reveal() {
        items[nextItem++].classList.add('on');
        _figures.pulse();
        if (nextItem < items.length) {
          _sequenceTimer = Timer(const Duration(milliseconds: 85), reveal);
        }
      }

      if (items.isNotEmpty) reveal();
    });
  }

  void _stream(web.Element element, int delay, void Function() onDone) {
    final words = _elements(element.querySelectorAll('.t'));
    for (final word in words) {
      word.classList.remove('on');
    }
    _cursor.remove();
    var index = 0;

    void reveal() {
      if (index == words.length) {
        onDone();
        return;
      }
      final word = words[index++];
      word.classList.add('on');
      word.after(_cursor);
      _figures.pulse();
      _sequenceTimer = Timer(Duration(milliseconds: delay + _random.nextInt(delay)), reveal);
    }

    reveal();
  }

  void _mountConsent() {
    final banner = _banner;
    if (banner == null) return;

    String? saved;
    try {
      saved = _window.localStorage.getItem(_consentKey);
    } catch (_) {
      // Storage can be blocked by the browser even when scripts are enabled.
    }
    if (saved == 'granted' || saved == 'denied') return;

    void remember(String choice) {
      try {
        _window.localStorage.setItem(_consentKey, choice);
      } catch (_) {
        // The choice still applies to the current page when storage is blocked.
      }
      _gtag('consent'.toJS, 'update'.toJS, {'analytics_storage': choice}.jsify()! as JSObject);
      banner.setAttribute('hidden', '');
    }

    _listen(_document.getElementById('analytics-accept')!, 'click', (_) => remember('granted'));
    _listen(_document.getElementById('analytics-decline')!, 'click', (_) => remember('denied'));
    banner.removeAttribute('hidden');
  }

  void _mountThemeSwitch() {
    final button = _document.getElementById('theme');
    if (button == null) return;

    var current = _root.getAttribute('data-theme');
    if (!_themes.contains(current)) current = _themes.first;
    button.textContent = 'theme: $current';

    _listen(button, 'click', (_) {
      final next = _themes[(_themes.indexOf(current!) + 1) % _themes.length];
      current = next;
      _root.setAttribute('data-theme', next);
      button.textContent = 'theme: $next';
      _figures.retint();
      try {
        _window.localStorage.setItem(_themeKey, next);
      } catch (_) {
        // The theme still applies to the current page when storage is blocked.
      }
    });
  }

  void _listen(web.EventTarget target, String type, void Function(web.Event) callback) {
    final listener = callback.toJS;
    target.addEventListener(type, listener);
    _listeners.add(() => target.removeEventListener(type, listener));
  }

  void _stopTimers() {
    for (final timer in _startupTimers) {
      timer.cancel();
    }
    _sequenceTimer?.cancel();
    _autoAnswerTimer?.cancel();
  }

  void dispose() {
    for (final remove in _listeners) {
      remove();
    }
    _stopTimers();
    _cursor.remove();
    _figures.dispose();
  }
}

List<web.Element> _elements(web.NodeList nodes) {
  return [for (var index = 0; index < nodes.length; index++) nodes.item(index)! as web.Element];
}
