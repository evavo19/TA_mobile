import 'package:flutter/material.dart';

import 'home_screen.dart'; // Import HomeScreen kamu

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _index = 0;

  // 1. TAMBAHKAN Halaman ke-4 di List _pages ini
  final List<Widget> _pages = const [
    HomeScreen(), // Tab 0: Beranda
    Center(child: Text('Tiket Saya')), // Tab 1: Tiket Saya
    Center(child: Text('Asisten AI')), // Tab 2: Asisten AI
    Center(child: Text('Profil')), // Tab 3: Profil
  ];

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF1550B6);

    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        selectedItemColor: primaryColor,
        unselectedItemColor: Colors.grey,
        // Properti ini penting agar 4 item tampil rapi & berlabel jelas
        type: BottomNavigationBarType.fixed,
        onTap: (i) => setState(() => _index = i),

        // 2. TAMBAHKAN Item ke-4 di List items ini
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: 'Beranda',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.confirmation_number_rounded),
            label: 'Tiket Saya',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.smart_toy_rounded), // Ikon Robot / AI
            label: 'Asisten AI',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_rounded),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
