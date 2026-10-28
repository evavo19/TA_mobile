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

class _MainScreenState extends State<MainScreen> {
  late int _index;

  late final List<Widget> _pages;

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
  }

  void _pindahKeAsistenAI(String pesan) {
    setState(() => _index = 2);
    chatbotPesanMasuk.value = pesan;
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF1550B6);

    return Scaffold(
      
      resizeToAvoidBottomInset: false,

      body: IndexedStack(index: _index, children: _pages),

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

            heroTag: null,
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

      floatingActionButtonLocation: const _DockedNoSnackBarLocation(),

      floatingActionButtonAnimator: FloatingActionButtonAnimator.noAnimation,

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
                _buildNavItem(Icons.home_rounded, 'Beranda', 0, primaryColor),
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
                _buildNavItem(Icons.person_rounded, 'Profil', 3, primaryColor),
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

    return InkWell(
      onTap: () => setState(() => _index = index),
      splashColor: Colors.transparent, 
      highlightColor:
          Colors.transparent, 
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