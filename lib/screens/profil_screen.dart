import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_auth/local_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/login_screen.dart';
import '../features/feedback.dart';
import '../features/game.dart';
import '../models/user_model.dart';
import '../services/gps_service.dart';

class PlaceholderProfilScreen extends StatefulWidget {
  const PlaceholderProfilScreen({super.key});

  @override
  State<PlaceholderProfilScreen> createState() => _PlaceholderProfilScreenState();
}

class _PlaceholderProfilScreenState extends State<PlaceholderProfilScreen> {
  final _supabase = Supabase.instance.client;
  UserModel? _currentUserModel;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // Mengambil data profil dari Supabase Auth & Tabel Profiles
  Future<void> _loadUserData() async {
    final user = _supabase.auth.currentUser;

    if (user != null) {
      try {
        final data = await _supabase
            .from('profiles')
            .select()
            .eq('id', user.id)
            .maybeSingle();

        if (data != null) {
          setState(() {
            _currentUserModel = UserModel.fromJson(data);
          });
        } else {
          // Jika baris di database belum ada, inisialisasi dari akun Auth
          setState(() {
            _currentUserModel = UserModel(
              id: user.id,
              email: user.email ?? '',
              fullName: user.userMetadata?['full_name'] ?? '',
            );
          });
        }
      } catch (e) {
        debugPrint('Error memuat profil: $e');
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Menyimpan data profil yang diedit ke Supabase
  Future<void> _updateUserData(UserModel updatedModel) async {
    final user = _supabase.auth.currentUser;

    if (user == null) return;

    try {
      final payload = {
        'id': user.id,
        'email': user.email,
        ...updatedModel.toUpdateJson(),
      };

      await _supabase.from('profiles').upsert(payload);

      setState(() {
        _currentUserModel = updatedModel;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Data profil berhasil disimpan ke database!',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: const Color(0xFF1550B6),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan data: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _showEditProfileDialog() {
    final model = _currentUserModel;
    final nameController = TextEditingController(text: model?.fullName);
    final phoneController = TextEditingController(text: model?.phone);
    final ageController = TextEditingController(text: model?.age);
    final addressController = TextEditingController(text: model?.address);
    String? selectedGender = model?.gender;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Edit Data Diri Pemesan',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1550B6),
                      ),
                    ),
                    Text(
                      'Lengkapi data ini untuk memproses e-tiket wisata Anda.',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Input Nama Lengkap
                    TextField(
                      controller: nameController,
                      style: GoogleFonts.poppins(fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Nama Lengkap',
                        prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF1550B6)),
                        filled: true,
                        fillColor: const Color(0xFFF6F8FB),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Input No. WhatsApp
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      style: GoogleFonts.poppins(fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'No. Telepon / WhatsApp',
                        prefixIcon: const Icon(Icons.phone_outlined, color: Color(0xFF1550B6)),
                        filled: true,
                        fillColor: const Color(0xFFF6F8FB),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Row Usia & Jenis Kelamin
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: ageController,
                            keyboardType: TextInputType.number,
                            style: GoogleFonts.poppins(fontSize: 14),
                            decoration: InputDecoration(
                              labelText: 'Usia (Tahun)',
                              prefixIcon: const Icon(Icons.cake_outlined, color: Color(0xFF1550B6)),
                              filled: true,
                              fillColor: const Color(0xFFF6F8FB),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey.shade200),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedGender,
                            style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
                            decoration: InputDecoration(
                              labelText: 'Gender',
                              prefixIcon: const Icon(Icons.wc_outlined, color: Color(0xFF1550B6)),
                              filled: true,
                              fillColor: const Color(0xFFF6F8FB),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey.shade200),
                              ),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'Laki-laki', child: Text('Laki-laki')),
                              DropdownMenuItem(value: 'Perempuan', child: Text('Perempuan')),
                            ],
                            onChanged: (val) {
                              setModalState(() => selectedGender = val);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Input Alamat
                    TextField(
                      controller: addressController,
                      maxLines: 2,
                      style: GoogleFonts.poppins(fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Alamat Tempat Tinggal',
                        prefixIcon: const Icon(Icons.home_outlined, color: Color(0xFF1550B6)),
                        filled: true,
                        fillColor: const Color(0xFFF6F8FB),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Tombol Simpan
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () {
                          final user = _supabase.auth.currentUser;
                          final newModel = UserModel(
                            id: user?.id ?? model?.id ?? '',
                            email: user?.email ?? model?.email ?? '',
                            fullName: nameController.text.trim(),
                            phone: phoneController.text.trim(),
                            age: ageController.text.trim(),
                            gender: selectedGender,
                            address: addressController.text.trim(),
                          );
                          _updateUserData(newModel);
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1550B6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                        child: Text(
                          'Simpan Perubahan',
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
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF1550B6);
    final user = _supabase.auth.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: AppBar(
        title: Text(
          'Profil Saya',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: primaryColor,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: primaryColor),
            )
          : SingleChildScrollView(
              child: Column(
                children: [
                  // Header Profil
                  Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: primaryColor,
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(28),
                        bottomRight: Radius.circular(28),
                      ),
                    ),
                    padding: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
                    child: Column(
                      children: [
                        Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            const CircleAvatar(
                              radius: 48,
                              backgroundColor: Colors.white24,
                              child: CircleAvatar(
                                radius: 44,
                                backgroundColor: Colors.white,
                                child: Icon(
                                  Icons.person,
                                  size: 50,
                                  color: primaryColor,
                                ),
                              ),
                            ),
                            InkWell(
                              onTap: _showEditProfileDialog,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.edit,
                                  size: 16,
                                  color: primaryColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Menampilkan Nama Lengkap
                        Text(
                          (_currentUserModel?.fullName != null && _currentUserModel!.fullName.isNotEmpty)
                              ? _currentUserModel!.fullName
                              : (user?.userMetadata?['full_name'] ?? 'Belum Diisi'),
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Menampilkan Email Secara Permanen
                        Text(
                          user?.email ?? (_currentUserModel?.email.isNotEmpty == true ? _currentUserModel!.email : 'Tidak ada email'),
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Fitur Aplikasi',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Wisata Terdekat
                        _buildMenuItem(
                          icon: Icons.near_me_outlined,
                          title: 'Wisata Terdekat (LBS)',
                          subtitle: 'Peta & jarak lokasi wisata dari Anda',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const LbsScreen(),
                              ),
                            );
                          },
                        ),

                        // Game Tangkap Tiket
                        _buildMenuItem(
                          icon: Icons.sports_esports_outlined,
                          title: 'Tangkap Tiket Wisata',
                          subtitle: 'Mainkan game & dapatkan voucher diskon',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const QuizScreen(),
                              ),
                            );
                          },
                        ),

                        // Saran & Kesan PAM
                        _buildMenuItem(
                          icon: Icons.rate_review_outlined,
                          title: 'Saran & Kesan PAM',
                          subtitle: 'Masukan untuk mata kuliah PAM',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const FeedbackScreen(),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 20),
                        Text(
                          'Akun',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Menu Keamanan & Biometrik
                        _buildMenuItem(
                          icon: Icons.lock_outline,
                          title: 'Keamanan & Biometrik',
                          subtitle: 'Kelola akses masuk akun',
                          onTap: () async {
                            final LocalAuthentication auth = LocalAuthentication();

                            try {
                              bool canCheckBiometrics = await auth.canCheckBiometrics;
                              bool isDeviceSupported = await auth.isDeviceSupported();

                              if (!canCheckBiometrics && !isDeviceSupported) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Perangkat tidak mendukung fitur biometrik'),
                                      backgroundColor: Colors.orange,
                                    ),
                                  );
                                }
                                return;
                              }

                              bool authenticated = await auth.authenticate(
                                localizedReason: 'Pindai sidik jari/wajah untuk verifikasi akun',
                                options: const AuthenticationOptions(
                                  stickyAuth: true,
                                  biometricOnly: true,
                                ),
                              );

                              if (context.mounted) {
                                if (authenticated) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Verifikasi Biometrik Berhasil!'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Verifikasi Biometrik Dibatalkan'),
                                      backgroundColor: Colors.redAccent,
                                    ),
                                  );
                                }
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error Biometrik: $e'),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                              }
                            }
                          },
                        ),

                        // Menu Keluar
                        _buildMenuItem(
                          icon: Icons.logout,
                          title: 'Keluar',
                          subtitle: 'Keluar dari akun LelunganJogja',
                          textColor: Colors.redAccent,
                          iconColor: Colors.redAccent,
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                title: Text(
                                  'Keluar Akun',
                                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                                ),
                                content: Text(
                                  'Apakah kamu yakin ingin keluar dari LelunganJogja?',
                                  style: GoogleFonts.poppins(fontSize: 13),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: Text('Batal', style: GoogleFonts.poppins(color: Colors.grey)),
                                  ),
                                  ElevatedButton(
                                    onPressed: () async {
                                      Navigator.pop(context);
                                      await _supabase.auth.signOut();
                                      if (context.mounted) {
                                        Navigator.pushAndRemoveUntil(
                                          context,
                                          MaterialPageRoute(builder: (context) => const LoginScreen()),
                                          (route) => false,
                                        );
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.redAccent,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: Text('Keluar', style: GoogleFonts.poppins(color: Colors.white)),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color textColor = Colors.black87,
    Color iconColor = const Color(0xFF1550B6),
  }) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      color: Colors.white,
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withAlpha(26),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor),
        ),
        title: Text(
          title,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: textColor,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      ),
    );
  }
}