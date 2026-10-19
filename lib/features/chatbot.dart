/*import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // 1. MASUKKAN GEMINI API KEY KAMU DI SINI
  static const String _geminiApiKey = 'AQ.Ab8RN6L7-On8MzQZBe9NGV392OKuCNmINHmfLabwd4yPSzUCtg';

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
          'Halo! Aku Asisten AI LelunganJogja. Aku bisa memberikan rekomendasi wisata terdekat dari lokasi GPS kamu secara realtime!',
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
    _model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: _geminiApiKey,
      systemInstruction: Content.system(
        'Kamu adalah asisten AI pemandu wisata ramah untuk aplikasi "LelunganJogja". '
        'Jawablah pertanyaan pengguna berdasarkan rekomendasi data tempat wisata Jogja secara singkat, jelas, dan informatif tanpa emoji berlebihan.',
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

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    var p = 0.017453292519943295;
    var c = cos;
    var a = 0.5 -
        c((lat2 - lat1) * p) / 2 +
        c(lat1 * p) * c(lat2 * p) * (1 - c((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a));
  }

  // Fetch dari Supabase berdasarkan Kategori / Terdekat
  Future<List<Map<String, dynamic>>> _getWisataFromSupabase(String query) async {
    try {
      String lowerQuery = query.toLowerCase();
      var dbQuery = Supabase.instance.client.from('wisata').select();

      if (lowerQuery.contains('pantai')) {
        dbQuery = dbQuery.ilike('kategori', '%pantai%');
      } else if (lowerQuery.contains('alam')) {
        dbQuery = dbQuery.ilike('kategori', '%alam%');
      } else if (lowerQuery.contains('budaya') || lowerQuery.contains('sejarah')) {
        dbQuery = dbQuery.ilike('kategori', '%budaya%');
      }

      final List<dynamic> data = await dbQuery;

      List<Map<String, dynamic>> results = data.map((item) {
        double itemLat = (item['latitude'] as num).toDouble();
        double itemLng = (item['longitude'] as num).toDouble();
        double distance = _calculateDistance(_userLat, _userLng, itemLat, itemLng);

        return {
          'nama': item['nama'] ?? '',
          'kategori': item['kategori'] ?? '',
          'rating': (item['rating'] as num?)?.toDouble() ?? 4.5,
          'harga': 'Rp ${item['harga_weekday'] ?? 0}',
          'jarak': '${distance.toStringAsFixed(1)} km',
          'jarak_num': distance,
          'foto_url': item['foto_url'] ?? '',
          'deskripsi': item['deskripsi'] ?? '',
        };
      }).toList();

      results.sort((a, b) => (a['jarak_num'] as double).compareTo(b['jarak_num'] as double));
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

    // 1. Ambil data wisata nyata dari Supabase
    List<Map<String, dynamic>> matchedCards = await _getWisataFromSupabase(userText);

    try {
      // 2. Buat Prompt untuk Gemini dengan Data Supabase + GPS
      String prompt = '''
Posisi GPS Pengguna: Latitude $_userLat, Longitude $_userLng.
Data Tempat Wisata dari Supabase Database:
${matchedCards.map((w) => "- ${w['nama']} (Kategori: ${w['kategori']}, Jarak: ${w['jarak']}, Tiket: ${w['harga']}, Rating: ${w['rating']})").join('\n')}

Pertanyaan Pengguna: "$userText"
Tolong jawab pertanyaan pengguna secara ramah dan rekomendasikan tempat-tempat dari data di atas.
''';

      final response = await _chat.sendMessage(Content.text(prompt));

      setState(() {
        _messages.add({
          'isUser': false,
          'text': response.text ?? 'Berikut rekomendasi wisata untuk Anda:',
          'cards': matchedCards,
          'time': _getCurrentTime(),
        });
      });
    } catch (e) {
      setState(() {
        _messages.add({
          'isUser': false,
          'text': matchedCards.isNotEmpty
              ? 'Berikut beberapa tempat wisata terdekat dari lokasimu:'
              : 'Maaf, gagal memproses rekomendasi saat ini. Pastikan koneksi internet aktif.',
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
        title: Column(
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
                const Icon(Icons.location_on, size: 12, color: Colors.white70),
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
        backgroundColor: primaryColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
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
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
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
                                return Container(
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
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      ClipRRect(
                                        borderRadius: const BorderRadius.vertical(
                                          top: Radius.circular(12),
                                        ),
                                        child: Image.network(
                                          item['foto_url'],
                                          height: 95,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) =>
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
                                              item['nama'],
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
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
                                                  '${item['rating']}',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                const Spacer(),
                                                Text(
                                                  item['harga'],
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: primaryColor,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Jarak: ${item['jarak']}',
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
                style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade600),
              ),
            ),

          // Quick Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildQuickChip(
                  icon: Icons.near_me_outlined,
                  label: 'Wisata Terdekat',
                  onTap: () => _sendMessage('Rekomendasi wisata terdekat dari lokasiku dong'),
                ),
                _buildQuickChip(
                  icon: Icons.park_outlined,
                  label: 'Wisata Alam',
                  onTap: () => _sendMessage('Cari wisata alam terbaik di Jogja'),
                ),
                _buildQuickChip(
                  icon: Icons.beach_access_outlined,
                  label: 'Pantai',
                  onTap: () => _sendMessage('Rekomendasi pantai indah di Jogja'),
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
                        hintText: 'Tanya Gemini AI tentang wisata...',
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
                      icon: const Icon(Icons.send, color: Colors.white, size: 18),
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
}*/