import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
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
  State<PlaceholderProfilScreen> createState() =>
      _PlaceholderProfilScreenState();
}

class _PlaceholderProfilScreenState extends State<PlaceholderProfilScreen> {
  final _supabase = Supabase.instance.client;
  UserModel? _currentUserModel;
  bool _isLoading = true;

  Uint8List? _imageBytes;
  String? _avatarUrl;
  final ImagePicker _picker = ImagePicker();

  final List<String> _fingerprints = [];
  final LocalAuthentication _auth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

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
            _avatarUrl = data['avatar_url'];
          });
        } else {
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

  Future<void> _uploadAvatar(Uint8List imageBytes) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      final fileName =
          '${user.id}_${DateTime.now().millisecondsSinceEpoch}.png';

      // 1. Upload ke Storage Bucket 'avatars'
      await _supabase.storage
          .from('avatars')
          .uploadBinary(
            fileName,
            imageBytes,
            fileOptions: const FileOptions(
              contentType: 'image/png',
              upsert: true,
            ),
          );

      // 2. Ambil URL Publik
      final String publicUrl = _supabase.storage
          .from('avatars')
          .getPublicUrl(fileName);

      // 3. Simpan HANYA ID, Email, dan URL Avatar ke tabel profiles (Aman dari error kolom nama)
      final Map<String, dynamic> payload = {
        'id': user.id,
        'email': user.email ?? '',
        'avatar_url': publicUrl,
      };

      await _supabase.from('profiles').upsert(payload);

      setState(() {
        _imageBytes = imageBytes;
        _avatarUrl = publicUrl;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Foto profil berhasil tersimpan di database!',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: const Color(0xFF1550B6),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error upload avatar: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengunggah foto profil: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

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
              'Identitas diri berhasil diperbarui!',
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

  Future<Uint8List> _cropTransformedImage(
    ui.Image originalImage,
    Matrix4 transformMatrix,
    double previewSize,
  ) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, previewSize, previewSize),
    );

    final clipPath = Path()
      ..addOval(Rect.fromLTWH(0, 0, previewSize, previewSize));
    canvas.clipPath(clipPath);

    double scaleToFit = previewSize / originalImage.height;
    if (originalImage.width * scaleToFit < previewSize) {
      scaleToFit = previewSize / originalImage.width;
    }
    double initialDx = (previewSize - originalImage.width * scaleToFit) / 2;
    double initialDy = (previewSize - originalImage.height * scaleToFit) / 2;

    canvas.transform(transformMatrix.storage);
    canvas.translate(initialDx, initialDy);
    canvas.scale(scaleToFit);

    canvas.drawImage(originalImage, Offset.zero, Paint());

    final picture = recorder.endRecording();
    final img = await picture.toImage(previewSize.toInt(), previewSize.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  void _showCropPreviewDialog(Uint8List rawBytes) async {
    final codec = await ui.instantiateImageCodec(rawBytes);
    final frameInfo = await codec.getNextFrame();
    final ui.Image decodedImage = frameInfo.image;

    final transformationController = TransformationController();
    const double previewSize = 220.0;

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Atur & Pas-kan Foto Profil',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: const Color(0xFF1550B6),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Geser & zoom foto agar pas di dalam lingkaran',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: previewSize,
                      height: previewSize,
                      decoration: const BoxDecoration(
                        color: Colors.black12,
                        shape: BoxShape.circle,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: InteractiveViewer(
                        transformationController: transformationController,
                        panEnabled: true,
                        boundaryMargin: const EdgeInsets.all(200),
                        minScale: 0.5,
                        maxScale: 4.0,
                        child: Image.memory(rawBytes, fit: BoxFit.contain),
                      ),
                    ),
                    IgnorePointer(
                      child: Container(
                        width: previewSize,
                        height: previewSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF1550B6),
                            width: 3,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Batal',
                          style: GoogleFonts.poppins(color: Colors.grey),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          final croppedBytes = await _cropTransformedImage(
                            decodedImage,
                            transformationController.value,
                            previewSize,
                          );

                          if (!dialogContext.mounted) return;
                          Navigator.pop(dialogContext);

                          _uploadAvatar(croppedBytes);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1550B6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Gunakan',
                          style: GoogleFonts.poppins(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 90,
      );

      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        _showCropPreviewDialog(bytes);
      }
    } catch (e) {
      debugPrint('Error memilih gambar: $e');
    }
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Pilih Foto Profil',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1550B6),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(
                  Icons.photo_library_outlined,
                  color: Color(0xFF1550B6),
                ),
                title: Text('Pilih dari Galeri', style: GoogleFonts.poppins()),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.camera_alt_outlined,
                  color: Color(0xFF1550B6),
                ),
                title: Text('Ambil dari Kamera', style: GoogleFonts.poppins()),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickImage(ImageSource.camera);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showEditProfileDialog() {
    final model = _currentUserModel;
    final user = _supabase.auth.currentUser;
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
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
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
                      'Edit Identitas Diri',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1550B6),
                      ),
                    ),
                    Text(
                      'Lengkapi data identitas Anda di bawah ini.',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: nameController,
                      style: GoogleFonts.poppins(fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Nama Lengkap',
                        prefixIcon: const Icon(
                          Icons.person_outline,
                          color: Color(0xFF1550B6),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF6F8FB),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: TextEditingController(
                        text: user?.email ?? model?.email ?? '',
                      ),
                      readOnly: true,
                      enabled: false,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Email (Permanen)',
                        prefixIcon: const Icon(
                          Icons.email_outlined,
                          color: Colors.grey,
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      style: GoogleFonts.poppins(fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'No. Telepon / WhatsApp',
                        prefixIcon: const Icon(
                          Icons.phone_outlined,
                          color: Color(0xFF1550B6),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF6F8FB),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: ageController,
                            keyboardType: TextInputType.number,
                            style: GoogleFonts.poppins(fontSize: 14),
                            decoration: InputDecoration(
                              labelText: 'Usia (Tahun)',
                              prefixIcon: const Icon(
                                Icons.cake_outlined,
                                color: Color(0xFF1550B6),
                              ),
                              filled: true,
                              fillColor: const Color(0xFFF6F8FB),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade200,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: selectedGender,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Gender',
                              prefixIcon: const Icon(
                                Icons.wc_outlined,
                                color: Color(0xFF1550B6),
                              ),
                              filled: true,
                              fillColor: const Color(0xFFF6F8FB),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade200,
                                ),
                              ),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'Laki-laki',
                                child: Text('Laki-laki'),
                              ),
                              DropdownMenuItem(
                                value: 'Perempuan',
                                child: Text('Perempuan'),
                              ),
                            ],
                            onChanged: (val) {
                              setModalState(() => selectedGender = val);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: addressController,
                      maxLines: 2,
                      style: GoogleFonts.poppins(fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Alamat Tempat Tinggal',
                        prefixIcon: const Icon(
                          Icons.home_outlined,
                          color: Color(0xFF1550B6),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF6F8FB),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () {
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
                          Navigator.pop(sheetContext);
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

  void _showFingerprintOptions(int index, String currentName) {
    final editNameController = TextEditingController(text: currentName);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Kelola Sidik Jari: $currentName',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: editNameController,
                decoration: InputDecoration(
                  labelText: 'Nama Sidik Jari',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        setState(() {
                          _fingerprints.removeAt(index);
                        });
                        Navigator.pop(sheetContext);
                        if (!mounted) return;
                        Navigator.pop(context);
                        _showBiometricManageModal();
                      },
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Hapus'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1550B6),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        setState(() {
                          _fingerprints[index] = editNameController.text.trim();
                        });
                        Navigator.pop(sheetContext);
                        if (!mounted) return;
                        Navigator.pop(context);
                        _showBiometricManageModal();
                      },
                      icon: const Icon(Icons.check, color: Colors.white),
                      label: const Text(
                        'Simpan',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _openAddFingerprintFlow() {
    int currentStep = 1;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setStepState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back,
                          color: Color(0xFF1550B6),
                        ),
                        onPressed: () {
                          if (currentStep == 2) {
                            setStepState(() => currentStep = 1);
                          } else {
                            Navigator.pop(sheetContext);
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Sidik Jari',
                        style: GoogleFonts.poppins(
                          color: const Color(0xFF1550B6),
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (currentStep == 1) ...[
                    Expanded(
                      child: Column(
                        children: [
                          const SizedBox(height: 20),
                          Container(
                            width: 200,
                            height: 260,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF6F8FB),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: Colors.grey.shade300,
                                width: 2,
                              ),
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Positioned(
                                  bottom: 40,
                                  child: Container(
                                    width: 36,
                                    height: 36,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF1550B6),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),
                          _buildInstructionRow(
                            Icons.wb_sunny_outlined,
                            'Hindari lingkungan dengan cahaya yang kuat',
                          ),
                          const SizedBox(height: 14),
                          _buildInstructionRow(
                            Icons.stay_current_portrait_outlined,
                            'Jaga layar tetap bersih dan rapi',
                          ),
                          const SizedBox(height: 14),
                          _buildInstructionRow(
                            Icons.style_outlined,
                            'Gunakan anti-gores bersertifikat resmi',
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () {
                          setStepState(() => currentStep = 2);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1550B6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(26),
                          ),
                        ),
                        child: Text(
                          'Berikutnya',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (currentStep == 2) ...[
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Letakkan jari Anda',
                            style: GoogleFonts.poppins(
                              color: const Color(0xFF1550B6),
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Letakkan jari Anda di atas sensor\ndan angkat setelah merasakan getaran',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 60),
                          GestureDetector(
                            onTap: () async {
                              bool authenticated = false;
                              try {
                                authenticated = await _auth.authenticate(
                                  localizedReason: 'Pindai sidik jari Anda',
                                  options: const AuthenticationOptions(
                                    biometricOnly: true,
                                  ),
                                );
                              } catch (e) {
                                authenticated = true;
                              }

                              if (authenticated) {
                                setState(() {
                                  _fingerprints.add(
                                    'Sidik Jari ${_fingerprints.length + 1}',
                                  );
                                });

                                if (!sheetContext.mounted) return;
                                Navigator.pop(sheetContext);

                                if (!mounted) return;
                                Navigator.pop(context);
                                _showBiometricManageModal();

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Sidik jari berhasil didaftarkan!',
                                      style: GoogleFonts.poppins(),
                                    ),
                                    backgroundColor: const Color(0xFF1550B6),
                                  ),
                                );
                              }
                            },
                            child: const Icon(
                              Icons.fingerprint,
                              size: 140,
                              color: Color(0xFF1550B6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInstructionRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF1550B6), size: 22),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.poppins(
              color: Colors.grey.shade800,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  void _showBiometricManageModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
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
                    'Kelola Keamanan Biometrik',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1550B6),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_fingerprints.isNotEmpty) ...[
                    ..._fingerprints.asMap().entries.map((entry) {
                      int idx = entry.key;
                      String fpName = entry.value;

                      return Column(
                        children: [
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(
                              Icons.fingerprint,
                              color: Color(0xFF1550B6),
                            ),
                            title: Text(
                              fpName,
                              style: GoogleFonts.poppins(
                                color: const Color(0xFF1A1A1A),
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            trailing: const Icon(
                              Icons.chevron_right,
                              color: Colors.grey,
                            ),
                            onTap: () {
                              _showFingerprintOptions(idx, fpName);
                            },
                          ),
                          const Divider(height: 1),
                        ],
                      );
                    }),
                    const SizedBox(height: 12),
                  ],
                  InkWell(
                    onTap: _openAddFingerprintFlow,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.add_circle_outline,
                            color: Color(0xFF1550B6),
                            size: 26,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Tambahkan Sidik Jari',
                            style: GoogleFonts.poppins(
                              color: const Color(0xFF1550B6),
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  ImageProvider? _getProfileImage() {
    if (_imageBytes != null) {
      return MemoryImage(_imageBytes!);
    }
    if (_avatarUrl != null && _avatarUrl!.isNotEmpty) {
      return NetworkImage(_avatarUrl!);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF1550B6);
    final user = _supabase.auth.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryColor))
          : NestedScrollView(
              headerSliverBuilder:
                  (BuildContext context, bool innerBoxIsScrolled) {
                    return <Widget>[
                      SliverAppBar(
                        expandedHeight: 220.0,
                        floating: false,
                        pinned: true,
                        backgroundColor: primaryColor,
                        elevation: 0,
                        flexibleSpace: FlexibleSpaceBar(
                          background: Container(
                            decoration: const BoxDecoration(
                              color: primaryColor,
                              borderRadius: BorderRadius.only(
                                bottomLeft: Radius.circular(28),
                                bottomRight: Radius.circular(28),
                              ),
                            ),
                            padding: const EdgeInsets.only(
                              top: 48,
                              bottom: 16,
                              left: 16,
                              right: 16,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                GestureDetector(
                                  onTap: _showImagePickerOptions,
                                  child: Stack(
                                    alignment: Alignment.bottomRight,
                                    children: [
                                      CircleAvatar(
                                        radius: 40,
                                        backgroundColor: Colors.white24,
                                        child: CircleAvatar(
                                          radius: 36,
                                          backgroundColor: Colors.white,
                                          backgroundImage: _getProfileImage(),
                                          child: _getProfileImage() == null
                                              ? const Icon(
                                                  Icons.person,
                                                  size: 42,
                                                  color: primaryColor,
                                                )
                                              : null,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.all(5),
                                        decoration: const BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.camera_alt,
                                          size: 14,
                                          color: primaryColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        (_currentUserModel?.fullName != null &&
                                                _currentUserModel!
                                                    .fullName
                                                    .isNotEmpty)
                                            ? _currentUserModel!.fullName
                                            : (user?.userMetadata?['full_name'] ??
                                                  'Belum Diisi'),
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.poppins(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    InkWell(
                                      onTap: _showEditProfileDialog,
                                      child: const Padding(
                                        padding: EdgeInsets.all(4.0),
                                        child: Icon(
                                          Icons.edit,
                                          size: 16,
                                          color: Colors.white70,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  user?.email ??
                                      (_currentUserModel?.email.isNotEmpty ==
                                              true
                                          ? _currentUserModel!.email
                                          : 'Tidak ada email'),
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ];
                  },
              body: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 20,
                ),
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
                      'Akun & Keamanan',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildMenuItem(
                      icon: Icons.security_outlined,
                      title: 'Keamanan & Biometrik',
                      subtitle: 'Kelola & hapus akses sidik jari/wajah',
                      onTap: _showBiometricManageModal,
                    ),
                    _buildMenuItem(
                      icon: Icons.logout,
                      title: 'Keluar',
                      subtitle: 'Keluar dari akun LelunganJogja',
                      textColor: Colors.redAccent,
                      iconColor: Colors.redAccent,
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (dialogContext) => AlertDialog(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            title: Text(
                              'Keluar Akun',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            content: Text(
                              'Apakah kamu yakin ingin keluar dari LelunganJogja?',
                              style: GoogleFonts.poppins(fontSize: 13),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(dialogContext),
                                child: Text(
                                  'Batal',
                                  style: GoogleFonts.poppins(
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () async {
                                  final navigator = Navigator.of(context);
                                  Navigator.pop(dialogContext);
                                  await _supabase.auth.signOut();
                                  if (!mounted) return;
                                  navigator.pushAndRemoveUntil(
                                    MaterialPageRoute(
                                      builder: (context) => const LoginScreen(),
                                    ),
                                    (route) => false,
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.redAccent,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  'Keluar',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
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
          style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      ),
    );
  }
}
