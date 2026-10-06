import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vaultkey/core/crypto/crypto_service.dart';
import 'package:vaultkey/core/error/failures.dart';

void main() {
  late CryptoService crypto;

  setUp(() {
    crypto = CryptoService();
  });

  group('CSPRNG & Random Generation', () {
    test(
      'generateSecureRandomBytes returns correct length and unique bytes',
      () {
        final bytes1 = crypto.generateSecureRandomBytes(32);
        final bytes2 = crypto.generateSecureRandomBytes(32);

        expect(bytes1.length, equals(32));
        expect(bytes2.length, equals(32));
        expect(bytes1, isNot(equals(bytes2)));
      },
    );

    test('generateVaultEncryptionKey produces 32-byte (256-bit) key', () {
      final vek = crypto.generateVaultEncryptionKey();
      expect(vek.length, equals(32));
    });
  });

  group('BIP-39 24-Word Master Recovery Key', () {
    test('generates valid 24-word recovery phrase that passes validation', () {
      final phrase = crypto.generateMasterRecoveryKey();
      final words = phrase.split(' ');

      expect(words.length, equals(24));
      expect(crypto.validateMasterRecoveryKey(phrase), isTrue);
    });

    test('rejects tampered or corrupt recovery phrases', () {
      final validPhrase = crypto.generateMasterRecoveryKey();
      final words = validPhrase.split(' ');

      // Corrupt the first word
      words[0] = 'invalidwordnotindict';
      expect(crypto.validateMasterRecoveryKey(words.join(' ')), isFalse);

      // Change valid word causing checksum mismatch
      final wordsCopy = validPhrase.split(' ');
      wordsCopy[23] = wordsCopy[23] == 'zoo' ? 'abandon' : 'zoo';
      expect(crypto.validateMasterRecoveryKey(wordsCopy.join(' ')), isFalse);
    });
  });

  group('AES-256-GCM Authenticated Encryption & Decryption', () {
    test('encrypts and decrypts payload correctly with valid key', () async {
      final key = crypto.generateVaultEncryptionKey();
      const secretMessage = 'My Super Secret Master Password & Bank Vault';
      final plaintext = utf8.encode(secretMessage);

      final encrypted = await crypto.encryptAesGcm(plaintext, key);

      // Nonce (12) + Tag (16) + Ciphertext
      expect(encrypted.length, greaterThan(28));

      final decryptedBytes = await crypto.decryptAesGcm(encrypted, key);
      final decryptedMessage = utf8.decode(decryptedBytes);

      expect(decryptedMessage, equals(secretMessage));
    });

    test('fails decryption when provided with a wrong key', () async {
      final correctKey = crypto.generateVaultEncryptionKey();
      final wrongKey = crypto.generateVaultEncryptionKey();
      final plaintext = utf8.encode('Sensitive Account Details');

      final encrypted = await crypto.encryptAesGcm(plaintext, correctKey);

      expect(
        () async => await crypto.decryptAesGcm(encrypted, wrongKey),
        throwsA(isA<CryptoFailure>()),
      );
    });

    test(
      'fails decryption when ciphertext is tampered (bit-flip attack)',
      () async {
        final key = crypto.generateVaultEncryptionKey();
        final plaintext = utf8.encode('Important Financial Credentials');
        final encrypted = await crypto.encryptAesGcm(plaintext, key);

        // Mutate one byte in the ciphertext payload
        final tampered = Uint8List.fromList(encrypted);
        tampered[tampered.length - 1] ^= 0xFF;

        expect(
          () async => await crypto.decryptAesGcm(tampered, key),
          throwsA(isA<CryptoFailure>()),
        );
      },
    );

    test('fails decryption when auth tag is tampered', () async {
      final key = crypto.generateVaultEncryptionKey();
      final plaintext = utf8.encode('Protected Secret');
      final encrypted = await crypto.encryptAesGcm(plaintext, key);

      // Tag is located at indices 12..28
      final tampered = Uint8List.fromList(encrypted);
      tampered[15] ^= 0x01;

      expect(
        () async => await crypto.decryptAesGcm(tampered, key),
        throwsA(isA<CryptoFailure>()),
      );
    });
  });

  group('Key Derivation Functions (KDF)', () {
    test(
      'deriveKeyFromPin derives consistent 256-bit key with same salt',
      () async {
        final salt = crypto.generateSecureRandomBytes(16);
        const pin = '123456';

        final key1 = await crypto.deriveKeyFromPin(pin, salt);
        final key2 = await crypto.deriveKeyFromPin(pin, salt);
        final keyWrongPin = await crypto.deriveKeyFromPin('654321', salt);

        expect(key1.length, equals(32));
        expect(key1, equals(key2));
        expect(key1, isNot(equals(keyWrongPin)));
      },
    );

    test('deriveKeyFromQuestions normalizes answers correctly', () async {
      final salt = crypto.generateSecureRandomBytes(16);
      final answers1 = [
        ' First Computer ',
        'PARIS, France!!',
        'Mr. Fluffy (Cat)',
      ];
      final answers2 = ['first computer', 'paris france', 'mr fluffy cat'];

      final key1 = await crypto.deriveKeyFromQuestions(answers1, salt);
      final key2 = await crypto.deriveKeyFromQuestions(answers2, salt);

      expect(key1, equals(key2));

      final verifier1 = crypto.computeQuestionsVerifier(key1);
      final verifier2 = crypto.computeQuestionsVerifier(key2);
      expect(CryptoService.constantTimeEquals(verifier1, verifier2), isTrue);
    });

    test('deriveKeyFromQuestions supports arbitrary question counts (1, 2, 4)', () async {
      final salt = crypto.generateSecureRandomBytes(16);
      
      // 1 question
      final keySingle = await crypto.deriveKeyFromQuestions(['Single Answer'], salt);
      expect(keySingle.length, equals(32));

      // 2 questions
      final keyDouble = await crypto.deriveKeyFromQuestions(['Answer A', 'Answer B'], salt);
      expect(keyDouble.length, equals(32));

      // 4 questions
      final keyQuad = await crypto.deriveKeyFromQuestions(['A1', 'A2', 'A3', 'A4'], salt);
      expect(keyQuad.length, equals(32));

      // Empty answers rejected
      expect(
        () => crypto.deriveKeyFromQuestions([], salt),
        throwsA(isA<CryptoFailure>()),
      );
    });
  });

  group('Password Generator & Entropy', () {
    test('generates password of specified length within character bounds', () {
      final pwd = crypto.generatePassword(
        length: 24,
        uppercase: true,
        lowercase: true,
        numbers: true,
        symbols: true,
      );

      expect(pwd.length, equals(24));
      expect(crypto.calculateEntropyScore(pwd), equals(4)); // Maximum strength
    });

    test('respects character set selection', () {
      final digitsOnly = crypto.generatePassword(
        length: 16,
        uppercase: false,
        lowercase: false,
        numbers: true,
        symbols: false,
      );

      expect(RegExp(r'^[0-9]+$').hasMatch(digitsOnly), isTrue);
    });
  });
}
