import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  final _kesanController = TextEditingController();
  final _saranController = TextEditingController();
  int _rating = 5;
  bool _isLoading = true;
  bool _hasExistingFeedback = false;
  bool _isEditing = false;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUserExistingFeedback();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _kesanController.dispose();
    _saranController.dispose();
    super.dispose();
  }

  Future<void> _loadUserExistingFeedback() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final response = await _supabase
          .from('feedback')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      if (response != null) {
        setState(() {
          _kesanController.text = response['kesan'] ?? '';
          _saranController.text = response['saran'] ?? '';
          _rating = response['rating'] ?? 5;
          _hasExistingFeedback = true;
          _isEditing = false;
        });
      } else {
        setState(() {
          _hasExistingFeedback = false;
          _isEditing = true;
        });
      }
    } catch (e) {
      debugPrint('Error memuat ulasan user: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitFeedback() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    if (_formKey.currentState!.validate()) {
      try {
        final payload = {
          'user_id': user.id,
          'rating': _rating,
          'kesan': _kesanController.text.trim(),
          'saran': _saranController.text.trim(),
          'updated_at': DateTime.now().toIso8601String(),
        };

        await _supabase.from('feedback').upsert(payload, onConflict: 'user_id');

        setState(() {
          _hasExistingFeedback = true;
          _isEditing = false;
        });

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Saran & Kesan berhasil disimpan!',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );

        _tabController.animateTo(1);
      } catch (e) {
        debugPrint('Gagal menyimpan feedback: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Gagal menyimpan: $e',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF1550B6);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: AppBar(
        title: Text(
          'Saran & Kesan PAM',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 18,
          ),
        ),
        backgroundColor: primaryColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelStyle: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
          unselectedLabelStyle: GoogleFonts.poppins(
            fontWeight: FontWeight.normal,
            fontSize: 13,
          ),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(text: 'Tulis Ulasan'),
            Tab(text: 'Riwayat Ulasan'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryColor))
          : TabBarView(
              controller: _tabController,
              children: [
                // TAB 1: TULIS / EDIT PESAN
                SingleChildScrollView(
                  padding: const EdgeInsets.all(20.0),
                  child: (_hasExistingFeedback && !_isEditing)
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withAlpha(25),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Ulasan Anda',
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: primaryColor,
                                        ),
                                      ),
                                      Row(
                                        children: List.generate(
                                          _rating,
                                          (_) => const Icon(
                                            Icons.star,
                                            color: Colors.amber,
                                            size: 18,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 24),
                                  Text.rich(
                                    TextSpan(
                                      text: 'Kesan: ',
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: Colors.black87,
                                      ),
                                      children: [
                                        TextSpan(
                                          text: _kesanController.text,
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.normal,
                                            fontSize: 13,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text.rich(
                                    TextSpan(
                                      text: 'Saran: ',
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: Colors.black87,
                                      ),
                                      children: [
                                        TextSpan(
                                          text: _saranController.text,
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.normal,
                                            fontSize: 13,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _isEditing = true;
                                  });
                                },
                                icon: const Icon(
                                  Icons.edit,
                                  color: Colors.white,
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryColor,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(26),
                                  ),
                                ),
                                label: Text(
                                  'Perbarui Ulasan',
                                  style: GoogleFonts.poppins(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _hasExistingFeedback
                                        ? 'Edit Ulasan Anda'
                                        : 'Buat Ulasan Baru',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: primaryColor,
                                    ),
                                  ),
                                  if (_hasExistingFeedback)
                                    TextButton(
                                      onPressed: () {
                                        setState(() {
                                          _isEditing = false;
                                        });
                                      },
                                      child: Text(
                                        'Batal',
                                        style: GoogleFonts.poppins(
                                          color: Colors.red,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Rating Mata Kuliah',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(5, (index) {
                                  return IconButton(
                                    onPressed: () {
                                      setState(() {
                                        _rating = index + 1;
                                      });
                                    },
                                    icon: Icon(
                                      index < _rating
                                          ? Icons.star
                                          : Icons.star_border,
                                      color: Colors.amber,
                                      size: 36,
                                    ),
                                  );
                                }),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'Kesan Selama Perkuliahan',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _kesanController,
                                maxLines: 4,
                                style: GoogleFonts.poppins(fontSize: 13),
                                validator: (value) =>
                                    value == null || value.trim().isEmpty
                                    ? 'Mohon isi kesan perkuliahan'
                                    : null,
                                decoration: InputDecoration(
                                  hintText: 'Tuliskan kesan kamu...',
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'Saran & Masukan',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _saranController,
                                maxLines: 4,
                                style: GoogleFonts.poppins(fontSize: 13),
                                validator: (value) =>
                                    value == null || value.trim().isEmpty
                                    ? 'Mohon isi saran & masukan'
                                    : null,
                                decoration: InputDecoration(
                                  hintText: 'Tuliskan saran pengembangan...',
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 32),
                              SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: ElevatedButton(
                                  onPressed: _submitFeedback,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryColor,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(26),
                                    ),
                                  ),
                                  child: Text(
                                    _hasExistingFeedback
                                        ? 'Simpan Perubahan'
                                        : 'Kirim Saran & Kesan',
                                    style: GoogleFonts.poppins(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                ),

                // TAB 2: RIWAYAT ULASAN
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _supabase
                      .from('feedback')
                      .select('*, profiles(fullName, avatar_url)')
                      .order('updated_at', ascending: false),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: primaryColor),
                      );
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Text('Gagal memuat riwayat: ${snapshot.error}'),
                      );
                    }
                    final feedbacks = snapshot.data ?? [];

                    if (feedbacks.isEmpty) {
                      return Center(
                        child: Text(
                          'Belum ada riwayat ulasan.',
                          style: GoogleFonts.poppins(color: Colors.grey),
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: feedbacks.length,
                      itemBuilder: (context, index) {
                        final item = feedbacks[index];
                        final profile = item['profiles'] ?? {};
                        final fullName =
                            profile['fullName'] ?? 'Pengguna Anonim';
                        final avatarUrl = profile['avatar_url'];
                        final kesan = item['kesan'] ?? '';
                        final saran = item['saran'] ?? '';
                        final rating = item['rating'] ?? 5;
                        final updatedAt = item['updated_at'] != null
                            ? DateTime.parse(item['updated_at'])
                                  .toLocal()
                                  .toString()
                                  .split('.')[0]
                            : '';

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundColor: primaryColor.withAlpha(
                                        26,
                                      ),
                                      backgroundImage: avatarUrl != null
                                          ? NetworkImage(avatarUrl)
                                          : null,
                                      child: avatarUrl == null
                                          ? const Icon(
                                              Icons.person,
                                              color: primaryColor,
                                            )
                                          : null,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            fullName,
                                            style: GoogleFonts.poppins(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                          Text(
                                            updatedAt,
                                            style: GoogleFonts.poppins(
                                              fontSize: 11,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Row(
                                      children: List.generate(
                                        rating,
                                        (_) => const Icon(
                                          Icons.star,
                                          color: Colors.amber,
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 20),
                                Text.rich(
                                  TextSpan(
                                    text: 'Kesan: ',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: Colors.black87,
                                    ),
                                    children: [
                                      TextSpan(
                                        text: kesan,
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.normal,
                                          fontSize: 13,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text.rich(
                                  TextSpan(
                                    text: 'Saran: ',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: Colors.black87,
                                    ),
                                    children: [
                                      TextSpan(
                                        text: saran,
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.normal,
                                          fontSize: 13,
                                          color: Colors.black87,
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
                    );
                  },
                ),
              ],
            ),
    );
  }
}
