import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  // Game State
  bool _isPlaying = false;
  bool _isGameOver = false;
  int _score = 0;
  int _timeLeft = 20;
  Timer? _gameTimer;
  Timer? _spawnTimer;

  // Posisi Keranjang (0.0 sampai 1.0)
  double _basketX = 0.5;

  // List Item yang Jatuh
  final List<_FallingItem> _items = [];
  final Random _random = Random();

  void _startGame() {
    setState(() {
      _isPlaying = true;
      _isGameOver = false;
      _score = 0;
      _timeLeft = 20;
      _items.clear();
      _basketX = 0.5;
    });

    // Timer Hitung Mundur Game (20 detik)
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeft > 1) {
        setState(() {
          _timeLeft--;
        });
      } else {
        _endGame();
      }
    });

    // Loop Spawn Item Jatuh & Update Posisi
    _spawnTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!_isPlaying) return;

      setState(() {
        if (_random.nextDouble() < 0.2) {
          _items.add(_FallingItem(
            x: _random.nextDouble(),
            y: 0,
            type: _getRandomItemType(),
            speed: 0.02 + (_random.nextDouble() * 0.02),
          ));
        }

        for (int i = _items.length - 1; i >= 0; i--) {
          _items[i].y += _items[i].speed;

          if (_items[i].y >= 0.85 && _items[i].y <= 0.95) {
            if ((_items[i].x - _basketX).abs() < 0.15) {
              _applyItemScore(_items[i].type);
              _items.removeAt(i);
              continue;
            }
          }

          if (_items[i].y > 1.0) {
            _items.removeAt(i);
          }
        }
      });
    });
  }

  _ItemType _getRandomItemType() {
    double rand = _random.nextDouble();
    if (rand < 0.5) return _ItemType.ticket; // 50% Tiket (+10)
    if (rand < 0.8) return _ItemType.coin;   // 30% Koin (+20)
    return _ItemType.bomb;                   // 20% Bom (-15)
  }

  void _applyItemScore(_ItemType type) {
    switch (type) {
      case _ItemType.ticket:
        _score += 10;
        break;
      case _ItemType.coin:
        _score += 20;
        break;
      case _ItemType.bomb:
        _score = max(0, _score - 15);
        break;
    }
  }

  void _endGame() {
    _gameTimer?.cancel();
    _spawnTimer?.cancel();

    setState(() {
      _isPlaying = false;
      _isGameOver = true;
    });

    _showResultDialog();
  }

  void _showResultDialog() {
    bool isWin = _score >= 60;
    
    // Penentuan Nominal Voucher (Rp 1k - Rp 5k)
    String voucherTitle = 'Potongan Rp 1.000';
    String voucherCode = 'HEMAT1K';

    if (_score >= 500) {
      voucherTitle = 'Potongan Rp 5.000';
      voucherCode = 'SULTAN5K';
    } else if (_score >= 300) {
      voucherTitle = 'Potongan Rp 4.000';
      voucherCode = 'HEMAT4K';
    } else if (_score >= 200) {
      voucherTitle = 'Potongan Rp 3.000';
      voucherCode = 'HEMAT3K';
    } else if (_score >= 100) {
      voucherTitle = 'Potongan Rp 2.000';
      voucherCode = 'HEMAT2K';
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            isWin ? 'Hore! Kamu Menang!' : 'Coba Lagi Yuk!',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: isWin ? const Color(0xFF1550B6) : Colors.redAccent,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Total Skor Kamu:',
                style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey),
              ),
              Text(
                '$_score Poin',
                style: GoogleFonts.poppins(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1550B6),
                ),
              ),
              const SizedBox(height: 12),
              if (isWin) ...[
                Text(
                  'Kamu dapat $voucherTitle tiket wisata!',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6F8FB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF1550B6), width: 1.5),
                  ),
                  child: SelectableText(
                    voucherCode,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: const Color(0xFF1550B6),
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ] else ...[
                Text(
                  'Kumpulkan minimal 60 Poin untuk membuka voucher diskon tiket!',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                      fontSize: 12, color: Colors.grey.shade700),
                ),
              ]
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _startGame();
              },
              child: Text(
                'Main Lagi',
                style: GoogleFonts.poppins(
                    color: const Color(0xFF1550B6),
                    fontWeight: FontWeight.bold),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1550B6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                'Tutup',
                style: GoogleFonts.poppins(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    _spawnTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF1550B6);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: AppBar(
        title: Text(
          'Tangkap Tiket Wisata',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 18,
          ),
        ),
        backgroundColor: primaryColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Panel Informasi Skor & Waktu
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              color: Colors.white,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.stars, color: Colors.amber, size: 28),
                      const SizedBox(width: 6),
                      Text(
                        'Skor: $_score',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Icon(Icons.timer_outlined,
                          color: Colors.redAccent, size: 28),
                      const SizedBox(width: 6),
                      Text(
                        '$_timeLeft dtk',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.redAccent,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Arena Game
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return GestureDetector(
                    onHorizontalDragUpdate: (details) {
                      if (!_isPlaying) return;
                      setState(() {
                        _basketX += details.delta.dx / constraints.maxWidth;
                        _basketX = _basketX.clamp(0.05, 0.95);
                      });
                    },
                    child: Container(
                      width: double.infinity,
                      height: double.infinity,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFFE3F2FD), Colors.white],
                        ),
                      ),
                      child: Stack(
                        children: [
                          if (!_isPlaying)
                            Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.sports_esports_outlined,
                                    size: 80,
                                    color: primaryColor,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Tangkap Tiket & Koin!',
                                    style: GoogleFonts.poppins(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: primaryColor,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 32, vertical: 8),
                                    child: Text(
                                      'Geser tas wisata dengan jarimu. Kumpulkan poin untuk dapatkan potongan harga Rp1.000 - Rp5.000!',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  SizedBox(
                                    width: 200,
                                    height: 50,
                                    child: ElevatedButton(
                                      onPressed: _startGame,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: primaryColor,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(25),
                                        ),
                                      ),
                                      child: Text(
                                        _isGameOver
                                            ? 'MAIN LAGI'
                                            : 'MULAI MAIN',
                                        style: GoogleFonts.poppins(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          if (_isPlaying)
                            ..._items.map((item) {
                              return Positioned(
                                left: item.x * (constraints.maxWidth - 40),
                                top: item.y * (constraints.maxHeight - 40),
                                child: _buildFallingIcon(item.type),
                              );
                            }),

                          if (_isPlaying)
                            Positioned(
                              left: (_basketX * constraints.maxWidth) - 35,
                              top: constraints.maxHeight - 80,
                              child: Container(
                                width: 70,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: primaryColor,
                                  borderRadius: const BorderRadius.only(
                                    bottomLeft: Radius.circular(20),
                                    bottomRight: Radius.circular(20),
                                    topLeft: Radius.circular(8),
                                    topRight: Radius.circular(8),
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 8,
                                      offset: Offset(0, 4),
                                    )
                                  ],
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.shopping_bag_outlined,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallingIcon(_ItemType type) {
    switch (type) {
      case _ItemType.ticket:
        return const Icon(
          Icons.confirmation_number_sharp,
          color: Colors.blueAccent,
          size: 36,
        );
      case _ItemType.coin:
        return const Icon(
          Icons.monetization_on,
          color: Colors.amber,
          size: 36,
        );
      case _ItemType.bomb:
        return const Icon(
          Icons.brightness_7_sharp,
          color: Colors.redAccent,
          size: 36,
        );
    }
  }
}

enum _ItemType { ticket, coin, bomb }

class _FallingItem {
  double x;
  double y;
  _ItemType type;
  double speed;

  _FallingItem({
    required this.x,
    required this.y,
    required this.type,
    required this.speed,
  });
}