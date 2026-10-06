# VaultKey System Architecture

## 1. Architectural Philosophy
VaultKey is architected using clean layer separation, repository pattern abstraction, and reactive state management via **Riverpod**.

The interface layer never interacts directly with cryptographic primitives, file systems, or database drivers. This decouples business logic from platform specifics, ensuring portability across Android and iOS, and laying the exact foundation required for future zero-knowledge cloud synchronization without needing to refactor the UI.

---

## 2. Layered Architecture

```
+-----------------------------------------------------------+
|                        UI LAYER                           |
|  - MainVaultScreen     - LockScreen       - Settings      |
|  - AddEditPassword     - PasswordSheet    - Onboarding    |
+-----------------------------------------------------------+
                             |
                             v
+-----------------------------------------------------------+
|                   STATE MANAGEMENT                        |
|  - AuthNotifier        - VaultListNotifier                |
|  - ThemeModeNotifier   - ClipboardHelper                  |
+-----------------------------------------------------------+
                             |
                             v
+-----------------------------------------------------------+
|                   REPOSITORY LAYER                        |
|  - VaultRepository (Abstract Interface)                  |
|  - LocalVaultRepository (Memory zeroing & Cache)          |
|  - [Future] CloudVaultRepository                          |
+-----------------------------------------------------------+
                             |
                             v
+-----------------------------------------------------------+
|                    SERVICE LAYER                          |
|  - AuthService         - RecoveryService                  |
|  - BackupService       - CryptoService                    |
+-----------------------------------------------------------+
                             |
                             v
+-----------------------------------------------------------+
|                    STORAGE LAYER                          |
|  - SecureKeyStore (Android Keystore / SecureStorage)      |
|  - EncryptedVaultStorage (File IO / AES-256-GCM)          |
+-----------------------------------------------------------+
```

---

## 3. Directory Layout

```
lib/
├── app/
│   ├── providers.dart           # Riverpod state providers and notifiers
│   └── theme.dart               # Stitch design tokens, typography, and theme
├── core/
│   ├── crypto/
│   │   └── crypto_service.dart  # AES-256-GCM, PBKDF2, CSPRNG generator
│   ├── error/
│   │   └── failures.dart        # Strongly-typed domain failures
│   ├── storage/
│   │   ├── secure_key_store.dart       # Keystore-backed key storage
│   │   └── encrypted_vault_storage.dart # AES-GCM encrypted database IO
│   └── utils/
│       ├── bip39_words.dart     # BIP-39 mnemonic phrase utility
│       ├── clipboard_helper.dart # Clipboard auto-clear controller
│       └── safe_logger.dart     # Zero-leakage safe logging utility
├── features/
│   ├── auth/
│   │   └── lock_screen.dart     # Stitch UI PIN pad & biometric challenge
│   ├── onboarding/
│   │   └── onboarding_screen.dart # Step-by-step first-run wizard
│   ├── password_generator/
│   │   └── password_generator_sheet.dart # Entropy meter & CSPRNG generator
│   ├── recovery/
│   │   └── recovery_screen.dart # Emergency recovery with words or questions
│   ├── settings/
│   │   └── settings_screen.dart # Stitch settings & backup export/import
│   └── vault/
│       ├── add_edit_password_screen.dart # Form for credentials
│       ├── main_vault_screen.dart        # Search, hero card, account list
│       └── password_details_sheet.dart   # Obfuscated detail & copy
├── models/
│   ├── vault_database.dart      # Database collection & serialization
│   └── vault_entry.dart         # Vault record data model
├── repositories/
│   └── vault_repository.dart    # Abstract interface & local implementation
├── services/
│   ├── auth_service.dart        # Authentication, lockout, and PIN logic
│   ├── backup_service.dart      # .vault backup export, integrity, restore
│   └── recovery_service.dart    # Zero-knowledge key unwrapping
└── main.dart                    # App bootstrap & lifecycle observer
```

---

## 4. Future Cloud Synchronization Architecture (Version 2 Readiness)

Version 1 is strictly local-only. However, `VaultRepository` is designed as an abstract interface:

```dart
abstract class VaultRepository {
  Future<List<VaultEntry>> getEntries();
  Future<void> addEntry(VaultEntry entry);
  Future<void> updateEntry(VaultEntry entry);
  Future<void> deleteEntry(String id);
  ...
}
```

In Version 2, a `CloudVaultRepository` can implement this same interface:
1. Local changes will be encrypted with the client-side VEK.
2. The encrypted diff payload will be synced to an end-to-end encrypted remote store.
3. The remote backend will never receive plaintext passwords, PINs, or master keys.
4. The UI components will remain unchanged.
