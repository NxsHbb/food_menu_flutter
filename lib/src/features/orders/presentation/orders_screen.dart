import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_tokens.dart';
import '../../auth/data/auth_controller.dart';
import '../../auth/presentation/login_screen.dart';
import '../data/order_history_controller.dart';
import '../domain/order_summary.dart';
import 'order_detail_screen.dart';
import 'widgets/order_row.dart';

/// The design's "My orders": two tabs over a paged list.
///
/// **Active and Past come from the server**, which decides what counts as
/// finished — a store can add statuses of its own and the app would have no
/// opinion about them. Each tab is its own query, so its count is the
/// server's and not something tallied from a page.
class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  static const routePath = '/orders';
  static const routeName = 'orders';

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final remaining =
        _scroll.position.maxScrollExtent - _scroll.position.pixels;
    if (remaining < 600) {
      ref.read(orderHistoryControllerProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final text = Theme.of(context).textTheme;
    final group = ref.watch(orderGroupProvider);
    final history = ref.watch(orderHistoryControllerProvider);
    final signedIn = ref.watch(isSignedInProvider);

    return Scaffold(
      backgroundColor: palette.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Container(
              color: palette.card,
              padding: const EdgeInsets.fromLTRB(
                AppTokens.space16,
                AppTokens.space12,
                AppTokens.space16,
                AppTokens.space14,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('My orders', style: text.headlineSmall),
                  if (signedIn) ...[
                    const SizedBox(height: AppTokens.space14),
                    _Tabs(
                      selected: group,
                      // Only the selected tab's count is known — the other tab
                      // has not been asked. The design shows a number on Active
                      // alone, which is the one that happens to be selected
                      // first, so this costs nothing and avoids a second
                      // request purely to label a tab.
                      activeCount: group == OrderGroup.active
                          ? history.value?.total
                          : null,
                      onSelected: (next) =>
                          ref.read(orderGroupProvider.notifier).show(next),
                    ),
                  ],
                ],
              ),
            ),
            if (!signedIn)
              Expanded(
                child: _SignedOut(
                  onSignIn: () => context.pushNamed(LoginScreen.routeName),
                ),
              )
            else
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => ref
                      .read(orderHistoryControllerProvider.notifier)
                      .reload(),
                  child: switch (history) {
                    AsyncLoading() => const Center(
                      child: CircularProgressIndicator(),
                    ),
                    AsyncError(:final error) => _OrdersError(error: error),
                    AsyncData(:final value) when value.isEmpty => _EmptyOrders(
                      group: group,
                    ),
                    AsyncData(:final value) => _OrderList(
                      state: value,
                      controller: _scroll,
                    ),
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Signed out, there is nothing to list and nothing a retry would fix.
///
/// The same invitation the wishlist gives, for the same reason: an order
/// history belongs to an account, and a 401 with a "Try again" would be both
/// alarming and useless.
class _SignedOut extends StatelessWidget {
  const _SignedOut({required this.onSignIn});

  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final text = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.space24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_outlined, size: 48, color: palette.muted),
            const SizedBox(height: AppTokens.space12),
            Text('Your orders', style: text.titleMedium),
            const SizedBox(height: AppTokens.space6),
            Text(
              'Sign in to follow an order and look back over what you have '
              'had before.',
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: palette.muted),
            ),
            const SizedBox(height: AppTokens.space20),
            SizedBox(
              height: AppTokens.buttonHeight,
              child: FilledButton(
                onPressed: onSignIn,
                child: const Text('Sign in'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({
    required this.selected,
    required this.activeCount,
    required this.onSelected,
  });

  final OrderGroup selected;
  final int? activeCount;
  final ValueChanged<OrderGroup> onSelected;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return Container(
      padding: const EdgeInsets.all(AppTokens.space4),
      decoration: BoxDecoration(
        color: palette.chip,
        borderRadius: BorderRadius.circular(AppTokens.radiusButton),
      ),
      child: Row(
        children: [
          Expanded(
            child: _Tab(
              label: activeCount == null ? 'Active' : 'Active ($activeCount)',
              selected: selected == OrderGroup.active,
              onTap: () => onSelected(OrderGroup.active),
            ),
          ),
          Expanded(
            child: _Tab(
              label: 'Past',
              selected: selected == OrderGroup.past,
              onTap: () => onSelected(OrderGroup.past),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return Material(
      color: selected ? palette.card : Colors.transparent,
      borderRadius: BorderRadius.circular(AppTokens.radiusControl),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTokens.radiusControl),
        child: SizedBox(
          height: 38,
          child: Center(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: selected ? palette.ink : palette.muted2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OrderList extends ConsumerWidget {
  const _OrderList({required this.state, required this.controller});

  final OrderHistoryState state;
  final ScrollController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.separated(
      controller: controller,
      // Always scrollable, so pull-to-refresh works on a list of one.
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppTokens.space16,
        AppTokens.space14,
        AppTokens.space16,
        AppTokens.space24,
      ),
      itemCount: state.orders.length + (state.hasMore ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: AppTokens.space12),
      itemBuilder: (context, index) {
        if (index >= state.orders.length) return const _LoadMoreFooter();

        final order = state.orders[index];

        return OrderRow(
          order: order,
          onTap: () => context.pushNamed(
            OrderDetailScreen.routeName,
            pathParameters: {'id': '${order.id}'},
          ),
        );
      },
    );
  }
}

/// Shown while another page loads, or offering a retry if one failed.
class _LoadMoreFooter extends ConsumerWidget {
  const _LoadMoreFooter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final error = ref.watch(orderHistoryLoadMoreErrorProvider);

    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppTokens.space12),
          child: TextButton(
            onPressed: () {
              ref.read(orderHistoryLoadMoreErrorProvider.notifier).clear();
              ref.read(orderHistoryControllerProvider.notifier).loadMore();
            },
            child: const Text('Try again'),
          ),
        ),
      );
    }

    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: AppTokens.space16),
        child: SizedBox.square(
          dimension: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

class _EmptyOrders extends StatelessWidget {
  const _EmptyOrders({required this.group});

  final OrderGroup group;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final text = Theme.of(context).textTheme;
    final active = group == OrderGroup.active;

    return ListView(
      // A ListView rather than a Center, so the empty state can still be
      // pulled down to refresh — an order may have arrived since.
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.space24,
        vertical: 60,
      ),
      children: [
        Icon(Icons.receipt_long_outlined, size: 44, color: palette.muted),
        const SizedBox(height: AppTokens.space12),
        Text(
          active ? 'No active orders' : 'No past orders',
          textAlign: TextAlign.center,
          style: text.titleMedium,
        ),
        const SizedBox(height: AppTokens.space6),
        Text(
          active
              ? 'Hungry? Your next favourite is a tap away.'
              : 'Orders you have finished will be kept here.',
          textAlign: TextAlign.center,
          style: text.bodySmall?.copyWith(color: palette.muted),
        ),
      ],
    );
  }
}

class _OrdersError extends ConsumerWidget {
  const _OrdersError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final text = Theme.of(context).textTheme;

    final message = error is ApiException
        ? (error as ApiException).message
        : 'Your orders could not be loaded.';

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.space24,
        vertical: 60,
      ),
      children: [
        Text(
          message,
          textAlign: TextAlign.center,
          style: text.bodyMedium?.copyWith(color: palette.muted2),
        ),
        const SizedBox(height: AppTokens.space12),
        Center(
          child: TextButton(
            onPressed: () =>
                ref.read(orderHistoryControllerProvider.notifier).reload(),
            child: const Text('Try again'),
          ),
        ),
      ],
    );
  }
}
