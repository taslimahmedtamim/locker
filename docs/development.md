# VaultKey Development & Verification Guide

## 1. Prerequisites
- **Flutter SDK**: 3.47.6 or newer (stable channel)
- **Dart SDK**: 3.13.5 or newer
- **Java**: JDK 17 or JDK 21
- **Target OS**: Android (API Level 23+ recommended, API 21+ supported)

---

## 2. Setting Up the Environment

1. Ensure the Flutter binary is accessible in your environment:
   ```bash
   flutter doctor
   ```

2. Clone or open the workspace:
   ```bash
   cd d:\Vautlkey
   ```

3. Resolve dependencies:
   ```bash
   flutter pub get
   ```

---

## 3. Running Static Analysis & Code Formatting

VaultKey adheres to strict linting and zero-warning standards:

```bash
# Analyze all Dart source code
flutter analyze
# or
dart analyze

# Format code according to official Dart style
dart format .
```

---

## 4. Running the Automated Test Suite

The test suite covers cryptographic primitives, encrypted storage, zero-leakage assertions, and clean-install backup restoration:

```bash
# Run all tests
flutter test

# Run individual test modules
flutter test test/crypto_service_test.dart
flutter test test/encrypted_vault_storage_test.dart
flutter test test/backup_recovery_test.dart
flutter test test/widget_test.dart
```

---

## 5. Building the Android Application

To generate a release or debug APK:

```bash
# Build release APK
flutter build apk --release

# The output APK will be placed at:
# build/app/outputs/flutter-apk/app-release.apk
```

---

## 6. Manual QA Verification Checklist

1. **Onboarding**:
   - Launch app on fresh install -> Onboarding wizard displays.
   - Enter 6-digit PIN -> Confirm PIN -> Toggle Biometrics.
   - Configure 3 custom questions and answers.
   - Copy 24-word recovery key -> Verify checkbox -> Complete setup.
2. **Vault CRUD**:
   - Add new password (test password generator, length slider, entropy meter).
   - View password (confirm masked dots by default, toggle reveal).
   - Copy password -> Confirm toast appears -> Wait 30 seconds -> Confirm clipboard clears.
   - Edit entry -> Modify username or title -> Save -> Confirm updated.
   - Search -> Type keyword -> Confirm real-time filtering.
   - Delete entry -> Confirm warning dialog appears -> Delete -> Confirm removed.
3. **Auto-Lock & Biometrics**:
   - Tap "Simulate Vault Auto-Lock" in Settings or tap Lock icon on Main Vault.
   - Enter wrong PIN -> Verify error toast and dot reset.
   - Enter wrong PIN 5 times -> Verify lockout countdown.
   - Enter correct PIN -> Vault unlocks.
4. **Backup & Recovery**:
   - Settings -> Export Encrypted Vault -> Save `.vault` file.
   - Simulate device wipe or import on new device -> Restore with 24-word key -> Set new PIN.
   - Verify all saved accounts are present.
