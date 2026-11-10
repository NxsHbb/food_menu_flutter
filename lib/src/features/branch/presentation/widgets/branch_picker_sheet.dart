import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../data/branch_controller.dart';
import '../../data/branch_switch.dart';
import '../../domain/branch.dart';
import '../../domain/unserved_dish.dart';

/// The sheet behind the header's "Deliver to" line.
///
/// A sheet rather than a screen: choosing a branch is a detour from the menu,
/// and the customer should land back on the dishes rather than navigate.
class BranchPickerSheet extends ConsumerWidget {
  const BranchPickerSheet({super.key});

  /// Opens it, and returns once the customer has chosen or dismissed.
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      // **The root navigator, not the tab's.** The shell paints the floating
      // cart bar in a Stack above its own navigator, so a sheet shown by the
      // inner one comes up *underneath* the bar — which covers the second
      // branch in the list.
      useRootNavigator: true,
      builder: (_) => const BranchPickerSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final text = Theme.of(context).textTheme;
    final branches = ref.watch(branchesProvider);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.8,
      ),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppTokens.radiusCardLarge),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTokens.space16,
                AppTokens.space12,
                AppTokens.space16,
                AppTokens.space8,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Choose a branch',
                      style: text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Flexible(
              child: switch (branches) {
                AsyncLoading() => const Padding(
                  padding: EdgeInsets.all(AppTokens.space24),
                  child: Center(child: CircularProgressIndicator()),
                ),
                AsyncError(:final error) => _Error(
                  error: error,
                  onRetry: () => ref.invalidate(branchesProvider),
                ),
                AsyncData(:final value) => _List(list: value),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _List extends ConsumerWidget {
  const _List({required this.list});

  final BranchList list;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final text = Theme.of(context).textTheme;
    final active = ref.watch(activeBranchProvider);

    // A store that runs no branches still has one entry — itself — and
    // offering it as a "choice" would be a list of one with nothing to pick.
    if (!list.multiLocation) {
      final only = list.branches.firstOrNull;

      return Padding(
        padding: const EdgeInsets.fromLTRB(
          AppTokens.space16,
          0,
          AppTokens.space16,
          AppTokens.space24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              only?.name ?? '',
              style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            if (only != null && only.address.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                only.address,
                style: text.bodySmall?.copyWith(color: palette.muted),
              ),
            ],
            const SizedBox(height: AppTokens.space10),
            Text(
              'This store has one location.',
              style: text.bodySmall?.copyWith(color: palette.muted),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(
        AppTokens.space16,
        0,
        AppTokens.space16,
        AppTokens.space16,
      ),
      itemCount: list.branches.length,
      separatorBuilder: (_, _) => Divider(color: palette.line, height: 1),
      itemBuilder: (context, index) {
        final branch = list.branches[index];

        return _Row(
          branch: branch,
          selected: branch.id == active?.id,
          onTap: () => _switchTo(context, ref, branch),
        );
      },
    );
  }
}

/// Moves to [branch], asking first if the cart would lose anything.
///
/// Cancelling leaves the sheet open on the branch they are still on, rather
/// than closing it — they came here to change branch and may want a different
/// one.
Future<void> _switchTo(
  BuildContext context,
  WidgetRef ref,
  Branch branch,
) async {
  final switcher = ref.read(branchSwitcherProvider);
  final unserved = await switcher.check(branch.id);

  if (!context.mounted) return;

  if (unserved.isNotEmpty) {
    final confirmed = await _confirmDropping(context, branch, unserved);
    if (confirmed != true || !context.mounted) return;
  }

  await switcher.commit(branchId: branch.id, dropping: unserved);

  if (context.mounted) Navigator.of(context).pop();
}

/// Names what the switch would remove, rather than counting it.
///
/// "2 dishes" is not enough to decide with: whether to go ahead depends
/// entirely on *which* dish, and the customer should not have to back out and
/// open the cart to find out.
Future<bool?> _confirmDropping(
  BuildContext context,
  Branch branch,
  List<UnservedDish> unserved,
) {
  final one = unserved.length == 1;

  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Switch to ${branch.name}?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            one
                ? "${branch.name} does not serve this, so it will leave your cart:"
                : '${branch.name} does not serve these, so they will leave your cart:',
          ),
          const SizedBox(height: AppTokens.space12),
          for (final dish in unserved)
            Padding(
              padding: const EdgeInsets.only(bottom: AppTokens.space4),
              child: Text(
                '\u2022  ${dish.name}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(one ? 'Switch and remove' : 'Switch and remove them'),
        ),
      ],
    ),
  );
}

class _Row extends StatelessWidget {
  const _Row({
    required this.branch,
    required this.selected,
    required this.onTap,
  });

  final Branch branch;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final text = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppTokens.space12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Nested branches are indented rather than flattened: the
            // taxonomy is hierarchical, so a store can file its branches
            // under a city, and a flat list shows the city as if it were one.
            SizedBox(width: branch.parent > 0 ? AppTokens.space16 : 0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    branch.name,
                    style: text.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: selected ? palette.brand : palette.ink,
                    ),
                  ),
                  if (branch.address.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      // The address arrives with its line breaks; on one line
                      // here, in full on the checkout.
                      branch.address.replaceAll(RegExp(r'\s*\n\s*'), ', '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall?.copyWith(color: palette.muted),
                    ),
                  ],
                  const SizedBox(height: AppTokens.space8),
                  _OpenNow(branch: branch),
                ],
              ),
            ),
            if (selected)
              Padding(
                padding: const EdgeInsets.only(left: AppTokens.space8),
                child: Icon(Icons.check_circle, color: palette.brand, size: 20),
              ),
          ],
        ),
      ),
    );
  }
}

/// Whether this branch is taking orders, in the store's own terms.
class _OpenNow extends StatelessWidget {
  const _OpenNow({required this.branch});

  final Branch branch;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final text = Theme.of(context).textTheme;
    final open = branch.openNow;

    // Closed is **not** a reason to stop someone choosing: the design lets a
    // customer browse a branch's menu and order for later, and the slot list
    // is what refuses a time the kitchen cannot make.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppTokens.space8, vertical: 3),
      decoration: BoxDecoration(
        color: open ? palette.okBackground : palette.chip,
        borderRadius: BorderRadius.circular(AppTokens.radiusChip),
      ),
      child: Text(
        open ? 'Open now' : (branch.openToday ? 'Closed now' : 'Closed today'),
        style: text.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: open ? palette.okForeground : palette.muted,
        ),
      ),
    );
  }
}

class _Error extends StatelessWidget {
  const _Error({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final text = Theme.of(context).textTheme;
    final api = error is ApiException ? error as ApiException : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTokens.space16,
        0,
        AppTokens.space16,
        AppTokens.space24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            api?.message ?? 'Could not load the branches.',
            style: text.bodyMedium?.copyWith(color: palette.muted),
          ),
          const SizedBox(height: AppTokens.space10),
          OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}
