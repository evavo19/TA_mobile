import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/wisata_model.dart';
import 'detail_wisata_screen.dart';
import 'notifikasi_screen.dart'; // 👈 Import halaman notifikasi

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final supabase = Supabase.instance.client;

  late final Future<List<WisataModel>> _wisataFuture;

  String _searchQuery = '';
  String _selectedCategory = 'Semua';

  final List<String> _categories = [
    'Semua',
    'Alam',
    'Budaya Dan Sejarah',
    'Kuliner',
  ];

  @override
  void initState() {
    super.initState();
    _wisataFuture = _fetchWisata();
  }

  Future<List<WisataModel>> _fetchWisata() async {
    final response = await supabase.from('wisata').select();
    final data = response as List<dynamic>;
    return data
        .map((e) => WisataModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF1550B6);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              pinned: true,
              floating: false,
              elevation: 0,
              backgroundColor: primaryColor,
              automaticallyImplyLeading: false,
              toolbarHeight: 60,
              title: Text(
                'LelunganJogja',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 20,
                ),
              ),
              // 👇 Tombol Icon Notifikasi Ditambahkan di Sini
              actions: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                  tooltip: 'Notifikasi & Izin',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const NotificationScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(70),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  color: primaryColor,
                  child: TextField(
                    onChanged: (value) {
                      setState(() => _searchQuery = value.toLowerCase());
                    },
                    style: GoogleFonts.poppins(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Cari destinasi wisata...',
                      hintStyle: GoogleFonts.poppins(
                        color: Colors.grey.shade400,
                      ),
                      prefixIcon: const Icon(Icons.search, color: primaryColor),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ];
        },
        body: SingleChildScrollView(
          padding: const EdgeInsets.only(top: 20, bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Judul Kategori Wisata
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Text(
                  'Kategori Wisata',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E293B),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Chip Kategori
              SizedBox(
                height: 40,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final category = _categories[index];
                    final isSelected = _selectedCategory == category;
                    return Padding(
                      padding: const EdgeInsets.only(right: 10.0),
                      child: FilterChip(
                        selected: isSelected,
                        label: Text(category),
                        showCheckmark: false,
                        labelStyle: GoogleFonts.poppins(
                          fontSize: 13,
                          color: isSelected
                              ? Colors.white
                              : Colors.grey.shade600,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.w500,
                        ),
                        selectedColor: primaryColor,
                        backgroundColor: Colors.white,
                        elevation: isSelected ? 2 : 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: isSelected
                                ? primaryColor
                                : Colors.grey.shade300,
                          ),
                        ),
                        onSelected: (_) {
                          setState(() => _selectedCategory = category);
                        },
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 24),

              // Judul Rekomendasi Wisata
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Text(
                  'Rekomendasi Wisata',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E293B),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Daftar Wisata
              FutureBuilder<List<WisataModel>>(
                future: _wisataFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40.0),
                        child: CircularProgressIndicator(color: primaryColor),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Text(
                          'Gagal memuat data: ${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(color: Colors.redAccent),
                        ),
                      ),
                    );
                  }

                  final allWisata = snapshot.data ?? [];

                  final filteredWisata = allWisata.where((wisata) {
                    final matchesSearch = wisata.nama.toLowerCase().contains(
                      _searchQuery,
                    );
                    final matchesCategory =
                        _selectedCategory == 'Semua' ||
                        wisata.kategori.toLowerCase() ==
                            _selectedCategory.toLowerCase();
                    return matchesSearch && matchesCategory;
                  }).toList();

                  if (filteredWisata.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40.0),
                        child: Text(
                          'Destinasi wisata tidak ditemukan',
                          style: GoogleFonts.poppins(color: Colors.grey),
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: filteredWisata.length,
                    itemBuilder: (context, index) {
                      final wisata = filteredWisata[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    DetailWisataScreen(wisata: wisata),
                              ),
                            );
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(20),
                                ),
                                child: Image.network(
                                  wisata.gambarUrl,
                                  height: 170,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Container(
                                    height: 170,
                                    color: Colors.grey.shade200,
                                    child: const Icon(
                                      Icons.broken_image_outlined,
                                      size: 48,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            wisata.nama,
                                            style: GoogleFonts.poppins(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: const Color(0xFF1E293B),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFFFBEB),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(
                                                Icons.star_rounded,
                                                color: Color(0xFFF59E0B),
                                                size: 18,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                wisata.rating.toString(),
                                                style: GoogleFonts.poppins(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                  color: const Color(
                                                    0xFF92400E,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      wisata.kategori,
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          wisata.hargaWeekday == 0
                                              ? 'Gratis'
                                              : 'Rp ${wisata.hargaWeekday} / tiket',
                                          style: GoogleFonts.poppins(
                                            color: primaryColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                        Text(
                                          '${wisata.jumlahUlasan} Ulasan',
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            color: Colors.grey.shade400,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}