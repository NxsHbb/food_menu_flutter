import '../../fulfilment/domain/order_types.dart';

/// Where this store can be ordered from — `GET fmp/v1/app/branches`.
///
/// **The list is never empty.** A store with no branches answers with a
/// single entry carrying `id: 0` and [isStore], built from WooCommerce's own
/// store address — and 0 is already what "store-wide" means to every other
/// route. So there is no empty case to handle, only [multiLocation] deciding
/// whether the customer gets a choice at all.
class BranchList {
  const BranchList({
    required this.multiLocation,
    required this.branches,
  });

  factory BranchList.fromJson(Map<String, dynamic> json) {
    final raw = json['branches'];

    return BranchList(
      multiLocation: json['multi_location'] == true,
      branches: raw is List
          ? raw
              .whereType<Map>()
              .map((e) => Branch.fromJson(e.cast<String, dynamic>()))
              .toList(growable: false)
          : const [],
    );
  }

  /// Whether the store runs branches. When false the one entry below is the
  /// shop itself, so show it rather than a picker.
  final bool multiLocation;

  final List<Branch> branches;

  bool get isEmpty => branches.isEmpty;

  Branch? byId(int id) {
    for (final branch in branches) {
      if (branch.id == id) return branch;
    }
    return null;
  }

  /// The branch to use, given what was chosen before.
  ///
  /// A remembered branch that no longer exists — deleted, or the store turned
  /// multi-location off — falls back to the first rather than leaving the app
  /// pointed at nothing. Resolved on every read for that reason.
  Branch? resolve(int? chosen) {
    if (branches.isEmpty) return null;
    if (chosen == null) return branches.first;

    return byId(chosen) ?? branches.first;
  }
}

/// One branch.
class Branch {
  const Branch({
    required this.id,
    required this.name,
    required this.parent,
    required this.description,
    required this.productCount,
    required this.address,
    required this.coordinates,
    required this.isStore,
    required this.types,
  });

  factory Branch.fromJson(Map<String, dynamic> json) {
    final types = json['types'];
    final coordinates = json['coordinates'];

    return Branch(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      parent: (json['parent'] as num?)?.toInt() ?? 0,
      description: json['description'] as String? ?? '',
      productCount: (json['product_count'] as num?)?.toInt() ?? 0,
      address: json['address'] as String? ?? '',
      coordinates: coordinates is Map
          ? Coordinates.tryParse(coordinates.cast<String, dynamic>())
          : null,
      isStore: json['is_store'] == true,
      types: types is List
          ? types
              .whereType<Map>()
              .map((e) => BranchType.tryParse(e.cast<String, dynamic>()))
              .nonNulls
              .toList(growable: false)
          : const [],
    );
  }

  final int id;
  final String name;

  /// The taxonomy is hierarchical, so a store can file branches under a city.
  /// 0 is top level. A flat list would show the city as if it were a branch.
  final int parent;

  final String description;
  final int productCount;

  /// One free-text field with its line breaks intact, as the admin typed it.
  final String address;

  /// **Null unless the branch really has them**, so a distance is omitted
  /// rather than computed against a point in the Atlantic.
  final Coordinates? coordinates;

  /// True for the stand-in entry built from the shop's own address, when the
  /// store runs no branches at all.
  final bool isStore;

  final List<BranchType> types;

  BranchType? type(OrderTypeKind kind) {
    for (final type in types) {
      if (type.kind == kind) return type;
    }
    return null;
  }

  /// Whether anything can be ordered from here right now. Used only to label
  /// the picker — the server decides what is actually orderable.
  bool get openNow =>
      types.any((type) => type.enabled && type.openNow);

  bool get openToday =>
      types.any((type) => type.enabled && type.openToday);
}

/// A branch's position, when it has one.
class Coordinates {
  const Coordinates({required this.latitude, required this.longitude});

  static Coordinates? tryParse(Map<String, dynamic> json) {
    final latitude = (json['latitude'] as num?)?.toDouble();
    final longitude = (json['longitude'] as num?)?.toDouble();

    if (latitude == null || longitude == null) return null;

    return Coordinates(latitude: latitude, longitude: longitude);
  }

  final double latitude;
  final double longitude;
}

/// What one order type looks like at one branch.
class BranchType {
  const BranchType({
    required this.kind,
    required this.label,
    required this.enabled,
    required this.hasCustomSchedule,
    required this.openToday,
    required this.openNow,
    required this.windows,
  });

  static BranchType? tryParse(Map<String, dynamic> json) {
    final kind = OrderTypeKind.tryParse(json['type'] as String?);
    if (kind == null) return null;

    final today = json['today'];
    final windows = today is Map ? today['windows'] : null;

    return BranchType(
      kind: kind,
      label: json['label'] as String? ?? '',
      enabled: json['enabled'] == true,
      hasCustomSchedule: json['has_custom_schedule'] == true,
      openToday: json['open_today'] == true,
      openNow: json['open_now'] == true,
      windows: windows is List
          ? windows
              .whereType<Map>()
              .map((e) => ScheduleWindow.fromJson(e.cast<String, dynamic>()))
              .toList(growable: false)
          : const [],
    );
  }

  final OrderTypeKind kind;
  final String label;
  final bool enabled;

  /// Whether this branch keeps its own hours for this type, rather than
  /// following the store's.
  final bool hasCustomSchedule;

  final bool openToday;
  final bool openNow;

  /// Today's opening windows, 24-hour.
  final List<ScheduleWindow> windows;
}
