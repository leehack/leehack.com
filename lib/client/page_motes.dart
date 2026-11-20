import 'dart:js_interop';
import 'dart:math';

import 'package:web/web.dart' as web;

import 'event_listeners.dart';
import 'theme_colors.dart';

class PageMotes {
  PageMotes(this._canvas, {required this._calm});

  static const _repelDistanceSquared = 120 * 120;

  final web.HTMLCanvasElement _canvas;
  final _listeners = EventListeners();
  final _random = Random();
  late final _drawFrame = _draw.toJS;
  web.CanvasRenderingContext2D? _context;
  List<_Mote> _motes = [];
  int _width = 0;
  int _height = 0;
  int? _frameId;
  bool _calm;
  ({double x, double y})? pointer;

  void mount() {
    _context = _canvas.getContext('2d') as web.CanvasRenderingContext2D?;
    if (_context == null) return;

    _listeners.add(web.window, 'resize', (_) => _seed());
    _listeners.add(web.document, 'visibilitychange', (_) {
      if (web.document.hidden) {
        pointer = null;
        _cancelFrame();
      } else {
        _scheduleFrame();
      }
    });
    _seed();
  }

  set calm(bool value) {
    if (_calm == value) return;
    _calm = value;
    if (_calm) {
      pointer = null;
      _cancelFrame();
      _paint();
    } else {
      _scheduleFrame();
    }
  }

  void retint() {
    if (_motes.isEmpty) return;
    final style = web.window.getComputedStyle(_canvas);
    final accent = themeColor(style, '--ac');
    final light = themeColor(style, '--tx');
    for (final mote in _motes) {
      mote.fill = mixColors(accent, light, mote.mix, mote.alpha).toJS;
    }
    if (_calm) {
      _paint();
    } else {
      _scheduleFrame();
    }
  }

  void _seed() {
    _width = _canvas.clientWidth;
    _height = _canvas.clientHeight;
    final ratio = min(2, web.window.devicePixelRatio);
    _canvas
      ..width = (_width * ratio).round()
      ..height = (_height * ratio).round();
    _context!.scale(ratio, ratio);

    final count = (_width * _height / 20000).round().clamp(16, 90);
    _motes = List.generate(
      count,
      (_) => _Mote(
        x: _random.nextDouble() * _width,
        y: _random.nextDouble() * _height,
        vx: .04 + _random.nextDouble() * .16,
        vy: -(.03 + _random.nextDouble() * .13),
        phase: _random.nextDouble() * 2 * pi,
        size: _random.nextDouble() < .2 ? 2.4 : 1.7,
        mix: _random.nextDouble(),
        alpha: .14 + _random.nextDouble() * .4,
      ),
    );
    retint();
  }

  void _draw(double time) {
    _frameId = null;
    if (_calm || web.document.hidden) return;
    _paint(time);
    _scheduleFrame();
  }

  void _paint([double? time]) {
    final drawing = _context;
    if (drawing == null) return;
    drawing.clearRect(0, 0, _width, _height);
    for (final mote in _motes) {
      if (time != null) _step(mote, time);
      drawing.fillStyle = mote.fill;
      drawing.fillRect(mote.x + mote.offsetX, mote.y + mote.offsetY, mote.size, mote.size);
    }
  }

  void _step(_Mote mote, double time) {
    mote.x += mote.vx + sin(time / 2600 + mote.phase) * .06;
    mote.y += mote.vy;
    if (mote.x > _width + 4) mote.x = -4;
    if (mote.y < -4) mote.y = _height + 4;
    if (pointer case final position?) {
      final dx = mote.x - position.x;
      final dy = mote.y - position.y;
      final distanceSquared = dx * dx + dy * dy;
      if (distanceSquared < _repelDistanceSquared && distanceSquared > 0) {
        final force = (_repelDistanceSquared - distanceSquared) / _repelDistanceSquared * 1.2 / sqrt(distanceSquared);
        mote.offsetX += dx * force;
        mote.offsetY += dy * force;
      }
    }
    mote.offsetX *= .93;
    mote.offsetY *= .93;
  }

  void _scheduleFrame() {
    if (!_calm && !web.document.hidden && _context != null) {
      _frameId ??= web.window.requestAnimationFrame(_drawFrame);
    }
  }

  void _cancelFrame() {
    if (_frameId case final frame?) web.window.cancelAnimationFrame(frame);
    _frameId = null;
  }

  void dispose() {
    _listeners.dispose();
    _cancelFrame();
    _context = null;
  }
}

class _Mote {
  _Mote({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.phase,
    required this.size,
    required this.mix,
    required this.alpha,
  });

  double x;
  double y;
  final double vx;
  final double vy;
  final double phase;
  final double size;
  final double mix;
  final double alpha;
  double offsetX = 0;
  double offsetY = 0;
  late JSString fill;
}
