import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../auth/presentation/widgets/auth_field.dart';
import '../../data/checkout_controller.dart';
import '../../domain/checkout_contact.dart';
import '../../domain/checkout_validation.dart';
import 'checkout_card.dart';

/// Who the order is for: a name, a phone number and the kitchen's note.
///
/// **The value lives in [checkoutControllerProvider], not in this widget.**
/// The inputs write through on every keystroke, so the address sheet, the
/// address book and — in task 6.5 — a refused order can all rebuild or leave
/// and come back without emptying the form.
///
/// The design draws placeholder-only inputs here; this uses the app's own
/// labelled field instead, as every other form in the app does, so a filled
/// field still says what it is.
class ContactDetailsSection extends ConsumerStatefulWidget {
  const ContactDetailsSection({super.key});

  @override
  ConsumerState<ContactDetailsSection> createState() =>
      _ContactDetailsSectionState();
}

class _ContactDetailsSectionState
    extends ConsumerState<ContactDetailsSection> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _note = TextEditingController();

  /// Prefilled once **per field**, and only once there is something to
  /// prefill it with.
  ///
  /// Per field rather than per form because the two arrive separately: the
  /// name comes from the account, which is restored from the keychain, and
  /// the phone can come from the chosen address, which is a round trip
  /// behind it. One flag for both meant a customer whose number was only on
  /// their address never saw it — the name seeded first and closed the door.
  ///
  /// Set as soon as the customer types, too, so a field they cleared is not
  /// refilled when the address book lands.
  bool _seededName = false;
  bool _seededPhone = false;

  @override
  void initState() {
    super.initState();
    // Whatever is already known, before the first frame.
    _seed(ref.read(checkoutContactProvider));
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _note.dispose();
    super.dispose();
  }

  void _seed(CheckoutContact contact) {
    if (!_seededName && contact.name.isNotEmpty) {
      _name.text = contact.name;
      _seededName = true;
    }
    if (!_seededPhone && contact.phone.isNotEmpty) {
      _phone.text = contact.phone;
      _seededPhone = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    // **Listened to, not watched.** Writing into a `TextEditingController`
    // notifies its field, which asks the ancestor `Form` to rebuild — doing
    // that from inside `build` is a `setState` during build. A listener fires
    // after the frame instead.
    ref.listen(checkoutContactProvider, (_, next) => _seed(next));

    final controller = ref.read(checkoutControllerProvider.notifier);

    return CheckoutCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CheckoutSectionTitle('Contact details'),
          const SizedBox(height: AppTokens.space12),
          AuthField(
            label: 'Full name',
            controller: _name,
            hint: 'Who the order is for',
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.name],
            validator: CheckoutValidation.fullName,
            onChanged: (value) {
              _seededName = true;
              controller.setName(value);
            },
          ),
          // The reserved helper line is exactly as tall as an error message,
          // so without this the message sits against the next field's label.
          const SizedBox(height: AppTokens.space8),
          AuthField(
            label: 'Phone number',
            controller: _phone,
            hint: 'For the kitchen and the driver',
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.telephoneNumber],
            validator: CheckoutValidation.phone,
            onChanged: (value) {
              _seededPhone = true;
              controller.setPhone(value);
            },
          ),
          const SizedBox(height: AppTokens.space8),
          AuthField(
            label: 'Order notes',
            controller: _note,
            hint: 'Optional — gate code, cutlery…',
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            minLines: 3,
            maxLines: 4,
            onChanged: controller.setNote,
          ),
        ],
      ),
    );
  }
}
