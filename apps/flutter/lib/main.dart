import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'services/notification_service.dart';
import 'ui/home_shell.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  try {
    await NotificationService.instance.init();
  } catch (_) {
    // Notifications optional on platforms without plugin channels.
  }
  runApp(const PersonalLifeOsApp());
}

class PersonalLifeOsApp extends StatelessWidget {
  const PersonalLifeOsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Personal Life OS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: const HomeShell(),
    );
  }
}
