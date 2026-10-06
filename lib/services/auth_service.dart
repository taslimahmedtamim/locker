import 'dart:convert';
import 'dart:typed_data';

import 'package:local_auth/local_auth.dart';

import '../core/crypto/crypto_service.dart';
import '../core/error/failures.dart';
import '../core/storage/secure_key_store.dart';
import '../core/utils/safe_logger.dart';

/// Service managing PIN authentication, biometrics, brute-force rate-limiting,
/// and master key initialization.
class AuthService {
  final CryptoService _crypto;
  final SecureKeyStore _keyStore;
  final LocalAuthentication _localAuth;

  static const String _kHasVault = 'vaultkey_has_vault';
  static const String _kPinSalt = 'vaultkey_pin_salt';
  static const String _kPinWrappedVek = 'vaultkey_pin_wrapped_vek';
  static const String _kRecoverySalt = 'vaultkey_rec_salt';
  static const String _kRecoveryWrappedVek = 'vaultkey_rec_wrapped_vek';
  static const String _kQuestionsSalt = 'vaultkey_q_salt';
  static const String _kQuestionsWrappedVek = 'vaultkey_q_wrapped_vek';
  static const String _kQuestionsVerifier = 'vaultkey_q_verifier';
  static const String _kQuestionsJson = 'vaultkey_questions_json';
  static const String _kQuestion1 = 'vaultkey_q1';
  static const String _kQuestion2 = 'vaultkey_q2';
  static const String _kQuestion3 = 'vaultkey_q3';
  static const String _kBiometricEnabled = 'vaultkey_bio_enabled';
  static const String _kBiometricWrappedVek = 'vaultkey_bio_wrapped_vek';
  static const String _kFailedPinAttempts = 'vaultkey_failed_attempts';
  static const String _kLockoutUntil = 'vaultkey_lockout_until';
  static const String _kAutoLockMinutes = 'vaultkey_autolock_minutes';

  AuthService({
    CryptoService? crypto,
    required this._keyStore,
    LocalAuthentication? localAuth,
  }) : _crypto = crypto ?? CryptoService(),
       _localAuth = localAuth ?? LocalAuthentication();

  Future<bool> hasVault() async {
    final val = await _keyStore.read(_kHasVault);
    return val == 'true';
  }

  Future<bool> isBiometricEnabled() async {
    final val = await _keyStore.read(_kBiometricEnabled);
    return val == 'true';
  }

  Future<int> getAutoLockMinutes() async {
    final val = await _keyStore.read(_kAutoLockMinutes);
    return val != null ? int.tryParse(val) ?? 5 : 5;
  }

  Future<void> setAutoLockMinutes(int minutes) async {
    await _keyStore.write(_kAutoLockMinutes, minutes.toString());
  }

  /// Initial setup of the entire cryptographic vault enclave during onboarding.
  Future<Uint8List> initializeVault({
    required String pin,
    required String recoveryKey,
    required List<String> questions,
    required List<String> answers,
    bool enableBiometrics = false,
  }) async {
    try {
      if (pin.length != 6 || int.tryParse(pin) == null) {
        throw const ValidationFailure('PIN must be exactly 6 digits');
      }
      if (questions.isEmpty ||
          answers.isEmpty ||
          questions.length != answers.length) {
        throw const ValidationFailure(
          'At least one question and answer are required',
        );
      }
      if (questions.any((q) => q.trim().isEmpty) ||
          answers.any((a) => a.trim().isEmpty)) {
        throw const ValidationFailure(
          'Questions and answers cannot be blank',
        );
      }

      // 1. Generate 256-bit VEK
      final vek = _crypto.generateVaultEncryptionKey();

      // 2. Wrap VEK under PIN-KEK
      final pinSalt = _crypto.generateSecureRandomBytes(16);
      final pinKek = await _crypto.deriveKeyFromPin(pin, pinSalt);
      final pinWrappedVek = await _crypto.encryptAesGcm(vek, pinKek);

      // 3. Wrap VEK under Recovery-KEK bound to user's PIN for 2-Factor recovery protection
      final recSalt = _crypto.generateSecureRandomBytes(16);
      final recKek = await _crypto.deriveKeyFromRecoveryKey(
        recoveryKey,
        recSalt,
        pin: pin,
      );
      final recWrappedVek = await _crypto.encryptAesGcm(vek, recKek);

      // 4. Wrap VEK under Questions-KEK
      final qSalt = _crypto.generateSecureRandomBytes(16);
      final qKek = await _crypto.deriveKeyFromQuestions(answers, qSalt);
      final qWrappedVek = await _crypto.encryptAesGcm(vek, qKek);
      final qVerifier = _crypto.computeQuestionsVerifier(qKek);

      // 5. Persist to platform SecureKeyStore
      await _keyStore.write(_kPinSalt, base64Encode(pinSalt));
      await _keyStore.write(_kPinWrappedVek, base64Encode(pinWrappedVek));

      await _keyStore.write(_kRecoverySalt, base64Encode(recSalt));
      await _keyStore.write(_kRecoveryWrappedVek, base64Encode(recWrappedVek));

      await _keyStore.write(_kQuestionsSalt, base64Encode(qSalt));
      await _keyStore.write(_kQuestionsWrappedVek, base64Encode(qWrappedVek));
      await _keyStore.write(_kQuestionsVerifier, base64Encode(qVerifier));

      // Persist questions as JSON array for arbitrary count, plus legacy keys for compatibility
      await _keyStore.write(_kQuestionsJson, jsonEncode(questions));
      if (questions.isNotEmpty) await _keyStore.write(_kQuestion1, questions[0]);
      if (questions.length > 1) await _keyStore.write(_kQuestion2, questions[1]);
      if (questions.length > 2) await _keyStore.write(_kQuestion3, questions[2]);

      await _keyStore.write(_kFailedPinAttempts, '0');
      await _keyStore.write(_kAutoLockMinutes, '5');

      if (enableBiometrics) {
        await enableBiometricUnlock(vek);
      }

      await _keyStore.write(_kHasVault, 'true');
      SafeLogger.info(
        'AuthService',
        'Vault initialized and all KEK wraps committed to SecureKeyStore',
      );

      return vek;
    } catch (e) {
      SafeLogger.error('AuthService', 'Failed to initialize vault', e);
      rethrow;
    }
  }

  /// Verifies lockout status and unlocks the VEK using 6-digit PIN.
  Future<Uint8List> unlockWithPin(String pin) async {
    await _checkLockout();

    final saltB64 = await _keyStore.read(_kPinSalt);
    final wrappedVekB64 = await _keyStore.read(_kPinWrappedVek);

    if (saltB64 == null || wrappedVekB64 == null) {
      throw const AuthFailure('Vault configuration missing');
    }

    final salt = base64Decode(saltB64);
    final wrappedVek = base64Decode(wrappedVekB64);

    try {
      final pinKek = await _crypto.deriveKeyFromPin(pin, salt);
      final vek = await _crypto.decryptAesGcm(wrappedVek, pinKek);

      // Reset failed attempts upon success
      await _keyStore.write(_kFailedPinAttempts, '0');
      await _keyStore.delete(_kLockoutUntil);
      SafeLogger.info('AuthService', 'PIN unlock successful');
      return vek;
    } catch (_) {
      await _recordFailedAttempt();
      throw const AuthFailure('Incorrect PIN');
    }
  }

  Future<void> _checkLockout() async {
    final lockoutUntilStr = await _keyStore.read(_kLockoutUntil);
    if (lockoutUntilStr != null) {
      final lockoutUntil = DateTime.tryParse(lockoutUntilStr);
      if (lockoutUntil != null) {
        final remaining = lockoutUntil.difference(DateTime.now()).inSeconds;
        if (remaining > 0) {
          throw LockoutFailure(remaining);
        }
      }
    }
  }

  Future<void> _recordFailedAttempt() async {
    final attemptsStr = await _keyStore.read(_kFailedPinAttempts);
    int attempts =
        (attemptsStr != null ? int.tryParse(attemptsStr) ?? 0 : 0) + 1;
    await _keyStore.write(_kFailedPinAttempts, attempts.toString());

    if (attempts >= 5) {
      // Exponential backoff: 5 attempts = 30s, 6 = 60s, 7+ = 300s
      int delaySeconds = attempts == 5 ? 30 : (attempts == 6 ? 60 : 300);
      final lockoutTime = DateTime.now().add(Duration(seconds: delaySeconds));
      await _keyStore.write(_kLockoutUntil, lockoutTime.toIso8601String());
      SafeLogger.warn(
        'AuthService',
        'Rate limit triggered: locked out for $delaySeconds s',
      );
    }
  }

  /// Unlocks using platform biometrics.
  Future<Uint8List> unlockWithBiometrics() async {
    final enabled = await isBiometricEnabled();
    if (!enabled) {
      throw const AuthFailure('Biometric unlock is disabled');
    }

    final bioWrappedVekB64 = await _keyStore.read(_kBiometricWrappedVek);
    if (bioWrappedVekB64 == null) {
      throw const AuthFailure('Biometric key wrap missing');
    }

    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();

      if (!canCheck && !isDeviceSupported) {
        throw const AuthFailure('Biometrics not available on this device');
      }

      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Scan fingerprint or face to unlock Locker',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );

      if (!authenticated) {
        throw const AuthFailure('Biometric authentication cancelled');
      }

      // Decrypt VEK from biometric wrap
      final wrappedBytes = base64Decode(bioWrappedVekB64);
      // In mobile Keystore, the biometric key wraps VEK
      // For cross-platform security, we derive or unwrap
      final bioKey = await _getOrCreateBiometricHardwareKey();
      final vek = await _crypto.decryptAesGcm(wrappedBytes, bioKey);

      // Reset failed PIN attempts on biometric success
      await _keyStore.write(_kFailedPinAttempts, '0');
      SafeLogger.info('AuthService', 'Biometric unlock successful');
      return vek;
    } catch (e) {
      SafeLogger.error('AuthService', 'Biometric unlock failed', e);
      if (e is Failure) rethrow;
      throw AuthFailure(e.toString());
    }
  }

  Future<Uint8List> _getOrCreateBiometricHardwareKey() async {
    const keyName = 'vaultkey_bio_hw_key';
    final existing = await _keyStore.read(keyName);
    if (existing != null) {
      return base64Decode(existing);
    }
    final newKey = _crypto.generateSecureRandomBytes(32);
    await _keyStore.write(keyName, base64Encode(newKey));
    return newKey;
  }

  Future<void> enableBiometricUnlock(Uint8List vek) async {
    final bioKey = await _getOrCreateBiometricHardwareKey();
    final wrappedVek = await _crypto.encryptAesGcm(vek, bioKey);
    await _keyStore.write(_kBiometricWrappedVek, base64Encode(wrappedVek));
    await _keyStore.write(_kBiometricEnabled, 'true');
    SafeLogger.info('AuthService', 'Biometric unlock enabled');
  }

  Future<void> disableBiometricUnlock() async {
    await _keyStore.write(_kBiometricEnabled, 'false');
    await _keyStore.delete(_kBiometricWrappedVek);
    SafeLogger.info('AuthService', 'Biometric unlock disabled');
  }

  /// Changes the user's 6-digit PIN, re-wrapping the active VEK with a new salt and PIN-KEK.
  Future<void> changePin(String newPin, Uint8List activeVek) async {
    if (newPin.length != 6 || int.tryParse(newPin) == null) {
      throw const ValidationFailure('New PIN must be 6 digits');
    }

    final newSalt = _crypto.generateSecureRandomBytes(16);
    final newPinKek = await _crypto.deriveKeyFromPin(newPin, newSalt);
    final newWrappedVek = await _crypto.encryptAesGcm(activeVek, newPinKek);

    await _keyStore.write(_kPinSalt, base64Encode(newSalt));
    await _keyStore.write(_kPinWrappedVek, base64Encode(newWrappedVek));
    await _keyStore.write(_kFailedPinAttempts, '0');
    SafeLogger.info(
      'AuthService',
      'PIN changed and VEK re-wrapped under new PIN-KEK',
    );
  }

  /// Retrieves user configured recovery questions for display.
  Future<List<String>> getStoredQuestions() async {
    final jsonStr = await _keyStore.read(_kQuestionsJson);
    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final decoded = jsonDecode(jsonStr);
        if (decoded is List) {
          final list = decoded.map((e) => e.toString()).toList();
          if (list.isNotEmpty) return list;
        }
      } catch (_) {}
    }
    // Fallback to legacy single-question keys
    final q1 = await _keyStore.read(_kQuestion1);
    final q2 = await _keyStore.read(_kQuestion2);
    final q3 = await _keyStore.read(_kQuestion3);
    final list = <String>[];
    if (q1 != null && q1.isNotEmpty) list.add(q1);
    if (q2 != null && q2.isNotEmpty) list.add(q2);
    if (q3 != null && q3.isNotEmpty) list.add(q3);
    return list.isNotEmpty ? list : ['Security Question 1'];
  }

  /// Generates a fresh 24-word Master Recovery Key, wraps the active VEK bound to the user's PIN,
  /// and updates the secure storage credentials.
  Future<String> regenerateRecoveryKey(String currentPin, Uint8List activeVek) async {
    if (currentPin.length != 6 || int.tryParse(currentPin) == null) {
      throw const ValidationFailure('PIN must be exactly 6 digits');
    }

    final newMnemonic = _crypto.generateMasterRecoveryKey();
    final recSalt = _crypto.generateSecureRandomBytes(16);
    final recKek = await _crypto.deriveKeyFromRecoveryKey(
      newMnemonic,
      recSalt,
      pin: currentPin,
    );
    final recWrappedVek = await _crypto.encryptAesGcm(activeVek, recKek);

    await _keyStore.write(_kRecoverySalt, base64Encode(recSalt));
    await _keyStore.write(_kRecoveryWrappedVek, base64Encode(recWrappedVek));

    SafeLogger.info(
      'AuthService',
      'Fresh 24-word recovery key generated and bound to PIN',
    );
    return newMnemonic;
  }
}
