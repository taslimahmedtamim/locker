import 'dart:convert';
import 'dart:typed_data';

import '../core/crypto/crypto_service.dart';
import '../core/error/failures.dart';
import '../core/storage/secure_key_store.dart';
import '../core/utils/safe_logger.dart';
import 'auth_service.dart';

/// Service coordinating emergency zero-knowledge recovery using 24-word key
/// or 3 custom security questions.
class RecoveryService {
  final CryptoService _crypto;
  final SecureKeyStore _keyStore;
  final AuthService _authService;

  static const String _kRecoverySalt = 'vaultkey_rec_salt';
  static const String _kRecoveryWrappedVek = 'vaultkey_rec_wrapped_vek';
  static const String _kQuestionsSalt = 'vaultkey_q_salt';
  static const String _kQuestionsWrappedVek = 'vaultkey_q_wrapped_vek';
  static const String _kQuestionsVerifier = 'vaultkey_q_verifier';

  RecoveryService({
    CryptoService? crypto,
    required this._keyStore,
    required this._authService,
  }) : _crypto = crypto ?? CryptoService();

  /// Recovers the Vault Encryption Key using the 24-word Master Recovery Key
  /// and the user's previous 6-digit PIN (enforcing Two-Factor recovery protection).
  Future<Uint8List> recoverWithMasterKey(
    String recoveryKey, {
    String? previousPin,
  }) async {
    try {
      final isValid = _crypto.validateMasterRecoveryKey(recoveryKey);
      if (!isValid) {
        throw const AuthFailure(
          'Invalid 24-word recovery key. Please check the spelling of your words.',
        );
      }

      final saltB64 = await _keyStore.read(_kRecoverySalt);
      final wrappedVekB64 = await _keyStore.read(_kRecoveryWrappedVek);

      if (saltB64 == null || wrappedVekB64 == null) {
        throw const AuthFailure(
          'Recovery credentials not found on this device',
        );
      }

      final salt = base64Decode(saltB64);
      final wrappedVek = base64Decode(wrappedVekB64);

      // Attempt unwrap with PIN binding first
      if (previousPin != null && previousPin.isNotEmpty) {
        try {
          final recKek = await _crypto.deriveKeyFromRecoveryKey(
            recoveryKey,
            salt,
            pin: previousPin,
          );
          final vek = await _crypto.decryptAesGcm(wrappedVek, recKek);
          SafeLogger.info(
            'RecoveryService',
            'Master recovery key + PIN successfully unwrapped VEK',
          );
          return vek;
        } catch (_) {
          throw const AuthFailure(
            'Recovery failed: Incorrect recovery key or previous PIN',
          );
        }
      }

      // If no PIN provided, attempt legacy unwrap (for backups created without PIN binding)
      try {
        final recKek = await _crypto.deriveKeyFromRecoveryKey(recoveryKey, salt);
        final vek = await _crypto.decryptAesGcm(wrappedVek, recKek);
        SafeLogger.info(
          'RecoveryService',
          'Master recovery key successfully unwrapped VEK (legacy mode)',
        );
        return vek;
      } catch (_) {
        throw const AuthFailure(
          'Recovery failed: Previous 6-digit PIN is required to decrypt this vault',
        );
      }
    } catch (e) {
      SafeLogger.error('RecoveryService', 'Recovery key unwrap failed', e);
      if (e is Failure) rethrow;
      throw const AuthFailure(
        'Recovery failed: Incorrect or invalid recovery key or previous PIN',
      );
    }
  }

  /// Recovers the Vault Encryption Key using custom security questions.
  Future<Uint8List> recoverWithQuestions(List<String> answers) async {
    try {
      if (answers.isEmpty || answers.any((a) => a.trim().isEmpty)) {
        throw const ValidationFailure(
          'All question answers must be provided',
        );
      }

      final saltB64 = await _keyStore.read(_kQuestionsSalt);
      final wrappedVekB64 = await _keyStore.read(_kQuestionsWrappedVek);
      final storedVerifierB64 = await _keyStore.read(_kQuestionsVerifier);

      if (saltB64 == null ||
          wrappedVekB64 == null ||
          storedVerifierB64 == null) {
        throw const AuthFailure(
          'Recovery questions not configured on this device',
        );
      }

      final salt = base64Decode(saltB64);
      final wrappedVek = base64Decode(wrappedVekB64);
      final storedVerifier = base64Decode(storedVerifierB64);

      final qKek = await _crypto.deriveKeyFromQuestions(answers, salt);
      final computedVerifier = _crypto.computeQuestionsVerifier(qKek);

      // Verify constant time
      if (!CryptoService.constantTimeEquals(storedVerifier, computedVerifier)) {
        throw const AuthFailure('One or more answers are incorrect');
      }

      final vek = await _crypto.decryptAesGcm(wrappedVek, qKek);
      SafeLogger.info(
        'RecoveryService',
        'Security questions successfully unwrapped VEK',
      );
      return vek;
    } catch (e) {
      SafeLogger.error('RecoveryService', 'Questions recovery failed', e);
      if (e is Failure) rethrow;
      throw const AuthFailure('Incorrect recovery answers');
    }
  }

  /// Sets a new PIN for the recovered vault and updates the PIN wrap.
  Future<void> completeRecovery(String newPin, Uint8List recoveredVek) async {
    await _authService.changePin(newPin, recoveredVek);
    SafeLogger.info(
      'RecoveryService',
      'Recovery finalized with newly configured PIN',
    );
  }
}
