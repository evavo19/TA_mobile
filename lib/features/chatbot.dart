import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Import model dan screen detail wisata
import '../models/wisata_model.dart';
import '../screens/detail_wisata_screen.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  late final String _geminiApiKey;
  late final GenerativeModel _model;
  late final ChatSession _chat;
  bool _isLoading = false;

  // GPS User Location (Default: Malioboro)
  double _userLat = -7.7926;
  double _userLng = 110.3658;
  String _currentLocationName = 'Malioboro, Yogyakarta';

  final List<Map<String, dynamic>> _messages = [
    {
      'isUser': false,
      'text':
          'Halo! Aku Asisten AI LelunganJogja. Mau cari rekomendasi wisata sesuai budget, lokasi terdekat, yang bisa dijalanin kaki, atau kategori favoritmu?',
      'cards': <Map<String, dynamic>>[],
      'time': '10:00',
    }
  ];

  @override
  void initState() {
    super.initState();
    _initGemini();
    _initUserGps();
  }

  void _initGemini() {
    _geminiApiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
    _model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: _geminiApiKey,
      systemInstruction: Content.system(
        'Kamu adalah asisten AI pemandu wisata ramah untuk aplikasi "LelunganJogja". '
        'Jawablah pertanyaan pengguna berdasarkan rekomendasi data tempat wisata Jogja yang diberikan secara singkat, jelas, ramah, dan informatif tanpa emoji berlebihan.',
      ),
    );
    _chat = _model.startChat();
  }

  Future<void> _initUserGps() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.whileInUse ||
            permission == LocationPermission.always) {
          Position pos = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
          );
          setState(() {
            _userLat = pos.latitude;
            _userLng = pos.longitude;
            _currentLocationName = 'Lokasi GPS Anda';
          });
        }
      }
    } catch (_) {}
  }

  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    var p = 0.017453292519943295;
    var c = cos;
    var a = 0.5 -
        c((lat2 - lat1) * p) / 2 +
        c(lat1 * p) * c(lat2 * p) * (1 - c((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a));
  }

  // Parser Budget, Jalan Kaki, & Filter Dinamis Supabase
  Future<List<Map<String, dynamic>>> _getWisataFromSupabase(
      String query) async {
    try {
      String lowerQuery = query.toLowerCase();
      var dbQuery = Supabase.instance.client.from('wisata').select();

      // 1. PARSING HARGA / BUDGET DARI TEKS USER
      int? maxBudget;
      final RegExp regExpAngka = RegExp(r'(\d+[\.\d]*)\s*(rb|ribu)?');
      final match = regExpAngka.firstMatch(lowerQuery);

      if (match != null) {
        String angkaStr = match.group(1)!.replaceAll('.', '');
        int baseVal = int.tryParse(angkaStr) ?? 0;
        bool hasRb = match.group(2) != null;

        if (hasRb) {
          maxBudget = baseVal * 1000;
        } else if (baseVal < 1000 && baseVal > 0) {
          maxBudget = baseVal * 1000;
        } else {
          maxBudget = baseVal;
        }
      } else if (lowerQuery.contains('gratis')) {
        maxBudget = 0;
      } else if (lowerQuery.contains('murah')) {
        maxBudget = 10000;
      }

      if (maxBudget != null) {
        if (maxBudget > 0) {
          // Jika user menyebutkan angka budget (>0), filter harga Rp 1.000 s/d maxBudget
          dbQuery = dbQuery
              .gte('harga_weekday', 1000)
              .lte('harga_weekday', maxBudget);
        } else {
          // Jika user spesifik mencari yang "gratis", ambil harga_weekday = 0
          dbQuery = dbQuery.eq('harga_weekday', 0);
        }
      }

      // 2. PARSING LOKASI DAERAH
      if (lowerQuery.contains('bantul') ||
          lowerQuery.contains('imogiri') ||
          lowerQuery.contains('piyungan')) {
        dbQuery = dbQuery.ilike('deskripsi', '%bantul%');
      } else if (lowerQuery.contains('sleman') ||
          lowerQuery.contains('kaliurang')) {
        dbQuery = dbQuery.ilike('deskripsi', '%sleman%');
      } else if (lowerQuery.contains('gunungkidul') ||
          lowerQuery.contains('wonosari')) {
        dbQuery = dbQuery.ilike('deskripsi', '%gunungkidul%');
      }

      // 3. PARSING KATEGORI
      if (lowerQuery.contains('pantai')) {
        dbQuery = dbQuery.ilike('kategori', '%pantai%');
      } else if (lowerQuery.contains('alam')) {
        dbQuery = dbQuery.ilike('kategori', '%alam%');
      } else if (lowerQuery.contains('budaya') ||
          lowerQuery.contains('sejarah') ||
          lowerQuery.contains('candi') ||
          lowerQuery.contains('museum')) {
        dbQuery = dbQuery.ilike('kategori', '%budaya%');
      }

      final List<dynamic> data = await dbQuery;

      List<Map<String, dynamic>> results = data.map((item) {
        double itemLat = (item['latitude'] as num?)?.toDouble() ?? 0.0;
        double itemLng = (item['longitude'] as num?)?.toDouble() ?? 0.0;
        double distance =
            _calculateDistance(_userLat, _userLng, itemLat, itemLng);

        Map<String, dynamic> rawItem = Map<String, dynamic>.from(item);

        rawItem['jarak'] = '${distance.toStringAsFixed(1)} km';
        rawItem['jarak_num'] = distance;
        rawItem['harga'] = 'Rp ${item['harga_weekday'] ?? 0}';

        return rawItem;
      }).toList();

      // 4. PARSING "JALAN KAKI" / DESTINASI SANGAT DEKAT (<= 1.5 KM)
      bool isWalk = lowerQuery.contains('jalan kaki') ||
          lowerQuery.contains('ditempuh jalan') ||
          lowerQuery.contains('jalan aja') ||
          lowerQuery.contains('jalan santai') ||
          lowerQuery.contains('dekat banget');

      if (isWalk) {
        results = results
            .where((item) => (item['jarak_num'] as double) <= 1.5)
            .toList();
      }

      // 5. URUTKAN HASIL
      if (maxBudget != null && maxBudget > 0) {
        // Urutkan dari harga tertinggi mendekati budget pengguna
        results.sort((a, b) => ((b['harga_weekday'] ?? 0) as int)
            .compareTo((a['harga_weekday'] ?? 0) as int));
      } else {
        // Urutkan berdasarkan jarak terdekat
        results.sort((a, b) =>
            (a['jarak_num'] as double).compareTo(b['jarak_num'] as double));
      }

      return results.take(4).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty || _isLoading) return;

    final userText = text.trim();
    _messageController.clear();

    setState(() {
      _messages.add({
        'isUser': true,
        'text': userText,
        'cards': <Map<String, dynamic>>[],
        'time': _getCurrentTime(),
      });
      _isLoading = true;
    });

    _scrollToBottom();

    // 1. Ambil data wisata terpilih dari Supabase
    List<Map<String, dynamic>> matchedCards =
        await _getWisataFromSupabase(userText);

    try {
      // 2. Buat Context Prompt untuk Gemini AI
      String prompt = '''
Posisi GPS Pengguna saat ini: Latitude $_userLat, Longitude $_userLng.
Pertanyaan Pengguna: "$userText"

Berikut adalah daftar tempat wisata dari Database Supabase yang SESUAI dengan kriteria/budget/jarak pengguna:
${matchedCards.isEmpty ? "Tidak ditemukan tempat wisata yang sesuai persis dengan kriteria tersebut." : matchedCards.map((w) => "- ${w['nama']} (Kategori: ${w['kategori']}, Jarak: ${w['jarak']}, Harga Tiket: ${w['harga']}, Rating: ${w['rating']})").join('\n')}

Instruksi untuk AI:
- Jawablah pertanyaan pengguna secara ramah dan natural.
- Jika ada hasil wisata di atas, rekomendasikan nama tempat tersebut beserta info jarak/harganya.
- Jika tidak ada hasil yang sesuai, jawab dengan sopan bahwa belum ada tempat wisata yang cocok di database.
''';

      final response = await _chat.sendMessage(Content.text(prompt));

      setState(() {
        _messages.add({
          'isUser': false,
          'text': response.text ??
              'Berikut rekomendasi tempat wisata yang sesuai untuk Anda:',
          'cards': matchedCards,
          'time': _getCurrentTime(),
        });
      });
    } catch (e) {
      setState(() {
        _messages.add({
          'isUser': false,
          'text': matchedCards.isNotEmpty
              ? 'Berikut rekomendasi destinasi yang sesuai dengan pencarianmu:'
              : 'Maaf, terjadi masalah saat memproses permintaan. Pastikan koneksi internet aktif.',
          'cards': matchedCards,
          'time': _getCurrentTime(),
        });
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  String _getCurrentTime() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF1550B6);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: AppBar(
        automaticallyImplyLeading: false, // Tanpa panah back
        title: Align(
          alignment: Alignment.centerLeft, // Teks rata kiri
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Asisten AI Wisata',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.location_on, size: 11, color: Colors.white70),
                  const SizedBox(width: 4),
                  Text(
                    _currentLocationName,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        backgroundColor: primaryColor,
        elevation: 0,
      ),
      body: Column(
        children: [
          // List Messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['isUser'];
                final List<Map<String, dynamic>> cards =
                    List<Map<String, dynamic>>.from(msg['cards'] ?? []);

                return Align(
                  alignment:
                      isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(14),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.85,
                    ),
                    decoration: BoxDecoration(
                      color: isUser ? primaryColor : Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(isUser ? 16 : 0),
                        bottomRight: Radius.circular(isUser ? 0 : 16),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(10),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          msg['text'],
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: isUser ? Colors.white : Colors.black87,
                            height: 1.4,
                          ),
                        ),

                        // Card Carousel Gambar
                        if (cards.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 195,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: cards.length,
                              itemBuilder: (context, cardIndex) {
                                final item = cards[cardIndex];
                                return GestureDetector(
                                  onTap: () {
                                    // Konversi Map ke WisataModel
                                    final wisataModel = WisataModel.fromMap(item);

                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => DetailWisataScreen(
                                          wisata: wisataModel,
                                        ),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    width: 200,
                                    margin: const EdgeInsets.only(right: 12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF6F8FB),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.grey.shade200,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        ClipRRect(
                                          borderRadius:
                                              const BorderRadius.vertical(
                                            top: Radius.circular(12),
                                          ),
                                          child: Image.network(
                                            item['foto_url'] ?? '',
                                            height: 95,
                                            width: double.infinity,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error,
                                                    stackTrace) =>
                                                Container(
                                              height: 95,
                                              color: Colors.grey.shade300,
                                              child: const Icon(
                                                Icons.landscape,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item['nama'] ?? '',
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow.ellipsis,
                                                style: GoogleFonts.poppins(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  const Icon(
                                                    Icons.star,
                                                    size: 14,
                                                    color: Colors.amber,
                                                  ),
                                                  const SizedBox(width: 2),
                                                  Text(
                                                    '${item['rating'] ?? 4.5}',
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                  const Spacer(),
                                                  Text(
                                                    item['harga'] ?? 'Rp 0',
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: primaryColor,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                'Jarak: ${item['jarak'] ?? '0.0 km'}',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 10,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                            ],
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

                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.bottomRight,
                          child: Text(
                            msg['time'],
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              color: isUser ? Colors.white70 : Colors.grey,
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

          if (_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6.0),
              child: Text(
                'Gemini AI sedang mengambil data Supabase & berpikir...',
                style: GoogleFonts.poppins(
                    fontSize: 11, color: Colors.grey.shade600),
              ),
            ),

          // Quick Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildQuickChip(
                  icon: Icons.directions_walk,
                  label: 'Bisa Jalan Kaki',
                  onTap: () => _sendMessage(
                      'Rekomendasi wisata yang bisa ditempuh jalan kaki'),
                ),
                _buildQuickChip(
                  icon: Icons.attach_money,
                  label: 'Wisata Rp 20.000',
                  onTap: () =>
                      _sendMessage('Rekomendasi wisata dengan tiket 20000 dong'),
                ),
                _buildQuickChip(
                  icon: Icons.near_me_outlined,
                  label: 'Wisata Terdekat',
                  onTap: () => _sendMessage(
                      'Rekomendasi wisata terdekat dari lokasiku'),
                ),
              ],
            ),
          ),

          // Input Bar
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.white,
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      style: GoogleFonts.poppins(fontSize: 14),
                      decoration: InputDecoration(
                        hintText:
                            'Tanya budget, jalan kaki, wisata terdekat...',
                        hintStyle: GoogleFonts.poppins(
                            fontSize: 13, color: Colors.grey.shade400),
                        filled: true,
                        fillColor: const Color(0xFFF6F8FB),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: _sendMessage,
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: primaryColor,
                    radius: 22,
                    child: IconButton(
                      icon: const Icon(Icons.send,
                          color: Colors.white, size: 18),
                      onPressed: () => _sendMessage(_messageController.text),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ActionChip(
        avatar: Icon(icon, size: 16, color: const Color(0xFF1550B6)),
        label: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: const Color(0xFF1550B6),
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: Colors.white,
        side: const BorderSide(color: Color(0xFF1550B6), width: 1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        onPressed: onTap,
      ),
    );
  }
}