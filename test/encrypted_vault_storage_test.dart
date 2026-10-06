import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vaultkey/core/crypto/crypto_service.dart';
import 'package:vaultkey/core/error/failures.dart';
import 'package:vaultkey/core/storage/encrypted_vault_storage.dart';
import 'package:vaultkey/models/vault_database.dart';
import 'package:vaultkey/models/vault_entry.dart';

void main() {
  late CryptoService crypto;
  late InMemoryEncryptedVaultStorage storage;

  setUp(() {
    crypto = CryptoService();
    storage = InMemoryEncryptedVaultStorage(crypto: crypto);
  });

  test(
    'Plaintext password, username, and notes NEVER appear in encrypted storage',
    () async {
      final vek = crypto.generateVaultEncryptionKey();
      const testPassword = 'SecretBankMasterPassword#2026!';
      const testUsername = 'alice.vaultkey@example.com';
      const testNotes = 'Confidential PIN 9988 and private security token';

      final entry = VaultEntry(
        id: 'entry-1',
        title: 'Global Bank Portal',
        username: testUsername,
        password: testPassword,
        website: 'https://bank.example.com',
        notes: testNotes,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final db = VaultDatabase(
        version: 1,
        updatedAt: DateTime.now(),
        entries: [entry],
      );

      // Save encrypted vault
      await storage.saveVault(db, vek);

      // Inspect raw stored bytes
      final rawBytes = await storage.getRawEncryptedBytes();
      expect(rawBytes, isNotNull);
      expect(rawBytes!.length, greaterThan(28));

      // Convert raw bytes to ascii/latin1 string to check for leaks
      final rawString = latin1.decode(rawBytes);

      // Ensure plaintext values NEVER appear in raw storage
      expect(
        rawString.contains(testPassword),
        isFalse,
        reason: 'Plaintext password leaked in stored file!',
      );
      expect(
        rawString.contains(testUsername),
        isFalse,
        reason: 'Plaintext username leaked in stored file!',
      );
      expect(
        rawString.contains(testNotes),
        isFalse,
        reason: 'Plaintext notes leaked in stored file!',
      );
      expect(
        rawString.contains('Global Bank Portal'),
        isFalse,
        reason: 'Plaintext title leaked in stored file!',
      );

      // Verify successful decryption with correct VEK
      final loadedDb = await storage.loadVault(vek);
      expect(loadedDb.entries.length, equals(1));
      expect(loadedDb.entries.first.password, equals(testPassword));
      expect(loadedDb.entries.first.username, equals(testUsername));

      // Verify decryption failure with wrong VEK
      final wrongVek = crypto.generateVaultEncryptionKey();
      expect(
        () async => await storage.loadVault(wrongVek),
        throwsA(isA<CryptoFailure>()),
      );
    },
  );
}
