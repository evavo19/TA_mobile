import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image_picker/image_picker.dart';

import '../models/wisata_model.dart';
import '../screens/detail_wisata_screen.dart';
import '../services/wisata_service.dart' as wisata_svc;

final ValueNotifier<String?> chatbotPesanMasuk = ValueNotifier<String?>(null);

class ChatbotScreen extends StatefulWidget {
  final String? pesanAwal;

  const ChatbotScreen({super.key, this.pesanAwal});

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
  bool _loadingHasImage = false;

  // Cache data wisata supaya tidak query database berulang tiap pesan
  List<Map<String, dynamic>> _wisataCache = [];
  Future<void> _cacheFuture = Future.value();

  Uint8List? _selectedImageBytes;

  double _userLat = -7.7926;
  double _userLng = 110.3658;
  String _currentLocationName = 'Malioboro, Yogyakarta';

  // State untuk efek "mengetik" ala ChatGPT
  Timer? _typeTimer;
  String _typeTarget = ''; // teks lengkap yang sudah diterima dari AI
  int _typeShown = 0; // jumlah karakter yang sudah ditampilkan
  int?
  _streamIndex; // index bubble jawaban AI di _messages (null = belum mulai)

  final List<Map<String, dynamic>> _messages = [
    {
      'isUser': false,
      'text': 'Halo! Aku Asisten AI LelunganJogja. Kamu bisa tanya rekomendasi wisata, atau upload foto wisata biar kubantu kenali lokasi dan harga tiketnya!',
      'cards': <Map<String, dynamic>>[],
      'time': '10:00',
      'imageBytes': null,
    },
  ];

  // Titik tiga "sedang mengetik" tampil selama belum ada teks pertama dari AI
  bool get _showTyping => _isLoading && _streamIndex == null;

  @override
  void initState() {
    super.initState();
    _initGemini();
    _cacheFuture = _loadWisataCache();
    final gps = _initUserGps();

    if (widget.pesanAwal != null) {
      gps.timeout(const Duration(seconds: 3), onTimeout: () {}).whenComplete(
        () {
          if (mounted) _sendMessage(widget.pesanAwal!);
        },
      );
    }

    if (widget.pesanAwal == null) {
      chatbotPesanMasuk.addListener(_onPesanMasuk);
    }
  }

  void _onPesanMasuk() {
    final pesan = chatbotPesanMasuk.value;
    if (pesan == null) return;
    chatbotPesanMasuk.value = null;
    _sendMessage(pesan);
  }

  @override
  void dispose() {
    chatbotPesanMasuk.removeListener(_onPesanMasuk);
    _typeTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _initGemini() {
    _geminiApiKey = dotenv.env['GEMINI_API_KEY'] ?? '';

    _model = GenerativeModel(
      model:
          'gemini-3.1-flash-lite', // kalau "not found", coba 'gemini-3.8-flash'
      apiKey: _geminiApiKey,
      systemInstruction: Content.system(
        'Kamu adalah asisten AI pemandu wisata ramah untuk aplikasi "LelunganJogja". '
        'Setiap pertanyaan dikirim bersama daftar referensi wisata. Setiap baris daftar berisi SEMUA data satu wisata '
        '(nama, kategori, harga tiket, rating, jumlah ulasan, jam buka, deskripsi, jarak dari pengguna, dan data lain). '
        'Gunakan semua data itu untuk menjawab. '
        'Daftar referensi SUDAH disaring oleh aplikasi sesuai filter harga dari pengguna (jika ada), '
        'jadi jangan menyebut wisata di luar daftar dan jangan menyaring ulang harga sendiri. '
        'Jika pengguna mengirimkan foto tempat wisata, analisislah gambar tersebut dan sebutkan nama tempat wisata di Yogyakarta yang paling sesuai dari daftar referensi yang diberikan. '
        'Sebutkan nama tempat dengan jelas di awal jawaban, beserta perkiraan jarak dan harga tiketnya jika relevan. '
        'Wisata dianggap bisa ditempuh jalan kaki jika jaraknya sekitar 2 km atau kurang. '
        'Kamu hanya boleh menjawab pertanyaan yang berkaitan dengan data wisata di daftar referensi (kategori apa pun) dan aplikasi LelunganJogja. '
        'Jika pertanyaan di luar topik itu, jawab persis: "Maaf, pertanyaan Anda di luar topik." tanpa tambahan apa pun. '
        'Jika pertanyaan masih seputar wisata atau aplikasi, jawablah sebisa mungkin dari daftar referensi, walaupun hanya sebagian informasi yang tersedia. '
        'Jawab "Maaf, aku tidak tahu informasi itu." HANYA jika datanya benar-benar tidak ada di daftar referensi, dan jangan mengarang. '
        'Jawablah secara singkat, ramah, dan informatif. '
        'Tulis dengan teks biasa, jangan pakai format markdown seperti tanda bintang atau pagar.',
      ),
    );
  }

  // Memuat data wisata sekali di awal (di background)
  Future<void> _loadWisataCache() async {
    try {
      final data = await wisata_svc.WisataService().getWisataList().timeout(
        const Duration(seconds: 10),
      );
      _wisataCache = data.map((w) => Map<String, dynamic>.from(w)).toList();
      debugPrint('Jumlah wisata di cache: ${_wisataCache.length}');
    } catch (e) {
      debugPrint('Gagal memuat cache wisata: $e');
    }
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
          // Pakai lokasi terakhir (instan); kalau tidak ada, ambil baru
          // dengan akurasi sedang dan batas waktu 5 detik.
          final Position pos =
              await Geolocator.getLastKnownPosition() ??
              await Geolocator.getCurrentPosition(
                locationSettings: const LocationSettings(
                  accuracy: LocationAccuracy.medium,
                  timeLimit: Duration(seconds: 5),
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
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    var p = 0.017453292519943295;
    var c = cos;
    var a =
        0.5 -
        c((lat2 - lat1) * p) / 2 +
        c(lat1 * p) * c(lat2 * p) * (1 - c((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a));
  }

  // ---------------------------------------------------------------------------
  // FILTER HARGA DI KODE (bukan oleh AI)
  // ---------------------------------------------------------------------------
  // Mengambil rentang harga dari teks pengguna. Contoh yang dikenali:
  //  - "15.000 - 30.000", "15000 sampai 30000", "15 ribu - 30 ribu"
  //  - "di bawah 20 ribu", "maksimal 25rb"
  //  - "di atas 10 ribu", "minimal 15rb"
  //  - "tiket 20000", "harga Rp 20.000" (dianggap harga pas)
  ({int? min, int? max}) _parseRentangHarga(String teks) {
    final t = teks.toLowerCase();

    int? parse(String angka, String? satuan) {
      final n = int.tryParse(angka.replaceAll(RegExp(r'[.,]'), ''));
      if (n == null) return null;
      if (satuan != null &&
          (satuan.startsWith('rb') || satuan.startsWith('ribu'))) {
        return n * 1000;
      }
      return n;
    }

    // Rentang: "15.000 - 30.000" / "15 ribu sampai 30 ribu"
    final range = RegExp(
      r'(\d[\d.,]*)\s*(rb|ribu)?\s*(?:-|–|sampai|hingga|s/d|sd)\s*(\d[\d.,]*)\s*(rb|ribu)?',
    ).firstMatch(t);
    if (range != null) {
      final a = parse(range.group(1)!, range.group(2) ?? range.group(4));
      final b = parse(range.group(3)!, range.group(4) ?? range.group(2));
      if (a != null && b != null) {
        return (min: a < b ? a : b, max: a < b ? b : a);
      }
    }

    // Batas atas: "di bawah 20 ribu", "maksimal 25rb"
    final atas = RegExp(
      r'(?:di bawah|dibawah|maks(?:imal)?|kurang dari|<)\s*(?:rp\.?\s*)?(\d[\d.,]*)\s*(rb|ribu)?',
    ).firstMatch(t);
    if (atas != null) {
      return (min: null, max: parse(atas.group(1)!, atas.group(2)));
    }

    // Batas bawah: "di atas 10 ribu", "minimal 15rb"
    final bawah = RegExp(
      r'(?:di atas|diatas|min(?:imal)?|lebih dari|>)\s*(?:rp\.?\s*)?(\d[\d.,]*)\s*(rb|ribu)?',
    ).firstMatch(t);
    if (bawah != null) {
      return (min: parse(bawah.group(1)!, bawah.group(2)), max: null);
    }

    // Harga pas: "tiket 20000", "harga Rp 20.000"
    final pas = RegExp(
      r'(?:tiket|harga|rp\.?)\s*(?:rp\.?\s*)?(\d[\d.,]*)\s*(rb|ribu)?',
    ).firstMatch(t);
    if (pas != null) {
      final n = parse(pas.group(1)!, pas.group(2));
      if (n != null) return (min: n, max: n);
    }

    return (min: null, max: null);
  }

  // Wisata lolos filter jika harga weekday ATAU weekend masuk rentang.
  bool _lolosFilterHarga(Map<String, dynamic> w, int? min, int? max) {
    if (min == null && max == null) return true;

    final weekday = (w['harga_weekday'] as num?)?.toInt() ?? 0;
    final weekend = (w['harga_weekend'] as num?)?.toInt() ?? weekday;

    bool dalamRentang(int harga) {
      if (min != null && harga < min) return false;
      if (max != null && harga > max) return false;
      return true;
    }

    return dalamRentang(weekday) || dalamRentang(weekend);
  }

  // Mengubah satu data wisata jadi satu baris teks berisi SEMUA kolomnya,
  // supaya Gemini punya informasi lengkap (rating, jam buka, deskripsi, dll).
  String _ringkasWisata(Map<String, dynamic> w) {
    const lewati = {
      'id',
      'foto_url',
      'foto_uri',
      'gambar_url',
      'latitude',
      'longitude',
      'created_at',
      'updated_at',
    };
    final bagian = <String>[];
    w.forEach((k, v) {
      if (lewati.contains(k) || v == null) return;
      var s = v.toString().trim();
      if (s.isEmpty) return;
      if (s.length > 250) s = '${s.substring(0, 250)}...';
      bagian.add('$k: $s');
    });
    return '- ${bagian.join(' | ')}';
  }

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
      _selectedImageBytes = null;
      _loadingHasImage = currentImageBytes != null;
      _isLoading = true;
      _streamIndex = null;
      _typeTarget = '';
      _typeShown = 0;
    });

    _scrollToBottom();

    try {
      // Tunggu cache yang sudah berjalan di initState (tidak query ganda).
      // Kalau ternyata kosong (gagal waktu pertama), coba muat sekali lagi.
      await _cacheFuture;
      if (_wisataCache.isEmpty) {
        _cacheFuture = _loadWisataCache();
        await _cacheFuture;
      }

      // Semua wisata disiapkan (tidak dibatasi 20), lengkap dengan jarak & harga.
      final List<Map<String, dynamic>> wisataList = _wisataCache.map((item) {
        final lat = (item['latitude'] as num?)?.toDouble();
        final lng = (item['longitude'] as num?)?.toDouble();
        final rawItem = Map<String, dynamic>.from(item);
        rawItem['jarak'] = (lat == null || lng == null)
            ? '-'
            : '${_calculateDistance(_userLat, _userLng, lat, lng).toStringAsFixed(1)} km';
        rawItem['harga'] = 'Rp ${item['harga_weekday'] ?? 0}';
        rawItem['foto_url'] = item['foto_uri'] ?? item['foto_url'] ?? '';
        return rawItem;
      }).toList();

      // Filter harga dilakukan di kode supaya akurat, bukan oleh Gemini.
      final rentang = _parseRentangHarga(userText);
      final bool adaFilterHarga = rentang.min != null || rentang.max != null;
      final List<Map<String, dynamic>> wisataFiltered = wisataList
          .where((w) => _lolosFilterHarga(w, rentang.min, rentang.max))
          .toList();

      debugPrint(
        'Filter harga: min=${rentang.min}, max=${rentang.max} '
        '-> ${wisataFiltered.length}/${wisataList.length} wisata',
      );

      final List<Part> contentParts = [];
      if (currentImageBytes != null) {
        contentParts.add(DataPart('image/jpeg', currentImageBytes));
      }

      // Aturan sudah ada di systemInstruction; di sini hanya data + pertanyaan.
      final String daftar;
      if (wisataFiltered.isEmpty) {
        daftar = adaFilterHarga
            ? 'Tidak ada wisata yang cocok dengan filter harga dari pengguna.'
            : 'Belum ada data referensi.';
      } else {
        daftar = wisataFiltered.map(_ringkasWisata).join('\n');
      }

      contentParts.add(
        TextPart(
          'Daftar referensi wisata (satu baris = satu wisata, lengkap dengan jarak dari pengguna):\n'
          '$daftar\n\n'
          'Pertanyaan pengguna: "$userText"',
        ),
      );

      // Jawaban datang bertahap (streaming) dan tampil dengan efek mengetik.
      final responseText = await _streamAnswer([Content.multi(contentParts)]);

      if (!mounted) return;

      // Kartu hanya dari wisata yang lolos filter, dan hanya jika NAMA LENGKAP
      // disebut di jawaban (tidak lagi mencocokkan per kata umum seperti "Pantai").
      final lower = responseText.toLowerCase();
      final List<Map<String, dynamic>> matchedCards = wisataFiltered.where((
        item,
      ) {
        final nama = (item['nama'] ?? '').toString().toLowerCase().trim();
        return nama.isNotEmpty && lower.contains(nama);
      }).toList();

      setState(() {
        final i = _streamIndex;
        if (i != null && i < _messages.length) {
          _messages[i]['text'] = responseText;
          _messages[i]['cards'] = matchedCards;
        } else {
          _messages.add({
            'isUser': false,
            'text': responseText.isEmpty
                ? 'Tidak ada respons dari AI.'
                : responseText,
            'cards': matchedCards,
            'time': _getCurrentTime(),
            'imageBytes': null,
          });
        }
      });
    } catch (e) {
      debugPrint("ERROR CHATBOT: $e");
      _typeTimer?.cancel();
      if (!mounted) return;
      final pesanError = (e is TimeoutException)
          ? 'AI terlalu lama merespons. Coba kirim lagi sebentar lagi ya.'
          : (e.toString().contains('503') ||
                e.toString().contains('UNAVAILABLE'))
          ? 'Server AI sedang sibuk. Tunggu beberapa detik lalu coba kirim lagi ya.'
          : 'Maaf, terjadi kendala saat menghubungi AI. Silakan coba lagi.';
      setState(() {
        final i = _streamIndex;
        if (i != null && i < _messages.length) {
          // Jawaban sudah sebagian tampil: tampilkan semua yang sempat diterima.
          _messages[i]['text'] = '$_typeTarget\n\n($pesanError)';
        } else {
          _messages.add({
            'isUser': false,
            'text': pesanError,
            'cards': <Map<String, dynamic>>[],
            'time': _getCurrentTime(),
            'imageBytes': null,
          });
        }
      });
    } finally {
      _typeTimer?.cancel();
      if (mounted) {
        setState(() {
          _isLoading = false;
          _streamIndex = null;
        });
        _scrollToBottom();
      }
    }
  }

  // Menerima jawaban Gemini secara streaming. Bubble jawaban dibuat saat teks
  // pertama datang, lalu teks "diketik" bertahap oleh _typeTimer.
  // Retry hanya dilakukan kalau server sibuk DAN belum ada teks yang tampil.
  Future<String> _streamAnswer(List<Content> content) async {
    const maxAttempts = 2;
    for (var attempt = 1; ; attempt++) {
      try {
        final stream = _model
            .generateContentStream(content)
            .timeout(const Duration(seconds: 40));

        await for (final chunk in stream) {
          if (!mounted) return _typeTarget;
          final t = chunk.text;
          if (t == null || t.isEmpty) continue;
          _typeTarget += t;
          if (_streamIndex == null) _openStreamBubble();
        }
        break;
      } catch (e) {
        final msg = e.toString();
        final isBusy =
            msg.contains('503') ||
            msg.contains('UNAVAILABLE') ||
            msg.contains('429');
        if (_streamIndex != null || !isBusy || attempt >= maxAttempts) {
          rethrow;
        }
        await Future.delayed(const Duration(seconds: 1));
      }
    }

    // Tunggu efek mengetik selesai menampilkan semua teks.
    while (mounted && _typeShown < _typeTarget.length) {
      await Future.delayed(const Duration(milliseconds: 30));
    }
    return _typeTarget;
  }

  void _openStreamBubble() {
    setState(() {
      _messages.add({
        'isUser': false,
        'text': '',
        'cards': <Map<String, dynamic>>[],
        'time': _getCurrentTime(),
        'imageBytes': null,
      });
      _streamIndex = _messages.length - 1;
    });

    _typeTimer?.cancel();
    _typeTimer = Timer.periodic(const Duration(milliseconds: 25), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      final i = _streamIndex;
      final remaining = _typeTarget.length - _typeShown;
      if (i == null || remaining <= 0) return;

      // Makin banyak teks tertunda, makin cepat mengetiknya.
      final step = min(12, max(1, remaining ~/ 10));
      _typeShown += step;

      // Jangan potong emoji (surrogate pair) di tengah.
      if (_typeShown < _typeTarget.length) {
        final cu = _typeTarget.codeUnitAt(_typeShown - 1);
        if (cu >= 0xD800 && cu <= 0xDBFF) _typeShown++;
      }

      setState(() {
        _messages[i]['text'] = _typeTarget.substring(0, _typeShown);
      });
      _jumpToBottom();
    });
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

  // Dipakai saat mengetik: langsung lompat, tanpa animasi, supaya tidak patah-patah.
  void _jumpToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  Widget _buildTypingBubble() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(0),
            bottomRight: Radius.circular(16),
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
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_loadingHasImage)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  'Menganalisis foto...',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            const _TypingDots(),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF1550B6);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: widget.pesanAwal != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              )
            : null,
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
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_showTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= _messages.length) {
                  return _buildTypingBubble();
                }

                final msg = _messages[index];
                final isUser = msg['isUser'];
                final Uint8List? imgBytes = msg['imageBytes'];
                final List<Map<String, dynamic>> cards =
                    List<Map<String, dynamic>>.from(msg['cards'] ?? []);

                return Align(
                  alignment: isUser
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
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
                                    final wisataModel = WisataModel.fromMap(
                                      item,
                                    );
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
                                            errorBuilder:
                                                (context, error, stackTrace) =>
                                                    Container(
                                                      height: 95,
                                                      color:
                                                          Colors.grey.shade300,
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
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildQuickChip(
                  icon: Icons.directions_walk,
                  label: 'Bisa Jalan Kaki',
                  onTap: () => _sendMessage(
                    'Rekomendasi wisata yang bisa ditempuh jalan kaki',
                  ),
                ),
                _buildQuickChip(
                  icon: Icons.attach_money,
                  label: 'Wisata Rp 20.000',
                  onTap: () => _sendMessage(
                    'Rekomendasi wisata dengan tiket 20000 dong',
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.white,
            child: SafeArea(
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.image_outlined,
                      color: Color(0xFF1550B6),
                    ),
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
                          fontSize: 13,
                          color: Colors.grey.shade400,
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF6F8FB),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
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
                      icon: const Icon(
                        Icons.send,
                        color: Colors.white,
                        size: 18,
                      ),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        onPressed: onTap,
      ),
    );
  }
}

// Animasi tiga titik "sedang mengetik" (titik melompat bergantian)
class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final t = (_controller.value - i * 0.15) % 1.0;
            final wave = t < 0.5 ? sin(t * 2 * pi) : 0.0;
            return Transform.translate(
              offset: Offset(0, -4 * wave),
              child: Container(
                width: 7,
                height: 7,
                margin: const EdgeInsets.symmetric(horizontal: 2.5),
                decoration: BoxDecoration(
                  color: Colors.grey.shade500.withValues(
                    alpha: 0.4 + 0.6 * wave,
                  ),
                  shape: BoxShape.circle,
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
