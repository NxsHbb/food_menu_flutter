import '../../address/domain/saved_address.dart';
import '../../fulfilment/domain/order_types.dart';
import 'checkout_contact.dart';

/// Everything the order is made of, as one value.
///
/// Built from what the screen has resolved — the address, the contact, the
/// type and the slot — and turned into the Store API's body here rather than
/// in the repository, so the payload can be asserted on without a network
/// layer, and so task 6.5 can resubmit the identical order after a failure.
class OrderDraft {
  const OrderDraft({
    required this.address,
    required this.contact,
    required this.email,
    required this.note,
    required this.type,
    required this.dateValue,
    required this.timeValue,
    required this.paymentMethod,
  });

  /// The customer's address. **Required even for pickup**: WooCommerce
  /// validates a billing address on every order, and refuses one with no
  /// street or city whatever the order type. See `FINDINGS.md`.
  final SavedAddress address;

  final CheckoutContact contact;

  /// The account's email. WooCommerce puts the order confirmation here.
  final String email;

  final String note;

  final OrderTypeKind type;

  /// **The server's own strings**, taken from the slot list: `date_value` is
  /// the site's display format and `value` is the slot's. Neither is ever
  /// composed here — the plugin matches orders on them as text.
  final String dateValue;

  /// Empty for ASAP, which means submit no time at all.
  final String timeValue;

  /// A WooCommerce gateway id. Cash on delivery is v1's only one; task 6.3
  /// picks it from the gateways the store actually has enabled.
  final String paymentMethod;

  /// The checkout body.
  Map<String, dynamic> toJson() => {
        'billing_address': _address(withEmail: true),
        // Sent for pickup too. WooCommerce copies billing into shipping when
        // this is absent anyway, and for a delivery order this is the address
        // the driver is given.
        'shipping_address': _address(withEmail: false),
        'customer_note': note,
        'payment_method': paymentMethod,
        'extensions': {'food-menu-pro': _extension()},
      };

  /// The plugin's checkout extension.
  ///
  /// **Every registered key, every time.** The schema types them all as
  /// strings, and an omitted key arrives as null and is rejected with
  /// `rest_invalid_param` — so the dine-in fields this app never uses still
  /// have to be sent, empty. See `FINDINGS.md`.
  Map<String, dynamic> _extension() {
    final isPickup = type == OrderTypeKind.pickup;

    return {
      'fmp_order_time_type': type.name,
      'fmp_pickup_date': isPickup ? dateValue : '',
      'fmp_pickup_time': isPickup ? timeValue : '',
      'fmp_delivery_date': isPickup ? '' : dateValue,
      'fmp_delivery_time': isPickup ? '' : timeValue,
      'fmp_dinein_date': '',
      'fmp_dinein_time': '',
      'fmp_dinein_table': '',
      'fmp_custom_fields': <String, dynamic>{},
    };
  }

  /// The address, with the checkout's own name and phone over the top.
  ///
  /// The contact block is who the order is for, so it wins over whatever name
  /// the address was saved under — a gift sent to your own flat is the
  /// obvious case.
  Map<String, dynamic> _address({required bool withEmail}) {
    final (first, last) = splitName(contact.name);

    return {
      'first_name': first,
      'last_name': last,
      'company': address.company,
      'address_1': address.address1,
      'address_2': address.address2,
      'city': address.city,
      'state': address.state,
      'postcode': address.postcode,
      'country': address.country,
      'phone': contact.phone,
      if (withEmail) 'email': email,
    };
  }

  /// Splits the design's single "Full name" into WooCommerce's two.
  ///
  /// On the **first** space, so "Nurul Huda Chowdhury" keeps its surname
  /// whole, and a one-word name goes in `first_name` rather than being
  /// rejected for an empty one.
  static (String, String) splitName(String full) {
    final trimmed = full.trim();
    final space = trimmed.indexOf(' ');

    if (space < 0) return (trimmed, '');
    return (
      trimmed.substring(0, space),
      trimmed.substring(space + 1).trim(),
    );
  }
}
