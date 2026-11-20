import 'package:web/web.dart' as web;

typedef Rgb = ({int r, int g, int b});

Rgb themeColor(web.CSSStyleDeclaration style, String property) {
  final color = style.getPropertyValue(property).trim();
  final rgb = int.parse(color.substring(1), radix: 16);
  return (r: rgb >> 16, g: (rgb >> 8) & 0xFF, b: rgb & 0xFF);
}

String mixColors(Rgb from, Rgb to, double amount, double alpha) {
  int mix(int start, int end) => (start + (end - start) * amount).round();
  return 'rgba(${mix(from.r, to.r)},${mix(from.g, to.g)},${mix(from.b, to.b)},${alpha.toStringAsFixed(2)})';
}
