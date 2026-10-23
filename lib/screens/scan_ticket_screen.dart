import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScanTicketScreen extends StatefulWidget {
  const ScanTicketScreen({super.key});

  @override
  State<ScanTicketScreen> createState() => _ScanTicketScreenState();
}

class _ScanTicketScreenState extends State<ScanTicketScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _isLoading = false;
  bool _isProcessing = false; // 👈 Proteksi agar tidak scan berulang/berkedip
  String? _message;
  bool _isSuccess = false;
  Map<String, dynamic>? _scannedTicketData;
  late MobileScannerController cameraController;

  @override
  void initState() {
    super.initState();
    cameraController = MobileScannerController();
  }

  @override
  void dispose() {
    cameraController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _logout(BuildContext context) async {
    final supabase = Supabase.instance.client;
    try {
      await supabase.auth.signOut();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
      }
    } catch (e) {
      debugPrint("Gagal logout: $e");
    }
  }

  Future<void> _validasiDanUbahStatus(String rawData) async {
    final qrData = rawData.trim();
    if (qrData.isEmpty || _isProcessing) return;

    setState(() {
      _isProcessing = true; // 👈 Matikan scanner sementara
      _isLoading = true;
      _message = null;
      _scannedTicketData = null;
    });

    // 🛑 Hentikan kamera fisik agar tidak membaca frame berkedip
    try {
      await cameraController.stop();
    } catch (_) {}

    final supabase = Supabase.instance.client;

    try {
      // Cari tiket di Supabase berdasarkan ticket_id
      final response = await supabase
          .from('blockchain_tiket')
          .select()
          .ilike('ticket_id', '%$qrData%')
          .maybeSingle();

      if (response == null) {
        setState(() {
          _isLoading = false;
          _isSuccess = false;
          _message = "Tiket tidak ditemukan di database!";
        });
        return;
      }

      final varId = response['id'];
      final bool isAlreadyUsed = response['status'] == true;

      if (isAlreadyUsed) {
        setState(() {
          _isLoading = false;
          _isSuccess = false;
          _message = "PERINGATAN: Tiket ini sudah pernah digunakan (Hangus)!";
          _scannedTicketData = response;
        });
        return;
      }

      // UPDATE status di database menjadi true (hangus)
      await supabase
          .from('blockchain_tiket')
          .update({'status': true})
          .eq('id', varId);

      response['status'] = true;

      setState(() {
        _isLoading = false;
        _isSuccess = true;
        _message = "BERHASIL! Tiket divalidasi & status diubah jadi Hangus.";
        _scannedTicketData = response;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isSuccess = false;
        _message = "Terjadi kesalahan sistem: $e";
      });
    }
  }

  // Fungsi untuk mereset scanner agar bisa scan tiket berikutnya
  void _resetScanner() {
    setState(() {
      _controller.clear();
      _message = null;
      _scannedTicketData = null;
      _isProcessing = false; // Aktifkan kembali scanner
    });
    cameraController.start();
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF1550B6);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: primaryColor,
        elevation: 0,
        title: Text(
          'Scanner Petugas Wisata',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
            tooltip: 'Logout',
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pemindaian QR Code Tiket Pengunjung',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Arahkan kamera ke QR Code untuk memvalidasi dan mengubah status tiket secara otomatis.',
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),

            // Kamera Scanner dengan Proteksi _isProcessing (Tidak berkedip)
            Container(
              height: 220,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: MobileScanner(
                  controller: cameraController,
                  onDetect: (capture) {
                    if (_isProcessing || _isLoading) return; // Mencegah scan bertubi-tubi
                    final List<Barcode> barcodes = capture.barcodes;
                    for (final barcode in barcodes) {
                      if (barcode.rawValue != null) {
                        final String code = barcode.rawValue!;
                        _controller.text = code;
                        _validasiDanUbahStatus(code);
                        break;
                      }
                    }
                  },
                ),
              ),
            ),

            const SizedBox(height: 20),

            TextField(
              controller: _controller,
              decoration: InputDecoration(
                labelText: 'Data Ticket ID / URL',
                hintText: 'Hasil scan QR atau masukkan ID',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : () => _validasiDanUbahStatus(_controller.text.trim()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              'Validasi & Ubah Status',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                    ),
                  ),
                ),
                if (_message != null) ...[
                  const SizedBox(width: 10),
                  // Tombol reset untuk scan tiket berikutnya
                  IconButton(
                    onPressed: _resetScanner,
                    icon: const Icon(Icons.refresh_rounded, color: primaryColor, size: 30),
                    tooltip: 'Scan Tiket Lain',
                  ),
                ]
              ],
            ),

            const SizedBox(height: 20),

            if (_message != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _isSuccess ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _isSuccess ? const Color(0xFF2E7D32) : Colors.red,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _isSuccess ? Icons.check_circle_rounded : Icons.error_rounded,
                          color: _isSuccess ? const Color(0xFF2E7D32) : Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _message!,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: _isSuccess ? const Color(0xFF2E7D32) : Colors.red.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_scannedTicketData != null) ...[
                      const Divider(height: 20),
                      Text('Wisata: ${_scannedTicketData!['nama_wisata'] ?? '-'}', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                      Text('Tanggal: ${_scannedTicketData!['tanggal_kunjungan'] ?? '-'}', style: GoogleFonts.poppins(fontSize: 12)),
                      Text('Status Database: TRUE (Hangus)', style: GoogleFonts.poppins(fontSize: 12, color: Colors.red.shade700, fontWeight: FontWeight.bold)),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}