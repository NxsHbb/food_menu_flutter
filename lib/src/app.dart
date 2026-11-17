import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/capability/capability_probe.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/store/data/store_config_repository.dart';

/// Application root: theme and router only.
///
/// Everything stateful lives behind Riverpod providers, so this widget stays
/// free of setup logic and is cheap to pump in a test.
class FoodMenuApp extends ConsumerWidget {
  const FoodMenuApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    // The store's own colour, once `GET /app/config` has answered (task
    // 14.3). Null until then, and null for a store that set none, so the
    // theme starts on the app's red and moves only if the store has a
    // different one — never through a third colour on the way.
    final brand = ref.watch(storeBrandProvider);

    // Starts the capability probe with the first frame (task 14.7), so the
    // app knows which of the plugin's routes this store actually has before a
    // screen asks for one. Listened to rather than watched: nothing up here
    // changes with the answer, and the features that care watch
    // `capabilitiesProvider` for themselves.
    ref.listen(storeCapabilitiesProvider, (previous, next) {});

    return MaterialApp.router(
      title: 'Food Menu',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(brand: brand),
      darkTheme: AppTheme.dark(brand: brand),
      // Follows the device. The design covers light only, so the dark
      // palette is derived — see AppTokens.
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
