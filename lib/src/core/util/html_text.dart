/// Turns the HTML that WordPress returns into plain text.
///
/// Every text field from both APIs arrives as rendered HTML: Store API
/// descriptions come wrapped in `<p>`, and `wp/v2` titles and excerpts are
/// also entity-escaped, so an ampersand reaches us as `&#038;`. Rendering
/// those raw puts tags and entity codes on screen.
///
/// This replaces the few constructs WordPress actually emits rather than
/// pulling in an HTML parser for one line of label text. It is not a general
/// sanitiser and must not be used on untrusted markup where correctness
/// matters.
String plainText(String html) {
  if (html.isEmpty) return '';

  var text = html.replaceAll(RegExp(r'<[^>]*>'), ' ');

  for (final entry in _entities.entries) {
    text = text.replaceAll(entry.key, entry.value);
  }

  // Numeric entities WordPress emits for anything outside the named set.
  text = text.replaceAllMapped(
    RegExp(r'&#(\d+);'),
    (match) {
      final code = int.tryParse(match[1]!);
      return code == null ? match[0]! : String.fromCharCode(code);
    },
  );

  // Collapse the whitespace that stripping tags leaves behind.
  return text.replaceAll(RegExp(r'\s+'), ' ').trim();
}

const _entities = <String, String>{
  '&nbsp;': ' ',
  '&amp;': '&',
  '&lt;': '<',
  '&gt;': '>',
  '&quot;': '"',
  '&apos;': "'",
  '&hellip;': '…',
  '&ndash;': '–',
  '&mdash;': '—',
  '&lsquo;': '‘',
  '&rsquo;': '’',
  '&ldquo;': '“',
  '&rdquo;': '”',
};
