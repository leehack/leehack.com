import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'event_listeners.dart';

// Pointer events can report fractional CSS pixels, unlike package:web's MouseEvent getters.
extension type _PointerCoordinates(JSObject _) implements JSObject {
  external double get clientX;
  external double get clientY;
}

class SitePointer {
  SitePointer(this._onMove, this._reducedMotion);

  final void Function(({double x, double y})?) _onMove;
  final bool Function() _reducedMotion;

  void mount(EventListeners listeners) {
    final root = web.document.documentElement!;
    listeners.add(root, 'pointermove', (event) {
      if (_reducedMotion()) return;
      final pointer = _PointerCoordinates(event);
      _onMove((x: pointer.clientX, y: pointer.clientY));
    });
    listeners.add(root, 'pointerleave', (_) => _onMove(null));
    listeners.add(web.window, 'blur', (_) => _onMove(null));
  }
}
