import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/wisata_model.dart';
import '../services/wisata_service.dart' as wisata_svc;
import 'detail_wisata_screen.dart';

class WisataGratisScreen extends StatefulWidget {
  const WisataGratisScreen({super.key});

  @override
  State<WisataGratisScreen> createState() => _WisataGratisScreenState();
}

class _WisataGratisScreenState extends State<WisataGratisScreen> {
  static const primaryColor = Color(0xFF1550B6);

  late final Future<List<WisataModel>> _wisataFuture;

  @override
  void initState() {
    super.initState();
    _wisataFuture = _fetchWisataGratis();
  }

  /// Online  -> Supabase (lalu disimpan ke SQLite)
  /// Offline -> SQLite lokal
  /// Setelah itu disaring: hanya wisata dengan harga tiket 0 (gratis).
  Future<List<WisataModel>> _fetchWisataGratis() async {
    final data = await wisata_svc.WisataService().getWisataList();
    return data
        .map((e) => WisataModel.fromMap(e))
        .where((w) => w.hargaWeekday == 0)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
   appBar: AppBar(
  backgroundColor: primaryColor,
  elevation: 0,
  centerTitle: true, // samakan dengan layar Terdekat
  leading: IconButton(
    icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
    onPressed: () => Navigator.pop(context),
  ),
  title: Text(
    'Wisata Gratis',
    style: GoogleFonts.poppins(
      fontWeight: FontWeight.bold,
      color: Colors.white,
      fontSize: 18,
    ),
  ),
),
      body: FutureBuilder<List<WisataModel>>(
        future: _wisataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: primaryColor),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Gagal memuat data: ${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(color: Colors.redAccent),
                ),
              ),
            );
          }

          final list = snapshot.data ?? [];

          if (list.isEmpty) {
            return Center(
              child: Text(
                'Belum ada wisata gratis',
                style: GoogleFonts.poppins(color: Colors.grey),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: list.length,
            itemBuilder: (context, index) {
              final wisata = list[index];
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
                        builder: (_) => DetailWisataScreen(wisata: wisata),
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
                        child: CachedNetworkImage(
                          imageUrl: wisata.gambarUrl,
                          height: 170,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            height: 170,
                            color: Colors.grey.shade200,
                          ),
                          errorWidget: (context, url, error) => Container(
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
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    wisata.nama,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF1E293B),
                                    ),
                                  ),
                                ),
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
                                    color: const Color(0xFF92400E),
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
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Gratis',
                                  style: GoogleFonts.poppins(
                                    color: const Color(0xFF10B981),
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
    );
  }
}