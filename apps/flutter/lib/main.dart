import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'services/error_log_service.dart';
import 'services/local_analytics.dart';
import 'services/notification_service.dart';
import 'services/offline_runtime.dart';
import 'services/security_service.dart';
import 'ui/home_shell.dart';
import 'ui/lock_screen.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ErrorLogService.instance.install();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  try {
    await NotificationService.instance.init();
  } catch (_) {}
  await SecurityService.instance.load();
  // Local-only maintenance — never waits on a network.
  try {
    await OfflineRuntime.instance.runMaintenance();
  } catch (_) {}
  runApp(const PersonalLifeOsApp());
}

class PersonalLifeOsApp extends StatefulWidget {
  const PersonalLifeOsApp({super.key});

  @override
  State<PersonalLifeOsApp> createState() => _PersonalLifeOsAppState();
}

class _PersonalLifeOsAppState extends State<PersonalLifeOsApp> with WidgetsBindingObserver {
  bool _unlocked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final sec = SecurityService.instance;
    _unlocked = !(sec.lockEnabled && sec.hasPin);
    LocalAnalytics.instance.track('app_open');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      SecurityService.instance.markBackground();
      LocalAnalytics.instance.track('app_background');
    }
    if (state == AppLifecycleState.resumed) {
      LocalAnalytics.instance.track('app_resume');
      OfflineRuntime.instance.runMaintenance();
      if (SecurityService.instance.shouldLockOnResume()) {
        setState(() => _unlocked = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Personal Life OS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: _unlocked
          ? const HomeShell()
          : LockScreen(
              onUnlocked: () {
                LocalAnalytics.instance.track('app_unlock');
                OfflineRuntime.instance.runMaintenance();
                setState(() => _unlocked = true);
              },
            ),
    );
  }
}
