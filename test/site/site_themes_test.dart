import 'package:leehack_site/site_themes.dart';
import 'package:test/test.dart';

void main() {
  test('emits the background shade for each homepage theme', () {
    final rules = RegExp(r'([^{}]+)\{([^{}]+)\}').allMatches(siteThemeCss);
    final shades = {
      for (final rule in rules) rule[1]!.trim(): RegExp(r'--shade: ([\d.]+);').firstMatch(rule[2]!)?[1],
    };
    expect(shades, {
      'body': '0.7',
      '[data-theme="amber"] body': '0.7',
      '[data-theme="sky"] body': '0.7',
      '[data-theme="coral"] body': '0.7',
      '[data-theme="paper"] body': '0.1',
    });
    expect(defaultSiteThemeCss, isNot(contains('--shade')));
  });
}
