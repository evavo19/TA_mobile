import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PlaceholderChatbotScreen extends StatefulWidget {
  const PlaceholderChatbotScreen({super.key});

  @override
  State<PlaceholderChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<PlaceholderChatbotScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Lokasi Simulasi User
  String _currentLocationName = 'Malioboro, Yogyakarta';

  // Sample Dataset Wisata Alam dari CSV
  final List<Map<String, dynamic>> _sampleWisataAlam = [
    {
      'nama': 'Taman Tempuran Cikal',
      'kategori': 'Alam',
      'rating': 4.4,
      'harga': 'Rp 5.000',
      'jarak': '6.5 km',
      'foto_url':
          'https://res.cloudinary.com/dfciqrwpe/image/upload/v1749301634/Taman_Tempuran_Cikal_y9ongb.jpg',
      'deskripsi':
          'Taman alam di Piyungan dengan wahana kano, speed boat, & area outbound di pertemuan dua sungai.',
    },
    {
      'nama': 'Selopamioro Adventure Park',
      'kategori': 'Alam',
      'rating': 4.5,
      'harga': 'Rp 30.000',
      'jarak': '18.2 km',
      'foto_url':
          'https://res.cloudinary.com/dfciqrwpe/image/upload/v1749368364/selopamioro-adventure_qhctxz.jpg',
      'deskripsi':
          'Aktivitas outbound & permainan air di tepi sungai Imogiri yang memanjakan pengunjung.',
    },
    {
      'nama': 'Tebing Gunung Gajah',
      'kategori': 'Alam',
      'rating': 4.5,
      'harga': 'Rp 5.000',
      'jarak': '25.0 km',
      'foto_url':
          'https://res.cloudinary.com/dfciqrwpe/image/upload/v1748937502/Tebing-Gunung-Gajah_wuodco.jpg',
      'deskripsi':
          'Spot foto perbukitan Menoreh yang hijau dengan pemandangan Waduk Sermo di tengahnya.',
    },
  ];

  // Sample Data Pantai
  final Map<String, dynamic> _samplePantai = {
    'nama': 'Pantai Indrayanti',
    'kategori': 'Pantai',
    'rating': 4.6,
    'harga': 'Rp 10.000',
    'jarak': '45.0 km',
    'foto_url':
        'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=500',
    'deskripsi': 'Pantai pasir putih bersih dengan restoran & gazebo di tepi laut Gunungkidul.',
  };

  // List Chat Messages
  final List<Map<String, dynamic>> _messages = [
    {
      'isUser': false,
      'text':
          'Halo! Aku Asisten AI LelunganJogja. Mau cari rekomendasi wisata terdekat atau sesuai kategori favoritmu?',
      'cards': <Map<String, dynamic>>[],
      'time': '10:00',
    }
  ];

  void _sendMessage(String text) {
    if (text.trim().isEmpty) return;

    setState(() {
      _messages.add({
        'isUser': true,
        'text': text,
        'cards': <Map<String, dynamic>>[],
        'time': _getCurrentTime(),
      });
    });

    _messageController.clear();
    _scrollToBottom();

    // Simulasi respon AI
    Future.delayed(const Duration(milliseconds: 600), () {
      _generateAiResponse(text);
    });
  }

  void _generateAiResponse(String query) {
    String lowerQuery = query.toLowerCase();
    String responseText = '';
    List<Map<String, dynamic>> matchedCards = [];

    if (lowerQuery.contains('pantai')) {
      responseText =
          'Berikut rekomendasi pantai pasir putih populer di Jogja untuk Anda:';
      matchedCards = [_samplePantai];
    } else if (lowerQuery.contains('lokasi') || lowerQuery.contains('terdekat')) {
      responseText =
          'Berdasarkan lokasimu di $_currentLocationName, berikut rekomendasi wisata terdekat:';
      matchedCards = [_sampleWisataAlam[0], _sampleWisataAlam[1]];
    } else if (lowerQuery.contains('alam')) {
      responseText =
          'Berikut rekomendasi wisata alam sejuk dan hits di Jogja:';
      matchedCards = _sampleWisataAlam;
    } else {
      responseText =
          'Kamu bisa memilih atau mengetik kategori wisata seperti Wisata Alam, Pantai, atau Wisata Terdekat.';
    }

    setState(() {
      _messages.add({
        'isUser': false,
        'text': responseText,
        'cards': matchedCards,
        'time': _getCurrentTime(),
      });
    });

    _scrollToBottom();
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

  void _changeLocationDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return SimpleDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Atur Lokasi Anda',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          children: [
            _buildLocationOption('Malioboro, Yogyakarta'),
            _buildLocationOption('Tugu Jogja, Sleman'),
            _buildLocationOption('Imogiri, Bantul'),
            _buildLocationOption('Wonosari, Gunungkidul'),
          ],
        );
      },
    );
  }

  Widget _buildLocationOption(String locationName) {
    return SimpleDialogOption(
      onPressed: () {
        setState(() {
          _currentLocationName = locationName;
        });
        Navigator.pop(context);
        _sendMessage('Sekarang saya di $locationName, rekomendasi wisata terdekat dong');
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children: [
            const Icon(Icons.location_on, color: Color(0xFF1550B6), size: 20),
            const SizedBox(width: 10),
            Text(
              locationName,
              style: GoogleFonts.poppins(fontSize: 14),
            ),
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
            InkWell(
              onTap: _changeLocationDialog,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.location_on, size: 12, color: Colors.white70),
                  const SizedBox(width: 4),
                  Text(
                    _currentLocationName,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.white70,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: primaryColor,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // List Chat
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
                        // Teks Pesan
                        Text(
                          msg['text'],
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: isUser ? Colors.white : Colors.black87,
                            height: 1.4,
                          ),
                        ),

                        // Card Carousel Gambar Wisata
                        if (cards.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 200,
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
                                          height: 100,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) =>
                                                  Container(
                                            height: 100,
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

          // Quick Suggestion Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildQuickChip(
                  icon: Icons.near_me_outlined,
                  label: 'Wisata Terdekat',
                  onTap: () {
                    _sendMessage('Rekomendasi wisata terdekat dari lokasiku dong');
                  },
                ),
                _buildQuickChip(
                  icon: Icons.park_outlined,
                  label: 'Wisata Alam',
                  onTap: () {
                    _sendMessage('Cari wisata alam di Jogja');
                  },
                ),
                _buildQuickChip(
                  icon: Icons.beach_access_outlined,
                  label: 'Pantai',
                  onTap: () {
                    _sendMessage('Rekomendasi pantai indah di Jogja');
                  },
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
                        hintText: 'Tanya wisata atau ketik lokasi...',
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
}