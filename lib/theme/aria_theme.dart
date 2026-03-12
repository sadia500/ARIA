import 'package:flutter/material.dart';

// ─── Colours ────────────────────────────────────────────────────────────────
class AC {
  AC._();
  static const bg         = Color(0xFF0D0B1A); // scaffold background
  static const card       = Color(0xFF13102A); // form cards
  static const input      = Color(0xFF0F0C22); // text field fill
  static const logoBadge  = Color(0xFF1E1530); // small logo badge bg
  static const sso        = Color(0xFF1A1535); // SSO circle bg

  static const purple     = Color(0xFF9B6FE8); // primary accent
  static const purpleDark = Color(0xFF7B4FD4); // darker accent
  static const purpleDeep = Color(0xFF6B3FBF); // gradient end

  // semi-transparent helpers (AARRGGBB)
  static const cardBorder    = Color(0x12FFFFFF); //  7% white
  static const inputBorder   = Color(0x1AFFFFFF); // 10% white
  static const divider       = Color(0x1AFFFFFF); // 10% white
  static const hint          = Color(0x4DFFFFFF); // 30% white
  static const iconTint      = Color(0x66FFFFFF); // 40% white
  static const subText       = Color(0x80FFFFFF); // 50% white
  static const labelText     = Color(0x8CFFFFFF); // 55% white
  static const mutedText     = Color(0x99FFFFFF); // 60% white
  static const bodyText      = Color(0xA6FFFFFF); // 65% white

  static const purpleBorder  = Color(0x667B4FD4); // 40% purple
  static const purpleRing1   = Color(0x267B4FD4); // 15% purple
  static const purpleRing2   = Color(0x337B4FD4); // 20% purple
  static const purpleShadow1 = Color(0x807B4FD4); // 50% purple
  static const purpleShadow2 = Color(0x4D7B4FD4); // 30% purple
  static const purpleShadow3 = Color(0xB37B4FD4); // 70% purple
  static const purpleGlow    = Color(0x664A2B90); // top glow
  static const purpleGlow2   = Color(0x553D1F8A); // signup glow
  static const dotInactive   = Color(0x599B6FE8); // 35% purple
  static const initText      = Color(0xE67B4FD4); // 90% purple
  static const footerA       = Color(0x4DFFFFFF); // 30% white
  static const footerB       = Color(0x33FFFFFF); // 20% white
}

// ─── Gradients ───────────────────────────────────────────────────────────────
class AGrad {
  AGrad._();
  static const logo = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AC.purple, AC.purpleDark],
  );
  static const button = LinearGradient(
    colors: [AC.purple, AC.purpleDeep],
  );
}

// ─── Text Styles ─────────────────────────────────────────────────────────────
class AText {
  AText._();
  static const headline = TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w700, letterSpacing: -0.5);
  static const title    = TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.5);
  static const splashTitle = TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.w800, letterSpacing: 6);
  static const subtitle = TextStyle(color: AC.subText,  fontSize: 14);
  static const splashSub = TextStyle(color: AC.bodyText, fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 3);
  static const fieldLabel = TextStyle(color: AC.labelText, fontSize: 11, letterSpacing: 1.5, fontWeight: FontWeight.w600);
  static const purpleLabel = TextStyle(color: AC.purple,  fontSize: 11, letterSpacing: 1.5, fontWeight: FontWeight.w600);
  static const button = TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.3);
  static const link   = TextStyle(color: AC.purple,   fontSize: 13, fontWeight: FontWeight.w600);
  static const muted  = TextStyle(color: AC.mutedText, fontSize: 13);
  static const tiny   = TextStyle(color: AC.footerA,  fontSize: 10, letterSpacing: 2);
  static const tinier = TextStyle(color: AC.footerB,  fontSize: 9,  letterSpacing: 0.5);
  static const initCore = TextStyle(color: AC.initText, fontSize: 11, letterSpacing: 3, fontWeight: FontWeight.w500);
}

// ─── Box Shadows ─────────────────────────────────────────────────────────────
class AShadow {
  AShadow._();
  static const logoInner = [
    BoxShadow(color: AC.purpleShadow1, blurRadius: 30, spreadRadius: 5),
    BoxShadow(color: AC.purpleShadow2, blurRadius: 60, spreadRadius: 10),
  ];
  static const button = [
    BoxShadow(color: AC.purpleShadow1, blurRadius: 20, offset: Offset(0, 6)),
  ];
  static const sso = [
    BoxShadow(color: AC.purpleRing2, blurRadius: 16, spreadRadius: 1),
  ];
  static const smallLogo = [
    BoxShadow(color: Color(0x737B4FD4), blurRadius: 20, spreadRadius: 2),
  ];
}