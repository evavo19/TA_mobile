import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/pesanan_model.dart';
import '../services/blockchain_service.dart';

class ETicketScreen extends StatefulWidget {
  final PesananModel pesanan;
  final String? hashTiket;

  const ETicketScreen({
    super.key,
    required this.pesanan,
    this.hashTiket,
  });

  @override
  State<ETicketScreen> createState() => _ETicketScreenState();
}

class _ETicketScreenState extends State<ETicketScreen> {
  bool _isVerified = false;
  bool _isLoading = true;
  String _displayHash = '';

  @override
  void initState() {
    super.initState();
    _verifyBlockchainData();
  }

  Future<void> _verifyBlockchainData() async {
    String currentHash = widget.hashTiket ?? '';

    bool isAuthentic = await BlockchainService.verifikasiTiket(
      widget.pesanan.qrCode,
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
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
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
                if (_isLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
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
                              ? 'Terverifikasi Blockchain ✓'
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
                  widget.pesanan.namaWisata,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tanggal: ${widget.pesanan.tanggalKunjungan}',
                  style: GoogleFonts.poppins(color: Colors.grey),
                ),
                const SizedBox(height: 20),

                Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.qr_code_2_rounded,
                        size: 100,
                        color: primaryColor,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Tunjukkan QR ini ke Petugas',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
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
                  'Jumlah Tiket: ${widget.pesanan.jumlahTiket} Orang',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
                Text(
                  'Total: ${widget.pesanan.mataUang} ${widget.pesanan.totalHarga.toStringAsFixed(0)}',
                  style: GoogleFonts.poppins(
                    color: primaryColor,
                    fontWeight: FontWeight.bold,
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