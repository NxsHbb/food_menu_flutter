import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/util/html_text.dart';
import '../../domain/addon_selection.dart';
import '../../domain/product_addons.dart';

/// One add-on group on the dish detail screen.
///
/// The design draws a group as a white card: a title with a one-line hint, a
/// Required / Optional / Done badge, and the options as rows with a tick
/// control, a label and a price. The card gains a red border and the hint
/// turns into "Please make a selection" once the customer has tried to add a
/// dish with the group still unanswered.
///
/// Two things the design has no vocabulary for, drawn from what it does have:
///
/// - **Per-option quantity.** Where `option_quantity` is set, a chosen option
///   gets a small stepper, built like the one in the bottom bar. The design
///   never shows one, but the plugin supports it and the cart prices it, so
///   leaving it out would make a dish's real options unreachable.
/// - **A `text` or `textarea` group** reuses the shape of the design's own
///   "Special instructions" card, with the group's own title and the server's
///   placeholder. That card itself is the cart line note, which is task 4.5;
///   this is a priced add-on that happens to be typed.
class AddonGroupCard extends StatelessWidget {
  const AddonGroupCard({
    required this.group,
    required this.selection,
    required this.onToggle,
    required this.onQuantity,
    required this.onText,
    this.showError = false,
    this.onLimitReached,
    super.key,
  });

  final AddonGroup group;
  final AddonSelection selection;
  final void Function(AddonOption option) onToggle;
  final void Function(AddonOption option, int quantity) onQuantity;
  final ValueChanged<String> onText;

  /// Whether the group is being flagged as unanswered.
  final bool showError;

  /// Called when a tick is refused because the group is already full, so the
  /// screen can say so rather than appearing to ignore the tap.
  final VoidCallback? onLimitReached;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return Container(
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(AppTokens.radiusCardLarge),
        border: Border.all(
          color: showError ? palette.brand : palette.line,
          width: showError ? 1.5 : 1,
        ),
      ),
      padding: const EdgeInsets.all(AppTokens.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(group: group, selection: selection, showError: showError),
          if (group.type.isText)
            _TextInput(group: group, selection: selection, onChanged: onText)
          else
            for (var i = 0; i < group.options.length; i++)
              _OptionRow(
                group: group,
                option: group.options[i],
                selection: selection,
                divided: i > 0,
                onToggle: onToggle,
                onQuantity: onQuantity,
                onLimitReached: onLimitReached,
              ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.group,
    required this.selection,
    required this.showError,
  });

  final AddonGroup group;
  final AddonSelection selection;
  final bool showError;

  /// The line under the title: what the group expects, or what is missing.
  ///
  /// The group's own description, when it has one, goes on a line of its own
  /// below this. Collapsing the two would mean choosing between the store's
  /// words and the rule, and a customer needs both.
  String get _rule {
    if (showError) {
      return group.type.isText
          ? 'Please fill this in'
          : 'Please make a selection';
    }

    if (group.type.isText) {
      return group.charLimit > 0 ? 'Up to ${group.charLimit} characters' : '';
    }

    if (group.type.isSingleChoice) return 'Select one';

    final floor = group.choiceFloor;
    final limit = group.choiceLimit;

    if (floor > 0 && limit != null) {
      return floor == limit
          ? 'Select $floor'
          : 'Select $floor to $limit';
    }
    if (floor > 0) return 'Select at least $floor';
    if (limit != null) return 'Select up to $limit';
    return 'Choose any';
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final text = Theme.of(context).textTheme;
    final rule = _rule;
    final description = plainText(group.description);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTokens.space8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(group.title, style: text.titleMedium),
                if (rule.isNotEmpty) ...[
                  const SizedBox(height: AppTokens.space2),
                  Text(
                    rule,
                    style: text.bodySmall?.copyWith(
                      color: showError ? palette.brand : palette.muted,
                    ),
                  ),
                ],
                if (description.isNotEmpty) ...[
                  const SizedBox(height: AppTokens.space2),
                  Text(
                    description,
                    style: text.bodySmall?.copyWith(color: palette.muted),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppTokens.space8),
          _Badge(group: group, selection: selection),
        ],
      ),
    );
  }
}

/// Required / Done / Optional, as the design pairs them with the title.
class _Badge extends StatelessWidget {
  const _Badge({required this.group, required this.selection});

  final AddonGroup group;
  final AddonSelection selection;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final text = Theme.of(context).textTheme;
    final answered = selection.unanswered([group]).isEmpty;

    final (label, background, foreground) = switch ((group.choiceFloor > 0, answered)) {
      (true, true) => ('Done', palette.okBackground, palette.okForeground),
      (true, false) => ('Required', palette.brand, palette.contrast),
      _ => ('Optional', palette.chip, palette.muted),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.space10,
        vertical: AppTokens.space4,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppTokens.radiusChip),
      ),
      child: Text(
        label,
        style: text.labelSmall?.copyWith(color: foreground),
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.group,
    required this.option,
    required this.selection,
    required this.divided,
    required this.onToggle,
    required this.onQuantity,
    required this.onLimitReached,
  });

  final AddonGroup group;
  final AddonOption option;
  final AddonSelection selection;
  final bool divided;
  final void Function(AddonOption option) onToggle;
  final void Function(AddonOption option, int quantity) onQuantity;
  final VoidCallback? onLimitReached;

  /// The price on the right: what this option adds, or "Free".
  ///
  /// `free_label` is the store's own answer about whether a zero-priced option
  /// says so, already resolved by the server, so a store that would rather not
  /// label every sauce "Free" simply shows nothing.
  String? get _price {
    if (option.isFree) return group.freeLabel ? 'Free' : null;
    return '+ ${option.price.format()}';
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final text = Theme.of(context).textTheme;
    final selected = selection.isSelected(group, option);
    final description = plainText(option.description);
    final price = _price;

    // A refused tap still needs to land somewhere, or the row looks broken.
    final full = !selected && selection.limitReached(group);

    return DecoratedBox(
      decoration: BoxDecoration(
        border: divided ? Border(top: BorderSide(color: palette.line)) : null,
      ),
      child: Semantics(
        selected: selected,
        child: InkWell(
          onTap: full ? onLimitReached : () => onToggle(option),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppTokens.space10),
            child: Row(
              children: [
                _Tick(selected: selected, single: group.type.isSingleChoice),
                const SizedBox(width: AppTokens.space12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        option.label,
                        style: text.bodyMedium?.copyWith(
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                          color: full ? palette.muted : palette.ink,
                        ),
                      ),
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: AppTokens.space2),
                        Text(
                          description,
                          style: text.bodySmall?.copyWith(color: palette.muted),
                        ),
                      ],
                    ],
                  ),
                ),
                if (selected && group.optionQuantity) ...[
                  const SizedBox(width: AppTokens.space8),
                  _OptionStepper(
                    quantity: selection.quantityOf(group, option),
                    onChanged: (q) => onQuantity(option, q),
                  ),
                ],
                if (price != null) ...[
                  const SizedBox(width: AppTokens.space8),
                  Text(
                    price,
                    style: text.bodyMedium?.copyWith(color: palette.muted2),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The design's tick: a circle for one-of, a rounded square for many-of.
class _Tick extends StatelessWidget {
  const _Tick({required this.selected, required this.single});

  final bool selected;
  final bool single;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: single ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: single ? null : BorderRadius.circular(AppTokens.space6),
        color: selected ? palette.brand : palette.card,
        border: Border.all(
          color: selected ? palette.brand : palette.ring,
          width: 1.8,
        ),
      ),
      child: selected
          ? Icon(Icons.check_rounded, size: 13, color: palette.contrast)
          : null,
    );
  }
}

/// The small stepper on an option that carries its own quantity.
class _OptionStepper extends StatelessWidget {
  const _OptionStepper({required this.quantity, required this.onChanged});

  final int quantity;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final text = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: palette.bg,
        borderRadius: BorderRadius.circular(AppTokens.radiusChip),
      ),
      child: Row(
        children: [
          _StepIcon(
            icon: Icons.remove,
            // One is the floor: unticking is the row's job, not the stepper's.
            onTap: quantity > 1 ? () => onChanged(quantity - 1) : null,
          ),
          SizedBox(
            width: 22,
            child: Center(child: Text('$quantity', style: text.labelLarge)),
          ),
          _StepIcon(
            icon: Icons.add,
            onTap: quantity < AddonSelection.maxOptionQuantity
                ? () => onChanged(quantity + 1)
                : null,
          ),
        ],
      ),
    );
  }
}

class _StepIcon extends StatelessWidget {
  const _StepIcon({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTokens.radiusChip),
      child: SizedBox(
        width: 28,
        height: 28,
        child: Icon(
          icon,
          size: 15,
          color: onTap == null ? palette.muted : palette.ink,
        ),
      ),
    );
  }
}

class _TextInput extends StatefulWidget {
  const _TextInput({
    required this.group,
    required this.selection,
    required this.onChanged,
  });

  final AddonGroup group;
  final AddonSelection selection;
  final ValueChanged<String> onChanged;

  @override
  State<_TextInput> createState() => _TextInputState();
}

class _TextInputState extends State<_TextInput> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.selection.choiceFor(widget.group).text,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final group = widget.group;

    return TextField(
      controller: _controller,
      onChanged: widget.onChanged,
      // A textarea is the design's own multi-line box; a text add-on is one
      // line, which is the difference the plugin draws between the two.
      minLines: group.type == AddonFieldType.textarea ? 3 : 1,
      maxLines: group.type == AddonFieldType.textarea ? 3 : 1,
      maxLength: group.charLimit > 0 ? group.charLimit : null,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(
        hintText: group.placeholder.isNotEmpty
            ? group.placeholder
            : 'e.g. No onions, sauce on the side',
        // The character counter is the limit's own reminder; the hint line
        // above already carries it, so this would say it twice.
        counterText: '',
      ),
    );
  }
}
