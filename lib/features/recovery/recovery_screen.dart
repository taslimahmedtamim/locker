import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';

/// Screen allowing emergency vault recovery when the user forgets their PIN.
class RecoveryScreen extends ConsumerStatefulWidget {
  const RecoveryScreen({super.key});

  @override
  ConsumerState<RecoveryScreen> createState() => _RecoveryScreenState();
}

class _RecoveryScreenState extends ConsumerState<RecoveryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final TextEditingController _keyController = TextEditingController();
  final TextEditingController _previousPinController = TextEditingController();
  bool _obscurePreviousPin = true;
  List<TextEditingController> _answerControllers = [];

  final TextEditingController _newPinController = TextEditingController();
  final TextEditingController _confirmPinController = TextEditingController();

  List<String> _questions = [];
  bool _isRecovering = false;
  bool _isLoadingQuestions = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    final auth = ref.read(authServiceProvider);
    final qs = await auth.getStoredQuestions();
    if (mounted) {
      setState(() {
        _questions = qs;
        for (final c in _answerControllers) {
          c.dispose();
        }
        _answerControllers = List.generate(
          qs.length,
          (_) => TextEditingController(),
        );
        _isLoadingQuestions = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _keyController.dispose();
    _previousPinController.dispose();
    for (final c in _answerControllers) {
      c.dispose();
    }
    _newPinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  Future<void> _handleKeyRecovery() async {
    final key = _keyController.text.trim();
    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your 24-word recovery key')),
      );
      return;
    }

    final prevPin = _previousPinController.text.trim();
    if (prevPin.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your 6-digit previous PIN')),
      );
      return;
    }

    final newPin = await _promptNewPin();
    if (newPin == null) return;

    setState(() => _isRecovering = true);
    try {
      final recoveryService = ref.read(recoveryServiceProvider);
      final vek = await recoveryService.recoverWithMasterKey(
        key,
        previousPin: prevPin,
      );
      await recoveryService.completeRecovery(newPin, vek);

      await ref.read(vaultRepositoryProvider).unlock(vek);
      ref.read(authStateProvider.notifier).completeOnboarding(vek);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vault successfully recovered! New PIN active.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isRecovering = false);
    }
  }

  Future<void> _handleQuestionsRecovery() async {
    final answers = _answerControllers.map((c) => c.text.trim()).toList();

    if (answers.isEmpty || answers.any((a) => a.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please answer all recovery questions')),
      );
      return;
    }

    final newPin = await _promptNewPin();
    if (newPin == null) return;

    setState(() => _isRecovering = true);
    try {
      final recoveryService = ref.read(recoveryServiceProvider);
      final vek = await recoveryService.recoverWithQuestions(answers);
      await recoveryService.completeRecovery(newPin, vek);

      await ref.read(vaultRepositoryProvider).unlock(vek);
      ref.read(authStateProvider.notifier).completeOnboarding(vek);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vault successfully recovered! New PIN active.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isRecovering = false);
    }
  }

  Future<String?> _promptNewPin() async {
    _newPinController.clear();
    _confirmPinController.clear();

    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Configure New PIN',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Your recovery credentials verified successfully. Please choose a new 6-digit PIN for daily access:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _newPinController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'New 6-Digit PIN'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _confirmPinController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Confirm New PIN'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final pin = _newPinController.text.trim();
              if (pin.length != 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PIN must be 6 digits')),
                );
                return;
              }
              if (pin != _confirmPinController.text.trim()) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('PIN confirmation does not match'),
                  ),
                );
                return;
              }
              Navigator.pop(ctx, pin);
            },
            child: const Text('Confirm PIN'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = AppTheme.getPrimary(isDark);
    final textPrimary = AppTheme.getTextPrimary(isDark);
    final textMuted = AppTheme.getTextMuted(isDark);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Recovery'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: primaryColor,
          labelColor: primaryColor,
          unselectedLabelColor: textMuted,
          labelStyle: const TextStyle(
            fontFamily: 'Manrope',
            fontWeight: FontWeight.w700,
          ),
          tabs: const [
            Tab(text: '24-Word Key'),
            Tab(text: 'Security Questions'),
          ],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            // Tab 1: 24-Word Key
            Padding(
              padding: const EdgeInsets.all(24),
              child: ListView(
                children: [
                  Text(
                    'Two-Factor Recovery: Enter your 24-word Master Recovery Key and previous PIN to unwrap your vault.',
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 14,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _keyController,
                    maxLines: 4,
                    style: AppTheme.monoStyle(
                      fontSize: 13,
                      color: textPrimary,
                    ),
                    decoration: const InputDecoration(
                      labelText: '24-Word Recovery Phrase',
                      hintText: 'Enter 24 words separated by spaces...',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _previousPinController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    obscureText: _obscurePreviousPin,
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 15,
                      letterSpacing: 4,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Previous 6-Digit PIN',
                      hintText: '••••••',
                      counterText: '',
                      prefixIcon: const Icon(Icons.pin_outlined),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePreviousPin
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: textMuted,
                        ),
                        onPressed: () => setState(
                          () => _obscurePreviousPin = !_obscurePreviousPin,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Protected: Possessing only the 24 words cannot decrypt your vault without your PIN.',
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 12,
                      color: textMuted,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isRecovering ? null : _handleKeyRecovery,
                    child: _isRecovering
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Recover Vault'),
                  ),
                ],
              ),
            ),

            // Tab 2: Security Questions
            Padding(
              padding: const EdgeInsets.all(24),
              child: ListView(
                children: [
                  Text(
                    'Answer your custom recovery questions to unlock your vault:',
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 14,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_isLoadingQuestions)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_questions.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        'No recovery questions configured on this device.',
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: textMuted,
                        ),
                      ),
                    )
                  else
                    for (int i = 0; i < _questions.length; i++) ...[
                      Text(
                        '${i + 1}. ${_questions[i]}',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _answerControllers[i],
                        style: TextStyle(color: textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Answer ${i + 1}',
                          prefixIcon: const Icon(Icons.key, size: 18),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _isRecovering || _questions.isEmpty
                        ? null
                        : _handleQuestionsRecovery,
                    child: _isRecovering
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Recover Vault'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
