/// Who the order is for, and how the kitchen reaches them.
///
/// A value object with an `==` so a provider that resolves it does not
/// re-notify on every cart emission.
class CheckoutContact {
  const CheckoutContact({required this.name, required this.phone});

  static const empty = CheckoutContact(name: '', phone: '');

  /// One field, not two, because that is what the design's checkout asks for
  /// and what WooCommerce is given back split on the first space at order
  /// time.
  final String name;

  final String phone;

  /// Whether this is enough to submit. The server has the last word; this is
  /// only what stops the screen from offering a button that cannot work.
  bool get isComplete => name.trim().isNotEmpty && phone.trim().isNotEmpty;

  @override
  bool operator ==(Object other) =>
      other is CheckoutContact && other.name == name && other.phone == phone;

  @override
  int get hashCode => Object.hash(name, phone);
}
