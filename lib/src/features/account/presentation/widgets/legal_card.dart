import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../store/data/store_config_repository.dart';
import 'account_row.dart';

/// The store's privacy policy and terms, on the account screen (task 14.4).
///
/// **Both app stores want a reachable privacy policy** before they will
/// publish an app that creates accounts — Apple's 5.1.1 and Play's User Data
/// policy — and the link has to be in the app, not only on the listing.
///
/// The pages are the store's, so the app does not host, cache or reformat
/// them: the row opens whatever the store published, in the browser the
/// customer already trusts with it.
///
/// **It draws nothing when the store has published nothing.** WordPress
/// creates its privacy page as a draft and a great many stores never publish
/// it, so an always-present row would send customers to a 404 — worse than no
/// row, and worse in the one place a reviewer will look.
class LegalCard extends ConsumerWidget {
  const LegalCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(storeConfigProvider).value;
    final privacy = store?.privacyPolicyUrl ?? '';
    final terms = store?.termsUrl ?? '';

    // **Nothing at all, not an empty card.** The spacing below belongs to this
    // widget for the same reason: a store with no published policy is the
    // common case, and a stray gap where a card is not would show on more
    // screens than the card itself.
    if (privacy.isEmpty && terms.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTokens.space16),
      child: AccountRowCard(
        rows: [
          if (privacy.isNotEmpty)
            AccountRow(
              mono: 'PP',
              label: 'Privacy policy',
              onTap: () => _open(context, privacy),
            ),
          if (terms.isNotEmpty)
            AccountRow(
              mono: 'TC',
              label: 'Terms & conditions',
              onTap: () => _open(context, terms),
            ),
        ],
      ),
    );
  }

  /// Hands the url to the system browser.
  ///
  /// **Says so when it cannot.** A tap that silently does nothing reads as a
  /// broken app, and this is the row a store reviewer is most likely to try.
  static Future<void> _open(BuildContext context, String url) async {
    final messenger = ScaffoldMessenger.of(context);
    final target = Uri.tryParse(url);

    var opened = false;
    if (target != null) {
      try {
        opened = await launchUrl(target, mode: LaunchMode.externalApplication);
      } on Object {
        // A missing browser, a blocked intent, a malformed scheme the parse
        // let through. All one answer to the customer.
        opened = false;
      }
    }

    if (!opened) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not open that page.')),
      );
    }
  }
}
