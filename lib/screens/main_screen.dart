import 'package:flutter/material.dart';

import '../features/chatbot.dart';
import '../features/kompas.dart';
import 'eticket_screen.dart';
import 'home_screen.dart';
import 'profil_screen.dart';

class MainScreen extends StatefulWidget {
  /// Tab yang aktif saat pertama dibuka:
  /// 0 = Beranda, 1 = Tiket Saya, 2 = Asisten AI, 3 = Profil
  final int initialIndex;

  const MainScreen({super.key, this.initialIndex = 0});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late int _index;

  late final List<Widget> _pages;

  static const double _notchMargin = 8.0;
  static const double _fabDiameter = 56.0;
  static const double _fabDropOffset = 10.0; // makin besar, makin turun

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
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
      // Mencegah konten dan FAB ikut terdorong ke atas saat keyboard HP muncul
      resizeToAvoidBottomInset: false,

      // IndexedStack agar state halaman tidak hilang saat pindah menu
      body: IndexedStack(index: _index, children: _pages),

      // Tombol Kompas (diturunkan sebesar _fabDropOffset)
      floatingActionButton: Transform.translate(
        offset: const Offset(0, _fabDropOffset),
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
                MaterialPageRoute(builder: (context) => const CompassScreen()),
              );
            },
            backgroundColor: primaryColor,
            elevation: 0,
            shape: const CircleBorder(),
            child: const Icon(
              Icons.explore_outlined,
              color: Colors.white,
              size: 30,
            ),
          ),
        ),
      ),

      // Lokasi custom: tetap menempel di lekukan walau ada SnackBar
      floatingActionButtonLocation: const _DockedNoSnackBarLocation(),

      // Bottom bar: bayangan + isi putih digambar di belakang,
      // garis border digambar di depan. Semua memakai satu path lekukan.
      bottomNavigationBar: CustomPaint(
        painter: _NotchedBarPainter(
          notchMargin: _notchMargin,
          fabDiameter: _fabDiameter,
          fabDropOffset: _fabDropOffset,
          borderColor: Colors.grey.shade300,
          shadowColor: Colors.black.withAlpha(40),
          drawBorder: false,
        ),
        foregroundPainter: _NotchedBarPainter(
          notchMargin: _notchMargin,
          fabDiameter: _fabDiameter,
          fabDropOffset: _fabDropOffset,
          borderColor: Colors.grey.shade300,
          shadowColor: Colors.black.withAlpha(40),
          drawBorder: true,
        ),
        child: BottomAppBar(
          shape: null, // bentuk lekukan ditangani painter
          color: Colors.transparent,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          padding: EdgeInsets.zero,
          child: SizedBox(
            height: 54,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(Icons.home_rounded, 'Beranda', 0, primaryColor),
                _buildNavItem(
                  Icons.confirmation_number_rounded,
                  'Tiket Saya',
                  1,
                  primaryColor,
                ),
                const SizedBox(width: 48), // Spasi tengah untuk tombol kompas
                _buildNavItem(
                  Icons.smart_toy_rounded,
                  'Asisten AI',
                  2,
                  primaryColor,
                ),
                _buildNavItem(Icons.person_rounded, 'Profil', 3, primaryColor),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Item navigasi custom supaya sejajar dengan notch
  Widget _buildNavItem(
    IconData icon,
    String label,
    int index,
    Color primaryColor,
  ) {
    final isSelected = _index == index;

    return InkWell(
      onTap: () => setState(() => _index = index),
      splashColor: Colors.transparent, // Menghilangkan efek gelombang sentuhan
      highlightColor:
          Colors.transparent, // Menghilangkan kotak abu-abu saat diklik
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

/// Lokasi FAB "centerDocked" versi sendiri.
/// Bedanya dengan bawaan Flutter: posisinya TIDAK ikut naik saat SnackBar
/// muncul, jadi tombol kompas selalu pas di lekukan bottom bar.
class _DockedNoSnackBarLocation extends FloatingActionButtonLocation {
  const _DockedNoSnackBarLocation();

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry geometry) {
    final x =
        (geometry.scaffoldSize.width -
            geometry.floatingActionButtonSize.width) /
        2;
    final y =
        geometry.contentBottom - geometry.floatingActionButtonSize.height / 2;
    return Offset(x, y);
  }
}

/// Menggambar bentuk bar dengan lekukan: bayangan + isi putih (di belakang)
/// atau garis border tipis (di depan).
class _NotchedBarPainter extends CustomPainter {
  final double notchMargin;
  final double fabDiameter;
  final double fabDropOffset;
  final Color borderColor;
  final Color shadowColor;
  final bool drawBorder;

  _NotchedBarPainter({
    required this.notchMargin,
    required this.fabDiameter,
    required this.fabDropOffset,
    required this.borderColor,
    required this.shadowColor,
    required this.drawBorder,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Pusat FAB digeser turun sesuai offset
    final fabRect = Rect.fromCenter(
      center: Offset(size.width / 2, fabDropOffset),
      width: fabDiameter,
      height: fabDiameter,
    );

    final path = const CircularNotchedRectangle().getOuterPath(
      Offset.zero & size,
      fabRect.inflate(notchMargin),
    );

    if (drawBorder) {
      // Garis border tipis mengikuti lekukan
      canvas.drawPath(
        path,
        Paint()
          ..color = borderColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );
    } else {
      // Bayangan lembut ke atas, lalu isi bar putih mengikuti lekukan
      canvas.drawShadow(path, shadowColor, 6, false);
      canvas.drawPath(path, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant _NotchedBarPainter old) =>
      old.borderColor != borderColor ||
      old.shadowColor != shadowColor ||
      old.notchMargin != notchMargin ||
      old.fabDiameter != fabDiameter ||
      old.fabDropOffset != fabDropOffset ||
      old.drawBorder != drawBorder;
}
