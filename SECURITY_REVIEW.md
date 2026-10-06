# VaultKey Comprehensive Security Review

## 1. Executive Summary
This document provides a rigorous, transparent security audit and verification record for **VaultKey (Version 1.0.0)**, an offline, local-first password manager engineered with zero-knowledge cryptographic safeguards.

VaultKey does not send credentials, encryption keys, or telemetry over the internet. All cryptographic operations occur on-device.

---

## 2. Cryptographic Specifications

| Component | Specification | Rationale & Configuration |
| :--- | :--- | :--- |
| **Authenticated Cipher** | **AES-256-GCM** | Hardware-accelerated, authenticated encryption with 128-bit MAC verification. 12-byte CSPRNG nonces generated per transaction. |
| **Key Derivation (KDF)** | **PBKDF2-HMAC-SHA256** | 100,000 iterations with 16-byte unique per-device CSPRNG salts. High computational hardness against brute-force attacks. |
| **Random Number Generator** | **CSPRNG** (`Random.secure()`) | Backed by OS platform entropy pools (`/dev/urandom` / `SecRandomCopyBytes`). |
| **Emergency Recovery Key** | **BIP-39 Mnemonic (24 Words)** | 256 bits of CSPRNG entropy with an 8-bit SHA-256 checksum byte. |
| **Question Answer Verifier** | **HMAC-SHA256** | Salted KDF derivation with constant-time equality checks (`CryptoService.constantTimeEquals`). |

---

## 3. Storage & Isolation

### 3.1 Sensitive Cryptographic Material
- All salts, wrapped Key Encryption Keys (KEKs), and question verifiers are persisted via `FlutterSecureStorage`, using Android's `EncryptedSharedPreferences` backed by the hardware **Android Keystore**.
- Plaintext keys or PINs are NEVER written to SharedPreferences, standard SQLite, or files.

### 3.2 Vault Database (`vaultkey_vault.enc`)
- The local database is serialized to JSON and encrypted using the 256-bit Vault Encryption Key (VEK) via AES-256-GCM.
- Forensic inspection confirms zero plaintext leakage of titles, usernames, passwords, websites, or notes.

---

## 4. Authentication & Protections

### 4.1 PIN Handling & Brute-Force Rate Limiting
- The user's 6-digit PIN is never stored.
- Failed attempts are tracked in secure storage.
- Rate-limiting policy:
  - 1–4 failed attempts: Immediate feedback.
  - 5 failed attempts: 30-second lockout.
  - 6 failed attempts: 60-second lockout.
  - 7+ failed attempts: 300-second (5-minute) exponential lockout.

### 4.2 Biometric Authentication
- Implemented via `local_auth` using the operating system's `BiometricPrompt`.
- The application never accesses, stores, or handles raw biometric data.
- Biometric unlock provides access to an enclave-wrapped key that unwraps the VEK. Fallback to PIN is always supported.

### 4.3 Auto-Lock & Lifecycle Security
- Default auto-lock timeout: 5 minutes (user configurable: Immediately, 1m, 5m, 15m).
- Inactivity timer resets on any user interaction.
- Application backgrounding triggers the auto-lock policy via `WidgetsBindingObserver`.
- Android `FLAG_SECURE` window attribute is enforced in `MainActivity.kt`, blocking screen recording, screenshots, and multitasking preview exposure.

### 4.4 Clipboard Protection
- Sensitive credentials copied to the clipboard initiate an automated 30-second background clearance timer (`ClipboardHelper`).
- Passwords are never surfaced in toasts, snackbars, or system notifications.

### 4.5 Safe Logging Policy
- Enforced through `SafeLogger`.
- All production log statements are audited. Under no circumstances are PINs, passwords, recovery words, or decrypted databases passed to `print()` or `debugPrint()`.

---

## 5. Backup & Recovery Integrity

### 5.1 Encrypted Backup Export (`.vault`)
- Encrypted backups package the raw AES-GCM ciphertext along with the wrapped key envelopes.
- Backups contain ZERO plaintext credentials.
- A SHA-256 cryptographic checksum covers the entire payload.

### 5.2 Tampering & Corruption Checks
- Automated integration tests verify that any bit-flip or payload alteration triggers an immediate `BackupFailure` and halts restoration.

---

## 6. Known Limitations & Security Boundary

No system is "100% secure". VaultKey explicitly delineates its security perimeter:
1. **Device Compromise / Root Access**: If an adversary obtains root access or runs kernel-level malware on the host operating system, memory scraping or driver-level keystroke logging cannot be prevented by any user-space app.
2. **Shoulder Surfing**: While passwords remain masked by default, visual observation while the user deliberately reveals a credential cannot be mitigated by software.
3. **OS Clipboard History Managers**: On devices running third-party clipboard loggers or custom ROMs that maintain an immutable history buffer, the 30-second clipboard clearing command may not clear third-party storage.
4. **Permanent Data Loss without Backup**: Because Version 1 is strictly local-first and zero-knowledge, loss of the physical phone without an exported `.vault` backup and recovery key results in permanent, irrecoverable data loss.
