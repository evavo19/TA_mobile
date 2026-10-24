
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image_picker/image_picker.dart';
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
  final ImagePicker _picker = ImagePicker();

  late final String _geminiApiKey;
  late final GenerativeModel _model;
  bool _isLoading = false;
  bool _loadingHasImage = false; // untuk teks loading yang sesuai

  // Variabel untuk menampung bytes foto yang di-upload user
  Uint8List? _selectedImageBytes;

  // GPS User Location (Default: Malioboro)
  double _userLat = -7.7926;
  double _userLng = 110.3658;
  String _currentLocationName = 'Malioboro, Yogyakarta';

  final List<Map<String, dynamic>> _messages = [
    {
      'isUser': false,
      'text':
          'Halo! Aku Asisten AI LelunganJogja. Kamu bisa tanya rekomendasi wisata, atau upload foto wisata biar kubantu kenali lokasi dan harga tiketnya!',
      'cards': <Map<String, dynamic>>[],
      'time': '10:00',
      'imageBytes': null,
    }
  ];

  @override
  void initState() {
    super.initState();
    _initGemini();
    _initUserGps();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _initGemini() {
    _geminiApiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
    // (debugPrint API key dihapus supaya key tidak muncul di log)

    // Model terbaru (gemini-1.5-* dan gemini-2.5-flash sudah tidak tersedia untuk user baru)
    _model = GenerativeModel(
      model: 'gemini-3.8-flash',
      apiKey: _geminiApiKey,
      systemInstruction: Content.system(
        'Kamu adalah asisten AI pemandu wisata ramah untuk aplikasi "LelunganJogja". '
        'Jika pengguna mengirimkan foto tempat wisata, analisislah gambar tersebut dan sebutkan nama tempat wisata di Yogyakarta yang paling sesuai dari daftar database yang diberikan. '
        'Kamu hanya boleh menjawab pertanyaan yang berkaitan dengan data wisata di daftar referensi database (kategori apa pun) dan aplikasi LelunganJogja. '
        'Jika pertanyaan di luar topik itu, jawab persis: "Maaf, pertanyaan Anda di luar topik." tanpa tambahan apa pun. '
        'Jika pertanyaan masih seputar wisata atau aplikasi tetapi informasinya tidak ada di daftar referensi, jawab: "Maaf, aku tidak tahu informasi itu." dan jangan mengarang. '
        'Jawablah secara singkat, ramah, dan informatif.',
      ),
    );
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
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
            ),
          );
          if (!mounted) return;
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

  // Fungsi Pilih Gambar dari Galeri atau Kamera
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 800,
        maxHeight: 800,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        if (!mounted) return;
        setState(() {
          _selectedImageBytes = bytes;
        });
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
    }
  }

  // Fungsi Kirim Pesan (Mendukung Teks + Gambar Multimodal yang Aman)
  Future<void> _sendMessage(String text) async {
    if ((text.trim().isEmpty && _selectedImageBytes == null) || _isLoading) {
      return;
    }

    final userText = text.trim().isEmpty
        ? "Tempat wisata apakah ini? Mohon berikan informasi nama tempat, lokasi, dan harga tiketnya."
        : text.trim();

    final currentImageBytes = _selectedImageBytes;

    _messageController.clear();
    setState(() {
      _messages.add({
        'isUser': true,
        'text': userText,
        'cards': <Map<String, dynamic>>[],
        'time': _getCurrentTime(),
        'imageBytes': currentImageBytes,
      });
      _selectedImageBytes = null; // Reset preview setelah dikirim
      _loadingHasImage = currentImageBytes != null;
      _isLoading = true;
    });

    _scrollToBottom();

    try {
      // 1. Ambil data wisata dari Supabase sebagai referensi
      List<Map<String, dynamic>> wisataList = [];
      try {
        final List<dynamic> allData = await Supabase.instance.client
            .from('wisata')
            .select()
            .limit(50);

        wisataList = allData.map((item) {
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
      } catch (dbError) {
        debugPrint("Error fetching Supabase: $dbError");
      }

      // 2. Siapkan Part Content untuk Gemini AI
      List<Part> contentParts = [];

      if (currentImageBytes != null) {
        contentParts.add(DataPart('image/jpeg', currentImageBytes));
      }

      String prompt = '''
Posisi GPS Pengguna saat ini: Latitude $_userLat, Longitude $_userLng.
Pertanyaan Pengguna: "$userText"

Berikut adalah daftar referensi tempat wisata di database Supabase kami:
${wisataList.isEmpty ? "Belum ada data referensi." : wisataList.map((w) => "- Nama: ${w['nama']}, Kategori: ${w['kategori']}, Harga Tiket: ${w['harga']}, Jarak: ${w['jarak']}").join('\n')}

Instruksi untuk AI:
- Jika pengguna mengirim foto, analisislah gambar tersebut dan cari nama tempat yang PALING SESUAI dari daftar referensi di atas.
- Sebutkan nama tempat wisatanya dengan jelas di awal kalimat balasan, beserta perkiraan jarak dan harga tiketnya.
- Jika pertanyaan di luar topik wisata/database/aplikasi LelunganJogja, jawab persis: "Maaf, pertanyaan Anda di luar topik."
- Jika pertanyaan seputar wisata tetapi tidak ada di daftar referensi, jawab: "Maaf, aku tidak tahu informasi itu." Jangan mengarang.
- Jawablah dengan ramah dan natural.
''';

      contentParts.add(TextPart(prompt));

      // 3. Kirim request multimodal ke Gemini Model secara langsung
      final response =
          await _generateWithRetry([Content.multi(contentParts)]);
      String responseText = response.text ?? 'Tidak ada respons dari AI.';

      // 4. Pencocokan Kartu Berdasarkan Nama Tempat di Respon AI
      List<Map<String, dynamic>> matchedCards = [];
      for (var item in wisataList) {
        String namaWisata = item['nama'].toString().toLowerCase();
        List<String> keywords = namaWisata.split(' ');

        bool isKeywordMatch = keywords.any(
            (kw) => kw.length > 3 && responseText.toLowerCase().contains(kw));

        if (responseText.toLowerCase().contains(namaWisata) || isKeywordMatch) {
          if (!matchedCards.contains(item)) {
            matchedCards.add(item);
          }
        }
      }

      // Jika user bertanya soal terdekat via teks/quick chip tanpa foto
      if (matchedCards.isEmpty &&
          currentImageBytes == null &&
          (userText.toLowerCase().contains('terdekat') ||
              userText.toLowerCase().contains('dekat'))) {
        wisataList.sort((a, b) =>
            (a['jarak_num'] as double).compareTo(b['jarak_num'] as double));
        matchedCards = wisataList.take(3).toList();
      }

      if (!mounted) return;
      setState(() {
        _messages.add({
          'isUser': false,
          'text': responseText,
          'cards': matchedCards,
          'time': _getCurrentTime(),
          'imageBytes': null,
        });
      });
    } catch (e) {
      debugPrint("ERROR CHATBOT: $e");
      if (!mounted) return;
      setState(() {
        _messages.add({
          'isUser': false,
          'text': (e.toString().contains('503') ||
                  e.toString().contains('UNAVAILABLE'))
              ? 'Server AI sedang sibuk. Tunggu beberapa detik lalu coba kirim lagi ya.'
              : 'Maaf, terjadi kendala saat menghubungi AI. Silakan coba lagi.',
          'cards': <Map<String, dynamic>>[],
          'time': _getCurrentTime(),
          'imageBytes': null,
        });
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _scrollToBottom();
      }
    }
  }

  // Otomatis coba ulang (maks 3x) kalau server Gemini sedang sibuk (503) / kena limit (429)
  Future<GenerateContentResponse> _generateWithRetry(
      List<Content> content) async {
    const maxAttempts = 3;
    for (var attempt = 1;; attempt++) {
      try {
        return await _model.generateContent(content);
      } catch (e) {
        final msg = e.toString();
        final isBusy = msg.contains('503') ||
            msg.contains('UNAVAILABLE') ||
            msg.contains('429');
        if (!isBusy || attempt >= maxAttempts) rethrow;
        await Future.delayed(Duration(seconds: 2 * attempt));
      }
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
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
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
              mainAxisAlignment: MainAxisAlignment.center,
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
                final Uint8List? imgBytes = msg['imageBytes'];
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
                        // Tampilkan foto jika pesan dari user memuat gambar
                        if (imgBytes != null) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.memory(
                              imgBytes,
                              height: 150,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        Text(
                          msg['text'],
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: isUser ? Colors.white : Colors.black87,
                            height: 1.4,
                          ),
                        ),

                        // Card Carousel Gambar Rekomendasi
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
                                    final wisataModel =
                                        WisataModel.fromMap(item);
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            DetailWisataScreen(
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
                                                    style:
                                                        GoogleFonts.poppins(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                  const Spacer(),
                                                  Text(
                                                    item['harga'] ?? 'Rp 0',
                                                    style:
                                                        GoogleFonts.poppins(
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
                _loadingHasImage
                    ? 'Gemini AI sedang menganalisis gambar & data Supabase...'
                    : 'Gemini AI sedang mencari jawaban dari data Supabase...',
                style: GoogleFonts.poppins(
                    fontSize: 11, color: Colors.grey.shade600),
              ),
            ),

          // Preview Gambar yang Dipilih Sebelum Dikirim
          if (_selectedImageBytes != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.white,
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      _selectedImageBytes!,
                      height: 50,
                      width: 50,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Foto siap dikirim. Ketik pertanyaan atau kirim langsung!',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: () {
                      setState(() {
                        _selectedImageBytes = null;
                      });
                    },
                  ),
                ],
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
                  onTap: () => _sendMessage(
                      'Rekomendasi wisata dengan tiket 20000 dong'),
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

          // Input Bar dengan Tombol Galeri/Kamera di Kiri
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.white,
            child: SafeArea(
              child: Row(
                children: [
                  // Tombol Ikon Upload Foto
                  IconButton(
                    icon: const Icon(Icons.image_outlined,
                        color: Color(0xFF1550B6)),
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        builder: (context) => SafeArea(
                          child: Wrap(
                            children: [
                              ListTile(
                                leading: const Icon(Icons.photo_library),
                                title: const Text('Pilih dari Galeri'),
                                onTap: () {
                                  Navigator.pop(context);
                                  _pickImage(ImageSource.gallery);
                                },
                              ),
                              ListTile(
                                leading: const Icon(Icons.camera_alt),
                                title: const Text('Ambil Foto dari Kamera'),
                                onTap: () {
                                  Navigator.pop(context);
                                  _pickImage(ImageSource.camera);
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      style: GoogleFonts.poppins(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Tanya atau upload foto wisata...',
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