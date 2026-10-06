import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../recovery/recovery_screen.dart';

/// App Lock Screen faithfully matching the Google Stitch specification.
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen>
    with SingleTickerProviderStateMixin {
  String _enteredPin = '';
  bool _isError = false;
  String? _errorMessage;
  int _lockoutSeconds = 0;
  Timer? _lockoutTimer;

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _lockoutTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _onDigitPressed(String digit) {
    if (_lockoutSeconds > 0) return;
    if (_enteredPin.length >= 6) return;

    HapticFeedback.lightImpact();
    setState(() {
      _isError = false;
      _errorMessage = null;
      _enteredPin += digit;
    });

    if (_enteredPin.length == 6) {
      _submitPin();
    }
  }

  void _onBackspace() {
    if (_enteredPin.isNotEmpty) {
      HapticFeedback.lightImpact();
      setState(() {
        _isError = false;
        _errorMessage = null;
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      });
    }
  }

  Future<void> _submitPin() async {
    final pin = _enteredPin;
    final success = await ref
        .read(authStateProvider.notifier)
        .unlockWithPin(pin);

    if (!success && mounted) {
      HapticFeedback.heavyImpact();
      final authState = ref.read(authStateProvider);

      setState(() {
        _isError = true;
        _errorMessage = authState.errorMessage ?? 'Incorrect PIN';
        _enteredPin = '';

        if (authState.lockoutSeconds > 0) {
          _startLockoutCountdown(authState.lockoutSeconds);
        }
      });
    }
  }

  void _startLockoutCountdown(int seconds) {
    _lockoutTimer?.cancel();
    setState(() => _lockoutSeconds = seconds);

    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_lockoutSeconds <= 1) {
        timer.cancel();
        setState(() {
          _lockoutSeconds = 0;
          _isError = false;
          _errorMessage = null;
        });
      } else {
        setState(() => _lockoutSeconds--);
      }
    });
  }

  Future<void> _triggerBiometric() async {
    HapticFeedback.selectionClick();
    final success = await ref
        .read(authStateProvider.notifier)
        .unlockWithBiometrics();
    if (!success && mounted) {
      // Biometrics failed or cancelled, user can use PIN
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark
        ? AppTheme.darkTextPrimary
        : AppTheme.lightTextPrimary;
    final textMuted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;
    final numpadBg = isDark ? AppTheme.darkCard : AppTheme.lightCard;
    final dotContainer = isDark
        ? AppTheme.darkContainerHigh
        : AppTheme.lightContainerHigh;
    final primaryColor = AppTheme.getPrimary(isDark);
    final secondaryColor = AppTheme.getSecondary(isDark);

    final authState = ref.watch(authStateProvider);
    final isBiometricAvailable = authState.biometricAvailable;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top Branding & Status Header
              Column(
                children: [
                  const SizedBox(height: 12),
                  // App Icon with lock badge
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withOpacity(0.35),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.asset(
                            'assets/images/logo.png',
                            width: 72,
                            height: 72,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0D9488) : const Color(0xFF86F2E4),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark
                                ? AppTheme.darkBackground
                                : AppTheme.lightBackground,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          Icons.shield,
                          size: 12,
                          color: isDark ? Colors.white : AppTheme.secondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Unlock Vault',
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isBiometricAvailable
                        ? 'Tap fingerprint sensor or enter PIN'
                        : 'Enter your 6-digit security PIN',
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 14,
                      color: textMuted,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Error Toast Banner
                  if (_isError || _lockoutSeconds > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: AppTheme.error,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _lockoutSeconds > 0
                                      ? 'Locked Out ($_lockoutSeconds s)'
                                      : 'Incorrect PIN',
                                  style: const TextStyle(
                                    fontFamily: 'Manrope',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.error,
                                  ),
                                ),
                                Text(
                                  _errorMessage ??
                                      (_lockoutSeconds > 0
                                          ? 'Too many attempts. Please wait before retrying.'
                                          : 'Your vault remains safe and protected.'),
                                  style: const TextStyle(
                                    fontFamily: 'Manrope',
                                    fontSize: 11,
                                    color: AppTheme.onErrorContainer,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),

              // Biometric Sensor Button (if available)
              if (isBiometricAvailable)
                Column(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        // Pulsing Ring
                        AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) {
                            return Container(
                              width: 80 + (_pulseController.value * 16),
                              height: 80 + (_pulseController.value * 16),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: secondaryColor.withOpacity(
                                  (1.0 - _pulseController.value) * 0.35,
                                ),
                              ),
                            );
                          },
                        ),
                        // Biometric Button Trigger
                        InkWell(
                          onTap: _triggerBiometric,
                          borderRadius: BorderRadius.circular(40),
                          child: Container(
                            width: 68,
                            height: 68,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isDark
                                  ? const Color(0xFF0D9488)
                                  : const Color(0xFF86F2E4),
                              boxShadow: [
                                BoxShadow(
                                  color: secondaryColor.withOpacity(0.2),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.fingerprint_rounded,
                              size: 38,
                              color: isDark ? Colors.white : AppTheme.secondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Touch sensor',
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: secondaryColor,
                      ),
                    ),
                  ],
                )
              else
                const SizedBox(height: 20),

              // PIN Indicator Dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(6, (index) {
                  final isFilled = index < _enteredPin.length;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.symmetric(horizontal: 7),
                    width: isFilled ? 14 : 12,
                    height: isFilled ? 14 : 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isError
                          ? AppTheme.error
                          : (isFilled ? primaryColor : dotContainer),
                    ),
                  );
                }),
              ),

              // 3x4 Numeric Keypad Grid
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  children: [
                    _buildNumpadRow(
                      ['1', '2', '3'],
                      ['', 'ABC', 'DEF'],
                      numpadBg,
                      textPrimary,
                    ),
                    const SizedBox(height: 12),
                    _buildNumpadRow(
                      ['4', '5', '6'],
                      ['GHI', 'JKL', 'MNO'],
                      numpadBg,
                      textPrimary,
                    ),
                    const SizedBox(height: 12),
                    _buildNumpadRow(
                      ['7', '8', '9'],
                      ['PQRS', 'TUV', 'WXYZ'],
                      numpadBg,
                      textPrimary,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Help / Emergency Recovery Button
                        InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (ctx) => const RecoveryScreen(),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(35),
                          child: SizedBox(
                            width: 68,
                            height: 68,
                            child: Center(
                              child: Text(
                                'Help',
                                style: TextStyle(
                                  fontFamily: 'Manrope',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: primaryColor,
                                ),
                              ),
                            ),
                          ),
                        ),
                        // '0' Button
                        _buildNumpadBtn('0', '', numpadBg, textPrimary),
                        // Backspace Button
                        InkWell(
                          onTap: _onBackspace,
                          borderRadius: BorderRadius.circular(35),
                          child: SizedBox(
                            width: 68,
                            height: 68,
                            child: Center(
                              child: Icon(
                                Icons.backspace_outlined,
                                size: 24,
                                color: textMuted,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNumpadRow(
    List<String> digits,
    List<String> subtexts,
    Color bg,
    Color textPrimary,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (int i = 0; i < digits.length; i++)
          _buildNumpadBtn(digits[i], subtexts[i], bg, textPrimary),
      ],
    );
  }

  Widget _buildNumpadBtn(
    String digit,
    String subtext,
    Color bg,
    Color textPrimary,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: () => _onDigitPressed(digit),
      borderRadius: BorderRadius.circular(35),
      child: Container(
        width: 68,
        height: 68,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              digit,
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: textPrimary,
              ),
            ),
            if (subtext.isNotEmpty)
              Text(
                subtext,
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted,
                  letterSpacing: 0.5,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
