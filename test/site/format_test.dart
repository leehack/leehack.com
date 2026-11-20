import 'package:leehack_site/format.dart';
import 'package:test/test.dart';

void main() {
  test('groupedNumber inserts separators in thousands', () {
    expect(groupedNumber(0), '0');
    expect(groupedNumber(999), '999');
    expect(groupedNumber(1000), '1,000');
    expect(groupedNumber(1234567890), '1,234,567,890');
    expect(groupedNumber(-12345), '-12,345');
  });

  test('postDate uses the abbreviated month and unpadded day', () {
    expect(postDate(DateTime(2026, 1, 2)), 'Jan 2');
    expect(postDate(DateTime.utc(2026, 12, 31)), 'Dec 31');
  });
}
