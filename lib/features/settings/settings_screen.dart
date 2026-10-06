import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';

/// Settings screen faithfully matching the Google Stitch UI/UX design.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _biometricEnabled = false;
  int _autoLockMinutes = 5;
  List<String> _configuredQuestions = [];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final authService = ref.read(authServiceProvider);
    final bio = await authService.isBiometricEnabled();
    final mins = await authService.getAutoLockMinutes();
    final questions = await authService.getStoredQuestions();

    if (mounted) {
      setState(() {
        _biometricEnabled = bio;
        _autoLockMinutes = mins;
        _configuredQuestions = questions;
      });
    }
  }

  Future<void> _toggleBiometrics(bool value) async {
    final authService = ref.read(authServiceProvider);
    final vaultRepo = ref.read(vaultRepositoryProvider);

    if (value) {
      if (vaultRepo.activeVek != null) {
        await authService.enableBiometricUnlock(vaultRepo.activeVek!);
        setState(() => _biometricEnabled = true);
      }
    } else {
      await authService.disableBiometricUnlock();
      setState(() => _biometricEnabled = false);
    }
  }

  void _showAutoLockModal() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppTheme.darkCard : AppTheme.lightCard;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppTheme.radiusSheet),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkOutline : AppTheme.lightOutline,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Auto-Lock Timer',
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Lock vault automatically after period of inactivity',
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 13,
                color: isDark
                    ? AppTheme.darkTextMuted
                    : AppTheme.lightTextMuted,
              ),
            ),
            const SizedBox(height: 16),
            _buildAutoLockOption('Immediately', 0),
            _buildAutoLockOption('1 minute', 1),
            _buildAutoLockOption('5 minutes', 5),
            _buildAutoLockOption('15 minutes', 15),
          ],
        ),
      ),
    );
  }

  Widget _buildAutoLockOption(String label, int minutes) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = AppTheme.getPrimary(isDark);
    final isSelected = _autoLockMinutes == minutes;
    return ListTile(
      title: Text(
        label,
        style: TextStyle(
          fontFamily: 'Manrope',
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          color: isSelected
              ? primaryColor
              : (isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary),
        ),
      ),
      trailing: isSelected
          ? Icon(Icons.check_circle, color: primaryColor)
          : null,
      onTap: () async {
        await ref.read(authServiceProvider).setAutoLockMinutes(minutes);
        setState(() => _autoLockMinutes = minutes);
        if (mounted) Navigator.pop(context);
      },
    );
  }

  Future<void> _handleChangePin() async {
    final oldPinController = TextEditingController();
    final newPinController = TextEditingController();
    final confirmPinController = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Change Security PIN',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: oldPinController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Current 6-Digit PIN',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: newPinController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'New 6-Digit PIN'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: confirmPinController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Confirm New PIN'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newPin = newPinController.text.trim();
              if (newPin.length != 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('New PIN must be 6 digits')),
                );
                return;
              }
              if (newPin != confirmPinController.text.trim()) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('New PIN confirmation does not match'),
                  ),
                );
                return;
              }

              try {
                // Verify old PIN
                final oldVek = await ref
                    .read(authServiceProvider)
                    .unlockWithPin(oldPinController.text.trim());
                await ref.read(authServiceProvider).changePin(newPin, oldVek);
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('PIN successfully changed')),
                  );
                }
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text('Failed to change PIN: $e'),
                      backgroundColor: AppTheme.error,
                    ),
                  );
                }
              }
            },
            child: const Text('Update PIN'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportEncryptedVault() async {
    try {
      final backupService = ref.read(backupServiceProvider);
      final jsonPayload = await backupService.exportEncryptedBackupJson();

      final tempDir = await getTemporaryDirectory();
      final dateStr = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .substring(0, 19);
      final file = File('${tempDir.path}/locker-backup-$dateStr.vault');
      await file.writeAsString(jsonPayload);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Locker Encrypted Backup (.vault)',
        subject: 'Locker Encrypted Vault Backup',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _restoreEncryptedVault() async {
    try {
      final result = await FilePicker.platform.pickFiles();
      if (result == null || result.files.single.path == null) return;

      final file = File(result.files.single.path!);
      final content = await file.readAsString();

      final backupService = ref.read(backupServiceProvider);
      backupService.validateBackupPayload(content);

      if (!mounted) return;
      _showRestoreDialog(content);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Restore failed: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  void _showRestoreDialog(String backupJson) {
    final keyController = TextEditingController();
    final previousPinController = TextEditingController();
    final newPinController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Restore Encrypted Vault',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your 24-word Master Recovery Key and the previous PIN that protected this backup:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: keyController,
              maxLines: 3,
              style: AppTheme.monoStyle(
                fontSize: 12,
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppTheme.darkTextPrimary
                    : AppTheme.lightTextPrimary,
              ),
              decoration: const InputDecoration(
                hintText: 'Enter 24 words separated by spaces',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: previousPinController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Previous 6-Digit PIN (Backup Password)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newPinController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Set New 6-Digit PIN',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final backupService = ref.read(backupServiceProvider);
                final db = await backupService.restoreWithRecoveryKey(
                  backupJson: backupJson,
                  recoveryKey: keyController.text.trim(),
                  previousPin: previousPinController.text.trim(),
                  newPin: newPinController.text.trim(),
                );

                await ref.read(vaultListProvider.notifier).refresh();
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Successfully restored ${db.entries.length} accounts!',
                      ),
                    ),
                  );
                }
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text('Restore failed: $e'),
                      backgroundColor: AppTheme.error,
                    ),
                  );
                }
              }
            },
            child: const Text('Restore Vault'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleBackupMasterKey() async {
    final pinController = TextEditingController();

    final pin = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Authenticate with PIN',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your 6-digit PIN to generate a fresh 24-word recovery key protected with Two-Factor recovery:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pinController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Current 6-Digit PIN',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, pinController.text.trim()),
            child: const Text('Verify & Generate'),
          ),
        ],
      ),
    );

    if (pin == null || pin.length != 6) return;

    try {
      final auth = ref.read(authServiceProvider);
      final activeVek = await auth.unlockWithPin(pin);
      final newMnemonic = await auth.regenerateRecoveryKey(pin, activeVek);

      if (!mounted) return;

      final isDark = Theme.of(context).brightness == Brightness.dark;
      final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
      final cardBg = isDark ? AppTheme.darkSurface : const Color(0xFFF1F5F9);
      final words = newMnemonic.split(' ');

      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(
                Icons.shield_outlined,
                color: isDark ? AppTheme.darkSecondary : AppTheme.secondary,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Your 24-Word Recovery Key',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Write down these 24 words and store them safely.\n\nTwo-Factor Protected: Anyone who finds this key CANNOT decrypt your vault without your PIN.',
                    style: TextStyle(fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? AppTheme.darkOutline : AppTheme.lightOutline,
                      ),
                    ),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(words.length, (i) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDark ? AppTheme.darkCard : Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isDark ? AppTheme.darkOutline : AppTheme.lightOutline,
                            ),
                          ),
                          child: Text(
                            '${i + 1}. ${words[i]}',
                            style: AppTheme.monoStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: textPrimary,
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text('Copy 24 Words'),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: newMnemonic));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Recovery phrase copied to clipboard!')),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('I Have Saved My Key'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: Incorrect PIN or error: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentThemeMode = ref.watch(themeModeProvider);

    final textPrimary = isDark
        ? AppTheme.darkTextPrimary
        : AppTheme.lightTextPrimary;
    final textMuted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;
    final cardBg = isDark ? AppTheme.darkCard : AppTheme.lightCard;
    final containerLow = isDark
        ? AppTheme.darkContainerLow
        : AppTheme.lightContainerLow;
    final outlineColor = isDark ? AppTheme.darkOutline : AppTheme.lightOutline;
    final primaryColor = AppTheme.getPrimary(isDark);
    final secondaryColor = AppTheme.getSecondary(isDark);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          // Synced Chip
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF0D9488).withOpacity(0.25)
                  : const Color(0xFF86F2E4).withOpacity(0.3),
              borderRadius: BorderRadius.circular(20),
              border: isDark
                  ? Border.all(color: secondaryColor.withOpacity(0.4), width: 1)
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check, size: 14, color: secondaryColor),
                const SizedBox(width: 4),
                Text(
                  'Synced',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: secondaryColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          children: [
            // Hero Status Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: containerLow,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: outlineColor),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF0D9488).withOpacity(0.25)
                                : const Color(0xFF86F2E4).withOpacity(0.4),
                            borderRadius: BorderRadius.circular(12),
                            border: isDark
                                ? Border.all(
                                    color: secondaryColor.withOpacity(0.4),
                                    width: 1,
                                  )
                                : null,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.verified_user,
                                size: 13,
                                color: secondaryColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Zero-Knowledge Active',
                                style: TextStyle(
                                  fontFamily: 'Manrope',
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: secondaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Peace of mind, crafted in privacy',
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Your master seed never leaves this hardware enclave.',
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 11,
                            color: textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      ref.read(authStateProvider.notifier).lockVault();
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: outlineColor),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.lock, size: 20, color: primaryColor),
                          Text(
                            'LOCK',
                            style: TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Section 1: Security & Access
            _buildSectionHeader('SECURITY & ACCESS', 'High Protection'),
            Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: outlineColor),
              ),
              child: Column(
                children: [
                  _buildListTile(
                    icon: Icons.pin_outlined,
                    iconBg: containerLow,
                    iconColor: primaryColor,
                    title: 'Change Security PIN',
                    subtitle: '6-digit hardware passcode',
                    onTap: _handleChangePin,
                  ),
                  _buildDivider(outlineColor),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF0D9488).withOpacity(0.25)
                                : const Color(0xFF86F2E4).withOpacity(0.3),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.fingerprint,
                            color: secondaryColor,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Biometric Unlock',
                                style: TextStyle(
                                  fontFamily: 'Manrope',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: textPrimary,
                                ),
                              ),
                              Text(
                                'Face or Fingerprint sensor',
                                style: TextStyle(
                                  fontFamily: 'Manrope',
                                  fontSize: 12,
                                  color: textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _biometricEnabled,
                          activeColor: primaryColor,
                          onChanged: _toggleBiometrics,
                        ),
                      ],
                    ),
                  ),
                  _buildDivider(outlineColor),
                  _buildListTile(
                    icon: Icons.timer_outlined,
                    iconBg: containerLow,
                    iconColor: primaryColor,
                    title: 'Auto-Lock Vault',
                    subtitle: 'Locks when backgrounded or inactive',
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: containerLow,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _autoLockMinutes == 0
                                ? 'Immediately'
                                : '$_autoLockMinutes mins',
                            style: TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: primaryColor,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.expand_more,
                          size: 18,
                          color: textMuted,
                        ),
                      ],
                    ),
                    onTap: _showAutoLockModal,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Section 2: Backup & Sync
            _buildSectionHeader('SYNC & REDUNDANCY', 'Encrypted'),
            Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: outlineColor),
              ),
              child: Column(
                children: [
                  _buildListTile(
                    icon: Icons.file_upload_outlined,
                    iconBg: containerLow,
                    iconColor: primaryColor,
                    title: 'Export Encrypted Vault',
                    subtitle: 'Save safe .vault backup file',
                    onTap: _exportEncryptedVault,
                  ),
                  _buildDivider(outlineColor),
                  _buildListTile(
                    icon: Icons.file_download_outlined,
                    iconBg: containerLow,
                    iconColor: secondaryColor,
                    title: 'Restore Encrypted Vault',
                    subtitle: 'Import verified backup file',
                    onTap: _restoreEncryptedVault,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Section 3: Recovery
            _buildSectionHeader('EMERGENCY RECOVERY', 'Ready'),
            Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: outlineColor),
              ),
              child: Column(
                children: [
                  _buildListTile(
                    icon: Icons.quiz_outlined,
                    iconBg: containerLow,
                    iconColor: primaryColor,
                    title: 'Recovery Questions',
                    subtitle: 'Personalized security challenges',
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF0D9488).withOpacity(0.25)
                            : const Color(0xFF86F2E4).withOpacity(0.4),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_configuredQuestions.length} configured',
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: secondaryColor,
                        ),
                      ),
                    ),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          title: const Text(
                            'Configured Questions',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: _configuredQuestions.asMap().entries.map((
                              entry,
                            ) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Text(
                                  '${entry.key + 1}. ${entry.value}',
                                  style: const TextStyle(fontSize: 14),
                                ),
                              );
                            }).toList(),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  Divider(
                    height: 1,
                    indent: 68,
                    endIndent: 16,
                    color: isDark ? AppTheme.darkOutline : AppTheme.lightOutline,
                  ),
                  _buildListTile(
                    icon: Icons.key_rounded,
                    iconBg: containerLow,
                    iconColor: primaryColor,
                    title: '24-Word Master Key',
                    subtitle: 'Generate & backup recovery phrase',
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _handleBackupMasterKey,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Section 4: Appearance (Light / Dark / System)
            _buildSectionHeader('APPEARANCE', 'Editorial Calm'),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: outlineColor),
              ),
              child: Row(
                children: [
                  _buildThemeOption(
                    'Light',
                    Icons.light_mode_outlined,
                    ThemeMode.light,
                    currentThemeMode,
                  ),
                  _buildThemeOption(
                    'Dark',
                    Icons.dark_mode_outlined,
                    ThemeMode.dark,
                    currentThemeMode,
                  ),
                  _buildThemeOption(
                    'System',
                    Icons.settings_brightness_outlined,
                    ThemeMode.system,
                    currentThemeMode,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Section 5: About Locker
            _buildSectionHeader('ABOUT LOCKER', 'v1.0.0'),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: outlineColor),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.asset(
                            'assets/images/logo.png',
                            width: 44,
                            height: 44,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Locker Safe Haven',
                            style: TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: textPrimary,
                            ),
                          ),
                          Text(
                            'Version 1.0.0 (Local-First Edition)',
                            style: TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 12,
                              color: textMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Divider(
                    height: 1,
                    color: isDark ? AppTheme.darkOutline : AppTheme.lightOutline,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.person_outline_rounded,
                        size: 18,
                        color: primaryColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Creator & Lead Architect',
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: textMuted,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: containerLow,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isDark
                                ? AppTheme.darkOutline
                                : AppTheme.lightOutline,
                          ),
                        ),
                        child: Text(
                          'Taslim Ahmed Tamim',
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: containerLow,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.shield_outlined,
                          color: secondaryColor,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Zero-knowledge encryption. Keys never leave this hardware enclave. Passwords are never sent over the internet.',
                            style: TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 12,
                              height: 1.4,
                              color: textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Simulate Vault Auto-Lock Screen (from Stitch UI design)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark
                    ? const Color(0xFF1E3A8A).withOpacity(0.4)
                    : containerLow,
                foregroundColor: primaryColor,
              ),
              icon: const Icon(Icons.screen_lock_portrait_rounded, size: 20),
              label: const Text('Simulate Vault Auto-Lock Screen'),
              onPressed: () {
                Navigator.pop(context);
                ref.read(authStateProvider.notifier).lockVault();
              },
            ),
            const SizedBox(height: 24),
            Center(
              child: Text(
                'Crafted with ❤️ by Taslim Ahmed Tamim',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: textMuted,
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, String status) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondaryColor = AppTheme.getSecondary(isDark);
    final textMuted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4, right: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: textMuted,
              letterSpacing: 0.8,
            ),
          ),
          Text(
            status,
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: secondaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark
        ? AppTheme.darkTextPrimary
        : AppTheme.lightTextPrimary;
    final textMuted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;

    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: iconBg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontFamily: 'Manrope',
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontFamily: 'Manrope', fontSize: 12, color: textMuted),
      ),
      trailing:
          trailing ??
          Icon(Icons.chevron_right, size: 20, color: textMuted),
    );
  }

  Widget _buildDivider(Color color) {
    return Divider(height: 1, thickness: 1, color: color, indent: 64);
  }

  Widget _buildThemeOption(
    String label,
    IconData icon,
    ThemeMode mode,
    ThemeMode currentMode,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = AppTheme.getPrimary(isDark);
    final textMuted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;
    final isSelected = mode == currentMode;

    return Expanded(
      child: InkWell(
        onTap: () => ref.read(themeModeProvider.notifier).setTheme(mode),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected
                    ? (isDark ? const Color(0xFF0B1C30) : Colors.white)
                    : textMuted,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? (isDark ? const Color(0xFF0B1C30) : Colors.white)
                      : textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
