# 🔐 Locker — Simple, Private & Secure Password Vault

<div align="center">

  <h3>Peace of mind, crafted in complete privacy.</h3>
  <p>An offline, zero-knowledge mobile password manager engineered to keep your passwords safe, private, and always in your control.</p>

  <p>
    <strong>👤 Creator & Lead Developer:</strong> <strong>Taslim Ahmed Tamim</strong>
  </p>

  <p>
    <a href="https://github.com/taslimahmedtamim/locker/releases"><img src="https://img.shields.io/badge/Download-Locker.apk-blue?style=for-the-badge&logo=android" alt="Download APK" /></a>
    <img src="https://img.shields.io/badge/Platform-Android-green?style=for-the-badge&logo=flutter" alt="Platform Android" />
    <img src="https://img.shields.io/badge/Privacy-100%25%20Offline-orange?style=for-the-badge" alt="100% Offline" />
    <img src="https://img.shields.io/badge/Security-AES--256--GCM-red?style=for-the-badge" alt="AES-256-GCM" />
  </p>

</div>

---

## 📖 What is Locker? (In Plain English)

Think of **Locker** as a **personal digital safe inside your phone**. 

In today's world, we have dozens of passwords for email, banking, social media, and work. Many people either use the same weak password everywhere, or trust cloud companies with their master passwords.

**Locker solves this problem without needing the internet:**
- Everything is stored **locally on your device**.
- There are **no servers, no cloud databases, and no trackers**.
- Your passwords are locked behind **bank-grade encryption (AES-256)** that only **you** can open with your **PIN or Fingerprint**.

---

## ✨ Why You’ll Love Locker

| What You Need | How Locker Helps You |
| :--- | :--- |
| **Complete Privacy** | 🛡️ **100% Offline.** Locker never connects to the internet. Nobody can hack, leak, or sell your data because it never leaves your physical phone. |
| **Military-Grade Security** | 🔒 **AES-256-GCM Encryption.** The same standard used by global banks and security agencies. |
| **Quick & Convenient** | 👆 **Fingerprint & Face Unlock.** Access your passwords in one tap using your phone's biometric sensor. |
| **Never Get Locked Out** | 🆘 **Two Recovery Options.** Forgot your PIN? Restore your vault safely using your **24-word recovery phrase** or your **secret security questions**. |
| **Strong Passwords Fast** | 🎲 **Built-in Password Generator.** Create strong, uncrackable passwords of any length with one click. |
| **Clipboard Protection** | ⏱️ **Auto-Clear Copy.** When you copy a password, Locker automatically wipes it from your clipboard after 30 seconds so other apps can't snoop. |
| **Spy-Proof Display** | 🚫 **Anti-Screenshot Shield.** The app automatically blocks screenshots and screen recording, protecting your secrets from malicious apps. |
| **Easy Phone Transfer** | 💾 **Encrypted Backup.** Export an encrypted backup file whenever you want to switch or backup to a new phone. |
| **Beautiful Dark & Light Modes** | 🎨 **Eye-Friendly Design.** High-contrast, elegant design that's easy to read in both bright sunlight and dark rooms. |

---

## 🚀 How It Works (3 Easy Steps)

```
[ Step 1: Setup ] ───> [ Step 2: Save Passwords ] ───> [ Step 3: Fast & Safe Login ]
Set 6-digit PIN &       Add your accounts, emails       Search & copy passwords
save 24-word backup      & generate strong passwords     with auto-clearing clipboard
```

1. **First-Time Setup (30 seconds):**
   * Choose a 6-digit PIN.
   * Enable Fingerprint / Face Unlock for fast access.
   * Save your **24-Word Recovery Phrase** (or set security questions) in case you ever forget your PIN.
2. **Add & Organize:**
   * Tap `+` to add an account (e.g., Google, Netflix, Bank).
   * Type your password or tap **Generate** to create a strong one automatically.
3. **Copy & Use:**
   * Search any account instantly.
   * Tap copy — paste it into your login screen — and Locker wipes your clipboard automatically after 30 seconds.

---

## 🔑 What Happens If You Forget Your PIN?

Unlike cloud services that require email resets (which can be hacked), Locker gives you two offline recovery methods:

1. **Option A: 24-Word Recovery Phrase + PIN**  
   Use your secret 24-word phrase to securely restore your vault. Because it is cryptographically paired with your PIN, anyone who accidentally finds your word list cannot unlock your vault without your PIN.
2. **Option B: Secret Security Questions**  
   If you ever forget your PIN, you can answer the 3 personal security questions you created during setup to reset your PIN and regain entry immediately.

---

## 📱 App Highlights & Features Walkthrough

### 1. 🛡️ Main Vault & Fast Search
* View all your accounts in a clean, alphabetical list.
* Search instantly by website name, app title, or username/email.
* Passwords stay masked with dots (`••••••••`) until you tap to view or copy.

### 2. 🎲 Built-in Password Generator
* Choose password length (12 to 32 characters).
* Toggle uppercase letters, numbers, and symbols.
* Live strength meter shows how secure your password is.

### 3. ⏱️ Auto-Lock & Brute Force Protection
* Choose when the app locks automatically (Immediately, 1 min, 5 min, or 15 min).
* If someone tries guessing your PIN repeatedly, Locker locks them out with increasing delays (30 seconds, 1 minute, 5 minutes).

### 4. 💾 Backup & Restore
* **Export Backup:** Creates an encrypted `.vault` file on your phone.
* **Import Backup:** Restore all your accounts on a new phone with 1 tap.

---

## 🛠️ Technical Details (For Developers & Engineers)

For developers curious about how Locker is built under the hood:

### Tech Stack
- **Framework:** [Flutter](https://flutter.dev) (v3.47.6 / Dart 3.13.5) with Material 3
- **State Management:** [Riverpod](https://pub.dev/packages/flutter_riverpod)
- **Encryption:** [`cryptography`](https://pub.dev/packages/cryptography) (AES-256-GCM, PBKDF2-HMAC-SHA256 with 100,000 iterations)
- **Key Storage:** [`flutter_secure_storage`](https://pub.dev/packages/flutter_secure_storage) (Android Keystore / Hardware-backed enclave)
- **Biometrics:** [`local_auth`](https://pub.dev/packages/local_auth)
- **Typography:** Google Fonts (`Manrope` & `JetBrains Mono`)

### Cryptographic Key Derivation Flow
```
User PIN ───────(PBKDF2 100,000 rounds)──> PIN-KEK ──(AES-GCM Wrap)──┐
Biometrics ─────(Android Keystore)────────> Bio-KEK ──(AES-GCM Wrap)──┼──> [ 256-bit Vault Key ] ──(AES-256-GCM)──> Vault File
24 Recovery Words ──(PBKDF2 100k)────────> Rec-KEK ──(AES-GCM Wrap)──┤
Security Q&A ───(PBKDF2 100k)────────────> Q&A-KEK ──(AES-GCM Wrap)──┘
```

### Folder Structure
```
lib/
├── app/                  # Riverpod providers & theme configuration
├── core/
│   ├── crypto/           # AES-256-GCM, PBKDF2, CSPRNG algorithms
│   ├── storage/          # Keystore & encrypted file storage
│   └── utils/            # BIP-39 wordlist, clipboard helpers, safe logger
├── features/
│   ├── auth/             # PIN pad & biometric authentication
│   ├── onboarding/       # Setup wizard & recovery configuration
│   ├── password_generator/# Password generator dialog & entropy calculator
│   ├── recovery/         # 24-word and security question recovery flows
│   ├── settings/         # Theme switcher, auto-lock, backup export/import
│   └── vault/            # Account list, add/edit form, password viewer
├── models/               # Vault database & entry data models
├── repositories/         # Local database repository implementation
└── services/             # Auth, recovery, and backup management services
```

---

## 💻 How to Build From Source

### Prerequisites
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (3.24+ recommended)
- Android Studio / VS Code with Flutter extension
- Java JDK 17

### Steps
1. **Clone the repository:**
   ```bash
   git clone https://github.com/taslimahmedtamim/locker.git
   cd locker
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run code analyzer & unit tests:**
   ```bash
   dart analyze
   flutter test
   ```

4. **Run on an Android device or emulator:**
   ```bash
   flutter run
   ```

5. **Build the release APK:**
   ```bash
   flutter build apk --release
   ```
   The APK will be generated at `build/app/outputs/flutter-apk/app-release.apk`.

---

## 👤 Author & Credits

* **Creator & Lead Architect:** **Taslim Ahmed Tamim**  
* **GitHub:** [@taslimahmedtamim](https://github.com/taslimahmedtamim)  
* **Repository:** [github.com/taslimahmedtamim/locker](https://github.com/taslimahmedtamim/locker)

---

## 📄 License
This project is open-source. See the repository for details.
