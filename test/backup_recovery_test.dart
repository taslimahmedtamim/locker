import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vaultkey/core/crypto/crypto_service.dart';
import 'package:vaultkey/core/error/failures.dart';
import 'package:vaultkey/core/storage/encrypted_vault_storage.dart';
import 'package:vaultkey/core/storage/secure_key_store.dart';
import 'package:vaultkey/models/vault_entry.dart';
import 'package:vaultkey/repositories/vault_repository.dart';
import 'package:vaultkey/services/auth_service.dart';
import 'package:vaultkey/services/backup_service.dart';
import 'package:vaultkey/services/recovery_service.dart';

void main() {
  late CryptoService crypto;
  late InMemorySecureKeyStore keyStoreA;
  late InMemoryEncryptedVaultStorage storageA;
  late AuthService authServiceA;
  late RecoveryService recoveryServiceA;
  late VaultRepository vaultRepoA;
  late BackupService backupServiceA;

  setUp(() {
    crypto = CryptoService();
    keyStoreA = InMemorySecureKeyStore();
    storageA = InMemoryEncryptedVaultStorage(crypto: crypto);
    authServiceA = AuthService(crypto: crypto, keyStore: keyStoreA);
    recoveryServiceA = RecoveryService(
      crypto: crypto,
      keyStore: keyStoreA,
      authService: authServiceA,
    );
    vaultRepoA = LocalVaultRepository(storage: storageA);
    backupServiceA = BackupService(
      storage: storageA,
      keyStore: keyStoreA,
      recoveryService: recoveryServiceA,
    );
  });

  test('Full Life-cycle: Setup -> Add 10 accounts -> Export -> Wipe -> Fresh Install -> Restore -> Verify 10 accounts', () async {
    const pinA = '123456';
    final recoveryKey = crypto.generateMasterRecoveryKey();
    final questions = [
      'What is your favorite planet?',
      'First car model?',
      'Childhood pet name?',
    ];
    final answers = ['Jupiter', 'Honda Civic', 'Barnaby'];

    // 1. Initial Onboarding on "Phone A"
    final vek = await authServiceA.initializeVault(
      pin: pinA,
      recoveryKey: recoveryKey,
      questions: questions,
      answers: answers,
    );

    // 2. Unlock vault and add 10 test accounts
    await vaultRepoA.unlock(vek);
    for (int i = 1; i <= 10; i++) {
      await vaultRepoA.addEntry(
        VaultEntry(
          id: 'acc-$i',
          title: 'Account $i Service',
          username: 'user$i@example.com',
          password: 'Password-$i-#CSPRNG!',
          website: 'https://service$i.example.com',
          notes: 'Test note for account $i',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
    }

    final entriesA = await vaultRepoA.getEntries();
    expect(entriesA.length, equals(10));

    // 3. Export encrypted backup
    final backupJson = await backupServiceA.exportEncryptedBackupJson();

    // Verify backup contains NO plaintext passwords
    expect(backupJson.contains('Password-1-#CSPRNG!'), isFalse);
    expect(backupJson.contains('user1@example.com'), isFalse);
    expect(backupJson.contains('Jupiter'), isFalse);

    // 4. Simulate complete Phone Wipe / Fresh App Installation (Phone B)
    final keyStoreB = InMemorySecureKeyStore();
    final storageB = InMemoryEncryptedVaultStorage(crypto: crypto);
    final authServiceB = AuthService(crypto: crypto, keyStore: keyStoreB);
    final recoveryServiceB = RecoveryService(
      crypto: crypto,
      keyStore: keyStoreB,
      authService: authServiceB,
    );
    final backupServiceB = BackupService(
      storage: storageB,
      keyStore: keyStoreB,
      recoveryService: recoveryServiceB,
    );
    final vaultRepoB = LocalVaultRepository(storage: storageB);

    // 5. Restore backup onto Phone B with Master Recovery Key, previous PIN, and new PIN
    const newPinB = '654321';
    final restoredDb = await backupServiceB.restoreWithRecoveryKey(
      backupJson: backupJson,
      recoveryKey: recoveryKey,
      previousPin: pinA,
      newPin: newPinB,
    );

    expect(restoredDb.entries.length, equals(10));

    // 6. Verify Phone B can now unlock seamlessly using the new PIN!
    final unlockedVekB = await authServiceB.unlockWithPin(newPinB);
    await vaultRepoB.unlock(unlockedVekB);

    final entriesB = await vaultRepoB.getEntries();
    expect(entriesB.length, equals(10));
    expect(entriesB.any((e) => e.username == 'user10@example.com'), isTrue);
    expect(entriesB.any((e) => e.username == 'user1@example.com'), isTrue);
    expect(entriesB.first.password, startsWith('Password-'));
  });

  test('Tampered or corrupted backup file is strictly rejected', () async {
    final recoveryKey = crypto.generateMasterRecoveryKey();
    final vek = await authServiceA.initializeVault(
      pin: '111222',
      recoveryKey: recoveryKey,
      questions: ['Q1', 'Q2', 'Q3'],
      answers: ['A1', 'A2', 'A3'],
    );
    await vaultRepoA.unlock(vek);
    await vaultRepoA.addEntry(
      VaultEntry(
        id: '1',
        title: 'Bank',
        username: 'user',
        password: 'pwd',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    final backupJson = await backupServiceA.exportEncryptedBackupJson();
    final map = jsonDecode(backupJson) as Map<String, dynamic>;

    // Tamper with the ciphertext by changing one character
    final originalCiphertext = map['vault_ciphertext'] as String;
    map['vault_ciphertext'] =
        '${originalCiphertext.substring(0, originalCiphertext.length - 2)}AA';

    final tamperedJson = jsonEncode(map);

    expect(
      () => backupServiceA.validateBackupPayload(tamperedJson),
      throwsA(isA<BackupFailure>()),
    );
  });

  test('Vault setup and recovery works with arbitrary user questions (e.g. 2 questions)', () async {
    final keyStore = InMemorySecureKeyStore();
    final authService = AuthService(crypto: crypto, keyStore: keyStore);
    final recoveryService = RecoveryService(
      crypto: crypto,
      keyStore: keyStore,
      authService: authService,
    );

    final questions = [
      'What was the model of your first guitar?',
      'Who was your favorite childhood artist?',
    ];
    final answers = ['Fender Stratocaster', 'Vincent van Gogh'];

    final vek = await authService.initializeVault(
      pin: '556677',
      recoveryKey: crypto.generateMasterRecoveryKey(),
      questions: questions,
      answers: answers,
    );

    // Stored questions should match exactly what user created
    final storedQuestions = await authService.getStoredQuestions();
    expect(storedQuestions, equals(questions));

    // Emergency recovery with the 2 answers
    final recoveredVek = await recoveryService.recoverWithQuestions(answers);
    expect(recoveredVek, equals(vek));

    // Recovery succeeds and new PIN can be set
    await recoveryService.completeRecovery('998877', recoveredVek);
    final pinUnlockedVek = await authService.unlockWithPin('998877');
    expect(pinUnlockedVek, equals(vek));
  });

  test('Two-Factor 24-word recovery: Finding 24 words alone CANNOT decrypt vault without previous PIN', () async {
    final keyStore = InMemorySecureKeyStore();
    final authService = AuthService(crypto: crypto, keyStore: keyStore);
    final recoveryService = RecoveryService(
      crypto: crypto,
      keyStore: keyStore,
      authService: authService,
    );

    const pin = '345678';
    final recoveryKey = crypto.generateMasterRecoveryKey();

    final vek = await authService.initializeVault(
      pin: pin,
      recoveryKey: recoveryKey,
      questions: ['Test question?'],
      answers: ['Test answer'],
    );

    // 1. Attacker finds ONLY the 24 words (no PIN) -> Must fail
    expect(
      () => recoveryService.recoverWithMasterKey(recoveryKey),
      throwsA(isA<AuthFailure>()),
    );

    // 2. Attacker enters 24 words + GUESSES incorrect PIN -> Must fail
    expect(
      () => recoveryService.recoverWithMasterKey(recoveryKey, previousPin: '000000'),
      throwsA(isA<AuthFailure>()),
    );
    expect(
      () => recoveryService.recoverWithMasterKey(recoveryKey, previousPin: '123456'),
      throwsA(isA<AuthFailure>()),
    );

    // 3. Legitimate user provides 24 words + correct previous PIN -> Must succeed!
    final recoveredVek = await recoveryService.recoverWithMasterKey(
      recoveryKey,
      previousPin: pin,
    );
    expect(recoveredVek, equals(vek));

    // 4. Test re-generating 24 words via Settings
    final freshMnemonic = await authService.regenerateRecoveryKey(pin, vek);
    expect(freshMnemonic, isNot(equals(recoveryKey)));

    // Old recovery key is no longer valid
    expect(
      () => recoveryService.recoverWithMasterKey(recoveryKey, previousPin: pin),
      throwsA(isA<AuthFailure>()),
    );

    // Fresh recovery key + correct PIN succeeds
    final reRecoveredVek = await recoveryService.recoverWithMasterKey(
      freshMnemonic,
      previousPin: pin,
    );
    expect(reRecoveredVek, equals(vek));
  });
}
