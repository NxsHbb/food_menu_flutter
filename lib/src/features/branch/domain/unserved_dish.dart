/// A dish in the cart that a branch does not serve.
///
/// [id] is echoed back exactly as the app sent it, variation ids included, so
/// it matches the `id` on the cart lines it came from — and a product can own
/// more than one line when the same dish was added with different add-ons.
class UnservedDish {
  const UnservedDish({required this.id, required this.name});

  factory UnservedDish.fromJson(Map<String, dynamic> json) {
    return UnservedDish(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
    );
  }

  final int id;
  final String name;

  @override
  String toString() => 'UnservedDish($id, $name)';
}
