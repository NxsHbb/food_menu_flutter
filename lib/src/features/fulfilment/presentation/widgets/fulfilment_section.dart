import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../data/fulfilment_controller.dart';
import '../../domain/order_types.dart';
import '../../domain/slots.dart';
import 'date_strip.dart';
import 'order_type_toggle.dart';
import 'slot_picker.dart';

/// How and when the order arrives: the type switch and the time list.
///
/// A section rather than a screen so the checkout owns the page while this
/// owns the decision. Every branch of it is driven by the server — which
/// types exist, which times are open, and what to say when there are none.
class FulfilmentSection extends ConsumerWidget {
  const FulfilmentSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final types = ref.watch(orderTypesProvider);

    return switch (types) {
      AsyncLoading() => const _Loading(),
      AsyncError(:final error) => _Error(
        error: error,
        onRetry: () => ref.invalidate(orderTypesProvider),
      ),
      AsyncData(:final value) => _Offered(types: value),
    };
  }
}

class _Offered extends ConsumerWidget {
  const _Offered({required this.types});

  final OrderTypes types;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offered = types.offered;

    // A store with neither type switched on takes no orders at all. Saying so
    // beats an empty switch above an empty time list.
    if (offered.isEmpty) return const _NotOrderable();

    final selected = ref.watch(resolvedOrderTypeProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OrderTypeToggle(
          options: offered,
          selected: selected,
          onSelected:
              ref.read(fulfilmentControllerProvider.notifier).chooseKind,
        ),
        const SizedBox(height: AppTokens.space20),
        const _Slots(),
      ],
    );
  }
}

class _Slots extends ConsumerWidget {
  const _Slots();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final palette = AppPalette.of(context);
    final async = ref.watch(slotsProvider);
    final slots = async.value;
    // The **store's** today, not the device's: the two disagree whenever the
    // phone is in another timezone, and the store's is the one the kitchen
    // works to.
    final today = ref.watch(orderTypesProvider).value?.today;

    // The title is the store's own word for the type — "Pickup time" is not
    // ours to compose once the label is translated.
    final title = slots == null ? 'Time' : '${slots.label} time';

    // Which dates the store takes orders for. One is the common case and
    // draws no strip at all.
    final dates = slots?.choosableDates ?? const <String>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            // Only while refreshing over a list already on screen: a full
            // spinner here would make every cart change blank the row.
            if (async.isLoading && slots != null)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        // **Only when there is nothing to pick.** A store that takes orders
        // for one date still has to say which, because a kitchen's lead time
        // can push the earliest slot to another day and "3:00 am" then looks
        // like tonight. `dateValue` is the store's own rendering, which saves
        // inventing a date format the site does not use. With a strip above,
        // the chosen chip says it already.
        if (slots != null &&
            today != null &&
            slots.date != today &&
            dates.length < 2)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              slots.dateValue,
              style: text.bodySmall?.copyWith(color: palette.muted),
            ),
          ),
        if (slots != null && dates.length > 1) ...[
          const SizedBox(height: AppTokens.space12),
          DateStrip(
            dates: dates,
            selected: slots.date,
            storeToday: today,
            onSelected: ref
                .read(fulfilmentControllerProvider.notifier)
                .chooseDate,
          ),
        ],
        const SizedBox(height: AppTokens.space12),
        switch (async) {
          AsyncError(:final error) => _Error(
            error: error,
            onRetry: () => ref.invalidate(slotsProvider),
          ),
          _ when slots == null => const _Loading(),
          _ => SlotPicker(
            slots: slots,
            selected: ref.watch(selectedSlotProvider),
            onSelected: (slot) => ref
                .read(fulfilmentControllerProvider.notifier)
                .chooseSlot(slot.startMinutes),
            onUnavailable: (slot) => _explain(context, slot),
          ),
        },
      ],
    );
  }

  /// Says why a chip cannot be picked, in the store's words.
  void _explain(BuildContext context, Slot slot) {
    final message = slot.message;
    if (message == null || message.isEmpty) return;

    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: AppTokens.space24),
      child: Center(child: CircularProgressIndicator()),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          api?.message ?? 'Could not load the available times.',
          style: text.bodyMedium?.copyWith(color: palette.muted),
        ),
        const SizedBox(height: AppTokens.space10),
        OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
      ],
    );
  }
}

class _NotOrderable extends StatelessWidget {
  const _NotOrderable();

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final text = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTokens.space14),
      decoration: BoxDecoration(
        color: palette.warnBackground,
        borderRadius: BorderRadius.circular(AppTokens.radiusCard),
      ),
      child: Text(
        'This store is not taking pickup or delivery orders right now.',
        style: text.bodySmall?.copyWith(color: palette.warnForeground),
      ),
    );
  }
}
