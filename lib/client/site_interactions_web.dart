import 'package:web/web.dart' as web;

import 'analytics_consent.dart';
import 'answer_stream.dart';
import 'event_listeners.dart';
import 'figure_pointer.dart';
import 'particle_figures.dart';
import 'theme_switch.dart';

void Function() mountSiteInteractions() {
  web.document.documentElement?.setAttribute('data-live', '');
  final listeners = EventListeners();
  final motion = web.window.matchMedia('(prefers-reduced-motion: reduce)');
  bool reducedMotion() => motion.matches;

  final figures = ParticleFigures(
    web.document.getElementById('figures') as web.HTMLCanvasElement,
    calm: reducedMotion(),
  )..mount();
  final consent = AnalyticsConsent()..mount(listeners);
  final stream = AnswerStream(figures.pulse, reducedMotion, consent.trackAnswer)..mount(listeners);
  ThemeSwitch(figures.retint).mount(listeners);
  FigurePointer(figures, reducedMotion).mount(listeners);

  listeners.add(motion, 'change', (_) {
    figures.calm = reducedMotion();
    if (reducedMotion()) stream.showFinalState();
  });

  return () {
    listeners.dispose();
    stream.dispose();
    figures.dispose();
  };
}
