// lib/main.dart
// ignore_for_file: duplicate_import

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'theme/aria_theme.dart';
import 'screens/splash_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/features_screen.dart';
import 'screens/final_step_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/main_shell.dart';
import 'screens/focus_screen.dart';
import 'services/storage_service.dart';
import 'services/notification_service.dart';
import 'services/theme_notifier.dart';
import 'screens/onboarding_screen.dart';
import 'screens/AI_chat_screen.dart';
import 'screens/aria_brief_screen.dart';
import 'services/aria_ai_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── 1. Firebase first ────────────────────────────────────────────────────
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  // ── 2. System UI ─────────────────────────────────────────────────────────
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  // ── 3. Storage + Theme ───────────────────────────────────────────────────
  await StorageService.instance.init();
  if (StorageService.instance.loadDailyBriefOn()) {
    await NotificationService.instance.scheduleDailyBrief(
      hour: StorageService.instance.loadBriefHour(),
      minute: StorageService.instance.loadBriefMinute(),
    );
  }

  
  ThemeNotifier.instance.init();

  // ── 4. Notifications ─────────────────────────────────────────────────────
  await NotificationService.instance.init();

  // Handle notification taps — must be set before requestPermissions

  NotificationService.instance.setOnTapHandler((payload) async {
    if (payload == 'daily_brief') {
      final s = StorageService.instance;
      String brief = s.loadDailyBriefContent();
      if (!s.isBriefReadyToday) {
        brief = await AriaAIService().generateDailyBrief();
        await s.saveDailyBriefContent(brief);
        await s.saveBriefGeneratedDate(
          DateTime.now().toIso8601String().substring(0, 10),
        );
      }
      await s.markBriefHeardToday();
      navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => ARIABriefScreen(brief: brief)),
      );
    }
  });

  await NotificationService.instance.requestPermissions();

  // ── 5. Schedule daily notifications if enabled ───────────────────────────
  if (StorageService.instance.loadNotificationsOn()) {
    await NotificationService.instance.scheduleDailySummary(
      taskCount: StorageService.instance.loadFocusSessions(),
      highPriorityCount: 0,
    );
    await NotificationService.instance.scheduleStreakReminder(
      StorageService.instance.loadStreak(),
    );
  }

  runApp(const ARIAApp());
}

class ARIAApp extends StatefulWidget {
  const ARIAApp({super.key});
  @override
  State<ARIAApp> createState() => _ARIAAppState();
}

class _ARIAAppState extends State<ARIAApp> {
  @override
  void initState() {
    super.initState();
    ThemeNotifier.instance.addListener(_onThemeChanged);
  }

  void _onThemeChanged() => setState(() {});

  @override
  void dispose() {
    ThemeNotifier.instance.removeListener(_onThemeChanged);
    super.dispose();
  }

  ThemeData get _darkTheme => ThemeData.dark().copyWith(
    scaffoldBackgroundColor: AC.bg,
    textTheme: GoogleFonts.spaceGroteskTextTheme(ThemeData.dark().textTheme),
    colorScheme: const ColorScheme.dark(
      primary: AC.purple,
      secondary: AC.purpleDark,
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: AC.purple,
      selectionColor: Color(0x559B6FE8),
      selectionHandleColor: AC.purple,
    ),
  );

  ThemeData get _lightTheme => ThemeData.light().copyWith(
    scaffoldBackgroundColor: const Color(0xFFF5F3FF),
    textTheme: GoogleFonts.spaceGroteskTextTheme(ThemeData.light().textTheme),
    colorScheme: ColorScheme.light(
      primary: AC.purple,
      secondary: AC.purpleDark,
      surface: Colors.white,
    ),
    cardColor: Colors.white,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Color(0xFF1A1035),
      elevation: 0,
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: AC.purple,
      selectionColor: Color(0x559B6FE8),
      selectionHandleColor: AC.purple,
    ),
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ARIA',
      debugShowCheckedModeBanner: false,
      theme: _lightTheme,
      darkTheme: _darkTheme,
      themeMode: ThemeNotifier.instance.themeMode,
      navigatorKey: navigatorKey,
      initialRoute: '/',
      routes: {
        '/': (context) => const ARIASplashScreen(),
        '/welcome': (context) => const WelcomeScreen(),
        '/features': (context) => const FeaturesScreen(),
        '/final': (context) => const FinalStepScreen(),
        '/login': (context) => const ARIALoginScreen(),
        '/signup': (context) => const ARIASignUpScreen(),
        '/onboarding': (context) => const OnboardingScreen(),
        '/focus': (context) => const FocusScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/home') {
          final userName = (settings.arguments as String?) ?? 'User';
          return MaterialPageRoute(
            builder: (_) => MainShell(userName: userName),
          );
        }
        return null;
      },
    );
  }
}
