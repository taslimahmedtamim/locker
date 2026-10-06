import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:cryptography/cryptography.dart' as crypt;

import '../error/failures.dart';
import '../utils/bip39_words.dart';

/// Cryptographic service providing institutional-grade encryption, key derivation,
/// CSPRNG generation, and key wrapping for VaultKey.
class CryptoService {
  final crypt.AesGcm _aesGcm = crypt.AesGcm.with256bits();
  final crypt.Pbkdf2 _pbkdf2 = crypt.Pbkdf2(
    macAlgorithm: crypt.Hmac.sha256(),
    iterations: 100000,
    bits: 256,
  );

  /// Generates cryptographically secure random bytes of given length.
  Uint8List generateSecureRandomBytes(int length) {
    final random = Random.secure();
    final bytes = Uint8List(length);
    for (int i = 0; i < length; i++) {
      bytes[i] = random.nextInt(256);
    }
    return bytes;
  }

  /// Generates a fresh 256-bit Vault Encryption Key (VEK).
  Uint8List generateVaultEncryptionKey() {
    return generateSecureRandomBytes(32);
  }

  /// Generates a 24-word Master Emergency Recovery Key using 256 bits of CSPRNG entropy.
  String generateMasterRecoveryKey() {
    final entropy = generateSecureRandomBytes(32);
    return Bip39Utility.entropyToMnemonic(entropy);
  }

  /// Validates a 24-word recovery key.
  bool validateMasterRecoveryKey(String mnemonic) {
    return Bip39Utility.mnemonicToEntropy(mnemonic) != null;
  }

  /// Derives a 256-bit Key Encryption Key (PIN-KEK) from a user PIN and salt.
  Future<Uint8List> deriveKeyFromPin(String pin, List<int> salt) async {
    try {
      final secretKey = crypt.SecretKey(utf8.encode(pin));
      final derivedKey = await _pbkdf2.deriveKey(
        secretKey: secretKey,
        nonce: salt,
      );
      final keyBytes = await derivedKey.extractBytes();
      return Uint8List.fromList(keyBytes);
    } catch (e) {
      throw CryptoFailure('Failed to derive key from PIN: $e');
    }
  }

  /// Derives a 256-bit Key Encryption Key (Recovery-KEK) from a 24-word recovery key,
  /// an optional PIN (for Two-Factor recovery protection), and salt.
  Future<Uint8List> deriveKeyFromRecoveryKey(
    String mnemonic,
    List<int> salt, {
    String? pin,
  }) async {
    try {
      final entropy = Bip39Utility.mnemonicToEntropy(mnemonic);
      if (entropy == null) {
        throw const CryptoFailure('Invalid recovery key checksum or wordlist');
      }
      final keyMaterial = (pin != null && pin.isNotEmpty)
          ? Uint8List.fromList([...entropy, ...utf8.encode(pin)])
          : entropy;
      final secretKey = crypt.SecretKey(keyMaterial);
      final derivedKey = await _pbkdf2.deriveKey(
        secretKey: secretKey,
        nonce: salt,
      );
      final keyBytes = await derivedKey.extractBytes();
      return Uint8List.fromList(keyBytes);
    } catch (e) {
      throw CryptoFailure('Failed to derive key from recovery key: $e');
    }
  }

  /// Normalizes a human security question answer.
  String normalizeAnswer(String answer) {
    return answer
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[.,!?:;\x27\x22\(\)\[\]]'), '')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Derives a 256-bit Key Encryption Key (Q&A-KEK) from normalized answers and salt.
  Future<Uint8List> deriveKeyFromQuestions(
    List<String> answers,
    List<int> salt,
  ) async {
    try {
      if (answers.isEmpty) {
        throw const CryptoFailure('At least one answer is required');
      }
      final normalized = answers.map(normalizeAnswer).join('|');
      final secretKey = crypt.SecretKey(utf8.encode(normalized));
      final derivedKey = await _pbkdf2.deriveKey(
        secretKey: secretKey,
        nonce: salt,
      );
      final keyBytes = await derivedKey.extractBytes();
      return Uint8List.fromList(keyBytes);
    } catch (e) {
      throw CryptoFailure('Failed to derive key from questions: $e');
    }
  }

  /// Computes a verifiable HMAC-SHA256 fingerprint for recovery answers without storing plaintext.
  Uint8List computeQuestionsVerifier(List<int> derivedKey) {
    final hmac = crypto.Hmac(crypto.sha256, derivedKey);
    final digest = hmac.convert(
      utf8.encode('vaultkey-recovery-qa-verifier-v1'),
    );
    return Uint8List.fromList(digest.bytes);
  }

  /// Encrypts plaintext bytes using AES-256-GCM authenticated encryption.
  /// Output format: [12-byte Nonce] + [16-byte MAC Tag] + [Ciphertext]
  Future<Uint8List> encryptAesGcm(
    List<int> plaintext,
    List<int> keyBytes,
  ) async {
    try {
      final secretKey = crypt.SecretKey(keyBytes);
      final nonce = generateSecureRandomBytes(12);

      final secretBox = await _aesGcm.encrypt(
        plaintext,
        secretKey: secretKey,
        nonce: nonce,
      );

      final combined = BytesBuilder(copy: false);
      combined.add(secretBox.nonce);
      combined.add(secretBox.mac.bytes);
      combined.add(secretBox.cipherText);
      return combined.toBytes();
    } catch (e) {
      throw CryptoFailure('Encryption failed: $e');
    }
  }

  /// Decrypts ciphertext bytes using AES-256-GCM.
  /// Verifies the 16-byte authentication tag; throws CryptoFailure if modified or invalid key.
  Future<Uint8List> decryptAesGcm(List<int> payload, List<int> keyBytes) async {
    try {
      if (payload.length < 28) {
        throw const CryptoFailure('Payload too short for AES-GCM envelope');
      }

      final nonce = payload.sublist(0, 12);
      final macBytes = payload.sublist(12, 28);
      final cipherText = payload.sublist(28);

      final secretKey = crypt.SecretKey(keyBytes);
      final secretBox = crypt.SecretBox(
        cipherText,
        nonce: nonce,
        mac: crypt.Mac(macBytes),
      );

      final decrypted = await _aesGcm.decrypt(secretBox, secretKey: secretKey);
      return Uint8List.fromList(decrypted);
    } catch (e) {
      throw CryptoFailure('Decryption failed or data tampered: $e');
    }
  }

  /// Secure CSPRNG Password Generator with zero bias.
  String generatePassword({
    int length = 20,
    bool uppercase = true,
    bool lowercase = true,
    bool numbers = true,
    bool symbols = true,
  }) {
    if (length < 8) length = 8;
    if (length > 64) length = 64;

    const upperChars = 'ABCDEFGHJKLMNPQRSTUVWXYZ'; // Exclude ambiguous I, O
    const lowerChars = 'abcdefghijkmnopqrstuvwxyz'; // Exclude ambiguous l
    const numberChars = '23456789'; // Exclude ambiguous 0, 1
    const symbolChars = '!@#\$%^&*()-_=+[]{}<>?~';

    String charPool = '';
    final guaranteed = <String>[];
    final random = Random.secure();

    if (uppercase) {
      charPool += upperChars;
      guaranteed.add(upperChars[random.nextInt(upperChars.length)]);
    }
    if (lowercase) {
      charPool += lowerChars;
      guaranteed.add(lowerChars[random.nextInt(lowerChars.length)]);
    }
    if (numbers) {
      charPool += numberChars;
      guaranteed.add(numberChars[random.nextInt(numberChars.length)]);
    }
    if (symbols) {
      charPool += symbolChars;
      guaranteed.add(symbolChars[random.nextInt(symbolChars.length)]);
    }

    if (charPool.isEmpty) {
      charPool = lowerChars + numberChars;
      guaranteed.add(lowerChars[random.nextInt(lowerChars.length)]);
      guaranteed.add(numberChars[random.nextInt(numberChars.length)]);
    }

    final result = <String>[...guaranteed];
    while (result.length < length) {
      final index = random.nextInt(charPool.length);
      result.add(charPool[index]);
    }

    // Fisher-Yates shuffle using CSPRNG
    for (int i = result.length - 1; i > 0; i--) {
      final j = random.nextInt(i + 1);
      final temp = result[i];
      result[i] = result[j];
      result[j] = temp;
    }

    return result.join();
  }

  /// Calculates password entropy score (0 to 4 bars).
  int calculateEntropyScore(String password) {
    if (password.isEmpty) return 0;
    int poolSize = 0;
    if (RegExp(r'[a-z]').hasMatch(password)) poolSize += 26;
    if (RegExp(r'[A-Z]').hasMatch(password)) poolSize += 26;
    if (RegExp(r'[0-9]').hasMatch(password)) poolSize += 10;
    if (RegExp(r'[^a-zA-Z0-9]').hasMatch(password)) poolSize += 32;

    if (poolSize == 0) return 0;

    final entropy = password.length * (log(poolSize) / ln2);

    if (entropy < 36) return 1;
    if (entropy < 60) return 2;
    if (entropy < 80) return 3;
    return 4;
  }

  /// Constant-time byte array equality check to prevent timing attacks.
  static bool constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    int result = 0;
    for (int i = 0; i < a.length; i++) {
      result |= a[i] ^ b[i];
    }
    return result == 0;
  }
}
