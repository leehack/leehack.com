import 'dart:async';
import 'dart:math';

import 'package:web/web.dart' as web;

import 'event_listeners.dart';

class AnswerStream {
  AnswerStream(this._pulse, this._reducedMotion, this._onSelect);

  final void Function() _pulse;
  final bool Function() _reducedMotion;
  final void Function(String) _onSelect;

  final _random = Random();
  final _startupTimers = <Timer>[];
  final _question = web.document.getElementById('question')!;
  final _intro = web.document.getElementById('intro')!;
  final _questions = web.document.getElementById('questions');
  final _cursor = (web.document.createElement('i') as web.HTMLElement)
    ..className = 'stream-cursor'
    ..setAttribute('aria-hidden', 'true');
  final _answers = [
    for (final chip in _elements(web.document.querySelectorAll('.chip[data-answer]')))
      (
        chip: chip,
        id: chip.getAttribute('data-answer')!,
        panel: web.document.getElementById(chip.getAttribute('aria-controls')!)!,
      ),
  ];

  Timer? _sequenceTimer;
  Timer? _autoAnswerTimer;
  int? _selected;

  void mount(EventListeners listeners) {
    for (var index = 0; index < _answers.length; index++) {
      final answer = _answers[index];
      listeners.add(answer.chip, 'click', (_) {
        _autoAnswerTimer?.cancel();
        _pick(index);
        _onSelect(answer.id);
      });
    }

    if (_reducedMotion()) {
      showFinalState();
      return;
    }

    _startupTimers.addAll([
      Timer(const Duration(milliseconds: 900), () => _question.classList.add('is-visible')),
      Timer(const Duration(milliseconds: 1500), () {
        _stream(_intro, 55, () {
          _questions?.classList.add('is-visible');
          if (_answers.isNotEmpty) {
            _autoAnswerTimer = Timer(const Duration(milliseconds: 450), () => _pick(0));
          }
        });
      }),
    ]);
  }

  void showFinalState() {
    _stopTimers();
    _cursor.remove();
    _question.classList.add('is-visible');
    _questions?.classList.add('is-visible');
    for (final word in _elements(_intro.querySelectorAll('.stream-word'))) {
      word.classList.add('is-visible');
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
      answer.panel.classList.toggle('is-visible', selected);
    }
    final panel = _answers[index].panel;
    if (_reducedMotion()) {
      for (final element in _elements(panel.querySelectorAll('.stream-word, .stream-item'))) {
        element.classList.add('is-visible');
      }
      return;
    }

    final items = _elements(panel.querySelectorAll('.stream-item'));
    for (final item in items) {
      item.classList.remove('is-visible');
    }

    _stream(panel.querySelector('.lead')!, 26, () {
      var nextItem = 0;
      void reveal() {
        items[nextItem++].classList.add('is-visible');
        _pulse();
        if (nextItem < items.length) {
          _sequenceTimer = Timer(const Duration(milliseconds: 85), reveal);
        }
      }

      if (items.isNotEmpty) reveal();
    });
  }

  void _stream(web.Element element, int delay, void Function() onDone) {
    final words = _elements(element.querySelectorAll('.stream-word'));
    for (final word in words) {
      word.classList.remove('is-visible');
    }
    _cursor.remove();
    var index = 0;

    void reveal() {
      if (index == words.length) {
        onDone();
        return;
      }
      final word = words[index++];
      word.classList.add('is-visible');
      word.after(_cursor);
      _pulse();
      _sequenceTimer = Timer(Duration(milliseconds: delay + _random.nextInt(delay)), reveal);
    }

    reveal();
  }

  void _stopTimers() {
    for (final timer in _startupTimers) {
      timer.cancel();
    }
    _sequenceTimer?.cancel();
    _autoAnswerTimer?.cancel();
  }

  void dispose() {
    _stopTimers();
    _cursor.remove();
  }
}

List<web.Element> _elements(web.NodeList nodes) {
  return [for (var index = 0; index < nodes.length; index++) nodes.item(index)! as web.Element];
}
