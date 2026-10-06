import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/utils/clipboard_helper.dart';
import '../../models/vault_entry.dart';
import 'add_edit_password_screen.dart';

/// Password Details Sheet displaying account information, masked password,
/// copy with 30s clipboard timeout, edit, and deletion confirmation.
class PasswordDetailsSheet extends ConsumerStatefulWidget {
  final VaultEntry entry;

  const PasswordDetailsSheet({super.key, required this.entry});

  static void show(BuildContext context, VaultEntry entry) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PasswordDetailsSheet(entry: entry),
    );
  }

  @override
  ConsumerState<PasswordDetailsSheet> createState() =>
      _PasswordDetailsSheetState();
}

class _PasswordDetailsSheetState extends ConsumerState<PasswordDetailsSheet> {
  bool _isPasswordRevealed = false;
  late VaultEntry _currentEntry;

  @override
  void initState() {
    super.initState();
    _currentEntry = widget.entry;
  }

  Future<void> _handleDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete this password?',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'This entry will be permanently removed from your vault. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
              minimumSize: const Size(90, 44),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref.read(vaultListProvider.notifier).deleteEntry(_currentEntry.id);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_currentEntry.title} deleted from vault'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  Future<void> _handleEdit() async {
    final updated = await Navigator.push<VaultEntry?>(
      context,
      MaterialPageRoute(
        builder: (ctx) => AddEditPasswordScreen(existingEntry: _currentEntry),
      ),
    );

    if (updated != null && mounted) {
      setState(() => _currentEntry = updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppTheme.darkCard : AppTheme.lightCard;
    final containerBg = isDark
        ? AppTheme.darkContainerLow
        : AppTheme.lightContainerLow;
    final outlineColor = isDark ? AppTheme.darkOutline : AppTheme.lightOutline;
    final textPrimary = isDark
        ? AppTheme.darkTextPrimary
        : AppTheme.lightTextPrimary;
    final textMuted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;
    final primaryColor = AppTheme.getPrimary(isDark);

    final dateFormat = DateFormat.yMMMd().add_jm();

    return Container(
      padding: EdgeInsets.only(
        top: 16,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
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
          // Drag handle
          Center(
            child: Container(
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: outlineColor,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E3A8A).withOpacity(0.35)
                      : containerBg,
                  borderRadius: BorderRadius.circular(12),
                  border: isDark
                      ? Border.all(
                          color: primaryColor.withOpacity(0.35),
                          width: 1,
                        )
                      : null,
                ),
                child: Center(
                  child: Text(
                    _currentEntry.title.isNotEmpty
                        ? _currentEntry.title[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: primaryColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currentEntry.title,
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                    Text(
                      'Updated ${dateFormat.format(_currentEntry.updatedAt)}',
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 12,
                        color: textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Edit',
                icon: Icon(Icons.edit_outlined, color: primaryColor),
                onPressed: _handleEdit,
              ),
              IconButton(
                tooltip: 'Delete',
                icon: const Icon(Icons.delete_outline, color: AppTheme.error),
                onPressed: _handleDelete,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Username field
          _buildFieldCard(
            label: 'Username / Email',
            value: _currentEntry.username,
            isDark: isDark,
            containerBg: containerBg,
            trailing: IconButton(
              icon: const Icon(Icons.copy_rounded, size: 20),
              color: textMuted,
              onPressed: () {
                ClipboardHelper.copyPublic(
                  context: context,
                  text: _currentEntry.username,
                  label: 'Username',
                );
              },
            ),
          ),
          const SizedBox(height: 12),

          // Password Field
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: containerBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: outlineColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Password',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: textMuted,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _isPasswordRevealed
                            ? _currentEntry.password
                            : '••••••••••••••••••••',
                        style: AppTheme.monoStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        _isPasswordRevealed
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: textMuted,
                      ),
                      onPressed: () {
                        setState(
                          () => _isPasswordRevealed = !_isPasswordRevealed,
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor:
                        isDark ? const Color(0xFF0B1C30) : Colors.white,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.copy_rounded, size: 20),
                  label: const Text('Copy Password (Clears in 30s)'),
                  onPressed: () {
                    ClipboardHelper.copySensitive(
                      context: context,
                      text: _currentEntry.password,
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Website (if present)
          if (_currentEntry.website.isNotEmpty) ...[
            _buildFieldCard(
              label: 'Website',
              value: _currentEntry.website,
              isDark: isDark,
              containerBg: containerBg,
              trailing: IconButton(
                icon: const Icon(Icons.open_in_new, size: 20),
                color: textMuted,
                onPressed: () {
                  ClipboardHelper.copyPublic(
                    context: context,
                    text: _currentEntry.website,
                    label: 'Website URL',
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Notes (if present)
          if (_currentEntry.notes.isNotEmpty) ...[
            _buildFieldCard(
              label: 'Notes',
              value: _currentEntry.notes,
              isDark: isDark,
              containerBg: containerBg,
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _buildFieldCard({
    required String label,
    required String value,
    required bool isDark,
    required Color containerBg,
    Widget? trailing,
  }) {
    final textPrimary = isDark
        ? AppTheme.darkTextPrimary
        : AppTheme.lightTextPrimary;
    final textMuted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;
    final outlineColor = isDark ? AppTheme.darkOutline : AppTheme.lightOutline;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: containerBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: outlineColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: textMuted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: textPrimary,
                  ),
                ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
