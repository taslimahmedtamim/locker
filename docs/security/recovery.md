# VaultKey Emergency Recovery Architecture

## 1. Overview & Security Philosophy
VaultKey is an offline, local-first password vault. Because Version 1 does not rely on any remote servers, cloud accounts, or third-party identity providers, lost credentials cannot be reset via email or SMS. 

To protect against forgotten PINs while maintaining absolute zero-knowledge security, VaultKey implements a multi-tier cryptographic key wrapping architecture.

Under no circumstances is the local vault decrypted by a weak backdoor, plaintext storage, or static master password. Instead, the single cryptographic master key responsible for vault encryption—the **Vault Encryption Key (VEK)**—is securely wrapped (encrypted) under separate independent Key Encryption Keys (KEKs).

---

## 2. Key Hierarchy & Wrapping Model

```
                     +---------------------------------------+
                     | Vault Encryption Key (VEK)            |
                     | 256-bit CSPRNG Secret (Cryptographic)  |
                     +---------------------------------------+
                                         |
     +-------------------+---------------+-------------------+--------------------+
     |                   |                                   |                    |
     v                   v                                   v                    v
+---------+        +-----------+                      +--------------+     +--------------+
| PIN-KEK |        |  Bio-KEK  |                      | Recovery-KEK |     |  Q&A-KEK     |
+---------+        +-----------+                      +--------------+     +--------------+
     ^                   ^                                   ^                    ^
     |                   |                                   |                    |
  User PIN           Biometric                           24-Word              3 Custom
 (PBKDF2/           Credential                         Recovery Key          Q&A Answers
 Argon2id)          (Keystore)                         (BIP-39/CSPRNG)       (Normalized
                                                                             + Salted KDF)
```

### 2.1 The Vault Encryption Key (VEK)
- A 256-bit (32-byte) cryptographically secure random value generated via platform CSPRNG (`Random.secure()`).
- All vault records (passwords, usernames, URLs, notes) are encrypted using AES-256-GCM authenticated encryption under this VEK.
- The VEK is never written to disk in unencrypted form.
- The VEK is loaded into memory only while the vault is unlocked, and cleared upon auto-lock or manual lock.

### 2.2 Mechanism A: Master Recovery Key (Emergency Key)
- During initial vault setup, a 256-bit random entropy seed is generated.
- The seed is converted into a 24-word human-readable mnemonic phrase using the BIP-39 standard wordlist.
- From this mnemonic phrase, a `Recovery-KEK` is derived using PBKDF2-HMAC-SHA256 (with a unique per-device salt and 100,000 rounds).
- The `VEK` is wrapped with `Recovery-KEK` using AES-256-GCM:
  $$\text{WrappedVEK}_{\text{rec}} = \text{AES-GCM-Encrypt}(\text{Recovery-KEK}, \text{Nonce}_{\text{rec}}, \text{VEK})$$
- The user is instructed to write down or print the 24 words and store them securely offline.
- When unlocking via Recovery Key:
  1. User enters the 24 words.
  2. The application derives `Recovery-KEK`.
  3. `WrappedVEK_{\text{rec}}` is decrypted and authenticated. If the authentication tag fails (wrong words or typo), decryption is rejected immediately.
  4. Upon successful decryption, the VEK is recovered into memory.
  5. The user is prompted to configure a new 6-digit PIN. The VEK is re-wrapped with the new `PIN-KEK`, preserving all existing vault entries without data loss.

### 2.3 Mechanism B: Custom Recovery Questions
Human answers have substantially lower entropy than 256-bit cryptographic keys. Therefore, recovery questions are treated with extreme care:
- **User-Defined Questions**: Users write three of their own distinct questions; generic, easily researched prompts (e.g. "Mother's maiden name", "High school mascot") are strongly discouraged in the UI guidance.
- **Normalization Engine**:
  1. Trim leading and trailing whitespace.
  2. Normalize Unicode (NFKC) and convert all characters to lowercase.
  3. Collapse multiple internal whitespace characters to a single space.
  4. Strip standard punctuation (`.,!?-:;'"()[]`).
- **Composite Answer Construction**:
  $$\text{Composite} = \text{norm}(A_1) \parallel \text{"|"}\parallel \text{norm}(A_2) \parallel \text{"|"}\parallel \text{norm}(A_3)$$
- **Key Derivation (Q&A-KEK)**:
  $$\text{Q\&A-KEK} = \text{PBKDF2-HMAC-SHA256}(\text{password}=\text{Composite}, \text{salt}=\text{Salt}_{QA}, \text{iterations}=100{,}000, \text{length}=32)$$
- **Answer Verifier**:
  To protect against unauthenticated trial-and-error without exposing raw answers:
  $$\text{Verifier}_{QA} = \text{HMAC-SHA256}(\text{Q\&A-KEK}, \text{"vaultkey-recovery-qa-verifier-v1"})$$
  Only the salted `Verifier_{QA}`, `Salt_{QA}`, and `WrappedVEK_{QA}` are persisted.
- **VEK Wrapping**:
  $$\text{WrappedVEK}_{QA} = \text{AES-GCM-Encrypt}(\text{Q\&A-KEK}, \text{Nonce}_{QA}, \text{VEK})$$
- **Rate Limiting & Anti-Brute-Force**:
  Exponential backoff delays are enforced after 3 incorrect recovery attempts, preventing local automated dictionary attacks on answers.

---

## 3. Threat Mitigation in Recovery
| Potential Attack Vector | Mitigation in VaultKey |
| :--- | :--- |
| Attacker extracts database and reads answers | Recovery answers are never stored in plaintext. Only a salted 100,000-round KDF verifier exists. |
| Attacker guesses 1 question | Key derivation requires all 3 answers concatenated in order. Missing 1 answer breaks the KEK derivation. |
| Attacker tampers with wrapped VEK | AES-256-GCM uses a 128-bit authentication tag. Any tampering triggers tag verification failure. |
| User makes typo in recovery key | BIP-39 checksum validates the mnemonic phrase before attempting cryptographic decryption. |
