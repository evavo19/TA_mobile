import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/wisata_model.dart';
import 'detail_wisata_screen.dart';
import 'notifikasi_screen.dart';
import 'wisata_gratis_screen.dart';
import '../features/chatbot.dart'; 
import 'main_screen.dart'; 
import '../features/game.dart'; 
import '../features/feedback.dart'; 
import '../services/gps_service.dart'; 
import '../services/wisata_service.dart' as wisata_svc; 

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const primaryColor = Color(0xFF1550B6);

  final supabase = Supabase.instance.client;

  static const _bgColor = Color(0xFFF8FAFC);

  late Future<List<WisataModel>> _wisataFuture;

  String _searchQuery = '';
  String _selectedCategory = 'Semua';

  final List<String> _categories = [
    'Semua',
    'Alam',
    'Budaya Dan Sejarah',
    'Kuliner',
  ];

  String get _userName {
    final user = supabase.auth.currentUser;
    final meta = user?.userMetadata;
    final name = meta?['nama'] ?? meta?['full_name'] ?? meta?['name'];
    if (name != null && name.toString().trim().isNotEmpty) {
      return name.toString();
    }
    final email = user?.email;
    if (email != null && email.isNotEmpty) {
      return email.split('@').first;
    }
    return 'Wisatawan';
  }

  /// Sapaan berdasarkan jam saat ini
  String get _greeting {
    final h = DateTime.now().hour;
    if (h >= 4 && h < 11) return 'Selamat pagi';
    if (h >= 11 && h < 15) return 'Selamat siang';
    if (h >= 15 && h < 18) return 'Selamat sore';
    return 'Selamat malam';
  }

  /// Foto profil dari akun (kalau ada)
  String? get _avatarUrl {
    final meta = supabase.auth.currentUser?.userMetadata;
    final url = meta?['avatar_url'] ?? meta?['picture'];
    if (url == null || url.toString().trim().isEmpty) return null;
    return url.toString();
  }

  @override
  void initState() {
    super.initState();
    _wisataFuture = _fetchWisata();
  }

  Future<List<WisataModel>> _fetchWisata() async {
    final data = await wisata_svc.WisataService().getWisataList();
    return data.map((e) => WisataModel.fromMap(e)).toList();
  }

  /// Dipanggil saat layar ditarik ke bawah
  Future<void> _refresh() async {
    final future = _fetchWisata();
    setState(() => _wisataFuture = future);
    try {
      await future;
    } catch (_) {
      // error ditampilkan oleh FutureBuilder
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: RefreshIndicator(
        color: primaryColor,
        // supaya indikator muncul di bawah header, bukan tertutup
        edgeOffset: MediaQuery.of(context).padding.top + 60 + 140,
        onRefresh: _refresh,
        child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          _buildAppBar(context),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildQuickMenu(context),
                  const SizedBox(height: 20),
                  _buildBanner(context),
                  const SizedBox(height: 24),
                  _sectionTitle('Kategori Wisata'),
                  const SizedBox(height: 12),
                  _buildCategoryChips(),
                  const SizedBox(height: 24),
                  _sectionTitle('Rekomendasi Wisata'),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),

          FutureBuilder<List<WisataModel>>(
            future: _wisataFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  snapshot.data == null) {
                return const SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(40.0),
                      child: CircularProgressIndicator(color: primaryColor),
                    ),
                  ),
                );
              }

              if (snapshot.hasError) {
                return SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Text(
                        'Gagal memuat data: ${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(color: Colors.redAccent),
                      ),
                    ),
                  ),
                );
              }

              final allWisata = snapshot.data ?? [];

              final filteredWisata = allWisata.where((wisata) {
                final matchesSearch =
                    wisata.nama.toLowerCase().contains(_searchQuery);
                final matchesCategory = _selectedCategory == 'Semua' ||
                    wisata.kategori.toLowerCase() ==
                        _selectedCategory.toLowerCase();
                return matchesSearch && matchesCategory;
              }).toList();

              if (filteredWisata.isEmpty) {
                return SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40.0),
                      child: Text(
                        allWisata.isEmpty
                            ? 'Belum ada data. Hubungkan internet untuk pertama kali.'
                            : 'Destinasi wisata tidak ditemukan',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(color: Colors.grey),
                      ),
                    ),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      return _WisataCard(
                        wisata: filteredWisata[index],
                        index: index,
                      );
                    },
                    childCount: filteredWisata.length,
                  ),
                ),
              );
            },
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    final url = _avatarUrl;
    final initial = _userName.isNotEmpty ? _userName[0].toUpperCase() : 'W';

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: CircleAvatar(
        radius: 22,
        backgroundColor: const Color(0xFFDBEAFE),
        backgroundImage: url != null ? CachedNetworkImageProvider(url) : null,
        child: url == null
            ? Text(
                initial,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: primaryColor,
                ),
              )
            : null,
      ),
    );
  }

  SliverAppBar _buildAppBar(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      floating: false,
      elevation: 0,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      toolbarHeight: 60,
      // === HEADER BIRU MELENGKUNG ===
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          color: primaryColor,
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
        ),
      ),
      // ==============================
      title: Text(
        'LelunganJogja',
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.bold,
          color: Colors.white,
          fontSize: 20,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined, color: Colors.white),
          tooltip: 'Notifikasi & Izin',
          onPressed: () {
            Navigator.push(
              context,
              halusRoute(const NotificationScreen()),
            );
          },
        ),
        const SizedBox(width: 8),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(140),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar + sapaan sesuai jam
              Row(
                children: [
                  _buildAvatar(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$_greeting 👋',
                          style: GoogleFonts.poppins(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          _userName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              TextField(
                onChanged: (value) {
                  setState(() => _searchQuery = value.toLowerCase());
                },
                style: GoogleFonts.poppins(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Cari destinasi wisata...',
                  hintStyle: GoogleFonts.poppins(color: Colors.grey.shade400),
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickMenu(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _QuickMenuItem(
              icon: Icons.location_on_rounded,
              label: 'Terdekat',
              color: const Color(0xFF10B981),
              onTap: () => Navigator.push(
                context,
                halusRoute(const LbsScreen()),
              ),
            ),
            _QuickMenuItem(
              icon: Icons.money_off_rounded,
              label: 'Gratis',
              color: const Color(0xFFF97316),
              onTap: () => Navigator.push(
                context,
                halusRoute(const WisataGratisScreen()),
              ),
            ),
            _QuickMenuItem(
              icon: Icons.rate_review_rounded,
              label: 'Masukan',
              color: primaryColor,
              onTap: () => Navigator.push(
                context,
                halusRoute(const FeedbackScreen()),
              ),
            ),
            _QuickMenuItem(
              icon: Icons.sports_esports_rounded,
              label: 'Mini Game',
              color: const Color(0xFF8B5CF6),
              onTap: () => Navigator.push(
                context,
                halusRoute(const QuizScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBanner(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          const pesan =
              'Rekomendasikan wisata terdekat dari lokasiku dan wisata favorit pengunjung.';

          if (!MainScreen.bukaAsistenAI(context, pesan)) {
            Navigator.push(
              context,
              halusRoute(const ChatbotScreen(pesanAwal: pesan)),
            );
          }
        },
        child: const _AiBannerContent(),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF1E293B),
        ),
      ),
    );
  }

  Widget _buildCategoryChips() {
    return SizedBox(
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
                color: isSelected ? Colors.white : Colors.grey.shade600,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
              selectedColor: primaryColor,
              backgroundColor: Colors.white,
              elevation: isSelected ? 2 : 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? primaryColor : Colors.grey.shade300,
                ),
              ),
              onSelected: (_) {
                setState(() => _selectedCategory = category);
              },
            ),
          );
        },
      ),
    );
  }
}

class _WisataCard extends StatelessWidget {
  final WisataModel wisata;

  /// Urutan kartu di daftar, untuk animasi muncul bertahap
  final int index;

  const _WisataCard({required this.wisata, this.index = 0});

  static const primaryColor = Color(0xFF1550B6);

  @override
  Widget build(BuildContext context) {
    final delay = (index > 6 ? 6 : index) * 70;

    // Animasi: kartu fade-in sambil naik dari bawah, kartu bawah sedikit lebih lambat
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 450 + delay),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 30 * (1 - value)),
            child: child,
          ),
        );
      },
      child: _buildCard(context),
    );
  }

  Widget _buildCard(BuildContext context) {
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
            halusRoute(DetailWisataScreen(wisata: wisata)),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),

              child: Hero(
                tag: 'wisata-${wisata.nama}',
                child: CachedNetworkImage(
                imageUrl: wisata.gambarUrl,
                height: 170,
                width: double.infinity,
                fit: BoxFit.cover,
                memCacheWidth: 600,
                fadeInDuration: const Duration(milliseconds: 150),
                placeholder: (context, url) => Container(
                  height: 170,
                  color: Colors.grey.shade200,
                ),
                errorWidget: (context, url, error) {
                  debugPrint('GAMBAR GAGAL: ${wisata.nama} | $url | $error');
                  return Container(
                    height: 170,
                    color: Colors.grey.shade200,
                    child: const Icon(
                      Icons.broken_image_outlined,
                      size: 48,
                      color: Colors.grey,
                    ),
                  );
                },
              ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                          borderRadius: BorderRadius.circular(8),
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
                                color: const Color(0xFF92400E),
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
  }
}

class _QuickMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickMenuItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1E293B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Transisi pindah halaman: fade + geser halus dari kanan.
/// Pakai ini sebagai pengganti MaterialPageRoute.
Route<T> halusRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 350),
    reverseTransitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (_, _, _) => page,
    transitionsBuilder: (_, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.06, 0),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// Banner AI: bintang berdenyut pelan + kilau lewat di atas banner.
class _AiBannerContent extends StatefulWidget {
  const _AiBannerContent();

  @override
  State<_AiBannerContent> createState() => _AiBannerContentState();
}

class _AiBannerContentState extends State<_AiBannerContent>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3000),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 120,
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1550B6), Color(0xFF3B82F6)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
        ),
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = _c.value;

            // Bintang berdenyut pelan (1.0 -> 1.25 -> 1.0)
            final pulse = 1 + 0.25 * (0.5 + 0.5 * math.sin(t * 2 * math.pi));

            // Kilau menyapu di paruh pertama siklus, lalu jeda
            final sweep = (t / 0.5).clamp(0.0, 1.0);

            return Stack(
              children: [
                Positioned.fill(
                  child: LayoutBuilder(
                    builder: (context, box) {
                      final w = box.maxWidth;
                      return Stack(
                        children: [
                          Positioned(
                            left: -90 + (w + 180) * Curves.easeInOut.transform(sweep),
                            top: -20,
                            bottom: -20,
                            width: 70,
                            child: Transform(
                              transform: Matrix4.skewX(-0.35),
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.white.withValues(alpha: 0),
                                      Colors.white.withValues(alpha: 0.22),
                                      Colors.white.withValues(alpha: 0),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Transform.scale(
                                  scale: pulse,
                                  child: const Icon(
                                    Icons.auto_awesome,
                                    color: Colors.amber,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'AI Rekomendasi Wisata',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Wisata terdekat dari lokasimu dan favorit pengunjung',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.white70,
                        size: 36,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}