import 'package:flutter/material.dart';

import 'onboarding_screen.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  void _navigateToOnboarding(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const OnboardingScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _navigateToOnboarding(context),
        child: SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40.0),
              child: Image.asset(
                'assets/LelunganJogja.jpg',
                width: 260, // Ukuran logo proporsional
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 180,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1550B6),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.confirmation_number_rounded,
                      size: 72,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
