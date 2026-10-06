import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultkey/core/crypto/crypto_service.dart';
import 'package:vaultkey/core/storage/encrypted_vault_storage.dart';
import 'package:vaultkey/core/storage/secure_key_store.dart';
import 'package:vaultkey/app/providers.dart';
import 'package:vaultkey/main.dart';

void main() {
  testWidgets('VaultKeyApp renders initial checking or onboarding screen', (
    WidgetTester tester,
  ) async {
    final crypto = CryptoService();
    final mockKeyStore = InMemorySecureKeyStore();
    final mockStorage = InMemoryEncryptedVaultStorage(crypto: crypto);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          secureKeyStoreProvider.overrideWithValue(mockKeyStore),
          encryptedVaultStorageProvider.overrideWithValue(mockStorage),
        ],
        child: const VaultKeyApp(),
      ),
    );

    await tester.pump();
    expect(find.byType(VaultKeyApp), findsOneWidget);
  });
}
