import 'promo_banner.dart';

/// The store's own scheduled promotion (task 9.5).
///
/// The plugin has had this all along: chosen dishes, offer text, a duration
/// and an end date that expires itself. The website draws it as a popup. The
/// app draws it as the banner carousel the design already has — a promotion
/// that reaches the customer without blocking them.
class SpecialMenu {
  const SpecialMenu({
    required this.active,
    required this.title,
    required this.offer,
    required this.duration,
    required this.dishes,
  });

  static const none = SpecialMenu(
    active: false,
    title: '',
    offer: '',
    duration: '',
    dishes: [],
  );

  factory SpecialMenu.fromJson(Map<String, dynamic> json) {
    final dishes = json['dishes'];

    return SpecialMenu(
      // **The server decides.** Whether a promotion is running is three
      // questions — an end date, today's date, and whether anything survived
      // the branch filter — and the app asking them again is how the two
      // come to disagree.
      active: json['active'] == true,
      title: json['title'] as String? ?? '',
      offer: json['offer'] as String? ?? '',
      duration: json['duration'] as String? ?? '',
      dishes: dishes is List
          ? dishes
              .whereType<Map>()
              .map((e) => SpecialMenuDish.fromJson(e.cast<String, dynamic>()))
              .where((d) => d.id > 0)
              .toList(growable: false)
          : const [],
    );
  }

  final bool active;

  /// The promotion's own name, e.g. "Weekend Specials".
  final String title;

  /// The offer, e.g. "20% off". Short enough for a badge.
  final String offer;

  /// When it applies, in the store's words, e.g. "Friday to Sunday only".
  final String duration;

  final List<SpecialMenuDish> dishes;

  /// One banner per dish, which is what makes a tap target possible.
  ///
  /// The design's banner is a badge, a dish and a line about it, and the
  /// promotion maps onto it exactly: the **offer** is the badge, the **dish**
  /// is the title, and the store's own words about when it runs are the line
  /// underneath — falling back to the promotion's name when it set none.
  List<PromoBanner> get banners => [
        if (active)
          for (final dish in dishes)
            PromoBanner(
              id: dish.id,
              title: dish.name,
              subtitle: duration.isNotEmpty ? duration : title,
              imageUrl: dish.image,
              badge: offer.isNotEmpty ? offer : null,
              productId: dish.id,
            ),
      ];
}

/// One dish on the promotion.
class SpecialMenuDish {
  const SpecialMenuDish({
    required this.id,
    required this.name,
    this.image,
  });

  factory SpecialMenuDish.fromJson(Map<String, dynamic> json) {
    return SpecialMenuDish(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      image: json['image'] as String?,
    );
  }

  final int id;
  final String name;
  final String? image;
}
