# VaultKey Security Threat Model (Version 1)

## 1. Overview
VaultKey is an offline, local-first password manager engineered with zero-knowledge cryptographic guarantees. The security perimeter assumes that the user's mobile device may be lost, stolen, inspected by forensic tools, or subjected to local tampering.

This threat model outlines the adversarial scenarios, potential impact, cryptographic mitigations, and realistic remaining limitations.

---

## 2. Threat Analysis Matrix

| Threat | Risk Level | Mitigation in VaultKey | Remaining Limitation |
| :--- | :--- | :--- | :--- |
| **1. Physical theft of device while locked** | High | Vault records are encrypted under a 256-bit CSPRNG Vault Encryption Key (VEK) using AES-256-GCM. The VEK is never stored unencrypted on disk; it is wrapped under a PIN-derived Key Encryption Key (PIN-KEK) using PBKDF2-HMAC-SHA256 (100,000 rounds). | An adversary with an electron microscope or state-level hardware memory freeze attacks immediately after locking could theoretically extract RAM fragments before power collapse. |
| **2. Adversary extracts local vault database file (`vaultkey_vault.enc`)** | High | Authenticated AES-256-GCM encryption with unique 96-bit random nonces for every database write. The file contains zero plaintext metadata, usernames, passwords, or URLs. | Offline brute-forcing of the database ciphertext requires discovering the 256-bit VEK ($2^{256}$ operations), which is computationally infeasible with present and projected computing architectures. |
| **3. Adversary obtains an exported encrypted backup (`.vault`)** | Medium-High | Backup files encapsulate only AES-256-GCM ciphertext along with VEK envelopes wrapped under the 24-word Master Recovery Key (256-bit entropy) and 3 custom questions (100k rounds KDF). No plaintext passwords, usernames, or notes exist in the backup. | If the user chose extremely predictable answers to all 3 recovery questions (e.g. single-letter answers), an adversary possessing the backup could attempt offline dictionary attacks against the questions KDF verifier. |
| **4. Adversary attempts to guess 6-digit PIN on device** | High | Exponential backoff rate limiting: 5 failed attempts trigger a 30-second lockout; 6 attempts trigger 60 seconds; 7+ attempts enforce a 300-second (5-minute) delay. PIN derivation uses PBKDF2 with 100,000 iterations. | Hardware emulation or platform-level bypassing of storage on rooted devices could allow offline cracking if the salt and wrapped VEK are dumped. |
| **5. Temporary physical access to an unlocked phone** | High | Configurable Auto-Lock policy (default 5 minutes, with 1-minute and Immediate options). Immediate locking on user backgrounding or manual trigger. Plaintext passwords remain masked behind dots by default until explicitly revealed. | If the attacker grabs the device while the vault is actively open and before the auto-lock timer elapses, they can view visible entries. |
| **6. Shoulder-surfing while password is revealed** | Medium | Passwords remain masked (`••••••••••••`) by default across all lists and detail views. Explicit eye-toggle required to view. Monospace fonts prevent character confusion. | Visual observation by third parties or CCTV cameras while the user intentionally reveals the password. |
| **7. Clipboard leakage / snooping** | Medium | Prominent "Copy Password" action triggers an automated 30-second background timer that overwrites the system clipboard with empty data. | On Android 13+, OS clipboard history trays or clipboard listener services installed before the 30-second timer expires may retain copied text. |
| **8. Malicious app inspecting screenshots / recent apps** | Medium | `FLAG_SECURE` window attribute is enabled in Android `MainActivity.kt`. Screenshots, screen recorders, and recent tasks multitasking thumbnails are blocked by the OS compositor. | Root exploits or custom ROMs with patched system compositors that ignore `FLAG_SECURE`. |
| **9. Tampering with or modifying local database / backup file** | High | AES-256-GCM enforces 128-bit Poly1305/GHASH authentication tags. Backup files include an additional SHA-256 integrity checksum over the entire ciphertext envelope. Any bit-flip or modification causes instant verification failure and aborts restoration. | Tampering renders the file unreadable; corrupted data cannot be salvaged without an uncorrupted replica. |
| **10. Corrupted or truncated backup file** | Medium | Strict schema validation and cryptographic MAC tag checking. Partial restorations are rejected; the engine refuses to restore corrupt fragments. | User must retain another uncorrupted backup. |
| **11. Forgotten 6-digit PIN** | Medium | Recovery system provides two independent zero-knowledge pathways: (A) 24-word Master Recovery Key, and (B) 3 custom recovery questions. Successful verification prompts the user to configure a new PIN and re-wraps the VEK. | If the user forgets their PIN AND loses their 24 words AND forgets their question answers, the vault cannot be decrypted. |
| **12. Forgotten security question answers** | Low | The 24-word Master Recovery Key remains available as an independent cryptographic fallback. | If user also loses the 24-word key, recovery is impossible. |
| **13. Lost 24-word recovery key** | Low | The user can still unlock via PIN or biometrics, or recover using their 3 custom questions. | If PIN is also forgotten and questions are lost, the vault is unrecoverable. |
| **14. Rooted device / compromised OS / kernel keyloggers** | Critical | Sensitive keys are isolated in Android Keystore / EncryptedSharedPreferences. | If the host operating system kernel is actively compromised with rootkit malware, memory scraping or keystroke interception at the input driver level cannot be fully mitigated by any user-space application. |

---

## 3. Cryptographic Boundary
- **Inside the Security Boundary**:
  - Vault Encryption Key (VEK) generated with CSPRNG (`Random.secure()`).
  - Key Encryption Keys (KEKs) derived via PBKDF2-HMAC-SHA256 (100,000 rounds) with per-device CSPRNG salts.
  - Authenticated encryption (AES-256-GCM) with 12-byte random nonces and 16-byte MAC tags.
  - Zero plaintext passwords or sensitive keys ever written to disk or system logs.
- **Outside the Security Boundary**:
  - The device hardware, CPU caches, and OS kernel memory management.
  - Third-party physical surveillance (cameras, optical shoulder-surfing).
  - Operating systems running unauthorized rootkits or compromised firmware.
