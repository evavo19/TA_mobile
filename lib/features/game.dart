import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sensors_plus/sensors_plus.dart';

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
  int _timeLeft = 15;
  Timer? _gameTimer;
  Timer? _spawnTimer;
  StreamSubscription? _accelerometerSubscription;

  // Target skor untuk menang
  static const int _targetScore = 60;

  // Koin: static agar jumlahnya tetap ada selama aplikasi berjalan
  static int _totalKoin = 0; // total koin yang dimiliki pengguna
  int _koinDidapat = 0; // koin dari permainan ini

  // Posisi Keranjang (0.0 sampai 1.0)
  double _basketX = 0.5;

  // List Item yang Jatuh
  final List<_FallingItem> _items = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _initSensor();
  }

  // Fungsi untuk membaca sensor akselerometer (kemiringan HP)
  void _initSensor() {
    _accelerometerSubscription = accelerometerEventStream().listen((event) {
      if (!_isPlaying) return;

      setState(() {
        // Sumbu Y pada event akselerometer mendeteksi kemiringan kiri-kanan HP
        // Kita kalikan faktor pengali (misal 0.05) agar pergerakan keranjang mulus dan tidak terlalu ngebut
        _basketX -= event.y * 0.04;

        // Batasi agar keranjang tidak keluar layar (antara 0.05 sampai 0.95)
        _basketX = _basketX.clamp(0.05, 0.95);
      });
    });
  }

  void _startGame() {
    setState(() {
      _isPlaying = true;
      _isGameOver = false;
      _score = 0;
      _timeLeft = 15;
      _items.clear();
      _basketX = 0.5;
    });

    // Timer Hitung Mundur Game (15 detik)
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
    _spawnTimer = Timer.periodic(const Duration(milliseconds: 40), (timer) {
      if (!_isPlaying) return;

      setState(() {
        if (_random.nextDouble() < 0.25) {
          _items.add(_FallingItem(
            x: _random.nextDouble(),
            y: 0,
            type: _getRandomItemType(),
            speed: 0.035 + (_random.nextDouble() * 0.025),
          ));
        }

        for (int i = _items.length - 1; i >= 0; i--) {
          _items[i].y += _items[i].speed;

          if (_items[i].y >= 0.85 && _items[i].y <= 0.95) {
            if ((_items[i].x - _basketX).abs() < 0.12) {
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
    if (rand < 0.40) return _ItemType.ticket; // 40% Tiket (+10)
    if (rand < 0.65) return _ItemType.coin; // 25% Koin (+20)
    if (rand < 0.85) return _ItemType.bomb; // 20% Bom (-20)
    return _ItemType.zonk; // 15% Zonk (-30)
  }

  void _applyItemScore(_ItemType type) {
    setState(() {
      switch (type) {
        case _ItemType.ticket:
          _score += 10;
          break;
        case _ItemType.coin:
          _score += 20;
          break;
        case _ItemType.bomb:
          _score = max(0, _score - 20);
          break;
        case _ItemType.zonk:
          _score = max(0, _score - 30);
          break;
      }
    });
  }

  void _endGame() {
    _gameTimer?.cancel();
    _spawnTimer?.cancel();

    // Skor akhir dikonversi menjadi koin lalu ditambahkan ke total koin
    _koinDidapat = _score;
    _totalKoin += _koinDidapat;

    setState(() {
      _isPlaying = false;
      _isGameOver = true;
    });

    _showResultDialog();
  }

  void _showResultDialog() {
    bool isWin = _score >= _targetScore;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Column(
            children: [
              Icon(
                isWin
                    ? Icons.emoji_events_rounded
                    : Icons.sentiment_very_dissatisfied_rounded,
                color: isWin ? Colors.amber : Colors.redAccent,
                size: 52,
              ),
              const SizedBox(height: 8),
              Text(
                isWin ? 'Luar Biasa! Menang! 🎉' : 'Kena Zonk! Gagal! 💥',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: isWin ? const Color(0xFF1550B6) : Colors.redAccent,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isWin
                    ? 'Hebat banget! Kamu berhasil lolos dari Bom & Zonk serta tembus target $_targetScore poin.'
                    : 'Wah, skor kamu belum cukup atau kena jebakan Zonk/Bom! Targetnya $_targetScore poin.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F8FB),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text(
                      'Total Skor Akhir',
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: Colors.grey),
                    ),
                    Text(
                      '$_score Poin',
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color:
                            isWin ? const Color(0xFF1550B6) : Colors.redAccent,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (_koinDidapat > 0) ...[
                Text(
                  'Kamu mendapatkan:',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.monetization_on,
                        color: Colors.amber, size: 26),
                    const SizedBox(width: 6),
                    Text(
                      '+$_koinDidapat Koin',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber.shade800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: Colors.amber.shade400, width: 1.5),
                  ),
                  child: Text(
                    'Total koin kamu: $_totalKoin',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.amber.shade900,
                    ),
                  ),
                ),
              ] else ...[
                Text(
                  'Skor kamu 0, jadi belum ada koin yang didapat. Hati-hati dengan Bom dan Zonk!',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                      fontSize: 11, color: Colors.grey.shade700),
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
                'Coba Lagi',
                style: GoogleFonts.poppins(
                  color: const Color(0xFF1550B6),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isWin ? const Color(0xFF1550B6) : Colors.grey.shade700,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Selesai',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
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
    _accelerometerSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF1550B6);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: AppBar(
        title: Text(
          'Tangkap Tiket',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 16,
          ),
        ),
        backgroundColor: primaryColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        // Menampilkan total koin yang dimiliki pengguna
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Row(
              children: [
                const Icon(Icons.monetization_on,
                    color: Colors.amber, size: 22),
                const SizedBox(width: 4),
                Text(
                  '$_totalKoin',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
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
                        'Skor: $_score / Target: $_targetScore',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
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
                  return Container(
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
                                  Icons.screen_rotation_outlined,
                                  size: 80,
                                  color: primaryColor,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Miringkan HP untuk Menangkap!',
                                  style: GoogleFonts.poppins(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: primaryColor,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 32, vertical: 8),
                                  child: Text(
                                    'Pegang HP dan miringkan ke kiri/kanan untuk menggerakkan keranjang. Kumpulkan skor setinggi mungkin untuk mendapatkan koin!',
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
                                          : 'MULAI TANTANGAN',
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
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
                            left: (_basketX * constraints.maxWidth) - 30,
                            top: constraints.maxHeight - 80,
                            child: Container(
                              width: 60,
                              height: 45,
                              decoration: BoxDecoration(
                                color: primaryColor,
                                borderRadius: const BorderRadius.only(
                                  bottomLeft: Radius.circular(16),
                                  bottomRight: Radius.circular(16),
                                  topLeft: Radius.circular(6),
                                  topRight: Radius.circular(6),
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
                                  size: 28,
                                ),
                              ),
                            ),
                          ),
                      ],
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
          size: 34,
        );
      case _ItemType.coin:
        return const Icon(
          Icons.monetization_on,
          color: Colors.amber,
          size: 34,
        );
      case _ItemType.bomb:
        return const Icon(
          Icons.local_fire_department,
          color: Colors.deepOrange,
          size: 36,
        );
      case _ItemType.zonk:
        return const Icon(
          Icons.cancel,
          color: Colors.red,
          size: 36,
        );
    }
  }
}

enum _ItemType { ticket, coin, bomb, zonk }

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