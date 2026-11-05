import 'package:flutter/material.dart';

import '../features/chatbot.dart';
import '../features/kompas.dart';
import 'eticket_screen.dart';
import 'home_screen.dart';
import 'profil_screen.dart';

class MainScreen extends StatefulWidget {
  final int initialIndex;

  const MainScreen({super.key, this.initialIndex = 0});

  static bool bukaAsistenAI(BuildContext context, String pesan) {
    final state = context.findAncestorStateOfType<_MainScreenState>();
    if (state == null) return false;
    state._pindahKeAsistenAI(pesan);
    return true;
  }

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>
    with SingleTickerProviderStateMixin {
  late int _index;

  late final List<Widget> _pages;

  // Animasi fade saat berganti tab
  late final AnimationController _fadeController;
  late final Animation<double> _fade;

  static const double _notchMargin = 8.0;
  static const double _fabDiameter = 56.0;
  static const double _fabDropOffset = 10.0;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _pages = [
      const HomeScreen(),
      const ETicketScreen(),
      const ChatbotScreen(),
      const PlaceholderProfilScreen(),
    ];

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: 1.0, // tampil penuh saat pertama dibuka
    );
    _fade = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  /// Ganti tab sekaligus memutar animasi fade
  void _setIndex(int i) {
    if (i == _index) return;
    setState(() => _index = i);
    _fadeController.forward(from: 0);
  }

  void _pindahKeAsistenAI(String pesan) {
    _setIndex(2);
    chatbotPesanMasuk.value = pesan;
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF1550B6);

    // Context ini ada di atas Scaffold, jadi viewInsets masih nilai asli keyboard.
    // Saat keyboard terbuka, bar bawah & tombol kompas disembunyikan supaya
    // area halaman (termasuk kotak chat) langsung menempel di atas keyboard.
    final keyboardTerbuka = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      resizeToAvoidBottomInset: false,

      // IndexedStack tetap dipakai supaya state tiap halaman terjaga,
      // dibungkus FadeTransition agar pergantian halaman terasa halus.
      body: FadeTransition(
        opacity: _fade,
        child: IndexedStack(index: _index, children: _pages),
      ),

      floatingActionButton: keyboardTerbuka
          ? null
          : Transform.translate(
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
                  heroTag: null,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CompassScreen(),
                      ),
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

      floatingActionButtonLocation: const _DockedNoSnackBarLocation(),

      floatingActionButtonAnimator: FloatingActionButtonAnimator.noAnimation,

      bottomNavigationBar: keyboardTerbuka
          ? null
          : CustomPaint(
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
                shape: null,
                color: Colors.transparent,
                elevation: 0,
                surfaceTintColor: Colors.transparent,
                padding: EdgeInsets.zero,
                child: SizedBox(
                  height: 54,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildNavItem(
                        Icons.home_rounded,
                        'Beranda',
                        0,
                        primaryColor,
                      ),
                      _buildNavItem(
                        Icons.confirmation_number_rounded,
                        'Tiket Saya',
                        1,
                        primaryColor,
                      ),
                      const SizedBox(width: 48),
                      _buildNavItem(
                        Icons.smart_toy_rounded,
                        'Asisten AI',
                        2,
                        primaryColor,
                      ),
                      _buildNavItem(
                        Icons.person_rounded,
                        'Profil',
                        3,
                        primaryColor,
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildNavItem(
    IconData icon,
    String label,
    int index,
    Color primaryColor,
  ) {
    final isSelected = _index == index;
    final iconColor = isSelected ? primaryColor : Colors.grey.shade400;

    return InkWell(
      onTap: () => _setIndex(index),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Ikon tab terpilih membesar dengan efek membal + naik sedikit
            AnimatedScale(
              scale: isSelected ? 1.25 : 1.0,
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutBack,
              child: AnimatedSlide(
                offset: isSelected ? const Offset(0, -0.08) : Offset.zero,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                child: TweenAnimationBuilder<Color?>(
                  tween: ColorTween(end: iconColor),
                  duration: const Duration(milliseconds: 250),
                  builder: (context, color, _) =>
                      Icon(icon, color: color, size: 24),
                ),
              ),
            ),
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 250),
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? primaryColor : Colors.grey.shade500,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}

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
      canvas.drawPath(
        path,
        Paint()
          ..color = borderColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );
    } else {
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