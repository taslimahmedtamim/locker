# Locker — Local-First Secure Password Vault

<div align="center">
  <h3>Peace of mind, crafted in privacy.</h3>
  <p>A single-person, zero-knowledge offline password manager engineered for simplicity and institutional-grade security.</p>
  <p><strong>Creator & Lead Architect:</strong> Taslim Ahmed Tamim</p>
</div>

---

## 1. What is Locker?
Locker is an offline, local-first mobile password manager tailored for users who value absolute privacy and simplicity. It dispenses with cybersecurity cliches in favor of an editorial, calming aesthetic faithful to the approved **Google Stitch** design system.

### Key Highlights
- **100% Local-Only**: Zero cloud reliance, zero external backend, zero analytics, zero trackers. Your credentials never leave your hardware enclave.
- **Zero-Knowledge Architecture**: The vault is encrypted under a 256-bit Vault Encryption Key (VEK) generated with cryptographically secure randomness (`Random.secure()`).
- **Authenticated Encryption**: Uses industry-standard **AES-256-GCM** to ensure confidentiality and tamper detection.
- **Two-Factor 24-Word Recovery**: 24-word recovery derivation is cryptographically bound to your PIN, preventing anyone who finds the 24 words from decrypting your vault without your PIN.
- **Security Questions Fallback**: If you forget your PIN, you can restore access via custom security questions protected with 100,000-round PBKDF2 derivation.
- **Encrypted Backup & Portability**: Export and import tamper-proof `.vault` backup files across devices without exposing plaintext credentials.

---

## 2. Features

| Feature | Description |
| :--- | :--- |
| **First-Run Onboarding** | Step-by-step wizard: Welcome -> Create PIN -> Confirm PIN -> Enable Biometrics -> Custom Recovery Questions -> 24-Word Recovery Key -> Vault Created. |
| **Biometric Authentication** | OS `BiometricPrompt` (Fingerprint / Face ID) with seamless fallback to 6-digit PIN. |
| **Brute-Force Rate Limiting** | Exponential backoff lockout delays (30s, 60s, 300s) after repeated failed PIN attempts. |
| **Main Vault & Search** | Real-time local search across account titles, usernames/emails, and websites. Passwords are never displayed as plaintext in lists. |
| **Password Generator** | CSPRNG password generator (12–32 characters, configurable charsets, 4-bar entropy meter). |
| **Clipboard Auto-Clear** | Prominent copy action with an automatic 30-second background clearance timer to protect system clipboard. |
| **Auto-Lock Policy** | Configurable auto-lock timer (Immediately, 1m, 5m, 15m) on inactivity or app backgrounding. |
| **Screen Protection** | Android `FLAG_SECURE` window attribute prevents screenshots, screen recording, and multitasking switcher previews. |
| **Appearance** | Light, Dark, and System theme modes matching the Google Stitch editorial design tokens. |

---

## 3. Technology Stack

- **Framework**: [Flutter](https://flutter.dev) (v3.47.6 / Dart 3.13.5) with Material 3
- **State Management**: [Riverpod](https://pub.dev/packages/flutter_riverpod) (Separated Auth, Vault, Theme, and Backup providers)
- **Cryptography**: [`cryptography`](https://pub.dev/packages/cryptography) (AES-256-GCM, PBKDF2-HMAC-SHA256, CSPRNG) & [`crypto`](https://pub.dev/packages/crypto)
- **Secure Key Storage**: [`flutter_secure_storage`](https://pub.dev/packages/flutter_secure_storage) (Android Keystore / EncryptedSharedPreferences)
- **Biometrics**: [`local_auth`](https://pub.dev/packages/local_auth) (Platform native biometric prompt)
- **Typography**: [Google Fonts](https://pub.dev/packages/google_fonts) (`Manrope` for editorial clarity and `JetBrains Mono` for masked keys and passwords)

---

## 4. Project Structure

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

## 5. Security Architecture

### Key Hierarchy
```
User PIN ──(PBKDF2 100k)──> PIN-KEK ──(AES-GCM Wrap)──> [ Vault Encryption Key ] ──(AES-256-GCM)──> Encrypted Vault
Biometrics ──(Keystore)───> Bio-KEK ──(AES-GCM Wrap)──> [    (256-bit CSPRNG)   ]
24 Words ──(PBKDF2 100k)──> Rec-KEK ──(AES-GCM Wrap)──> [                      ]
3 Questions ─(PBKDF2)─────> Q&A-KEK ──(AES-GCM Wrap)──> [                      ]
```

- For detailed specifications, see:
  - [docs/security/threat-model.md](file:///d:/Vautlkey/docs/security/threat-model.md)
  - [docs/security/key-management.md](file:///d:/Vautlkey/docs/security/key-management.md)
  - [docs/security/recovery.md](file:///d:/Vautlkey/docs/security/recovery.md)
  - [SECURITY_REVIEW.md](file:///d:/Vautlkey/SECURITY_REVIEW.md)

---

## 6. How to Build & Test

### Dependencies
Dependencies are managed via `pubspec.yaml`. To install:
```bash
flutter pub get
```

### Static Analysis & Lints
```bash
dart analyze
```

### Run Tests
```bash
flutter test
```

### Build APK
```bash
flutter build apk --release
```

---

## 7. Known Limitations (Version 1)
1. **Device-Bound**: Version 1 is strictly offline. If the phone is permanently lost without an exported `.vault` backup file and recovery key, data cannot be recovered.
2. **Root Compromise**: If the underlying Android OS is rooted with malicious kernel software, user-space memory protection cannot be guaranteed.

---

## 8. Future Roadmap (Version 2)
The repository architecture (`VaultRepository`) is designed as an abstraction to allow future cloud synchronization:
- Client-side end-to-end encrypted sync payloads.
- Multi-device syncing across Android, iOS, and desktop companions.
- Zero-knowledge remote encrypted backups.
