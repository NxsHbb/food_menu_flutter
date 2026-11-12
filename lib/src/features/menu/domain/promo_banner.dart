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
/// **Or from the plugin's own Special Menu** (task 9.5), which is the better
/// source and the one that wins when a store has configured it: it carries
/// chosen dishes, offer text and a schedule that expires itself, and each
/// banner gets a real tap target in [productId]. A WordPress post cannot —
/// `wp/v2/posts` exposes only registered meta, and registering a field needs
/// plugin code, which is the whole reason the Special Menu was the right
/// place to start.
class PromoBanner {
  const PromoBanner({
    required this.id,
    required this.title,
    required this.subtitle,
    this.imageUrl,
    this.badge,
    this.productId,
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

  /// Short label — the post's first tag, or the Special Menu's offer text.
  /// Often null.
  final String? badge;

  /// The dish this banner leads to, when it has one.
  ///
  /// Null for a banner built from a WordPress post, which has no way to name
  /// a dish. Those still open the full menu, which is the most a post can
  /// honestly promise.
  final int? productId;

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
