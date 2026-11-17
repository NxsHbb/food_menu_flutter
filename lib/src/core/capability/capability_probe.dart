import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart';
import '../network/api_exception.dart';
import 'plugin_route.dart';
import 'store_capabilities.dart';

/// Asks the store which plugin routes it has (task 14.7).
///
/// One request, to the plugin's own REST namespace index — `GET
/// /wp-json/fmp/v1`, which WordPress registers for every namespace and which
/// lists every route in it. 19 KB on the dev store, once per launch.
///
/// **Why a probe at all.** The app is built against the newest Pro, and a
/// store runs whatever it has installed: before this, every route newer than
/// the store's build answered 404 and the app showed an error for a feature
/// that store never had. Asking up front is the difference between hiding the
/// wishlist and failing on it.
class CapabilityProbe {
  const CapabilityProbe(this._client);

  final ApiClient _client;

  /// What this store can do.
  ///
  /// **Never throws.** Every failure has an answer that leaves the app usable:
  /// a 404 on the index means WordPress has no `fmp/v1` namespace, so the
  /// plugin is not there and nothing built on it is either; anything else
  /// means the app could not ask, and an app that cannot ask assumes the store
  /// has everything rather than hiding features over a flaky connection.
  Future<StoreCapabilities> probe() async {
    try {
      final raw = await _client.get<Map<String, dynamic>>(
        _client.foodMenuIndex,
      );

      return StoreCapabilities.fromIndex(raw);
    } on ApiException catch (error) {
      // WordPress answered, and has no such namespace: `rest_no_route`. The
      // plugin is inactive or absent, and this is the one case where hiding
      // everything is the honest answer.
      if (error.statusCode == 404) return StoreCapabilities.absent;

      return StoreCapabilities.unknown;
    } on Object {
      // A body that would not parse. Treated as "could not ask" rather than
      // as an empty store, for the same reason.
      return StoreCapabilities.unknown;
    }
  }
}

final capabilityProbeProvider = Provider<CapabilityProbe>((ref) {
  return CapabilityProbe(ref.watch(apiClientProvider));
});

/// The store's capabilities, probed once at launch.
///
/// Also the sink for what the app learns the hard way: a route that answers
/// `rest_no_route` mid-session is recorded here by `CapabilityInterceptor`,
/// which is what covers a store whose probe never landed.
class StoreCapabilitiesController extends AsyncNotifier<StoreCapabilities> {
  /// Routes this store has refused. Kept on the controller rather than only
  /// in the state so that a re-probe cannot un-learn them — the index is
  /// authoritative about what exists, but a refusal is a fact.
  final _refused = <PluginRoute>{};

  @override
  Future<StoreCapabilities> build() async {
    final probed = await ref.read(capabilityProbeProvider).probe();

    return probed.ruleOutAll(_refused);
  }

  /// Records a route the store does not have.
  ///
  /// Idempotent, and deliberately **not** a reload: one refusal is not a
  /// reason to re-ask the whole index, and the answer for that route is
  /// already known.
  void ruleOut(PluginRoute route) {
    if (!_refused.add(route)) return;

    final current = state.value;
    if (current == null) return;

    state = AsyncData(current.ruleOut(route));
  }
}

final storeCapabilitiesProvider =
    AsyncNotifierProvider<StoreCapabilitiesController, StoreCapabilities>(
  StoreCapabilitiesController.new,
  // No retry. The probe never throws — a failure resolves to
  // `StoreCapabilities.unknown`, which is a usable answer — so there is
  // nothing for a retry to improve.
  retry: (retryCount, error) => null,
);

/// What the store can do, as a plain value every widget can read.
///
/// **[StoreCapabilities.unknown] while the probe is in flight**, which assumes
/// every feature is present. The alternative — assume absent until the probe
/// lands — would make the wishlist heart, the branch picker and the account
/// rows pop into existence on every launch of every store, to spare an older
/// store a flicker. Hiding late is rarer and cheaper than appearing late.
final capabilitiesProvider = Provider<StoreCapabilities>((ref) {
  return ref.watch(storeCapabilitiesProvider).value ?? StoreCapabilities.unknown;
});
