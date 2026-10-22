import 'package:flutter/material.dart';
import '../features/chatbot.dart';
import '../features/kompas.dart'; // 👈 Import halaman kompas yang baru
import 'eticket_screen.dart';
import 'home_screen.dart';
import 'notifikasi_screen.dart'; // 👈 Import halaman notifikasi
import 'profil_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _index = 0;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      // Tab 0: Beranda
      const HomeScreen(),

      // Tab 1: Tiket Saya
      const ETicketScreen(),

      // Tab 2: Asisten AI
      const ChatbotScreen(),

      // Tab 3: Profil
      const PlaceholderProfilScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF1550B6);

    return Scaffold(
      // Menggunakan IndexedStack agar state halaman tidak hilang saat pindah menu
      body: IndexedStack(index: _index, children: _pages),

      // Tombol Kompas Melayang di Tengah (Diturunkan dan diberi bayangan agar menyatu rapi)
      floatingActionButton: Transform.translate(
        offset: const Offset(0, 16), // 👈 Menurunkan posisi tombol agar pas duduk di dalam mangkuk
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: primaryColor.withAlpha(100),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: FloatingActionButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CompassScreen(),
                ),
              );
            },
            backgroundColor: primaryColor,
            elevation: 0, // Dimatikan karena sudah di-handle oleh Container shadow
            shape: const CircleBorder(),
            child: const Icon(
              Icons.explore_outlined,
              color: Colors.white,
              size: 30,
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

    // Bottom Navigation Bar dengan Lengkungan Mangkuk yang Jelas
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        color: Colors.white,
        elevation: 12,
        child: SizedBox(
          height: 60,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Garis batas atas dengan efek bayangan lembut agar terangkat
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 1,
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(30),
                        blurRadius: 4,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                ),
              ),
              // Menu Navigasi Bawah
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(Icons.home_rounded, 'Beranda', 0, primaryColor),
                  _buildNavItem(Icons.confirmation_number_rounded, 'Tiket Saya', 1, primaryColor),
                  const SizedBox(width: 48), // Spasi tengah untuk kompas
                  _buildNavItem(Icons.smart_toy_rounded, 'Asisten AI', 2, primaryColor),
                  _buildNavItem(Icons.person_rounded, 'Profil', 3, primaryColor),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Widget helper custom untuk item BottomAppBar supaya sejajar dengan Notch
  Widget _buildNavItem(IconData icon, String label, int index, Color primaryColor) {
    bool isSelected = _index == index;

    return InkWell(
      onTap: () => setState(() => _index = index),
      child: Padding(
        padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? primaryColor : Colors.grey.shade400,
              size: 24,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? primaryColor : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}