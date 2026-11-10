import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where the chosen branch is remembered between launches.
///
/// A branch is not a secret, so this would sit just as well in
/// `SharedPreferences` — it uses secure storage only because the app already
/// depends on it for the cart token and the keychain, and one storage
/// dependency is better than two.
abstract class BranchStore {
  /// The remembered branch id, or null if none was ever chosen. **Zero is a
  /// real answer**, meaning store-wide, and is not the same as null.
  Future<int?> read();

  Future<void> write(int branchId);
}

class SecureBranchStore implements BranchStore {
  SecureBranchStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock_this_device,
                synchronizable: false,
              ),
            );

  final FlutterSecureStorage _storage;

  static const _key = 'fmp_branch_v1';

  @override
  Future<int?> read() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null || raw.isEmpty) return null;

      return int.tryParse(raw);
    } on Exception {
      // An unreadable keystore must not stop the app launching; the customer
      // is simply asked to choose again.
      return null;
    }
  }

  @override
  Future<void> write(int branchId) async {
    try {
      await _storage.write(key: _key, value: '$branchId');
    } on Exception {
      // Remembering is a convenience; the choice still holds for this run.
    }
  }
}

final branchStoreProvider = Provider<BranchStore>((ref) => SecureBranchStore());
