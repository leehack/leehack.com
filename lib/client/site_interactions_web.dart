import 'package:web/web.dart' as web;

import 'analytics_consent.dart';
import 'answer_stream.dart';
import 'event_listeners.dart';
import 'page_motes.dart';
import 'particle_figures.dart';
import 'site_pointer.dart';
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
  final motes = PageMotes(
    web.document.querySelector('.background-motes') as web.HTMLCanvasElement,
    calm: reducedMotion(),
  )..mount();
  final consent = AnalyticsConsent()..mount(listeners);
  final stream = AnswerStream(figures.pulse, reducedMotion, consent.trackAnswer)..mount(listeners);
  ThemeSwitch(() {
    figures.retint();
    motes.retint();
  }).mount(listeners);
  SitePointer((pointer) {
    figures.pointer = pointer;
    motes.pointer = pointer;
  }, reducedMotion).mount(listeners);

  listeners.add(motion, 'change', (_) {
    figures.calm = reducedMotion();
    motes.calm = reducedMotion();
    if (reducedMotion()) stream.showFinalState();
  });

  return () {
    listeners.dispose();
    stream.dispose();
    figures.dispose();
    motes.dispose();
  };
}
