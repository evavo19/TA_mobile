import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_model.dart';
import '../models/wisata_model.dart';
import '../services/wisata_service.dart' as wisata_svc;
import 'detail_wisata_screen.dart';

/// Hasil perhitungan rekomendasi untuk satu wisata
class _Hasil {
  final WisataModel wisata;
  final double? jarakKm; // null kalau jarak tidak bisa dihitung
  final double skor; // 0.0 - 1.0
  final List<String> alasan;

  _Hasil({
    required this.wisata,
    required this.jarakKm,
    required this.skor,
    required this.alasan,
  });
}

class _DataRekomendasi {
  final List<_Hasil> daftar;
  final String alamat;

  /// Catatan untuk pengguna kalau ada yang kurang (alamat kosong, dll).
  /// Kosong berarti semuanya normal.
  final String catatan;

  _DataRekomendasi({
    required this.daftar,
    required this.alamat,
    required this.catatan,
  });
}

class _Koordinat {
  final double lat;
  final double lng;
  const _Koordinat(this.lat, this.lng);
}

class RekomendasiWisataScreen extends StatefulWidget {
  const RekomendasiWisataScreen({super.key});

  @override
  State<RekomendasiWisataScreen> createState() =>
      _RekomendasiWisataScreenState();
}

class _RekomendasiWisataScreenState extends State<RekomendasiWisataScreen> {
  static const primaryColor = Color(0xFF1550B6);

  // Bobot skor (jumlahnya 1.0)
  static const _bobotJarak = 0.40;
  static const _bobotRating = 0.35;
  static const _bobotPopuler = 0.25;

  late Future<_DataRekomendasi> _future;

  @override
  void initState() {
    super.initState();
    _future = _muat();
  }

  // ---------------------------------------------------------------------------
  // Pengambilan data + perhitungan skor
  // ---------------------------------------------------------------------------

  Future<_DataRekomendasi> _muat() async {
    final supabase = Supabase.instance.client;

    // 1) Alamat rumah dari profil
    String alamat = '';
    final user = supabase.auth.currentUser;
    if (user != null) {
      try {
        final response = await supabase
            .from('profiles')
            .select()
            .eq('id', user.id)
            .maybeSingle();
        if (response != null) {
          final model = UserModel.fromJson(Map<String, dynamic>.from(response));
          alamat = ((model.address as String?) ?? '').trim();
        }
      } catch (e) {
        debugPrint('Gagal ambil alamat profil: $e');
      }
    }

    // 2) Alamat -> koordinat
    _Koordinat? rumah;
    String catatan = '';
    if (alamat.isEmpty) {
      catatan =
          'Alamat rumah belum diisi di profil. Lengkapi alamat agar jarak ikut dihitung. '
          'Untuk sementara, urutan berdasarkan rating dan favorit pengunjung.';
    } else {
      try {
        final lokasi = await locationFromAddress('$alamat, Indonesia');
        if (lokasi.isNotEmpty) {
          rumah = _Koordinat(lokasi.first.latitude, lokasi.first.longitude);
        }
      } catch (e) {
        debugPrint('Geocoding gagal: $e');
      }
      if (rumah == null) {
        catatan =
            'Alamat rumahmu belum bisa dikenali sebagai lokasi. Coba tulis alamat lebih lengkap di profil. '
            'Untuk sementara, urutan berdasarkan rating dan favorit pengunjung.';
      }
    }

    // 3) Data wisata (ambil juga map mentahnya untuk membaca koordinat)
    final data = await wisata_svc.WisataService().getWisataList();
    final items = <MapEntry<WisataModel, _Koordinat?>>[];
    for (final e in data) {
      final map = Map<String, dynamic>.from(e as Map);
      final wisata = WisataModel.fromMap(map);
      final lat = _angka(map, ['latitude', 'lat', 'lintang']);
      final lng = _angka(map, ['longitude', 'lng', 'lon', 'long', 'bujur']);
      items.add(
        MapEntry(wisata, (lat != null && lng != null) ? _Koordinat(lat, lng) : null),
      );
    }

    if (rumah != null && items.every((e) => e.value == null)) {
      catatan =
          'Data koordinat wisata belum tersedia, jadi jarak belum bisa dihitung. '
          'Urutan berdasarkan rating dan favorit pengunjung.';
    }

    // 4) Hitung skor
    final maxUlasan = items.fold<int>(
      0,
      (a, e) => math.max(a, e.key.jumlahUlasan.toInt()),
    );

    final hasil = <_Hasil>[];
    for (final item in items) {
      final w = item.key;
      final rating = w.rating.toDouble();
      final ulasan = w.jumlahUlasan.toInt();

      final skorRating = (rating / 5).clamp(0.0, 1.0);
      final skorPopuler = maxUlasan == 0
          ? 0.0
          : math.log(1 + ulasan) / math.log(1 + maxUlasan);

      double? jarak;
      double skor;
      final pakaiJarak = rumah != null && items.any((e) => e.value != null);

      if (pakaiJarak) {
        if (item.value != null) {
          jarak = _jarakKm(
            rumah.lat,
            rumah.lng,
            item.value!.lat,
            item.value!.lng,
          );
        }
        // makin dekat makin tinggi: 0 km -> 1.0, 10 km -> 0.5, 30 km -> 0.25
        final skorJarak = jarak == null ? 0.3 : 1 / (1 + jarak / 10);
        skor = _bobotJarak * skorJarak +
            _bobotRating * skorRating +
            _bobotPopuler * skorPopuler;
      } else {
        // tanpa jarak: bobot dibagi ulang antara rating dan popularitas
        skor = 0.6 * skorRating + 0.4 * skorPopuler;
      }

      final alasan = <String>[];
      if (jarak != null && jarak <= 10) alasan.add('Dekat rumahmu');
      if (rating >= 4.5) alasan.add('Rating tinggi');
      if (maxUlasan > 0 && ulasan >= maxUlasan * 0.6) {
        alasan.add('Favorit pengunjung');
      }

      hasil.add(
        _Hasil(wisata: w, jarakKm: jarak, skor: skor, alasan: alasan),
      );
    }

    hasil.sort((a, b) => b.skor.compareTo(a.skor));

    return _DataRekomendasi(
      daftar: hasil.take(10).toList(),
      alamat: alamat,
      catatan: catatan,
    );
  }

  /// Baca angka dari map dengan beberapa kemungkinan nama kolom
  double? _angka(Map<String, dynamic> map, List<String> keys) {
    for (final k in keys) {
      final v = map[k];
      if (v == null) continue;
      if (v is num) return v.toDouble();
      final p = double.tryParse(v.toString().replaceAll(',', '.'));
      if (p != null) return p;
    }
    return null;
  }

  /// Jarak dua titik (km) dengan rumus Haversine
  double _jarakKm(double lat1, double lon1, double lat2, double lon2) {
    const radiusBumi = 6371.0;
    double rad(double d) => d * math.pi / 180;

    final dLat = rad(lat2 - lat1);
    final dLon = rad(lon2 - lon1);
    final a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(rad(lat1)) *
            math.cos(rad(lat2)) *
            math.pow(math.sin(dLon / 2), 2);
    return 2 * radiusBumi * math.asin(math.sqrt(a));
  }

  String _formatJarak(double km) {
    if (km < 1) return '${(km * 1000).round()} m';
    return '${km.toStringAsFixed(1)} km';
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  void _tampilkanCaraKerja() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Cara kerja rekomendasi',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: Text(
          'Setiap wisata diberi skor dari tiga hal:\n\n'
          '• 40% kedekatan dengan alamat rumahmu di profil\n'
          '• 35% rating wisata\n'
          '• 25% jumlah ulasan (favorit pengunjung)\n\n'
          'Wisata diurutkan dari skor tertinggi. Kalau alamat belum diisi, '
          'skor hanya memakai rating dan jumlah ulasan.',
          style: GoogleFonts.poppins(fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Mengerti', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        // Tombol kembali: panah saja, tanpa pembungkus lingkaran
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Rekomendasi Wisata',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            tooltip: 'Cara kerja',
            onPressed: _tampilkanCaraKerja,
          ),
        ],
      ),
      body: FutureBuilder<_DataRekomendasi>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: primaryColor),
                  const SizedBox(height: 16),
                  Text(
                    'Menghitung rekomendasi untukmu...',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Gagal memuat rekomendasi: ${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(color: Colors.redAccent),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => setState(() => _future = _muat()),
                      child: Text('Coba lagi', style: GoogleFonts.poppins()),
                    ),
                  ],
                ),
              ),
            );
          }

          final data = snapshot.data!;

          return RefreshIndicator(
            color: primaryColor,
            onRefresh: () async {
              final f = _muat();
              setState(() => _future = f);
              try {
                await f;
              } catch (_) {}
            },
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              itemCount: data.daftar.length + 1,
              itemBuilder: (context, i) {
                if (i == 0) return _buildInfoAlamat(data);
                return _buildKartu(data.daftar[i - 1], i);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoAlamat(_DataRekomendasi data) {
    final bermasalah = data.catatan.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bermasalah ? const Color(0xFFFFFBEB) : const Color(0xFFE8F1FF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            bermasalah ? Icons.info_outline_rounded : Icons.home_rounded,
            color: bermasalah ? const Color(0xFFF59E0B) : primaryColor,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: bermasalah
                ? Text(
                    data.catatan,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      height: 1.5,
                      color: const Color(0xFF92400E),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dihitung dari alamat rumahmu',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        data.alamat,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildKartu(_Hasil h, int peringkat) {
    final w = h.wisata;
    final persen = (h.skor * 100).round();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DetailWisataScreen(wisata: w),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Gambar + nomor peringkat
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: CachedNetworkImage(
                        imageUrl: w.gambarUrl,
                        width: 96,
                        height: 96,
                        fit: BoxFit.cover,
                        memCacheWidth: 300,
                        placeholder: (context, url) => Container(
                          width: 96,
                          height: 96,
                          color: Colors.grey.shade200,
                        ),
                        errorWidget: (context, url, error) => Container(
                          width: 96,
                          height: 96,
                          color: Colors.grey.shade200,
                          child: const Icon(
                            Icons.broken_image_outlined,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: peringkat <= 3
                              ? const Color(0xFFF59E0B)
                              : Colors.black.withValues(alpha: 0.55),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$peringkat',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),

                // Keterangan
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        w.nama,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                      Text(
                        w.kategori,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            color: Color(0xFFF59E0B),
                            size: 16,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${w.rating}',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            ' (${w.jumlahUlasan})',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                            ),
                          ),
                          if (h.jarakKm != null) ...[
                            const SizedBox(width: 10),
                            Icon(
                              Icons.location_on_rounded,
                              color: Colors.grey.shade500,
                              size: 15,
                            ),
                            Text(
                              _formatJarak(h.jarakKm!),
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (h.alasan.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: h.alasan
                              .map(
                                (a) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE8F1FF),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    a,
                                    style: GoogleFonts.poppins(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: primaryColor,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: h.skor.clamp(0.0, 1.0),
                                minHeight: 6,
                                backgroundColor: const Color(0xFFE2E8F0),
                                color: primaryColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$persen%',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
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
        ),
      ),
    );
  }
}