import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/crypto/crypto_service.dart';
import '../../core/utils/clipboard_helper.dart';

/// Onboarding wizard: Welcome -> Create PIN -> Confirm PIN -> Biometrics
/// -> Recovery Questions -> Recovery Key -> Vault Created.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _QuestionPair {
  final TextEditingController questionController;
  final TextEditingController answerController;

  _QuestionPair({String question = '', String answer = ''})
      : questionController = TextEditingController(text: question),
        answerController = TextEditingController(text: answer);

  void dispose() {
    questionController.dispose();
    answerController.dispose();
  }
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  final CryptoService _crypto = CryptoService();

  int _currentPage = 0;

  // State variables for wizard
  String _pin = '';
  String _confirmPin = '';
  bool _pinMismatchError = false;
  bool _enableBiometrics = true;

  // User-created Security Questions & Answers (arbitrary count)
  final List<_QuestionPair> _questionPairs = [];

  String _recoveryKey = '';
  bool _hasSavedRecoveryKey = false;
  bool _isCreatingVault = false;

  @override
  void initState() {
    super.initState();
    _recoveryKey = _crypto.generateMasterRecoveryKey();
    // Start with 2 blank customizable questions created by the user
    _questionPairs.add(_QuestionPair());
    _questionPairs.add(_QuestionPair());
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final pair in _questionPairs) {
      pair.dispose();
    }
    super.dispose();
  }

  void _addQuestion() {
    setState(() {
      _questionPairs.add(_QuestionPair());
    });
  }

  void _removeQuestion(int index) {
    if (_questionPairs.length <= 1) return;
    setState(() {
      final removed = _questionPairs.removeAt(index);
      removed.dispose();
    });
  }

  void _nextPage() {
    if (_currentPage < 5) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _finalizeVaultCreation() async {
    setState(() => _isCreatingVault = true);
    try {
      final authService = ref.read(authServiceProvider);
      final questions = _questionPairs
          .map((p) => p.questionController.text.trim())
          .toList();
      final answers = _questionPairs
          .map((p) => p.answerController.text.trim())
          .toList();

      final vek = await authService.initializeVault(
        pin: _pin,
        recoveryKey: _recoveryKey,
        questions: questions,
        answers: answers,
        enableBiometrics: _enableBiometrics,
      );

      ref.read(authStateProvider.notifier).completeOnboarding(vek);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to initialize vault: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCreatingVault = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: _currentPage == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _currentPage > 0) {
          _prevPage();
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              // Progress Bar
              if (_currentPage > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: _prevPage,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: _currentPage / 5.0,
                            backgroundColor: isDark
                                ? AppTheme.darkContainerHigh
                                : AppTheme.lightContainerHigh,
                            valueColor: AlwaysStoppedAnimation(
                              AppTheme.getPrimary(isDark),
                            ),
                            minHeight: 6,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'Step $_currentPage of 5',
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppTheme.darkTextMuted
                              : AppTheme.lightTextMuted,
                        ),
                      ),
                    ],
                  ),
                ),

              // Page Content
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (page) => setState(() => _currentPage = page),
                  children: [
                    _buildWelcomeStep(isDark),
                    _buildCreatePinStep(isDark),
                    _buildConfirmPinStep(isDark),
                    _buildBiometricStep(isDark),
                    _buildQuestionsStep(isDark),
                    _buildRecoveryKeyStep(isDark),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeStep(bool isDark) {
    final textPrimary = isDark
        ? AppTheme.darkTextPrimary
        : AppTheme.lightTextPrimary;
    final textMuted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;

    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withOpacity(0.35),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: Image.asset(
                'assets/images/logo.png',
                width: 96,
                height: 96,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Locker',
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Peace of mind, crafted in privacy.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.secondary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'A local-first, zero-knowledge password vault. Your passwords never leave this phone, and nobody can access them without your credentials.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 14,
              color: textMuted,
              height: 1.5,
            ),
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: _nextPage,
            child: const Text('Create Vault'),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildCreatePinStep(bool isDark) {
    return _buildPinEntryView(
      title: 'Create 6-Digit PIN',
      subtitle: 'This PIN will be your primary key to unlock your vault.',
      currentPin: _pin,
      onDigit: (digit) {
        if (_pin.length < 6) {
          setState(() => _pin += digit);
          if (_pin.length == 6) {
            _nextPage();
          }
        }
      },
      onBackspace: () {
        if (_pin.isNotEmpty) {
          setState(() => _pin = _pin.substring(0, _pin.length - 1));
        }
      },
      isDark: isDark,
    );
  }

  Widget _buildConfirmPinStep(bool isDark) {
    return _buildPinEntryView(
      title: 'Confirm 6-Digit PIN',
      subtitle: 'Enter the exact same PIN to ensure accuracy.',
      currentPin: _confirmPin,
      errorMessage: _pinMismatchError
          ? 'PINs do not match. Please try again.'
          : null,
      onDigit: (digit) {
        if (_confirmPin.length < 6) {
          setState(() {
            _pinMismatchError = false;
            _confirmPin += digit;
          });
          if (_confirmPin.length == 6) {
            if (_confirmPin == _pin) {
              _nextPage();
            } else {
              HapticFeedback.heavyImpact();
              setState(() {
                _pinMismatchError = true;
                _confirmPin = '';
              });
            }
          }
        }
      },
      onBackspace: () {
        if (_confirmPin.isNotEmpty) {
          setState(
            () =>
                _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1),
          );
        }
      },
      isDark: isDark,
    );
  }

  Widget _buildPinEntryView({
    required String title,
    required String subtitle,
    required String currentPin,
    String? errorMessage,
    required ValueChanged<String> onDigit,
    required VoidCallback onBackspace,
    required bool isDark,
  }) {
    final textPrimary = isDark
        ? AppTheme.darkTextPrimary
        : AppTheme.lightTextPrimary;
    final textMuted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;
    final numpadBg = isDark ? AppTheme.darkCard : AppTheme.lightCard;
    final dotContainer = isDark
        ? AppTheme.darkContainerHigh
        : AppTheme.lightContainerHigh;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            children: [
              const SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 14,
                  color: textMuted,
                ),
              ),
              const SizedBox(height: 24),
              // PIN Dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(6, (index) {
                  final isFilled = index < currentPin.length;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: errorMessage != null
                          ? AppTheme.error
                          : (isFilled
                              ? AppTheme.getPrimary(isDark)
                              : dotContainer),
                    ),
                  );
                }),
              ),
              if (errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  errorMessage,
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.error,
                  ),
                ),
              ],
            ],
          ),
          // Numpad Grid
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              children: [
                _buildNumpadRow(
                  ['1', '2', '3'],
                  onDigit,
                  numpadBg,
                  textPrimary,
                ),
                const SizedBox(height: 12),
                _buildNumpadRow(
                  ['4', '5', '6'],
                  onDigit,
                  numpadBg,
                  textPrimary,
                ),
                const SizedBox(height: 12),
                _buildNumpadRow(
                  ['7', '8', '9'],
                  onDigit,
                  numpadBg,
                  textPrimary,
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    const SizedBox(width: 68, height: 68),
                    _buildNumpadButton('0', onDigit, numpadBg, textPrimary),
                    InkWell(
                      onTap: onBackspace,
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
    );
  }

  Widget _buildNumpadRow(
    List<String> digits,
    ValueChanged<String> onDigit,
    Color bg,
    Color textPrimary,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (final d in digits) _buildNumpadButton(d, onDigit, bg, textPrimary),
      ],
    );
  }

  Widget _buildNumpadButton(
    String digit,
    ValueChanged<String> onDigit,
    Color bg,
    Color textPrimary,
  ) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onDigit(digit);
      },
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
        child: Center(
          child: Text(
            digit,
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBiometricStep(bool isDark) {
    final textPrimary = isDark
        ? AppTheme.darkTextPrimary
        : AppTheme.lightTextPrimary;
    final textMuted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;

    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFF86F2E4),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.fingerprint_rounded,
              size: 48,
              color: AppTheme.secondary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Biometric Unlock',
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Enable fingerprint or face unlock for effortless and secure vault access.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 14,
              color: textMuted,
              height: 1.5,
            ),
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: () {
              setState(() => _enableBiometrics = true);
              _nextPage();
            },
            child: const Text('Enable Biometrics'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusButton),
              ),
            ),
            onPressed: () {
              setState(() => _enableBiometrics = false);
              _nextPage();
            },
            child: const Text('Skip for Now'),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildQuestionsStep(bool isDark) {
    final textPrimary = isDark
        ? AppTheme.darkTextPrimary
        : AppTheme.lightTextPrimary;
    final textMuted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;

    final canProceed = _questionPairs.isNotEmpty &&
        _questionPairs.every((pair) =>
            pair.questionController.text.trim().isNotEmpty &&
            pair.answerController.text.trim().isNotEmpty);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: ListView(
        children: [
          Text(
            'Recovery Questions',
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Create your own security questions and answers to recover your vault if you ever forget your PIN. You can add any number of questions.',
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 13,
              color: textMuted,
            ),
          ),
          const SizedBox(height: 20),

          // Dynamic question cards created by user
          for (int i = 0; i < _questionPairs.length; i++) ...[
            _buildQuestionCard(
              index: i,
              pair: _questionPairs[i],
              isDark: isDark,
              canRemove: _questionPairs.length > 1,
            ),
            const SizedBox(height: 16),
          ],

          // Add Question Button
          OutlinedButton.icon(
            onPressed: _addQuestion,
            icon: const Icon(Icons.add_rounded, size: 20),
            label: const Text('Add Another Question'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              side: BorderSide(
                color: isDark
                    ? AppTheme.darkOutline
                    : AppTheme.lightOutline,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusButton),
              ),
            ),
          ),
          const SizedBox(height: 28),

          ElevatedButton(
            onPressed: canProceed ? _nextPage : null,
            child: const Text('Continue'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildQuestionCard({
    required int index,
    required _QuestionPair pair,
    required bool isDark,
    required bool canRemove,
  }) {
    final cardBg =
        isDark ? AppTheme.darkContainerLow : AppTheme.lightContainerLow;
    final outlineColor =
        isDark ? AppTheme.darkOutline : AppTheme.lightOutline;

    final hintExamples = [
      'e.g., What was the name of your first pet?',
      'e.g., What city was your childhood home in?',
      'e.g., What was your favorite school subject?',
      'e.g., What was the name of your first manager?',
    ];
    final questionHint = index < hintExamples.length
        ? hintExamples[index]
        : 'Enter your custom security question';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: outlineColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'QUESTION ${index + 1}',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color:
                      isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted,
                  letterSpacing: 0.8,
                ),
              ),
              if (canRemove)
                InkWell(
                  onTap: () => _removeQuestion(index),
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.delete_outline_rounded,
                          size: 16,
                          color: AppTheme.error.withOpacity(0.85),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Remove',
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.error.withOpacity(0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: pair.questionController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              isDense: true,
              labelText: 'Question ${index + 1}',
              hintText: questionHint,
              prefixIcon: const Icon(Icons.help_outline_rounded, size: 18),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: pair.answerController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              isDense: true,
              labelText: 'Answer ${index + 1}',
              hintText: 'Enter secret answer',
              prefixIcon: const Icon(Icons.key, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecoveryKeyStep(bool isDark) {
    final textPrimary = isDark
        ? AppTheme.darkTextPrimary
        : AppTheme.lightTextPrimary;
    final textMuted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;
    final containerBg = isDark
        ? AppTheme.darkContainerLow
        : AppTheme.lightContainerLow;
    final words = _recoveryKey.split(' ');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: ListView(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.tertiaryFixed,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.vpn_key_rounded,
                  color: AppTheme.tertiary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Master Recovery Key',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Write down these 24 words in order and store them in a secure offline location. They provide complete zero-knowledge recovery if you ever forget your PIN.',
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 13,
              color: textMuted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),

          // 24-Word Box Grid
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: containerBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppTheme.darkOutline : AppTheme.lightOutline,
              ),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(words.length, (index) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark
                          ? AppTheme.darkOutline
                          : AppTheme.lightOutline,
                    ),
                  ),
                  child: Text(
                    '${index + 1}. ${words[index]}',
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
          const SizedBox(height: 12),

          OutlinedButton.icon(
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Copy 24 Words'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusButton),
              ),
            ),
            onPressed: () {
              ClipboardHelper.copySensitive(
                context: context,
                text: _recoveryKey,
                feedbackMessage: '24-word recovery key copied (clears in 30s)',
              );
            },
          ),
          const SizedBox(height: 16),

          // Checkbox confirmation
          CheckboxListTile(
            value: _hasSavedRecoveryKey,
            activeColor: AppTheme.getPrimary(isDark),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(
              'I have saved these 24 words safely offline.',
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: textPrimary,
              ),
            ),
            onChanged: (val) =>
                setState(() => _hasSavedRecoveryKey = val ?? false),
          ),
          const SizedBox(height: 20),

          ElevatedButton(
            onPressed: _hasSavedRecoveryKey && !_isCreatingVault
                ? _finalizeVaultCreation
                : null,
            child: _isCreatingVault
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text('Initialize & Open Vault'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
