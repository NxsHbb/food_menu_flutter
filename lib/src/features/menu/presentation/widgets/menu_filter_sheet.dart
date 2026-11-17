import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../data/menu_list_controller.dart';
import '../../data/menu_repository.dart';

/// Sort and food-tag filters for the menu list (task 14.5).
///
/// **Held locally until Apply.** Every tap could drive the list straight away,
/// and on a slow connection that is four refetches on the way to one filter.
/// The sheet keeps a draft and commits it once, which is also what makes
/// Cancel mean something.
///
/// The tag section is absent on a store with no tags, rather than an empty
/// heading: most stores have none, and a heading over nothing is the kind of
/// gap that reads as a loading bug.
class MenuFilterSheet extends ConsumerStatefulWidget {
  const MenuFilterSheet({required this.query, super.key});

  final MenuQuery query;

  /// Opens the sheet and applies whatever comes back.
  static Future<void> show(BuildContext context, WidgetRef ref) async {
    final result = await showModalBottomSheet<({Set<int> tags, MenuSort sort})>(
      context: context,
      isScrollControlled: true,
      // **The root navigator, as `BranchPickerSheet` learned to.** The shell
      // paints the floating cart bar in a Stack above its own navigator, so a
      // sheet shown by the inner one comes up *underneath* it — and here that
      // covered the Show dishes button outright, on any device with something
      // in the cart. Caught on the phone; a widget test pumps this screen
      // without the shell, so the bar is not there to collide with.
      useRootNavigator: true,
      builder: (context) =>
          MenuFilterSheet(query: ref.read(menuQueryProvider)),
    );

    if (result == null) return;

    ref
        .read(menuQueryProvider.notifier)
        .applyFilters(tagIds: result.tags, sort: result.sort);
  }

  @override
  ConsumerState<MenuFilterSheet> createState() => _MenuFilterSheetState();
}

class _MenuFilterSheetState extends ConsumerState<MenuFilterSheet> {
  late Set<int> _tags = {...widget.query.tagIds};
  late MenuSort _sort = widget.query.sort;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final text = Theme.of(context).textTheme;
    final tags = ref.watch(foodTagsProvider).value ?? const [];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppTokens.space20,
          AppTokens.space12,
          AppTokens.space20,
          AppTokens.space20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: palette.line,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppTokens.space16),
              Row(
                children: [
                  Expanded(
                    child: Text('Sort & filter', style: text.titleMedium),
                  ),
                  TextButton(
                    onPressed: _anythingSet
                        ? () => setState(() {
                              _tags = {};
                              _sort = MenuSort.storeOrder;
                            })
                        : null,
                    child: const Text('Clear'),
                  ),
                ],
              ),
              const SizedBox(height: AppTokens.space8),
              Text('Sort by', style: text.labelLarge),
              const SizedBox(height: AppTokens.space4),
              // `RadioGroup` rather than each tile's own `groupValue`, which
              // this SDK deprecated — and task 11.4 took the blanket
              // `deprecated_member_use` suppression out of
              // `analysis_options.yaml`, so the analyzer is the thing keeping
              // that honest.
              RadioGroup<MenuSort>(
                groupValue: _sort,
                onChanged: (value) =>
                    setState(() => _sort = value ?? MenuSort.storeOrder),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final option in MenuSort.values)
                      RadioListTile<MenuSort>(
                        value: option,
                        title: Text(option.label, style: text.bodyMedium),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                  ],
                ),
              ),
              if (tags.isNotEmpty) ...[
                const SizedBox(height: AppTokens.space12),
                Text('Food tags', style: text.labelLarge),
                const SizedBox(height: AppTokens.space4),
                // **Any, not all.** The server ORs them, so saying "all" here
                // would describe the opposite of what the list does.
                Text(
                  'Dishes with any of these',
                  style: text.bodySmall?.copyWith(color: palette.muted),
                ),
                const SizedBox(height: AppTokens.space8),
                Wrap(
                  spacing: AppTokens.space8,
                  runSpacing: AppTokens.space8,
                  children: [
                    for (final tag in tags)
                      FilterChip(
                        label: Text(tag.name),
                        selected: _tags.contains(tag.id),
                        onSelected: (selected) => setState(() {
                          if (selected) {
                            _tags.add(tag.id);
                          } else {
                            _tags.remove(tag.id);
                          }
                        }),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: AppTokens.space20),
              SizedBox(
                width: double.infinity,
                height: AppTokens.buttonHeight,
                child: FilledButton(
                  onPressed: () => Navigator.of(context)
                      .pop((tags: _tags, sort: _sort)),
                  child: const Text('Show dishes'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool get _anythingSet => _tags.isNotEmpty || _sort != MenuSort.storeOrder;
}
