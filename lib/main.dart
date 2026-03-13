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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const ARIAApp());
}

class ARIAApp extends StatelessWidget {
  const ARIAApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ARIA',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: AC.bg,
        textTheme: GoogleFonts.spaceGroteskTextTheme(
          ThemeData.dark().textTheme,
        ),
        colorScheme: const ColorScheme.dark(
          primary: AC.purple,
          secondary: AC.purpleDark,
        ),
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: AC.purple,
          selectionColor: Color(0x559B6FE8),
          selectionHandleColor: AC.purple,
        ),
      ),
      initialRoute: '/',
      routes: {
        '/':         (context) => const ARIASplashScreen(),
        '/welcome':  (context) => const WelcomeScreen(),
        '/features': (context) => const FeaturesScreen(),
        '/final':    (context) => const FinalStepScreen(),
        '/login':    (context) => const ARIALoginScreen(),
        '/signup':   (context) => const ARIASignUpScreen(),
      },
    );
  }
}