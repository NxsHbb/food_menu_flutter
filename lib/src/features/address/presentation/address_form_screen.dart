import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/screen_header.dart';
import '../../auth/presentation/widgets/auth_error_banner.dart';
import '../data/address_controller.dart';
import '../domain/address_field.dart';
import '../domain/saved_address.dart';
import 'widgets/address_field_input.dart';

/// Add or edit one saved address.
///
/// **The form is not written here.** Which inputs exist, in what order, under
/// what label, required or not, and whether a state is a picker or free text
/// all come from `GET /app/address-fields` for the chosen country. Hard-coding
/// them would be wrong in most of the world — see `FINDINGS.md`.
class AddressFormScreen extends ConsumerStatefulWidget {
  const AddressFormScreen({this.addressId, super.key});

  /// Null when adding.
  final String? addressId;

  /// Editing an existing address.
  static const routePath = 'addresses/:id';
  static const routeName = 'address-form';

  /// Adding. A separate path rather than an empty `:id`, which go_router will
  /// not match. Registered **before** `:id` so it is not swallowed by it —
  /// the ids are hex, so "new" could never be one anyway.
  static const newRoutePath = 'addresses/new';
  static const newRouteName = 'address-new';

  @override
  ConsumerState<AddressFormScreen> createState() => _AddressFormScreenState();
}

class _AddressFormScreenState extends ConsumerState<AddressFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _label = TextEditingController();
  final _controllers = <String, TextEditingController>{};

  /// The address as edited so far. Picker values live here; text lives in the
  /// controllers until submit, so typing does not rebuild the whole form.
  SavedAddress _address = const SavedAddress();

  /// Null until the customer picks one, at which point the fields are
  /// refetched for it.
  String? _country;

  bool _seeded = false;
  bool _busy = false;
  AddressSaveException? _error;

  bool get _isEdit => widget.addressId != null && widget.addressId!.isNotEmpty;

  @override
  void dispose() {
    _label.dispose();
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Fills the form from the saved address, once the book has arrived.
  void _seed(List<SavedAddress> book) {
    if (_seeded) return;

    final existing =
        book.where((a) => a.id == widget.addressId).firstOrNull;

    if (existing != null) {
      _address = existing;
      _label.text = existing.label;
      _country = existing.country.isEmpty ? null : existing.country;
    }

    _seeded = true;
  }

  TextEditingController _controllerFor(String key) {
    return _controllers.putIfAbsent(
      key,
      () => TextEditingController(text: _address.field(key)),
    );
  }

  /// The address as the inputs currently have it.
  SavedAddress _collect(AddressFields fields) {
    var address = _address.copyWith(label: _label.text.trim());

    for (final field in fields.fields) {
      // Pickers already wrote into `_address`; only text needs collecting.
      if (field.isPicker) continue;
      final controller = _controllers[field.key];
      if (controller != null) {
        address = address.withField(field.key, controller.text.trim());
      }
    }

    return address.copyWith(country: _country ?? fields.country);
  }

  Future<void> _save(AddressFields fields) async {
    setState(() => _error = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _busy = true);
    try {
      await ref
          .read(addressControllerProvider.notifier)
          .save(_collect(fields));
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on AddressSaveException catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
      // Re-run validation **after** the rebuild, so the inputs have the new
      // server error to report. Validating here would ask the widgets that
      // are still on screen, which have the previous one.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _formKey.currentState?.validate();
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(
        () => _error = AddressSaveException.from(error),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final id = widget.addressId;
    if (id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this address?'),
        content: const Text('It will be removed from your account.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref.read(addressControllerProvider.notifier).remove(id);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on Object catch (error) {
      if (!mounted) return;
      final message =
          error is AddressSaveException ? error.message : 'Could not delete.';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// The server's complaint for one field, if it named this one.
  String? _serverErrorFor(String key) {
    final error = _error;
    if (error == null || !error.isThisAddress) return null;
    return error.field == key ? error.message : null;
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final book = ref.watch(addressControllerProvider);

    book.whenData(_seed);

    final fields = ref.watch(addressFieldsProvider(_country));

    return Scaffold(
      backgroundColor: palette.page,
      body: Column(
        children: [
          ScreenHeader(
            title: _isEdit ? 'Edit address' : 'Add address',
            trailing: _isEdit
                ? IconButton(
                    onPressed: _busy ? null : _delete,
                    icon: const Icon(Icons.delete_outline_rounded),
                    color: palette.brand,
                    tooltip: 'Delete address',
                  )
                : null,
          ),
          Expanded(
            child: fields.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _FieldsError(
                error: error,
                onRetry: () =>
                    ref.invalidate(addressFieldsProvider(_country)),
              ),
              data: (fields) => _form(fields),
            ),
          ),
        ],
      ),
    );
  }

  Widget _form(AddressFields fields) {
    final palette = AppPalette.of(context);
    final error = _error;

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppTokens.space16,
          AppTokens.space16,
          AppTokens.space16,
          140,
        ),
        children: [
          // A rejection aimed at a different saved address would otherwise
          // highlight an input the customer did not touch.
          if (error != null && !error.isThisAddress) ...[
            AuthErrorBanner(error: error.error),
            const SizedBox(height: AppTokens.space8),
            Text(
              'Another saved address needs fixing before this one can be '
              'saved.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: palette.muted),
            ),
            const SizedBox(height: AppTokens.space16),
          ],
          AddressFieldInput(
            field: const AddressField(
              key: 'label',
              // Ours, not WooCommerce's — the server stores it but has no
              // opinion about it, so this label is written here.
              label: 'Name this address',
              required: false,
              priority: 0,
              type: 'text',
            ),
            controller: _label,
            enabled: !_busy,
            hint: 'Home, Work…',
          ),
          const SizedBox(height: AppTokens.space16),
          for (final field in fields.fields) ...[
            AddressFieldInput(
              field: field,
              controller: field.isPicker ? null : _controllerFor(field.key),
              value: field.isPicker ? _selectedFor(field, fields) : null,
              options: field.key == 'country' ? fields.countries : null,
              enabled: !_busy,
              serverError: _serverErrorFor(field.key),
              onChanged: (value) => _onPicked(field, value),
            ),
            const SizedBox(height: AppTokens.space16),
          ],
          SwitchListTile.adaptive(
            value: _address.isDefault,
            onChanged: _busy
                ? null
                : (value) =>
                    setState(() => _address = _address.copyWith(isDefault: value)),
            title: const Text('Use as my default address'),
            subtitle: const Text(
              'Also kept in step with your account on the web.',
            ),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: AppTokens.space20),
          SizedBox(
            height: AppTokens.buttonHeight,
            child: FilledButton(
              onPressed: _busy ? null : () => _save(fields),
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  // Always "Save", because the header already says whether
                  // this is a new address or an edit — and a button repeating
                  // the title reads as a second heading.
                  : const Text('Save address'),
            ),
          ),
        ],
      ),
    );
  }

  /// The current value of a picker.
  String? _selectedFor(AddressField field, AddressFields fields) {
    if (field.key == 'country') return _country ?? fields.country;

    final value = _address.field(field.key);
    // A state carried over from another country will not be in this one's
    // list, and handing a DropdownButton an absent value throws.
    return field.options.containsKey(value) ? value : null;
  }

  void _onPicked(AddressField field, String? value) {
    if (value == null) return;

    setState(() {
      if (field.key == 'country') {
        _country = value;
        // The new country has its own fields, and a state code from the old
        // one is meaningless under it.
        _address = _address.copyWith(country: value, state: '');
        _controllers.remove('state')?.dispose();
      } else {
        _address = _address.withField(field.key, value);
      }
    });
  }
}

class _FieldsError extends StatelessWidget {
  const _FieldsError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final text = Theme.of(context).textTheme;
    final api = error is ApiException ? error as ApiException : null;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.space24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 40, color: palette.muted),
            const SizedBox(height: AppTokens.space12),
            Text(
              api?.message ?? 'Could not load the address form.',
              textAlign: TextAlign.center,
              style: text.bodyLarge?.copyWith(color: palette.muted),
            ),
            const SizedBox(height: AppTokens.space16),
            OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}
