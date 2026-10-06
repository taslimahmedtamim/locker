import 'dart:typed_data';

import '../core/error/failures.dart';
import '../core/storage/encrypted_vault_storage.dart';
import '../core/utils/safe_logger.dart';
import '../models/vault_database.dart';
import '../models/vault_entry.dart';

/// Abstract repository for Vault management. Designed to allow seamless
/// future cloud synchronization providers without rewriting UI/controllers.
abstract class VaultRepository {
  Future<List<VaultEntry>> getEntries();
  Future<List<VaultEntry>> searchEntries(String query);
  Future<VaultEntry?> getEntryById(String id);
  Future<void> addEntry(VaultEntry entry);
  Future<void> updateEntry(VaultEntry entry);
  Future<void> deleteEntry(String id);
  Future<void> unlock(Uint8List vek);
  void lock();
  bool get isUnlocked;
  Uint8List? get activeVek;
}

/// Production implementation of LocalVaultRepository.
class LocalVaultRepository implements VaultRepository {
  final EncryptedVaultStorage _storage;
  VaultDatabase? _inMemoryDatabase;
  Uint8List? _activeVek;

  LocalVaultRepository({required this._storage});

  @override
  bool get isUnlocked => _activeVek != null && _inMemoryDatabase != null;

  @override
  Uint8List? get activeVek => _activeVek;

  void _ensureUnlocked() {
    if (!isUnlocked) {
      throw const AuthFailure('Vault is locked');
    }
  }

  @override
  Future<void> unlock(Uint8List vek) async {
    try {
      _activeVek = Uint8List.fromList(vek);
      _inMemoryDatabase = await _storage.loadVault(_activeVek!);
      SafeLogger.info(
        'VaultRepository',
        'Vault unlocked successfully with ${_inMemoryDatabase!.entries.length} entries',
      );
    } catch (e) {
      lock();
      rethrow;
    }
  }

  @override
  void lock() {
    // Clear decrypted vault and zero-out VEK from memory
    if (_activeVek != null) {
      for (int i = 0; i < _activeVek!.length; i++) {
        _activeVek![i] = 0;
      }
      _activeVek = null;
    }
    _inMemoryDatabase = null;
    SafeLogger.info('VaultRepository', 'Vault locked and memory cleared');
  }

  @override
  Future<List<VaultEntry>> getEntries() async {
    _ensureUnlocked();
    // Return sorted by updated/title with favorites first
    final list = List<VaultEntry>.from(_inMemoryDatabase!.entries);
    list.sort((a, b) {
      if (a.isFavorite && !b.isFavorite) return -1;
      if (!a.isFavorite && b.isFavorite) return 1;
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });
    return list;
  }

  @override
  Future<List<VaultEntry>> searchEntries(String query) async {
    _ensureUnlocked();
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return getEntries();

    final all = await getEntries();
    return all.where((entry) {
      final titleMatch = entry.title.toLowerCase().contains(q);
      final userMatch = entry.username.toLowerCase().contains(q);
      final siteMatch = entry.website.toLowerCase().contains(q);
      return titleMatch || userMatch || siteMatch;
    }).toList();
  }

  @override
  Future<VaultEntry?> getEntryById(String id) async {
    _ensureUnlocked();
    try {
      return _inMemoryDatabase!.entries.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> addEntry(VaultEntry entry) async {
    _ensureUnlocked();
    final updatedList = List<VaultEntry>.from(_inMemoryDatabase!.entries)
      ..add(entry);
    _inMemoryDatabase = VaultDatabase(
      version: _inMemoryDatabase!.version,
      updatedAt: DateTime.now(),
      entries: updatedList,
    );
    await _storage.saveVault(_inMemoryDatabase!, _activeVek!);
    SafeLogger.info('VaultRepository', 'New entry added to encrypted vault');
  }

  @override
  Future<void> updateEntry(VaultEntry entry) async {
    _ensureUnlocked();
    final list = List<VaultEntry>.from(_inMemoryDatabase!.entries);
    final index = list.indexWhere((e) => e.id == entry.id);
    if (index == -1) {
      throw const ValidationFailure('Entry not found');
    }
    list[index] = entry;
    _inMemoryDatabase = VaultDatabase(
      version: _inMemoryDatabase!.version,
      updatedAt: DateTime.now(),
      entries: list,
    );
    await _storage.saveVault(_inMemoryDatabase!, _activeVek!);
    SafeLogger.info('VaultRepository', 'Entry updated in encrypted vault');
  }

  @override
  Future<void> deleteEntry(String id) async {
    _ensureUnlocked();
    final list = List<VaultEntry>.from(_inMemoryDatabase!.entries)
      ..removeWhere((e) => e.id == id);
    _inMemoryDatabase = VaultDatabase(
      version: _inMemoryDatabase!.version,
      updatedAt: DateTime.now(),
      entries: list,
    );
    await _storage.saveVault(_inMemoryDatabase!, _activeVek!);
    SafeLogger.info('VaultRepository', 'Entry deleted and vault re-encrypted');
  }
}
