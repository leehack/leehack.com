import 'dart:async';
import 'dart:js_interop';
import 'dart:math';

import 'package:web/web.dart' as web;

import 'theme_colors.dart';

typedef _Figure = ({String attribute, double centerX, double bottom, double height, bool themed});

/// Draws the hero figures as particles: the llama in the theme's colours, Dash in its own.
class ParticleFigures {
  ParticleFigures(this._canvas, {required this._calm});

  static const _width = 300;
  static const _height = 210;
  static const _sampleStep = 3;
  static const _scratchSize = 256;
  static const _repelDistanceSquared = 2600;
  static const _idleMilliseconds = 4000;
  static const _figures = <_Figure>[
    (attribute: 'data-image', centerX: 96, bottom: 200, height: 176, themed: true),
    (attribute: 'data-companion', centerX: 236, bottom: 200, height: 104, themed: false),
  ];

  final web.HTMLCanvasElement _canvas;
  bool _calm;
  final _random = Random();
  final _particles = <_Particle>[];
  late final _drawFrame = _draw.toJS;
  web.CanvasRenderingContext2D? _context;
  web.IntersectionObserver? _observer;
  int? _frameId;
  double? _idleSince;
  double _energy = 0;
  bool _visible = false;
  bool _disposed = false;
  ({double x, double y})? _pointer;

  void mount() => unawaited(_loadParticles());

  void pulse() {
    _energy = 1;
    _wake();
  }

  set pointer(({double x, double y})? value) {
    if (value == null && _pointer == null) return;
    _pointer = value;
    _wake();
  }

  set calm(bool value) {
    if (_calm == value) return;
    _calm = value;
    if (_context != null) _applyMotionPreference();
  }

  /// Re-reads the theme colours, for when the theme changes after load.
  void retint() {
    if (_particles.isEmpty) return;

    final style = web.window.getComputedStyle(_canvas);
    final shade = themeColor(style, '--ac');
    final light = themeColor(style, '--tx');
    for (final particle in _particles) {
      final brightness = particle.brightness;
      if (brightness == null) continue;
      particle.color = mixColors(shade, light, brightness, .3 + .7 * brightness).toJS;
    }
    if (_calm && _context != null) {
      _drawStill();
    } else {
      _wake();
    }
  }

  Future<void> _loadParticles() async {
    final images = await Future.wait([
      for (final figure in _figures) _loadImage(_canvas.getAttribute(figure.attribute)),
    ]);
    if (_disposed) return;

    final ratio = min(2, web.window.devicePixelRatio);
    _canvas
      ..width = (_width * ratio).round()
      ..height = (_height * ratio).round();
    final drawing = _canvas.getContext('2d') as web.CanvasRenderingContext2D?;
    if (drawing == null) return;
    drawing.scale(ratio, ratio);

    for (final (index, image) in images.indexed) {
      if (image != null) _sample(image, _figures[index]);
    }
    if (_particles.isEmpty) return;

    retint();
    _context = drawing;
    _applyMotionPreference();
  }

  Future<web.HTMLImageElement?> _loadImage(String? source) async {
    if (source == null) return null;
    final image = web.HTMLImageElement()..src = source;
    try {
      await image.decode().toDart;
      return image;
    } catch (_) {
      return null;
    }
  }

  void _sample(web.HTMLImageElement image, _Figure figure) {
    // An SVG without width and height reports no natural size, so it is treated as square.
    final naturalWidth = image.naturalWidth == 0 ? _scratchSize : image.naturalWidth;
    final naturalHeight = image.naturalHeight == 0 ? _scratchSize : image.naturalHeight;
    final fit = _scratchSize / max(naturalWidth, naturalHeight);
    final scratchWidth = (naturalWidth * fit).round();
    final scratchHeight = (naturalHeight * fit).round();

    final scratch = _scratchContext(scratchWidth, scratchHeight);
    if (scratch == null) return;
    scratch.drawImage(image, 0, 0, scratchWidth, scratchHeight);
    final outline = scratch.getImageData(0, 0, scratchWidth, scratchHeight).data.toDart;
    var left = scratchWidth, top = scratchHeight, right = 0, bottom = 0;
    for (var y = 0; y < scratchHeight; y++) {
      for (var x = 0; x < scratchWidth; x++) {
        if (outline[(y * scratchWidth + x) * 4 + 3] <= 130) continue;
        left = min(left, x);
        right = max(right, x);
        top = min(top, y);
        bottom = max(bottom, y);
      }
    }
    if (right <= left || bottom <= top) return;

    final scale = figure.height / (bottom - top);
    final scene = _scratchContext(_width, _height);
    if (scene == null) return;
    scene.drawImage(
      image,
      figure.centerX - (left + right) / 2 * scale,
      figure.bottom - bottom * scale,
      scratchWidth * scale,
      scratchHeight * scale,
    );
    final pixels = scene.getImageData(0, 0, _width, _height).data.toDart;
    for (var y = 0; y < _height; y += _sampleStep) {
      for (var x = 0; x < _width; x += _sampleStep) {
        final index = (y * _width + x) * 4;
        if (pixels[index + 3] <= 130) continue;
        final brightness = (pixels[index] * .3 + pixels[index + 1] * .59 + pixels[index + 2] * .11) / 255;
        // Dark pixels are left empty so that eyes and outlines read as gaps on the dark page.
        if (!figure.themed && brightness < .22) continue;
        _particles.add(
          _Particle(
            homeX: x.toDouble(),
            homeY: y.toDouble(),
            x: _random.nextDouble() * _width,
            y: _random.nextDouble() * _height,
            phase: _random.nextDouble() * 2 * pi,
            brightness: figure.themed ? brightness : null,
            color: 'rgba(${pixels[index]},${pixels[index + 1]},${pixels[index + 2]},.92)'.toJS,
          ),
        );
      }
    }
  }

  web.CanvasRenderingContext2D? _scratchContext(int width, int height) {
    final canvas = (web.document.createElement('canvas') as web.HTMLCanvasElement)
      ..width = width
      ..height = height;
    return canvas.getContext(
      '2d',
      web.CanvasRenderingContext2DSettings(willReadFrequently: true),
    ) as web.CanvasRenderingContext2D?;
  }

  void _applyMotionPreference() {
    if (_calm) {
      _cancelFrame();
      _observer?.disconnect();
      _observer = null;
      _visible = false;
      _pointer = null;
      _energy = 0;
      _drawStill();
      return;
    }

    _observer ??= web.IntersectionObserver(
      (JSArray<web.IntersectionObserverEntry> entries, web.IntersectionObserver _) {
        if (_calm || _disposed) return;
        _visible = entries.toDart.last.isIntersecting;
        if (_visible) {
          _wake();
        } else {
          _cancelFrame();
        }
      }.toJS,
    )..observe(_canvas);
  }

  void _drawStill() {
    final drawing = _context!;
    drawing.clearRect(0, 0, _width, _height);
    for (final particle in _particles) {
      particle.x = particle.homeX;
      particle.y = particle.homeY;
      particle.vx = particle.vy = 0;
      drawing.fillStyle = particle.color;
      drawing.fillRect(particle.homeX, particle.homeY, 1.7, 1.7);
    }
  }

  void _draw(double time) {
    _frameId = null;
    if (!_visible || _disposed) return;

    final drawing = _context!;
    var pointerX = -999.0, pointerY = -999.0;
    if (_pointer case final pointer?) {
      final bounds = _canvas.getBoundingClientRect();
      pointerX = (pointer.x - bounds.left) * _width / bounds.width;
      pointerY = (pointer.y - bounds.top) * _height / bounds.height;
    }
    drawing.clearRect(0, 0, _width, _height);
    _energy *= .965;
    final drift = 1.1 + _energy * 3.2;
    final idleSince = _idleSince ??= time;
    var settled = time - idleSince >= _idleMilliseconds && _energy < .03;
    var pointerNearby = false;

    for (final particle in _particles) {
      final goalX = particle.homeX + sin(time / 900 + particle.phase) * drift;
      final goalY = particle.homeY + cos(time / 1100 + particle.phase) * drift;
      final dx = particle.x - pointerX;
      final dy = particle.y - pointerY;
      final distanceSquared = dx * dx + dy * dy;
      if (distanceSquared < _repelDistanceSquared) {
        pointerNearby = true;
        if (distanceSquared > 0) {
          final force = (_repelDistanceSquared - distanceSquared) / _repelDistanceSquared * 2.4 / sqrt(distanceSquared);
          particle.vx += dx * force;
          particle.vy += dy * force;
        }
      }
      particle.vx = (particle.vx + (goalX - particle.x) * .055) * .84;
      particle.vy = (particle.vy + (goalY - particle.y) * .055) * .84;
      particle.x += particle.vx;
      particle.y += particle.vy;
      if (settled && ((particle.x - goalX).abs() > 1 || (particle.y - goalY).abs() > 1)) {
        settled = false;
      }
      drawing.fillStyle = particle.color;
      drawing.fillRect(particle.x, particle.y, 1.7, 1.7);
    }

    if (pointerNearby) _idleSince = null;
    if (pointerNearby || !settled) _scheduleFrame();
  }

  void _wake() {
    _idleSince = null;
    _scheduleFrame();
  }

  void _scheduleFrame() {
    if (_visible && !_calm && !_disposed) {
      _frameId ??= web.window.requestAnimationFrame(_drawFrame);
    }
  }

  void _cancelFrame() {
    if (_frameId case final frame?) web.window.cancelAnimationFrame(frame);
    _frameId = null;
  }

  void dispose() {
    _disposed = true;
    _observer?.disconnect();
    _cancelFrame();
  }
}

class _Particle {
  _Particle({
    required this.homeX,
    required this.homeY,
    required this.x,
    required this.y,
    required this.phase,
    required this.brightness,
    required this.color,
  });

  final double homeX;
  final double homeY;
  final double phase;

  /// Set for particles that follow the theme; null for ones that keep their image colour.
  final double? brightness;
  JSString color;
  double x;
  double y;
  double vx = 0;
  double vy = 0;
}
