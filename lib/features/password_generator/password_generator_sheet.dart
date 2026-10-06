import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/crypto/crypto_service.dart';
import '../../core/utils/clipboard_helper.dart';

/// Password Generator Bottom Sheet with entropy strength meter and custom character sets.
class PasswordGeneratorSheet extends StatefulWidget {
  final ValueChanged<String>? onUsePassword;

  const PasswordGeneratorSheet({super.key, this.onUsePassword});

  static Future<String?> show(BuildContext context) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const PasswordGeneratorSheet(),
    );
  }

  @override
  State<PasswordGeneratorSheet> createState() => _PasswordGeneratorSheetState();
}

class _PasswordGeneratorSheetState extends State<PasswordGeneratorSheet> {
  final CryptoService _crypto = CryptoService();

  int _length = 20;
  bool _includeUpper = true;
  bool _includeLower = true;
  bool _includeNumbers = true;
  bool _includeSymbols = true;

  String _generatedPassword = '';
  int _entropyScore = 4;

  @override
  void initState() {
    super.initState();
    _regenerate();
  }

  void _regenerate() {
    setState(() {
      _generatedPassword = _crypto.generatePassword(
        length: _length,
        uppercase: _includeUpper,
        lowercase: _includeLower,
        numbers: _includeNumbers,
        symbols: _includeSymbols,
      );
      _entropyScore = _crypto.calculateEntropyScore(_generatedPassword);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppTheme.darkCard : AppTheme.lightCard;
    final containerBg = isDark
        ? AppTheme.darkContainerLow
        : AppTheme.lightContainerLow;
    final outlineColor = isDark ? AppTheme.darkOutline : AppTheme.lightOutline;
    final primaryColor = AppTheme.getPrimary(isDark);
    final secondaryColor = AppTheme.getSecondary(isDark);
    final tertiaryColor = AppTheme.getTertiary(isDark);

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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Password Generator',
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? AppTheme.darkTextPrimary
                          : AppTheme.lightTextPrimary,
                    ),
                  ),
                  Text(
                    'Cryptographically secure CSPRNG',
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 12,
                      color: isDark
                          ? AppTheme.darkTextMuted
                          : AppTheme.lightTextMuted,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Password Display Box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: containerBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: outlineColor),
            ),
            child: Row(
              children: [
                Expanded(
                  child: SelectableText(
                    _generatedPassword,
                    style: AppTheme.monoStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppTheme.darkTextPrimary
                          : AppTheme.lightTextPrimary,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Regenerate',
                  icon: Icon(Icons.refresh, color: primaryColor),
                  onPressed: _regenerate,
                ),
                IconButton(
                  tooltip: 'Copy',
                  icon: Icon(
                    Icons.copy_rounded,
                    color: secondaryColor,
                  ),
                  onPressed: () {
                    ClipboardHelper.copySensitive(
                      context: context,
                      text: _generatedPassword,
                      feedbackMessage:
                          'Generated password copied (clears in 30s)',
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 4-Bar Entropy Strength Meter
          Row(
            children: [
              for (int i = 1; i <= 4; i++)
                Expanded(
                  child: Container(
                    height: 5,
                    margin: EdgeInsets.only(right: i < 4 ? 6 : 0),
                    decoration: BoxDecoration(
                      color: i <= _entropyScore
                          ? (_entropyScore <= 2
                              ? tertiaryColor
                              : secondaryColor)
                          : outlineColor,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              _entropyScore == 4
                  ? 'Very Strong (256-bit entropy)'
                  : (_entropyScore == 3 ? 'Strong' : 'Moderate'),
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _entropyScore >= 3
                    ? secondaryColor
                    : tertiaryColor,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Length Slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Password Length',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppTheme.darkTextPrimary
                      : AppTheme.lightTextPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: containerBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$_length chars',
                  style: AppTheme.monoStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: primaryColor,
                  ),
                ),
              ),
            ],
          ),
          Slider(
            value: _length.toDouble(),
            min: 12,
            max: 32,
            divisions: 20,
            activeColor: primaryColor,
            onChanged: (val) {
              setState(() => _length = val.round());
              _regenerate();
            },
          ),
          const SizedBox(height: 8),

          // Character Set Switches
          _buildToggle(
            title: 'Uppercase Letters (A-Z)',
            value: _includeUpper,
            onChanged: (val) {
              if (!val &&
                  !_includeLower &&
                  !_includeNumbers &&
                  !_includeSymbols)
                return;
              setState(() => _includeUpper = val);
              _regenerate();
            },
            isDark: isDark,
          ),
          _buildToggle(
            title: 'Lowercase Letters (a-z)',
            value: _includeLower,
            onChanged: (val) {
              if (!val &&
                  !_includeUpper &&
                  !_includeNumbers &&
                  !_includeSymbols)
                return;
              setState(() => _includeLower = val);
              _regenerate();
            },
            isDark: isDark,
          ),
          _buildToggle(
            title: 'Numbers (0-9)',
            value: _includeNumbers,
            onChanged: (val) {
              if (!val && !_includeUpper && !_includeLower && !_includeSymbols)
                return;
              setState(() => _includeNumbers = val);
              _regenerate();
            },
            isDark: isDark,
          ),
          _buildToggle(
            title: 'Special Symbols (!@#\$%^&*)',
            value: _includeSymbols,
            onChanged: (val) {
              if (!val && !_includeUpper && !_includeLower && !_includeNumbers)
                return;
              setState(() => _includeSymbols = val);
              _regenerate();
            },
            isDark: isDark,
          ),
          const SizedBox(height: 20),

          // Action Button
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context, _generatedPassword);
            },
            child: const Text('Use This Password'),
          ),
        ],
      ),
    );
  }

  Widget _buildToggle({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
    required bool isDark,
  }) {
    final primaryColor = AppTheme.getPrimary(isDark);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 14,
              color: isDark
                  ? AppTheme.darkTextPrimary
                  : AppTheme.lightTextPrimary,
            ),
          ),
          Switch(
            value: value,
            activeColor: primaryColor,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
