import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import '../crypto/crypto_service.dart';
import '../error/failures.dart';
import '../utils/safe_logger.dart';
import '../../models/vault_database.dart';

/// Storage abstraction for reading and writing the encrypted vault database.
abstract class EncryptedVaultStorage {
  Future<void> saveVault(VaultDatabase database, Uint8List vek);
  Future<VaultDatabase> loadVault(Uint8List vek);
  Future<bool> hasStoredVault();
  Future<void> deleteStoredVault();
  Future<Uint8List?> getRawEncryptedBytes();
}

/// Local file-backed encrypted vault storage.
class LocalEncryptedVaultStorage implements EncryptedVaultStorage {
  final CryptoService _crypto;
  final String _fileName;
  final String? _customDirPath;

  LocalEncryptedVaultStorage({
    CryptoService? crypto,
    this._fileName = 'vaultkey_vault.enc',
    this._customDirPath,
  }) : _crypto = crypto ?? CryptoService();

  Future<File> _getFile() async {
    final dirPath =
        _customDirPath ?? (await getApplicationDocumentsDirectory()).path;
    return File('$dirPath/$_fileName');
  }

  @override
  Future<void> saveVault(VaultDatabase database, Uint8List vek) async {
    try {
      final jsonString = database.serialize();
      final plaintextBytes = utf8.encode(jsonString);

      // Encrypt with VEK using AES-256-GCM
      final encryptedBytes = await _crypto.encryptAesGcm(plaintextBytes, vek);

      final file = await _getFile();
      await file.writeAsBytes(encryptedBytes, flush: true);
      SafeLogger.info(
        'EncryptedVaultStorage',
        'Vault encrypted and saved successfully (${encryptedBytes.length} bytes)',
      );
    } catch (e) {
      SafeLogger.error(
        'EncryptedVaultStorage',
        'Failed to save encrypted vault',
        e,
      );
      throw StorageFailure('Failed to save vault: $e');
    }
  }

  @override
  Future<VaultDatabase> loadVault(Uint8List vek) async {
    try {
      final file = await _getFile();
      if (!await file.exists()) {
        // Return empty database if no file exists yet
        return VaultDatabase(updatedAt: DateTime.now());
      }

      final encryptedBytes = await file.readAsBytes();
      if (encryptedBytes.isEmpty) {
        return VaultDatabase(updatedAt: DateTime.now());
      }

      // Decrypt with VEK
      final decryptedBytes = await _crypto.decryptAesGcm(encryptedBytes, vek);
      final jsonString = utf8.decode(decryptedBytes);
      return VaultDatabase.deserialize(jsonString);
    } catch (e) {
      SafeLogger.error(
        'EncryptedVaultStorage',
        'Failed to load or decrypt vault',
        e,
      );
      throw StorageFailure('Failed to load vault: $e');
    }
  }

  @override
  Future<bool> hasStoredVault() async {
    final file = await _getFile();
    return await file.exists() && (await file.length()) > 0;
  }

  @override
  Future<void> deleteStoredVault() async {
    final file = await _getFile();
    if (await file.exists()) {
      await file.delete();
      SafeLogger.info(
        'EncryptedVaultStorage',
        'Local encrypted vault file deleted',
      );
    }
  }

  @override
  Future<Uint8List?> getRawEncryptedBytes() async {
    final file = await _getFile();
    if (await file.exists()) {
      return await file.readAsBytes();
    }
    return null;
  }
}

/// In-memory encrypted vault storage for testing.
class InMemoryEncryptedVaultStorage implements EncryptedVaultStorage {
  final CryptoService _crypto;
  Uint8List? _storedEncryptedBytes;

  InMemoryEncryptedVaultStorage({CryptoService? crypto})
    : _crypto = crypto ?? CryptoService();

  @override
  Future<void> saveVault(VaultDatabase database, Uint8List vek) async {
    final jsonString = database.serialize();
    final plaintextBytes = utf8.encode(jsonString);
    _storedEncryptedBytes = await _crypto.encryptAesGcm(plaintextBytes, vek);
  }

  @override
  Future<VaultDatabase> loadVault(Uint8List vek) async {
    if (_storedEncryptedBytes == null || _storedEncryptedBytes!.isEmpty) {
      return VaultDatabase(updatedAt: DateTime.now());
    }
    final decryptedBytes = await _crypto.decryptAesGcm(
      _storedEncryptedBytes!,
      vek,
    );
    return VaultDatabase.deserialize(utf8.decode(decryptedBytes));
  }

  @override
  Future<bool> hasStoredVault() async =>
      _storedEncryptedBytes != null && _storedEncryptedBytes!.isNotEmpty;

  @override
  Future<void> deleteStoredVault() async {
    _storedEncryptedBytes = null;
  }

  @override
  Future<Uint8List?> getRawEncryptedBytes() async => _storedEncryptedBytes;
}
