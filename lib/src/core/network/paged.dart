/// One page of a list endpoint, with the totals WordPress sends as headers.
///
/// The Store API reports `X-WP-Total` and `X-WP-TotalPages` rather than
/// wrapping the list in an envelope, so the body alone cannot tell a caller
/// whether more pages exist.
class Paged<T> {
  const Paged({
    required this.items,
    required this.total,
    required this.totalPages,
    required this.page,
  });

  final List<T> items;

  /// Total matching records across all pages, from `X-WP-Total`.
  final int total;

  /// From `X-WP-TotalPages`.
  final int totalPages;

  /// The page this response represents, 1-based.
  final int page;

  bool get hasMore => page < totalPages;

  @override
  String toString() =>
      'Paged(page $page/$totalPages, ${items.length} of $total)';
}
