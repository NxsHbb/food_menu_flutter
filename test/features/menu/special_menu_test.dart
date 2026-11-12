import 'package:flutter_test/flutter_test.dart';
import 'package:food_menu/src/features/menu/domain/special_menu.dart';

/// Task 9.5: the plugin's own promotion, drawn as the banner carousel the
/// design already has.
void main() {
  Map<String, dynamic> json({
    bool active = true,
    String title = 'Weekend Specials',
    String offer = '20% off',
    String duration = 'Friday to Sunday only',
    List<Map<String, dynamic>>? dishes,
  }) =>
      {
        'active': active,
        'title': title,
        'offer': offer,
        'duration': duration,
        'ends_on': '2027-06-30',
        'button': {'text': 'See the offer', 'link': 'https://example.test'},
        'dishes': dishes ??
            [
              {'id': 18, 'name': 'Double Smash', 'image': 'a.jpg'},
              {'id': 83, 'name': 'Tiramisu', 'image': 'b.jpg'},
            ],
      };

  test('one banner per dish, each with a dish to open', () {
    final banners = SpecialMenu.fromJson(json()).banners;

    expect(banners.length, 2);
    expect(banners.first.title, 'Double Smash');
    expect(banners.first.productId, 18);
    expect(banners.last.productId, 83);
  });

  test('the offer is the badge and the duration the line under it', () {
    final banner = SpecialMenu.fromJson(json()).banners.first;

    expect(banner.badge, '20% off');
    expect(banner.subtitle, 'Friday to Sunday only');
  });

  test('a promotion with no duration falls back to its own name', () {
    final banner = SpecialMenu.fromJson(json(duration: '')).banners.first;

    expect(banner.subtitle, 'Weekend Specials');
  });

  test('no offer text means no badge rather than an empty one', () {
    final banner = SpecialMenu.fromJson(json(offer: '')).banners.first;

    expect(banner.badge, isNull);
  });

  test('an expired promotion draws nothing, whatever dishes it names', () {
    // Three questions decide this — an end date, today, and whether anything
    // survived the branch filter — and the server answers all three. The app
    // asking again is how the two come to disagree.
    final menu = SpecialMenu.fromJson(json(active: false));

    expect(menu.dishes, hasLength(2));
    expect(menu.banners, isEmpty);
  });

  test('a dish that lost its id is dropped, not drawn blank', () {
    final menu = SpecialMenu.fromJson(
      json(dishes: [
        {'id': 0, 'name': 'Gone', 'image': null},
        {'id': 21, 'name': 'Lamb Biryani', 'image': 'c.jpg'},
      ]),
    );

    expect(menu.banners.single.productId, 21);
  });

  test('an older plugin answers nothing useful and costs nothing', () {
    expect(SpecialMenu.none.active, isFalse);
    expect(SpecialMenu.none.banners, isEmpty);
  });
}
