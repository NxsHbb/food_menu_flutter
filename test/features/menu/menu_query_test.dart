import 'package:flutter_test/flutter_test.dart';
import 'package:food_menu/src/features/menu/data/menu_list_controller.dart';
import 'package:food_menu/src/features/menu/data/menu_repository.dart';

void main() {
  group('the parameters a filtered list asks with (task 14.5)', () {
    test('an unfiltered list asks for nothing extra', () {
      // `storeOrder` is not a sort to send: an empty `orderby` is a 400 from
      // the Store API, and omitting it leaves the store's own arrangement.
      expect(tagAndSort(const {}, MenuSort.storeOrder), isEmpty);
    });

    test('tags go as a comma-separated list', () {
      expect(
        tagAndSort({22, 24}, MenuSort.storeOrder),
        {'tag': '22,24'},
      );
    });

    test('tag order never changes the url', () {
      // An unordered set must not produce two urls for one filter, or every
      // cache between here and the server is defeated by chance.
      expect(
        tagAndSort({24, 22}, MenuSort.storeOrder),
        tagAndSort({22, 24}, MenuSort.storeOrder),
      );
    });

    test('price carries a direction, popularity does not', () {
      expect(
        tagAndSort(const {}, MenuSort.priceLowHigh),
        {'orderby': 'price', 'order': 'asc'},
      );
      expect(
        tagAndSort(const {}, MenuSort.priceHighLow),
        {'orderby': 'price', 'order': 'desc'},
      );
      // WooCommerce defaults these to desc, which is what they should be.
      expect(tagAndSort(const {}, MenuSort.popularity), {'orderby': 'popularity'});
      expect(tagAndSort(const {}, MenuSort.newest), {'orderby': 'date'});
    });

    test('every sort the app offers names a real WooCommerce orderby', () {
      // The Store API answers 400 to an unknown `orderby`, so a typo here is
      // a screen that cannot load rather than a list in the wrong order.
      const accepted = {'price', 'popularity', 'date', 'rating', 'title'};

      for (final sort in MenuSort.values) {
        if (sort.orderby == null) continue;
        expect(accepted, contains(sort.orderby), reason: sort.name);
      }
    });

    test('every sort has a label a customer can read', () {
      for (final sort in MenuSort.values) {
        expect(sort.label, isNotEmpty, reason: sort.name);
      }
    });
  });

  group('the query itself', () {
    test('two equal filters compare equal, whatever order they were built in',
        () {
      // The controller refetches on every query change, so a set that does
      // not compare by value would refetch the same list on every tap.
      const a = MenuQuery(tagIds: {22, 24}, sort: MenuSort.priceLowHigh);
      const b = MenuQuery(tagIds: {24, 22}, sort: MenuSort.priceLowHigh);

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('knows when something is in force', () {
      expect(const MenuQuery().isFiltered, isFalse);
      // A search or a category has its own visible control, so neither counts
      // towards the filter button's dot.
      expect(const MenuQuery(search: 'pizza', categoryId: 3).isFiltered, isFalse);
      expect(const MenuQuery(tagIds: {22}).isFiltered, isTrue);
      expect(const MenuQuery(sort: MenuSort.newest).isFiltered, isTrue);
    });
  });
}
