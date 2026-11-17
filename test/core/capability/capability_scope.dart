/// The three stores a widget test wants to put in front of the app (task
/// 14.7), for `capabilitiesProvider.overrideWithValue(...)`.
///
/// **Override that provider, not the notifier behind it**, and the probe is
/// never made: a test that pumps a dish card would otherwise reach for the
/// store's REST index and leave a pending timer, which is how these came to
/// exist. (`Override` itself cannot be named here — flutter_riverpod 3.5 does
/// not export the type — so each test spells the override out.)
library;

import 'package:food_menu/src/core/capability/store_capabilities.dart';

import 'plugin_index_fixtures.dart';

/// A store the app could not ask, which assumes every feature is present.
/// The right choice for a test about something else.
const anyStore = StoreCapabilities.unknown;

/// The dev store: the newest Pro, with every route registered.
final newProStore = StoreCapabilities.fromIndex(indexPayload(newPro));

/// The released Pro — auth and the profile, and nothing the app has added
/// since. The store task 14.7 exists for.
final releasedProStore = StoreCapabilities.fromIndex(indexPayload(releasedPro));
