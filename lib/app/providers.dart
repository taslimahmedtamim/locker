import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/crypto/crypto_service.dart';
import '../core/error/failures.dart';
import '../core/storage/encrypted_vault_storage.dart';
import '../core/storage/secure_key_store.dart';
import '../core/utils/safe_logger.dart';
import '../models/vault_entry.dart';
import '../repositories/vault_repository.dart';
import '../services/auth_service.dart';
import '../services/backup_service.dart';
import '../services/recovery_service.dart';

// Low-level Singletons
final cryptoServiceProvider = Provider<CryptoService>((ref) => CryptoService());

final secureKeyStoreProvider = Provider<SecureKeyStore>(
  (ref) => PlatformSecureKeyStore(),
);

final encryptedVaultStorageProvider = Provider<EncryptedVaultStorage>((ref) {
  final crypto = ref.watch(cryptoServiceProvider);
  return LocalEncryptedVaultStorage(crypto: crypto);
});

final authServiceProvider = Provider<AuthService>((ref) {
  final crypto = ref.watch(cryptoServiceProvider);
  final keyStore = ref.watch(secureKeyStoreProvider);
  return AuthService(crypto: crypto, keyStore: keyStore);
});

final recoveryServiceProvider = Provider<RecoveryService>((ref) {
  final crypto = ref.watch(cryptoServiceProvider);
  final keyStore = ref.watch(secureKeyStoreProvider);
  final authService = ref.watch(authServiceProvider);
  return RecoveryService(
    crypto: crypto,
    keyStore: keyStore,
    authService: authService,
  );
});

final vaultRepositoryProvider = Provider<VaultRepository>((ref) {
  final storage = ref.watch(encryptedVaultStorageProvider);
  return LocalVaultRepository(storage: storage);
});

final backupServiceProvider = Provider<BackupService>((ref) {
  final storage = ref.watch(encryptedVaultStorageProvider);
  final keyStore = ref.watch(secureKeyStoreProvider);
  final recoveryService = ref.watch(recoveryServiceProvider);
  final crypto = ref.watch(cryptoServiceProvider);
  return BackupService(
    storage: storage,
    keyStore: keyStore,
    recoveryService: recoveryService,
    crypto: crypto,
  );
});

// Theme Mode Provider (Light, Dark, System)
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  final SecureKeyStore _keyStore;
  ThemeModeNotifier(this._keyStore) : super(ThemeMode.system) {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final val = await _keyStore.read('vaultkey_theme_mode');
    if (val == 'light') state = ThemeMode.light;
    if (val == 'dark') state = ThemeMode.dark;
    if (val == 'system') state = ThemeMode.system;
  }

  Future<void> setTheme(ThemeMode mode) async {
    state = mode;
    final val = mode == ThemeMode.light
        ? 'light'
        : (mode == ThemeMode.dark ? 'dark' : 'system');
    await _keyStore.write('vaultkey_theme_mode', val);
  }
}

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((
  ref,
) {
  final keyStore = ref.watch(secureKeyStoreProvider);
  return ThemeModeNotifier(keyStore);
});

// App / Auth Status
enum AuthStatus { checking, onboardingRequired, locked, unlocked }

class AuthState {
  final AuthStatus status;
  final String? errorMessage;
  final int lockoutSeconds;
  final bool biometricAvailable;

  const AuthState({
    required this.status,
    this.errorMessage,
    this.lockoutSeconds = 0,
    this.biometricAvailable = false,
  });

  AuthState copyWith({
    AuthStatus? status,
    String? errorMessage,
    int? lockoutSeconds,
    bool? biometricAvailable,
  }) {
    return AuthState(
      status: status ?? this.status,
      errorMessage: errorMessage,
      lockoutSeconds: lockoutSeconds ?? this.lockoutSeconds,
      biometricAvailable: biometricAvailable ?? this.biometricAvailable,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _authService;
  final VaultRepository _vaultRepo;
  Timer? _autoLockTimer;

  AuthNotifier(this._authService, this._vaultRepo)
    : super(const AuthState(status: AuthStatus.checking)) {
    checkInitialState();
  }

  Future<void> checkInitialState() async {
    try {
      final hasVault = await _authService.hasVault();
      if (!hasVault) {
        state = const AuthState(status: AuthStatus.onboardingRequired);
        return;
      }

      final bioEnabled = await _authService.isBiometricEnabled();
      state = AuthState(
        status: AuthStatus.locked,
        biometricAvailable: bioEnabled,
      );

      // Attempt biometric unlock automatically if enabled
      if (bioEnabled) {
        await unlockWithBiometrics();
      }
    } catch (e) {
      state = const AuthState(status: AuthStatus.onboardingRequired);
    }
  }

  Future<bool> unlockWithPin(String pin) async {
    try {
      state = state.copyWith(errorMessage: null);
      final vek = await _authService.unlockWithPin(pin);
      await _vaultRepo.unlock(vek);
      state = const AuthState(status: AuthStatus.unlocked);
      _resetAutoLockTimer();
      return true;
    } on LockoutFailure catch (e) {
      state = state.copyWith(
        errorMessage: e.message,
        lockoutSeconds: e.remainingSeconds,
      );
      return false;
    } on Failure catch (e) {
      state = state.copyWith(errorMessage: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Unable to unlock vault');
      return false;
    }
  }

  Future<bool> unlockWithBiometrics() async {
    try {
      state = state.copyWith(errorMessage: null);
      final vek = await _authService.unlockWithBiometrics();
      await _vaultRepo.unlock(vek);
      state = const AuthState(status: AuthStatus.unlocked);
      _resetAutoLockTimer();
      return true;
    } catch (e) {
      SafeLogger.warn(
        'AuthNotifier',
        'Biometric prompt cancelled or unavailable',
      );
      // Remains locked on biometric cancel, user can type PIN
      return false;
    }
  }

  void recordUserActivity() {
    _resetAutoLockTimer();
  }

  Future<void> _resetAutoLockTimer() async {
    _autoLockTimer?.cancel();
    if (state.status != AuthStatus.unlocked) return;

    final minutes = await _authService.getAutoLockMinutes();
    if (minutes == 0) return; // Immediate lock handled by lifecycle

    _autoLockTimer = Timer(Duration(minutes: minutes), () {
      lockVault();
    });
  }

  void lockVault() {
    _autoLockTimer?.cancel();
    _vaultRepo.lock();
    _authService.isBiometricEnabled().then((bio) {
      state = AuthState(status: AuthStatus.locked, biometricAvailable: bio);
    });
    SafeLogger.info(
      'AuthNotifier',
      'Vault locked via auto-lock/manual trigger',
    );
  }

  void completeOnboarding(Uint8List vek) {
    _vaultRepo.unlock(vek);
    state = const AuthState(status: AuthStatus.unlocked);
    _resetAutoLockTimer();
  }

  @override
  void dispose() {
    _autoLockTimer?.cancel();
    super.dispose();
  }
}

final authStateProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final authService = ref.watch(authServiceProvider);
  final vaultRepo = ref.watch(vaultRepositoryProvider);
  return AuthNotifier(authService, vaultRepo);
});

// Vault Entries List Provider
class VaultListNotifier extends StateNotifier<AsyncValue<List<VaultEntry>>> {
  final VaultRepository _repository;
  String _currentQuery = '';

  VaultListNotifier(this._repository) : super(const AsyncValue.loading()) {
    refresh();
  }

  Future<void> refresh() async {
    if (!_repository.isUnlocked) {
      state = const AsyncValue.data([]);
      return;
    }
    try {
      state = const AsyncValue.loading();
      final items = _currentQuery.isEmpty
          ? await _repository.getEntries()
          : await _repository.searchEntries(_currentQuery);
      state = AsyncValue.data(items);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void search(String query) {
    _currentQuery = query;
    refresh();
  }

  Future<void> addEntry(VaultEntry entry) async {
    await _repository.addEntry(entry);
    await refresh();
  }

  Future<void> updateEntry(VaultEntry entry) async {
    await _repository.updateEntry(entry);
    await refresh();
  }

  Future<void> deleteEntry(String id) async {
    await _repository.deleteEntry(id);
    await refresh();
  }
}

final vaultListProvider =
    StateNotifierProvider<VaultListNotifier, AsyncValue<List<VaultEntry>>>((
      ref,
    ) {
      final repo = ref.watch(vaultRepositoryProvider);
      return VaultListNotifier(repo);
    });
