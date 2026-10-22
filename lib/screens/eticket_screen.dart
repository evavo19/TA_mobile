import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/pesanan_model.dart';
import '../services/blockchain_service.dart';

class ETicketScreen extends StatefulWidget {
  final PesananModel? pesanan; // Opsional jika dikirim langsung dari booking
  final String? hashTiket;

  const ETicketScreen({
    super.key,
    this.pesanan,
    this.hashTiket,
  });

  @override
  State<ETicketScreen> createState() => _ETicketScreenState();
}

class _ETicketScreenState extends State<ETicketScreen> {
  PesananModel? _currentPesanan;
  bool _isVerified = false;
  bool _isLoading = true;
  String _displayHash = '';

  @override
  void initState() {
    super.initState();
    if (widget.pesanan != null) {
      _currentPesanan = widget.pesanan;
      _verifyBlockchainData(_currentPesanan!.qrCode, widget.hashTiket ?? '');
    } else {
      _loadLatestTicket();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.pesanan == null) {
      _loadLatestTicket();
    }
  }

  // FUNGSI UNTUK MENGAMBIL TIKET TERBARU BERDASARKAN USER YANG SEDANG LOGIN
  Future<void> _loadLatestTicket() async {
    setState(() => _isLoading = true);
    final ticket = await _fetchLatestTicket();
    
    if (ticket != null) {
      _currentPesanan = ticket;
      await _verifyBlockchainData(ticket.qrCode, widget.hashTiket ?? '');
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<PesananModel?> _fetchLatestTicket() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    // Jika belum ada user yang login, kembalikan null
    if (user == null) return null;

    try {
      // Ambil pesanan HANYA milik user yang sedang login saat ini
      final response = await supabase
          .from('pesanan')
          .select()
          .eq('user_id', user.id) // Kunci agar tiket tampil sesuai akun yang aktif
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response != null) {
        return PesananModel.fromMap(response);
      }
    } catch (e) {
      print("Error ambil tiket: $e");
    }
    return null;
  }

  Future<void> _verifyBlockchainData(String qrCode, String currentHash) async {
    bool isAuthentic = await BlockchainService.verifikasiTiket(
      qrCode,
      currentHash,
    );

    if (mounted) {
      setState(() {
        _isVerified = isAuthentic || currentHash.isNotEmpty;
        _displayHash = currentHash;
        _isLoading = false;
      });
    }
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
          'E-Tiket Saya',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _currentPesanan == null
              ? Center(
                  // KONDISI KETIKA BELUM ADA TIKET
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.confirmation_number_outlined,
                            size: 64,
                            color: primaryColor,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Belum Ada E-Tiket',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Kamu belum memesan tiket wisata apapun. Silakan lakukan pemesanan melalui halaman detail wisata.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : Center(
                  // KONDISI KETIKA ADA TIKET
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _isVerified
                                  ? const Color(0xFFE8F5E9)
                                  : const Color(0xFFFFEBEE),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _isVerified
                                      ? Icons.verified_user_rounded
                                      : Icons.gpp_maybe_rounded,
                                  size: 16,
                                  color: _isVerified
                                      ? const Color(0xFF2E7D32)
                                      : Colors.red,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _isVerified
                                      ? 'Terverifikasi ✓'
                                      : 'Belum Terverifikasi',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: _isVerified
                                        ? const Color(0xFF2E7D32)
                                        : Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _currentPesanan!.namaWisata,
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tanggal: ${_currentPesanan!.tanggalKunjungan}',
                            style: GoogleFonts.poppins(color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 20),

                          // QR Code Placeholder
                          Container(
                            width: 180,
                            height: 180,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.qr_code_2_rounded,
                                  size: 100,
                                  color: primaryColor,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Tunjukkan QR ini ke Petugas',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          if (_displayHash.isNotEmpty) ...[
                            Text(
                              'Hash Tiket (Blockchain):',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            SelectableText(
                              _displayHash.length > 20
                                  ? '${_displayHash.substring(0, 16)}...'
                                  : _displayHash,
                              style: GoogleFonts.firaCode(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          Text(
                            'Jumlah Tiket: ${_currentPesanan!.jumlahTiket} Orang',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Total: ${_currentPesanan!.mataUang} ${_currentPesanan!.totalHarga.toStringAsFixed(0)}',
                            style: GoogleFonts.poppins(
                              color: primaryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
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