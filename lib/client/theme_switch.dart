import 'package:web/web.dart' as web;

import 'event_listeners.dart';

const _themeKey = 'leehack-theme';

class ThemeSwitch {
  ThemeSwitch(this._onChange);

  final void Function() _onChange;

  void mount(EventListeners listeners) {
    final button = web.document.getElementById('theme');
    if (button == null) return;

    final themes = button.getAttribute('data-themes')!.split(' ');
    final root = web.document.documentElement!;
    var index = themes.indexOf(root.getAttribute('data-theme') ?? '');
    if (index < 0) index = 0;
    button.textContent = 'theme: ${themes[index]}';

    listeners.add(button, 'click', (_) {
      index = (index + 1) % themes.length;
      final theme = themes[index];
      root.setAttribute('data-theme', theme);
      button.textContent = 'theme: $theme';
      _onChange();
      try {
        web.window.localStorage.setItem(_themeKey, theme);
      } catch (_) {
        // The theme still applies to the current page when storage is blocked.
      }
    });
  }
}
