import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── Colours ──────────────────────────────────────────────────────────────────
class AC {
  AC._();
  static const bg         = Color(0xFF0D0B1A);
  static const card       = Color(0xFF13102A);
  static const input      = Color(0xFF0F0C22);
  static const logoBadge  = Color(0xFF1E1530);
  static const sso        = Color(0xFF1A1535);

  static const purple     = Color(0xFF9B6FE8);
  static const purpleDark = Color(0xFF7B4FD4);
  static const purpleDeep = Color(0xFF6B3FBF);
  static const error      = Color(0xFFEF4444);

  static const cardBorder    = Color(0x12FFFFFF);
  static const inputBorder   = Color(0x1AFFFFFF);
  static const divider       = Color(0x1AFFFFFF);
  static const hint          = Color(0x4DFFFFFF);
  static const iconTint      = Color(0x66FFFFFF);
  static const subText       = Color(0x80FFFFFF);
  static const labelText     = Color(0x8CFFFFFF);
  static const mutedText     = Color(0x99FFFFFF);
  static const bodyText      = Color(0xA6FFFFFF);

  static const purpleBorder  = Color(0x667B4FD4);
  static const purpleRing1   = Color(0x267B4FD4);
  static const purpleRing2   = Color(0x337B4FD4);
  static const purpleShadow1 = Color(0x807B4FD4);
  static const purpleShadow2 = Color(0x4D7B4FD4);
  static const purpleShadow3 = Color(0xB37B4FD4);
  static const purpleGlow    = Color(0x664A2B90);
  static const purpleGlow2   = Color(0x553D1F8A);
  static const dotInactive   = Color(0x599B6FE8);
  static const initText      = Color(0xE67B4FD4);
  static const footerA       = Color(0x4DFFFFFF);
  static const footerB       = Color(0x33FFFFFF);
}

// ─── Gradients ────────────────────────────────────────────────────────────────
class AGrad {
  AGrad._();
  static const button = LinearGradient(
    colors: [AC.purple, AC.purpleDeep],
  );
}

// ─── Text Styles — Space Grotesk ──────────────────────────────────────────────
class AText {
  AText._();

  static TextStyle get headline => GoogleFonts.spaceGrotesk(
      color: Colors.white, fontSize: 30,
      fontWeight: FontWeight.w700, letterSpacing: -0.5);

  static TextStyle get title => GoogleFonts.spaceGrotesk(
      color: Colors.white, fontSize: 26,
      fontWeight: FontWeight.w700, letterSpacing: -0.3);

  static TextStyle get subtitle => GoogleFonts.spaceGrotesk(
      color: AC.subText, fontSize: 14,
      fontWeight: FontWeight.w400);

  static TextStyle get fieldLabel => GoogleFonts.spaceGrotesk(
      color: AC.labelText, fontSize: 11,
      letterSpacing: 1.5, fontWeight: FontWeight.w600);

  static TextStyle get purpleLabel => GoogleFonts.spaceGrotesk(
      color: AC.purple, fontSize: 11,
      letterSpacing: 1.5, fontWeight: FontWeight.w600);

  static TextStyle get button => GoogleFonts.spaceGrotesk(
      color: Colors.white, fontSize: 16,
      fontWeight: FontWeight.w600, letterSpacing: 0.3);

  static TextStyle get link => GoogleFonts.spaceGrotesk(
      color: AC.purple, fontSize: 13,
      fontWeight: FontWeight.w600);

  static TextStyle get muted => GoogleFonts.spaceGrotesk(
      color: AC.mutedText, fontSize: 13);

  static TextStyle get tiny => GoogleFonts.spaceGrotesk(
      color: AC.footerA, fontSize: 10, letterSpacing: 2);

  static TextStyle get tinier => GoogleFonts.spaceGrotesk(
      color: AC.footerB, fontSize: 9, letterSpacing: 0.5);

  static TextStyle get splashSub => GoogleFonts.spaceGrotesk(
      color: AC.bodyText, fontSize: 11,
      fontWeight: FontWeight.w500, letterSpacing: 3.5);

  static TextStyle get initCore => GoogleFonts.spaceGrotesk(
      color: AC.initText, fontSize: 11,
      letterSpacing: 3, fontWeight: FontWeight.w500);
}

// ─── Box Shadows ──────────────────────────────────────────────────────────────
class AShadow {
  AShadow._();
  static const button = [
    BoxShadow(color: AC.purpleShadow1, blurRadius: 20, offset: Offset(0, 6)),
  ];
  static const sso = [
    BoxShadow(color: AC.purpleRing2, blurRadius: 16, spreadRadius: 1),
  ];
}