import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'event_listeners.dart';
import 'particle_figures.dart';

// Pointer events can report fractional CSS pixels, unlike package:web's MouseEvent getters.
extension type _PointerCoordinates(JSObject _) implements JSObject {
  external double get clientX;
  external double get clientY;
}

class FigurePointer {
  FigurePointer(this._figures, this._reducedMotion);

  final ParticleFigures _figures;
  final bool Function() _reducedMotion;

  void mount(EventListeners listeners) {
    final root = web.document.documentElement!;
    listeners.add(root, 'pointermove', (event) {
      if (_reducedMotion()) return;
      final pointer = _PointerCoordinates(event);
      _figures.pointer = (x: pointer.clientX, y: pointer.clientY);
    });
    listeners.add(root, 'pointerleave', (_) => _figures.pointer = null);
    listeners.add(web.window, 'blur', (_) => _figures.pointer = null);
  }
}
