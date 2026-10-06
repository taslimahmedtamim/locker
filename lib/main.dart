import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/providers.dart';
import 'app/theme.dart';
import 'core/utils/safe_logger.dart';
import 'features/auth/lock_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/vault/main_vault_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Enforce system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const ProviderScope(child: LockerApp()));
}

class LockerApp extends ConsumerStatefulWidget {
  const LockerApp({super.key});

  @override
  ConsumerState<LockerApp> createState() => _LockerAppState();
}

typedef VaultKeyApp = LockerApp;

class _LockerAppState extends ConsumerState<LockerApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      SafeLogger.info(
        'VaultKeyApp',
        'App backgrounded - evaluating auto-lock policy',
      );
      ref.read(authServiceProvider).getAutoLockMinutes().then((minutes) {
        if (minutes == 0) {
          // Lock immediately when backgrounded
          ref.read(authStateProvider.notifier).lockVault();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final authState = ref.watch(authStateProvider);

    return MaterialApp(
      title: 'Locker',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: _buildHomeForStatus(authState.status),
    );
  }

  Widget _buildHomeForStatus(AuthStatus status) {
    switch (status) {
      case AuthStatus.checking:
        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        );
      case AuthStatus.onboardingRequired:
        return const OnboardingScreen();
      case AuthStatus.locked:
        return const LockScreen();
      case AuthStatus.unlocked:
        return const MainVaultScreen();
    }
  }
}
