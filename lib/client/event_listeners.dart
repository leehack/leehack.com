import 'dart:js_interop';

import 'package:web/web.dart' as web;

class EventListeners {
  final _removeListeners = <void Function()>[];

  void add(web.EventTarget target, String type, void Function(web.Event) callback) {
    final listener = callback.toJS;
    target.addEventListener(type, listener);
    _removeListeners.add(() => target.removeEventListener(type, listener));
  }

  void dispose() {
    for (final remove in _removeListeners) {
      remove();
    }
  }
}
