import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../branch/data/branch_controller.dart';
import '../../cart/data/cart_controller.dart';
import '../domain/order_types.dart';
import '../domain/slots.dart';
import 'fulfilment_repository.dart';

/// What the customer has chosen about fulfilment.
///
/// Deliberately small, and deliberately **not** the server's answer: this
/// holds only the three things a tap can change. Everything else — which
/// types exist, which slots are open, what to submit — is read back from the
/// server, so a choice can never contradict what the store will accept.
class FulfilmentChoice {
  const FulfilmentChoice({this.kind, this.date, this.slotMinutes});

  /// Null until the customer picks, so [resolvedKind] can follow the store's
  /// own default instead of this guessing one before the store has answered.
  final OrderTypeKind? kind;

  /// `Y-m-d`, or null for the earliest date the type can be fulfilled on.
  /// The design has no date picker, so this stays null for now; `/app/slots`
  /// takes a date for when one is designed.
  final String? date;

  /// The chosen slot's minutes-since-midnight, -1 being ASAP. Null means
  /// "whatever is earliest and open", which is also what it falls back to
  /// when the chosen slot stops being offered.
  final int? slotMinutes;

  FulfilmentChoice copyWith({
    OrderTypeKind? kind,
    String? date,
    int? slotMinutes,
    bool clearSlot = false,
    bool clearDate = false,
  }) {
    return FulfilmentChoice(
      kind: kind ?? this.kind,
      date: clearDate ? null : (date ?? this.date),
      slotMinutes: clearSlot ? null : (slotMinutes ?? this.slotMinutes),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is FulfilmentChoice &&
      other.kind == kind &&
      other.date == date &&
      other.slotMinutes == slotMinutes;

  @override
  int get hashCode => Object.hash(kind, date, slotMinutes);
}

class FulfilmentController extends Notifier<FulfilmentChoice> {
  @override
  FulfilmentChoice build() => const FulfilmentChoice();

  /// Switches type and **drops the chosen slot**, because the two lists are
  /// not comparable: pickup offers point times and delivery offers windows,
  /// an hour apart on a different interval, and the store can keep different
  /// hours for each. The design clears it on the same tap.
  void chooseKind(OrderTypeKind kind) {
    if (state.kind == kind) return;
    state = state.copyWith(kind: kind, clearSlot: true, clearDate: true);
  }

  /// Picks a slot by its identity within the day. -1 is ASAP.
  void chooseSlot(int startMinutes) {
    state = state.copyWith(slotMinutes: startMinutes);
  }

  /// Moves to another date, for when a date picker is designed.
  void chooseDate(String? date) {
    state = state.copyWith(date: date, clearDate: date == null, clearSlot: true);
  }
}

final fulfilmentControllerProvider =
    NotifierProvider<FulfilmentController, FulfilmentChoice>(
  FulfilmentController.new,
);

/// Which types the store offers, and its hours, for the chosen branch.
///
/// The answer's own `branch` says whether the one asked for was honoured — a
/// store not running branches answers store-wide with 0.
final orderTypesProvider = FutureProvider<OrderTypes>(
  (ref) => ref.watch(fulfilmentRepositoryProvider).orderTypes(
        branch: ref.watch(activeBranchIdProvider) ?? 0,
      ),
  // No background retry. The section offers "Try again", and a retry loop
  // would keep firing while the customer reads the error — and would stop
  // `.future` ever completing, hiding the failure from anything awaiting it.
  retry: (retryCount, error) => null,
);

/// The type actually in force: the customer's choice if the store still
/// offers it, otherwise the store's default.
///
/// Resolved rather than stored. A store can switch a type off between the
/// choice and the order, and a screen must not go on showing a type the
/// server has stopped accepting.
final resolvedOrderTypeProvider = Provider<OrderTypeKind?>((ref) {
  final types = ref.watch(orderTypesProvider).value;
  if (types == null) return null;

  return types.resolve(ref.watch(fulfilmentControllerProvider).kind);
});

/// The cart, encoded for the slot request.
///
/// A **String** rather than a map, so that an unchanged cart is recognised as
/// unchanged: the cart controller re-emits on every mutation, and two equal
/// maps are never `==`, so a map here made [slotsProvider] re-ask the server
/// twice for one cart.
///
/// A line's `id` is the **variation** id for a variable dish and the Store
/// API carries no parent anywhere, so these are sent as they are and the
/// server resolves each one to the dish its limits are set on.
final cartItemsProvider = Provider<String>((ref) {
  final cart = ref.watch(cartControllerProvider).value;
  if (cart == null) return '';

  final items = <int, int>{};
  for (final item in cart.items) {
    items[item.id] = (items[item.id] ?? 0) + item.quantity;
  }
  return FulfilmentRepository.encodeItems(items);
});

/// Everything a slot request is made of, as one comparable value.
///
/// Exists so the request has **exactly one dependency, and one that compares
/// by value**. Watching the type, the date and the cart separately inside the
/// future meant the server was asked twice for the same slots: the body
/// resumed after its await, and the dependency that settled in the meantime
/// rebuilt it. A key like this can only change when the answer would.
class SlotRequest {
  const SlotRequest({
    required this.type,
    this.date,
    this.items = '',
    this.branch = 0,
  });

  final OrderTypeKind type;

  /// `Y-m-d`, or null for the earliest date the type can be fulfilled on.
  final String? date;

  /// The cart, already encoded — see [cartItemsProvider].
  final String items;

  /// Which branch the slots are for. 0 is store-wide.
  final int branch;

  @override
  bool operator ==(Object other) =>
      other is SlotRequest &&
      other.type == type &&
      other.date == date &&
      other.items == items &&
      other.branch == branch;

  @override
  int get hashCode => Object.hash(type, date, items, branch);
}

/// What to ask for, or null when there is nothing to ask about yet — the
/// store has not answered, or it offers no type at all.
final slotRequestProvider = Provider<SlotRequest?>((ref) {
  final type = ref.watch(resolvedOrderTypeProvider);
  if (type == null) return null;

  return SlotRequest(
    type: type,
    date: ref.watch(fulfilmentControllerProvider).date,
    items: ref.watch(cartItemsProvider),
    branch: ref.watch(activeBranchIdProvider) ?? 0,
  );
});

/// The slots for the type, date and cart currently in force.
///
/// **Depends on the cart on purpose.** Availability is a function of what is
/// being ordered: adding a breakfast dish can take the afternoon away, and
/// raising a quantity can exhaust a dish's per-slot limit. A list fetched
/// before the cart changed would offer a slot the checkout then refuses.
///
/// Null while the order types are still loading, and when the store offers
/// neither type. A screen tells those apart from [orderTypesProvider], which
/// it is already watching for the toggle.
final slotsProvider = FutureProvider<SlotList?>(
  (ref) async {
    final request = ref.watch(slotRequestProvider);
    if (request == null) return null;

    return ref.watch(fulfilmentRepositoryProvider).slots(
      type: request.type,
      date: request.date,
      items: request.items,
      branch: request.branch,
    );
  },
  // No background retry, for the same reason as the order types above.
  retry: (retryCount, error) => null,
);

/// The slot a screen should treat as chosen, after the server's own list has
/// had its say. Null when there is nothing to choose.
final selectedSlotProvider = Provider<Slot?>((ref) {
  final slots = ref.watch(slotsProvider).value;
  if (slots == null) return null;

  return slots.resolve(ref.watch(fulfilmentControllerProvider).slotMinutes);
});
