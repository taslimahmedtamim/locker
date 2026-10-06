import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/utils/clipboard_helper.dart';
import '../../models/vault_entry.dart';
import '../settings/settings_screen.dart';
import 'add_edit_password_screen.dart';
import 'password_details_sheet.dart';

/// Main Vault Screen featuring zero-knowledge status, fast search, account cards,
/// rapid copy, and settings navigation.
class MainVaultScreen extends ConsumerStatefulWidget {
  const MainVaultScreen({super.key});

  @override
  ConsumerState<MainVaultScreen> createState() => _MainVaultScreenState();
}

class _MainVaultScreenState extends ConsumerState<MainVaultScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final vaultListAsync = ref.watch(vaultListProvider);

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

    // Report user activity on any tap for auto-lock reset
    return Listener(
      onPointerDown: (_) =>
          ref.read(authStateProvider.notifier).recordUserActivity(),
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    'assets/images/logo.png',
                    width: 32,
                    height: 32,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Locker',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
            ],
          ),
          actions: [
            // Status Pill
            Container(
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
            const SizedBox(width: 8),

            // Settings Button
            IconButton(
              tooltip: 'Settings',
              icon: const Icon(Icons.settings_outlined),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (ctx) => const SettingsScreen()),
                );
              },
            ),

            // Quick Lock
            IconButton(
              tooltip: 'Lock Vault Now',
              icon: const Icon(Icons.lock_outline_rounded),
              onPressed: () {
                ref.read(authStateProvider.notifier).lockVault();
              },
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Hero Calming Status Banner
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Container(
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
                      // Lock button
                      InkWell(
                        onTap: () =>
                            ref.read(authStateProvider.notifier).lockVault(),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: outlineColor),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.lock,
                                size: 18,
                                color: primaryColor,
                              ),
                              Text(
                                'LOCK',
                                style: TextStyle(
                                  fontFamily: 'Manrope',
                                  fontSize: 8,
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
              ),

              // Search Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) {
                    ref.read(vaultListProvider.notifier).search(val);
                  },
                  decoration: InputDecoration(
                    hintText: 'Search accounts, emails, sites...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              ref.read(vaultListProvider.notifier).search('');
                            },
                          )
                        : null,
                  ),
                ),
              ),

              // Entries List
              Expanded(
                child: vaultListAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (err, _) =>
                      Center(child: Text('Error loading vault: $err')),
                  data: (entries) {
                    if (entries.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: containerLow,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.shield_outlined,
                                size: 32,
                                color: AppTheme.secondary,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchController.text.isNotEmpty
                                  ? 'No matching credentials found'
                                  : 'Your vault is safe and empty',
                              style: TextStyle(
                                fontFamily: 'Manrope',
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _searchController.text.isNotEmpty
                                  ? 'Try searching with a different keyword'
                                  : 'Tap the button below to store your first password',
                              style: TextStyle(
                                fontFamily: 'Manrope',
                                fontSize: 13,
                                color: textMuted,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                      itemCount: entries.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final entry = entries[index];
                        return _buildEntryCard(
                          entry: entry,
                          isDark: isDark,
                          cardBg: cardBg,
                          outlineColor: outlineColor,
                          textPrimary: textPrimary,
                          textMuted: textMuted,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: primaryColor,
          foregroundColor: isDark ? const Color(0xFF0B1C30) : Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          icon: const Icon(Icons.add_rounded),
          label: const Text(
            'Add Password',
            style: TextStyle(
              fontFamily: 'Manrope',
              fontWeight: FontWeight.w700,
            ),
          ),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (ctx) => const AddEditPasswordScreen(),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEntryCard({
    required VaultEntry entry,
    required bool isDark,
    required Color cardBg,
    required Color outlineColor,
    required Color textPrimary,
    required Color textMuted,
  }) {
    final primaryColor = AppTheme.getPrimary(isDark);
    final secondaryColor = AppTheme.getSecondary(isDark);
    final tertiaryColor = AppTheme.getTertiary(isDark);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: outlineColor),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF1E3A8A).withOpacity(0.35)
                : AppTheme.lightContainerLow,
            borderRadius: BorderRadius.circular(12),
            border: isDark
                ? Border.all(color: primaryColor.withOpacity(0.35), width: 1)
                : null,
          ),
          child: Center(
            child: Text(
              entry.title.isNotEmpty ? entry.title[0].toUpperCase() : '?',
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: primaryColor,
              ),
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                entry.title,
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (entry.isFavorite)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Icon(
                  Icons.star_rounded,
                  size: 16,
                  color: tertiaryColor,
                ),
              ),
          ],
        ),
        subtitle: Text(
          entry.username,
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: 13,
            color: textMuted,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Copy Password',
              icon: const Icon(Icons.copy_rounded, size: 20),
              color: secondaryColor,
              onPressed: () {
                ClipboardHelper.copySensitive(
                  context: context,
                  text: entry.password,
                  feedbackMessage:
                      'Password for ${entry.title} copied (clears in 30s)',
                );
              },
            ),
            Icon(Icons.chevron_right, size: 20, color: textMuted),
          ],
        ),
        onTap: () {
          PasswordDetailsSheet.show(context, entry);
        },
      ),
    );
  }
}
