// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'features_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0B1E),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A1640), Color(0xFF0D0B1E), Color(0xFF080612)],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              SizedBox(height: screenHeight * 0.08),

              SizedBox(
                width: 160,
                height: 160,
                child: Image.asset('assets/aria_logo.png', fit: BoxFit.contain),
              ),

              const SizedBox(height: 14),

              const Text(
                "A R I A",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 6,
                ),
              ),

              const SizedBox(height: 36),

              const Text(
                "Meet ARIA",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),

              const SizedBox(height: 14),

              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 36),
                child: Text(
                  "Your intelligent productivity\nassistant designed for the future\nof work.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF8A86A8),
                    fontSize: 15,
                    height: 1.55,
                  ),
                ),
              ),

              const Spacer(),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _pillBadge(Icons.shield_outlined, "SECURE"),
                  const SizedBox(width: 14),
                  _pillBadge(
                    Icons.bolt,
                    "INSTANT",
                    iconColor: const Color(0xFFB085F5),
                  ),
                ],
              ),

              const SizedBox(height: 22),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const FeaturesScreen()),
                  ),
                  child: Container(
                    width: double.infinity,
                    height: 54,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF7B52E0), Color(0xFF9B72FF)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF7B52E0).withOpacity(0.45),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Text(
                          "Get Started",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(width: 6),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF7B52E0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              const SizedBox(height: 14),

              const Text(
                "PREMIUM AI EXPERIENCE",
                style: TextStyle(
                  color: Color(0xFF3D3A55),
                  fontSize: 10,
                  letterSpacing: 2.5,
                  fontWeight: FontWeight.w500,
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pillBadge(IconData icon, String label, {Color? iconColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withOpacity(0.06),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color: iconColor ?? Colors.white.withOpacity(0.7),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.75),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
