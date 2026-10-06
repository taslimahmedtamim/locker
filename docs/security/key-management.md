# VaultKey Cryptographic Key Management Architecture

## 1. Key Hierarchy Specification

VaultKey implements a zero-knowledge key wrapping model to ensure that user credentials and personal notes remain encrypted at rest with authenticated encryption.

```
                              User Credentials / Entropies
   +--------------------+     +---------------------+     +--------------------+
   | 6-Digit User PIN   |     | Biometric Keystore  |     | 24-Word Recovery   |     | 3 Custom Questions |
   +--------------------+     +---------------------+     +--------------------+     +--------------------+
             |                          |                           |                          |
    PBKDF2-HMAC-SHA256          Hardware Key              PBKDF2-HMAC-SHA256          PBKDF2-HMAC-SHA256
      100,000 rounds             (Biometric)                100,000 rounds             100,000 rounds
             |                          |                           |                          |
             v                          v                           v                          v
      [ PIN-KEK 256 ]            [ Bio-KEK 256 ]             [ Rec-KEK 256 ]            [ Q&A-KEK 256 ]
             \                          |                           /                          /
              \                         |                          /                          /
               v                        v                         v                          v
       +-----------------------------------------------------------------------------------------+
       |                        Vault Encryption Key (VEK) [256-bit CSPRNG]                      |
       +-----------------------------------------------------------------------------------------+
                                                    |
                                       Authenticated Encryption
                                            (AES-256-GCM)
                                                    |
                                                    v
                                      +--------------------------+
                                      | Encrypted Local Vault    |
                                      | (`vaultkey_vault.enc`)   |
                                      +--------------------------+
```

---

## 2. Selection Rationale for Cryptographic Primitives

### 2.1 Authenticated Encryption: AES-256-GCM
- **Rationale**: AES-GCM (Galois/Counter Mode) is an NIST SP 800-38D standard authenticated cipher offering high throughput, hardware acceleration on ARM64 mobile chipsets, and intrinsic 128-bit authentication tags that detect tampering or bit-flipping immediately.
- **Parameters**:
  - Key size: 256 bits (32 bytes).
  - Initialization Vector (Nonce): 96 bits (12 bytes) uniquely sampled from CSPRNG for every encryption operation. Nonces are never reused.
  - Tag length: 128 bits (16 bytes).

### 2.2 Password-Based Key Derivation: PBKDF2-HMAC-SHA256
- **Rationale**: Standardized under RFC 8018 (PKCS #5 v2.1). Configured with **100,000 iterations**, generating substantial computational cost for brute-force attacks on mobile processors while maintaining responsive unlock times (< 300 ms on modern hardware).
- **Salt**: 128-bit (16-byte) CSPRNG unique random salt per device, preventing rainbow table attacks.

### 2.3 Entropy & Random Number Generation
- **Source**: `Random.secure()` backed by OS hardware entropy (`/dev/urandom` on Linux/Android and `SecRandomCopyBytes` on iOS/macOS).
- Used for all salts, nonces, passwords, and the 256-bit VEK.

### 2.4 Recovery Key Encoding: BIP-39 Standard
- Standard 2048-word English dictionary.
- 256 bits of entropy + 8-bit SHA256 checksum = 264 bits = 24 words $\times$ 11 bits.
- Guarantees typo detection and cross-platform compatibility.

---

## 3. Storage Separation

| Data Classification | Storage Medium | Protection Mechanism |
| :--- | :--- | :--- |
| **PIN Salt, KEK Salts** | Android Keystore / `FlutterSecureStorage` | OS-backed hardware enclave encryption |
| **Wrapped VEKs** | Android Keystore / `FlutterSecureStorage` | Encrypted with respective KEKs (AES-GCM) |
| **Question Verifier** | Android Keystore / `FlutterSecureStorage` | HMAC-SHA256 hash |
| **Vault Records & Database** | App Documents directory (`vaultkey_vault.enc`) | AES-256-GCM authenticated encryption |

---

## 4. In-Memory Security & Lifecycle

- When the application launches or unlocks:
  1. User authenticates via PIN, Biometrics, or Recovery.
  2. The corresponding KEK is derived.
  3. The wrapped VEK is decrypted and placed in RAM.
  4. The encrypted database is decrypted into memory.
- When the vault is locked (via auto-lock, backgrounding, or manual lock):
  1. The in-memory VEK byte array is actively overwritten with zeros (`0x00`).
  2. The in-memory database object reference is released for garbage collection.
  3. State providers transition to `AuthStatus.locked`.
