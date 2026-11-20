import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

const _siteThemes = {
  'navy': _Theme(
    background: '#0E1220',
    text: '#E9EAF2',
    secondary: '#C6C9D8',
    muted: '#8388A2',
    line: 'rgba(233,234,242,.14)',
    accent: '#FFD166',
    colorScheme: 'dark',
  ),
  'amber': _Theme(
    background: '#121211',
    text: '#E9E5DB',
    secondary: '#CFCABD',
    muted: '#8C877B',
    line: 'rgba(233,229,219,.14)',
    accent: '#F0A23B',
    colorScheme: 'dark',
  ),
  'sky': _Theme(
    background: '#0F1418',
    text: '#E6ECF0',
    secondary: '#C3CDD4',
    muted: '#7E8B95',
    line: 'rgba(230,236,240,.14)',
    accent: '#5CC8F8',
    colorScheme: 'dark',
  ),
  'coral': _Theme(
    background: '#151211',
    text: '#EFE7E1',
    secondary: '#D3C8C0',
    muted: '#92877F',
    line: 'rgba(239,231,225,.14)',
    accent: '#FF6F59',
    colorScheme: 'dark',
  ),
  'paper': _Theme(
    background: '#F4F0E6',
    text: '#1C1B18',
    secondary: '#3A3832',
    muted: '#736D61',
    line: 'rgba(28,27,24,.18)',
    accent: '#C2410C',
    colorScheme: 'light',
    shade: .1,
  ),
};

final themeNames = _siteThemes.keys;

String get defaultSiteThemeCss => _siteThemes.values.first.rule('body');

String get siteThemeCss => [
  _siteThemes.values.first.rule('body', includeShade: true),
  for (final theme in _siteThemes.entries.skip(1))
    theme.value.rule('[data-theme="${theme.key}"] body', includeShade: true),
].join('\n');

Component siteThemeStyles() => Component.element(tag: 'style', children: [RawText(siteThemeCss)]);

class _Theme {
  const _Theme({
    required this.background,
    required this.text,
    required this.secondary,
    required this.muted,
    required this.line,
    required this.accent,
    required this.colorScheme,
    this.shade = .7,
  });

  final String background;
  final String text;
  final String secondary;
  final String muted;
  final String line;
  final String accent;
  final String colorScheme;
  final double shade;

  String rule(String selector, {bool includeShade = false}) =>
      '''
$selector {
  --bg: $background;
  --tx: $text;
  --so: $secondary;
  --mu: $muted;
  --line: $line;
  --ac: $accent;
  color-scheme: $colorScheme;
${includeShade ? '  --shade: $shade;\n' : ''}}''';
}
