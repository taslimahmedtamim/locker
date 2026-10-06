import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;

import '../core/crypto/crypto_service.dart';
import '../core/error/failures.dart';
import '../core/storage/encrypted_vault_storage.dart';
import '../core/storage/secure_key_store.dart';
import '../core/utils/safe_logger.dart';
import '../models/vault_database.dart';
import 'recovery_service.dart';

/// Service managing export and import of tamper-proof encrypted vault backup files (.vault).
class BackupService {
  final EncryptedVaultStorage _storage;
  final SecureKeyStore _keyStore;
  final RecoveryService _recoveryService;
  final CryptoService _crypto;

  BackupService({
    required this._storage,
    required this._keyStore,
    required this._recoveryService,
    CryptoService? crypto,
  }) : _crypto = crypto ?? CryptoService();

  /// Creates a fully encrypted, standalone backup envelope (.vault)
  /// containing NO plaintext passwords, notes, or keys.
  Future<String> exportEncryptedBackupJson() async {
    try {
      final rawVaultBytes = await _storage.getRawEncryptedBytes();
      if (rawVaultBytes == null || rawVaultBytes.isEmpty) {
        throw const BackupFailure('No vault data available to backup');
      }

      final recSalt = await _keyStore.read('vaultkey_rec_salt');
      final recWrappedVek = await _keyStore.read('vaultkey_rec_wrapped_vek');
      final qSalt = await _keyStore.read('vaultkey_q_salt');
      final qWrappedVek = await _keyStore.read('vaultkey_q_wrapped_vek');
      final qVerifier = await _keyStore.read('vaultkey_q_verifier');
      final questionsJson = await _keyStore.read('vaultkey_questions_json');
      List<String> questionsList = [];
      if (questionsJson != null && questionsJson.isNotEmpty) {
        try {
          final decoded = jsonDecode(questionsJson);
          if (decoded is List) {
            questionsList = decoded.map((e) => e.toString()).toList();
          }
        } catch (_) {}
      }
      final q1 = await _keyStore.read('vaultkey_q1') ?? '';
      final q2 = await _keyStore.read('vaultkey_q2') ?? '';
      final q3 = await _keyStore.read('vaultkey_q3') ?? '';
      if (questionsList.isEmpty) {
        questionsList = [
          if (q1.isNotEmpty) q1,
          if (q2.isNotEmpty) q2,
          if (q3.isNotEmpty) q3,
        ];
      }

      final keyEnvelopes = {
        'recovery_salt': recSalt ?? '',
        'recovery_wrapped_vek': recWrappedVek ?? '',
        'questions_salt': qSalt ?? '',
        'questions_wrapped_vek': qWrappedVek ?? '',
        'questions_verifier': qVerifier ?? '',
        'questions': questionsList,
        'question_1': questionsList.isNotEmpty ? questionsList[0] : q1,
        'question_2': questionsList.length > 1 ? questionsList[1] : q2,
        'question_3': questionsList.length > 2 ? questionsList[2] : q3,
      };

      final vaultPayloadB64 = base64Encode(rawVaultBytes);
      final keyEnvelopesJson = jsonEncode(keyEnvelopes);

      // Compute cryptographic SHA256 integrity checksum over the ciphertexts
      final checksumDigest = crypto.sha256.convert(
        utf8.encode(vaultPayloadB64 + keyEnvelopesJson),
      );

      final backupMap = {
        'vaultkey_format': 'V1_ENCRYPTED_BACKUP',
        'created_at': DateTime.now().toIso8601String(),
        'vault_ciphertext': vaultPayloadB64,
        'key_envelopes': keyEnvelopes,
        'integrity_checksum': checksumDigest.toString(),
      };

      SafeLogger.info(
        'BackupService',
        'Encrypted backup generated successfully',
      );
      return jsonEncode(backupMap);
    } catch (e) {
      SafeLogger.error('BackupService', 'Failed to generate backup', e);
      if (e is Failure) rethrow;
      throw BackupFailure('Export failed: $e');
    }
  }

  /// Validates backup format and integrity checksum before restore.
  Map<String, dynamic> validateBackupPayload(String backupJson) {
    try {
      final map = jsonDecode(backupJson) as Map<String, dynamic>;
      if (map['vaultkey_format'] != 'V1_ENCRYPTED_BACKUP') {
        throw const BackupFailure('Invalid backup file format');
      }

      final vaultPayloadB64 = map['vault_ciphertext'] as String?;
      final keyEnvelopes = map['key_envelopes'] as Map<String, dynamic>?;
      final storedChecksum = map['integrity_checksum'] as String?;

      if (vaultPayloadB64 == null ||
          keyEnvelopes == null ||
          storedChecksum == null) {
        throw const BackupFailure(
          'Corrupted backup: Missing required data fields',
        );
      }

      // Verify integrity checksum
      final keyEnvelopesJson = jsonEncode(keyEnvelopes);
      final computedDigest = crypto.sha256.convert(
        utf8.encode(vaultPayloadB64 + keyEnvelopesJson),
      );

      if (computedDigest.toString() != storedChecksum) {
        throw const BackupFailure(
          'Backup could not be verified. Integrity check failed (file modified or corrupted).',
        );
      }

      return map;
    } catch (e) {
      if (e is Failure) rethrow;
      throw const BackupFailure('Invalid or corrupted backup file');
    }
  }

  /// Restores vault on a fresh installation using the 24-word recovery key,
  /// the previous PIN that encrypted the backup (for 2FA protection), and sets a new PIN.
  Future<VaultDatabase> restoreWithRecoveryKey({
    required String backupJson,
    required String recoveryKey,
    String? previousPin,
    required String newPin,
  }) async {
    try {
      final map = validateBackupPayload(backupJson);
      final keyEnvelopes = map['key_envelopes'] as Map<String, dynamic>;
      final vaultCiphertextB64 = map['vault_ciphertext'] as String;

      // Stage key envelopes into keyStore
      await _keyStore.write(
        'vaultkey_rec_salt',
        keyEnvelopes['recovery_salt'] as String,
      );
      await _keyStore.write(
        'vaultkey_rec_wrapped_vek',
        keyEnvelopes['recovery_wrapped_vek'] as String,
      );
      await _keyStore.write(
        'vaultkey_q_salt',
        keyEnvelopes['questions_salt'] as String,
      );
      await _keyStore.write(
        'vaultkey_q_wrapped_vek',
        keyEnvelopes['questions_wrapped_vek'] as String,
      );
      await _keyStore.write(
        'vaultkey_q_verifier',
        keyEnvelopes['questions_verifier'] as String,
      );
      // Stage questions into keyStore (supporting any count)
      if (keyEnvelopes['questions'] is List) {
        final qList = (keyEnvelopes['questions'] as List)
            .map((e) => e.toString())
            .toList();
        await _keyStore.write('vaultkey_questions_json', jsonEncode(qList));
        if (qList.isNotEmpty) await _keyStore.write('vaultkey_q1', qList[0]);
        if (qList.length > 1) await _keyStore.write('vaultkey_q2', qList[1]);
        if (qList.length > 2) await _keyStore.write('vaultkey_q3', qList[2]);
      } else {
        final qList = <String>[];
        if (keyEnvelopes['question_1'] != null &&
            (keyEnvelopes['question_1'] as String).isNotEmpty) {
          qList.add(keyEnvelopes['question_1'] as String);
          await _keyStore.write(
            'vaultkey_q1',
            keyEnvelopes['question_1'] as String,
          );
        }
        if (keyEnvelopes['question_2'] != null &&
            (keyEnvelopes['question_2'] as String).isNotEmpty) {
          qList.add(keyEnvelopes['question_2'] as String);
          await _keyStore.write(
            'vaultkey_q2',
            keyEnvelopes['question_2'] as String,
          );
        }
        if (keyEnvelopes['question_3'] != null &&
            (keyEnvelopes['question_3'] as String).isNotEmpty) {
          qList.add(keyEnvelopes['question_3'] as String);
          await _keyStore.write(
            'vaultkey_q3',
            keyEnvelopes['question_3'] as String,
          );
        }
        await _keyStore.write('vaultkey_questions_json', jsonEncode(qList));
      }

      // Attempt unwrap VEK using the recovery key and previous PIN
      final vek = await _recoveryService.recoverWithMasterKey(
        recoveryKey,
        previousPin: previousPin,
      );

      // Decode and decrypt raw encrypted vault data with recovered VEK
      final rawVaultBytes = base64Decode(vaultCiphertextB64);
      final decryptedBytes = await _crypto.decryptAesGcm(rawVaultBytes, vek);
      final db = VaultDatabase.deserialize(utf8.decode(decryptedBytes));

      // Finalize setup with user's new PIN
      await _recoveryService.completeRecovery(newPin, vek);
      await _keyStore.write('vaultkey_has_vault', 'true');

      // Persist restored verified database to storage
      await _storage.saveVault(db, vek);

      SafeLogger.info(
        'BackupService',
        'Vault restored from backup successfully with ${db.entries.length} entries',
      );
      return db;
    } catch (e) {
      SafeLogger.error('BackupService', 'Failed to restore backup', e);
      if (e is Failure) rethrow;
      throw BackupFailure('Restore failed: $e');
    }
  }

  /// Restores vault using the 3 custom security questions and sets a new PIN.
  Future<VaultDatabase> restoreWithQuestions({
    required String backupJson,
    required List<String> answers,
    required String newPin,
  }) async {
    try {
      final map = validateBackupPayload(backupJson);
      final keyEnvelopes = map['key_envelopes'] as Map<String, dynamic>;
      final vaultCiphertextB64 = map['vault_ciphertext'] as String;

      // Stage key envelopes into keyStore
      await _keyStore.write(
        'vaultkey_rec_salt',
        keyEnvelopes['recovery_salt'] as String,
      );
      await _keyStore.write(
        'vaultkey_rec_wrapped_vek',
        keyEnvelopes['recovery_wrapped_vek'] as String,
      );
      await _keyStore.write(
        'vaultkey_q_salt',
        keyEnvelopes['questions_salt'] as String,
      );
      await _keyStore.write(
        'vaultkey_q_wrapped_vek',
        keyEnvelopes['questions_wrapped_vek'] as String,
      );
      await _keyStore.write(
        'vaultkey_q_verifier',
        keyEnvelopes['questions_verifier'] as String,
      );
      // Stage questions into keyStore (supporting any count)
      if (keyEnvelopes['questions'] is List) {
        final qList = (keyEnvelopes['questions'] as List)
            .map((e) => e.toString())
            .toList();
        await _keyStore.write('vaultkey_questions_json', jsonEncode(qList));
        if (qList.isNotEmpty) await _keyStore.write('vaultkey_q1', qList[0]);
        if (qList.length > 1) await _keyStore.write('vaultkey_q2', qList[1]);
        if (qList.length > 2) await _keyStore.write('vaultkey_q3', qList[2]);
      } else {
        final qList = <String>[];
        if (keyEnvelopes['question_1'] != null &&
            (keyEnvelopes['question_1'] as String).isNotEmpty) {
          qList.add(keyEnvelopes['question_1'] as String);
          await _keyStore.write(
            'vaultkey_q1',
            keyEnvelopes['question_1'] as String,
          );
        }
        if (keyEnvelopes['question_2'] != null &&
            (keyEnvelopes['question_2'] as String).isNotEmpty) {
          qList.add(keyEnvelopes['question_2'] as String);
          await _keyStore.write(
            'vaultkey_q2',
            keyEnvelopes['question_2'] as String,
          );
        }
        if (keyEnvelopes['question_3'] != null &&
            (keyEnvelopes['question_3'] as String).isNotEmpty) {
          qList.add(keyEnvelopes['question_3'] as String);
          await _keyStore.write(
            'vaultkey_q3',
            keyEnvelopes['question_3'] as String,
          );
        }
        await _keyStore.write('vaultkey_questions_json', jsonEncode(qList));
      }

      // Attempt unwrap VEK using the questions
      final vek = await _recoveryService.recoverWithQuestions(answers);

      // Load and verify decrypted database
      final rawVaultBytes = base64Decode(vaultCiphertextB64);
      final decryptedBytes = await _crypto.decryptAesGcm(rawVaultBytes, vek);
      final db = VaultDatabase.deserialize(utf8.decode(decryptedBytes));

      // Finalize with user's new PIN
      await _recoveryService.completeRecovery(newPin, vek);
      await _keyStore.write('vaultkey_has_vault', 'true');
      await _storage.saveVault(db, vek);

      SafeLogger.info(
        'BackupService',
        'Vault restored via security questions from backup',
      );
      return db;
    } catch (e) {
      SafeLogger.error(
        'BackupService',
        'Failed to restore backup via questions',
        e,
      );
      if (e is Failure) rethrow;
      throw BackupFailure('Restore failed: $e');
    }
  }
}
