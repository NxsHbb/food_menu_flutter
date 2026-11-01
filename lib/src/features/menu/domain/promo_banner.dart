import '../../../core/util/html_text.dart';

/// A promotional banner for the landing screen.
///
/// Sourced from a WordPress post in a dedicated category, so the team edits
/// banners in WordPress with no custom fields and no plugin code:
///
/// - post **title** → [title]
/// - post **excerpt** → [subtitle]
/// - **featured image** → [imageUrl]
/// - first post **tag** → [badge], e.g. "New" or "Offer"
///
/// What a banner cannot yet carry is a tap target of its own. `wp/v2/posts`
/// only exposes registered meta, and registering a field needs plugin code,
/// so every banner currently opens the full menu. Adding a per-banner target
/// is a small follow-up: one `register_post_meta` call plus a field here.
class PromoBanner {
  const PromoBanner({
    required this.id,
    required this.title,
    required this.subtitle,
    this.imageUrl,
    this.badge,
  });

  /// Reads one `wp/v2/posts` entry fetched with
  /// `_embed=wp:featuredmedia,wp:term`.
  factory PromoBanner.fromJson(Map<String, dynamic> json) {
    final embedded = json['_embedded'];

    String? image;
    if (embedded is Map) {
      final media = embedded['wp:featuredmedia'];
      if (media is List && media.isNotEmpty && media.first is Map) {
        final first = (media.first as Map).cast<String, dynamic>();
        // Prefer a sized rendition; `full` can be a multi-megabyte upload.
        image = _bestSize(first) ?? first['source_url'] as String?;
      }
    }

    String? badge;
    if (embedded is Map) {
      final groups = embedded['wp:term'];
      if (groups is List) {
        for (final group in groups) {
          if (group is! List) continue;
          for (final term in group) {
            if (term is! Map) continue;
            if (term['taxonomy'] == 'post_tag') {
              final name = term['name'] as String?;
              if (name != null && name.isNotEmpty) {
                badge ??= plainText(name);
              }
            }
          }
        }
      }
    }

    return PromoBanner(
      id: (json['id'] as num?)?.toInt() ?? 0,
      // Both arrive as rendered, entity-escaped HTML.
      title: plainText(_rendered(json['title'])),
      subtitle: plainText(_rendered(json['excerpt'])),
      imageUrl: image,
      badge: badge,
    );
  }

  final int id;
  final String title;
  final String subtitle;
  final String? imageUrl;

  /// Short label, from the post's first tag. Often null.
  final String? badge;

  /// A banner with neither artwork nor a title has nothing to show.
  bool get isRenderable => title.isNotEmpty || imageUrl != null;

  static String _rendered(Object? field) {
    if (field is Map) return field['rendered'] as String? ?? '';
    if (field is String) return field;
    return '';
  }

  /// Picks a reasonably sized rendition, largest-first among the sensible
  /// ones, falling back to whatever exists.
  static String? _bestSize(Map<String, dynamic> media) {
    final sizes = media['media_details'];
    if (sizes is! Map) return null;
    final bySize = sizes['sizes'];
    if (bySize is! Map) return null;

    for (final name in const ['large', 'medium_large', 'medium', 'full']) {
      final entry = bySize[name];
      if (entry is Map && entry['source_url'] is String) {
        return entry['source_url'] as String;
      }
    }
    return null;
  }
}
