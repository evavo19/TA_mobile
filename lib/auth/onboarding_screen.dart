import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Data 3 Slide Onboarding Menggunakan Asset Lokal
  final List<Map<String, String>> _onboardingData = [
    {
      'title': 'Jelajahi Wisata\nIstimewa Jogja',
      'subtitle':
          'Temukan Tugu Jogja, Keraton, Malioboro, Pantai Gunungkidul, dan ratusan destinasi seru di Yogyakarta.',
      'image': 'assets/tugu.jpg',
    },
    {
      'title': 'Pesan E-Tiket\nTanpa Antre',
      'subtitle':
          'Beli tiket wisata tujuanmu secara langsung, cepat, dan praktis dalam satu genggaman.',
      'image': 'assets/keraton.jpg',
    },
    {
      'title': 'Rekomendasi AI\nPemandu Pintar',
      'subtitle':
          'Cari tempat wisata hemat budget, lokasi terdekat, hingga rute jalan kaki dengan Asisten AI.',
      'image': 'assets/pemandangan.jpg',
    },
  ];

  void _onFinish() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF1550B6);
    const darkBlue = Color(0xFF1B3C53);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 1. Gambar Background Asset Full Screen
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemCount: _onboardingData.length,
            itemBuilder: (context, index) {
              final item = _onboardingData[index];
              return Stack(
                children: [
                  Positioned.fill(
                    child: Image.asset(
                      item['image']!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: primaryBlue,
                        child: const Center(
                          child: Icon(Icons.image, size: 64, color: Colors.white),
                        ),
                      ),
                    ),
                  ),

                  // Overlay Biru Tua Halus
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            darkBlue.withAlpha(90),
                            Colors.transparent,
                            darkBlue.withAlpha(51),
                          ],
                          stops: const [0.0, 0.5, 1.0],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          // 2. Card Konten Bawah (Presisi Rapat Layar)
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(28, 32, 28, 36),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(32),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 20,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    _onboardingData[_currentPage]['title']!,
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: darkBlue,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Subtitle
                  Text(
                    _onboardingData[_currentPage]['subtitle']!,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Dots Indicator
                  Row(
                    children: List.generate(
                      _onboardingData.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.only(right: 6),
                        height: 8,
                        width: _currentPage == index ? 24 : 8,
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? primaryBlue
                              : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Navigasi Tombol Kembali & Lanjut/Mulai
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (_currentPage > 0)
                        TextButton(
                          onPressed: () {
                            _pageController.previousPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                          ),
                          child: Text(
                            'Kembali',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        )
                      else
                        const SizedBox.shrink(),

                      ElevatedButton(
                        onPressed: () {
                          if (_currentPage < _onboardingData.length - 1) {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          } else {
                            _onFinish();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryBlue,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 32, vertical: 14),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: Text(
                          _currentPage == _onboardingData.length - 1
                              ? 'Mulai'
                              : 'Lanjut',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 3. Tombol Skip (Lewati) Kanan Atas
          Positioned(
            top: 48,
            right: 20,
            child: GestureDetector(
              onTap: _onFinish,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(77),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Lewati',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}