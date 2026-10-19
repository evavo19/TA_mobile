import 'package:flutter/material.dart';

//import '../features/chatbot.dart';
import '../models/pesanan_model.dart';
import 'eticket_screen.dart';
import 'home_screen.dart';
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

      // Tab 1: Tiket Saya (Terhubung ke ETicketScreen)
      ETicketScreen(
        pesanan: PesananModel(
          userId: 'user_demo',
          wisataId: 1,
          namaWisata: 'Candi Prambanan',
          tanggalKunjungan: '20/10/2026',
          jumlahTiket: 2,
          totalHarga: 100000,
          mataUang: 'IDR',
          metodePembayaran: 'QRIS',
          qrCode: 'TIC-DEMO-12345',
        ),
      ),

      // Tab 2: Asisten AI
      // const ChatbotScreen(),

      // Tab 3: Profil
      const PlaceholderProfilScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF1550B6);

    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        selectedItemColor: primaryColor,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        onTap: (i) => setState(() => _index = i),
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
            icon: Icon(Icons.smart_toy_rounded),
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
