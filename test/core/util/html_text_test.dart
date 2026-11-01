import 'package:flutter_test/flutter_test.dart';
import 'package:food_menu/src/core/util/html_text.dart';

void main() {
  group('plainText', () {
    test('strips tags', () {
      expect(plainText('<p>Double espresso over ice.</p>'),
          'Double espresso over ice.');
    });

    test('decodes named entities', () {
      expect(plainText('Salt &amp; pepper'), 'Salt & pepper');
      expect(plainText('&quot;Chef&apos;s pick&quot;'), '"Chef\'s pick"');
    });

    test('decodes the numeric entities WordPress emits', () {
      // wp/v2 returns an ampersand as &#038;, not &amp;.
      expect(plainText('Extra cheese &#038; bacon'), 'Extra cheese & bacon');
      expect(plainText('Chef&#8217;s special'), 'Chef’s special');
    });

    test('collapses the whitespace tag stripping leaves behind', () {
      expect(plainText('<p>One</p>\n<p>Two</p>'), 'One Two');
    });

    test('is a no-op on plain text and empty input', () {
      expect(plainText('Grilled Salmon'), 'Grilled Salmon');
      expect(plainText(''), '');
    });

    test('leaves an unknown numeric entity alone rather than mangling it', () {
      expect(plainText('&#notanumber;'), '&#notanumber;');
    });
  });
}
