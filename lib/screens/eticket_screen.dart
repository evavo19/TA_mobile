import 'dart:async'; // Diperlukan untuk StreamSubscription
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/pesanan_model.dart';
import '../services/blockchain_service.dart';

class ETicketScreen extends StatefulWidget {
  final PesananModel? pesanan;
  final String? hashTiket;

  const ETicketScreen({super.key, this.pesanan, this.hashTiket});

  @override
  State<ETicketScreen> createState() => _ETicketScreenState();
}

class _ETicketScreenState extends State<ETicketScreen> {
  PesananModel? _directPesanan;
  List<PesananModel> _listPesanan = [];
  bool _isVerified = true;
  bool _isLoading = true;
  String _displayHash = '';

  // Langganan stream untuk Supabase Realtime
  StreamSubscription? _ticketSubscription;

  @override
  void initState() {
    super.initState();
    if (widget.pesanan != null) {
      _directPesanan = widget.pesanan;
      String h = widget.hashTiket ?? widget.pesanan!.hash;

      _displayHash = h;
      _isVerified = h.isNotEmpty;
      _isLoading = false;

      _verifyBlockchainData(_directPesanan!.qrCode, h);

      // Dengarkan perubahan real-time untuk detail tiket tunggal ini
      _subscribeToSingleTicket(_directPesanan!.id);
    } else {
      _loadUserTickets();
      // Dengarkan perubahan real-time untuk daftar tiket pengguna
      _subscribeToUserTickets();
    }
  }

  @override
  void dispose() {
    // Batalkan stream listener saat layar ditutup agar tidak terjadi memory leak
    _ticketSubscription?.cancel();
    super.dispose();
  }

  // 1. Real-time Stream untuk Daftar Tiket (Daftar Banyak Tiket)
  void _subscribeToUserTickets() {
    final supabase = Supabase.instance.client;
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) return;

    _ticketSubscription = supabase
        .from('blockchain_tiket')
        .stream(primaryKey: ['id'])
        .eq('user_id', currentUser.id)
        .order('id', ascending: false)
        .listen((data) {
      if (mounted) {
        setState(() {
          _listPesanan = data.map((map) => PesananModel.fromMap(map)).toList();
          _isLoading = false;
        });
      }
    });
  }

  // 2. Real-time Stream untuk Detail Tiket Tunggal
  void _subscribeToSingleTicket(dynamic ticketId) {
    final supabase = Supabase.instance.client;

    _ticketSubscription = supabase
        .from('blockchain_tiket')
        .stream(primaryKey: ['id'])
        .eq('id', ticketId)
        .listen((data) {
      if (data.isNotEmpty && mounted) {
        setState(() {
          _directPesanan = PesananModel.fromMap(data.first);
        });
      }
    });
  }

  Future<void> _verifyBlockchainData(String qrCode, String currentHash) async {
    bool isAuthentic = await BlockchainService.verifikasiTiket(
      qrCode,
      currentHash,
    );

    if (mounted) {
      setState(() {
        _isVerified = isAuthentic || currentHash.isNotEmpty;
      });
    }
  }

  Future<void> _loadUserTickets() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final supabase = Supabase.instance.client;
    final currentUser = supabase.auth.currentUser;

    if (currentUser == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final response = await supabase
          .from('blockchain_tiket')
          .select()
          .eq('user_id', currentUser.id)
          .order('id', ascending: false);

      if (mounted) {
        setState(() {
          _listPesanan = (response as List)
              .map((map) => PesananModel.fromMap(map))
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Gagal mengambil data tiket user: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Mata uang dibaca dari kolom 'mata_uang' di database (sesuai pilihan user saat memesan)
  String _dapatkanMataUang(PesananModel item) {
    final kode = item.mataUang.trim().toUpperCase();
    return kode.isEmpty ? 'IDR' : kode;
  }

  // IDR dan JPY tanpa desimal, USD dan EUR dua desimal
  String _formatTotal(PesananModel item) {
    final kode = _dapatkanMataUang(item);
    final desimal = (kode == 'IDR' || kode == 'JPY') ? 0 : 2;
    return '$kode ${item.totalHarga.toStringAsFixed(desimal)}';
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
          widget.pesanan != null ? 'Detail Tiket' : 'Tiket Saya',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading && widget.pesanan == null
          ? const Center(child: CircularProgressIndicator())
          : widget.pesanan != null
              ? _buildDirectTicketView(primaryColor)
              : _buildTixIdListView(primaryColor),
    );
  }

  Widget _buildDirectTicketView(Color primaryColor) {
    final item = _directPesanan!;
    final bool isUsed = item.isUsed;

    return Center(
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
                color: Colors.black.withValues(alpha: 0.06),
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
                  color: isUsed
                      ? const Color(0xFFFFEBEE)
                      : (_isVerified
                          ? const Color(0xFFE8F5E9)
                          : const Color(0xFFFFEBEE)),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isUsed
                          ? Icons.block_rounded
                          : (_isVerified
                              ? Icons.verified_user_rounded
                              : Icons.gpp_maybe_rounded),
                      size: 16,
                      color: isUsed
                          ? Colors.red.shade700
                          : (_isVerified
                              ? const Color(0xFF2E7D32)
                              : Colors.red),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isUsed
                          ? 'Sudah Digunakan (Hangus)'
                          : (_isVerified
                              ? 'Terverifikasi ✓'
                              : 'Belum Terverifikasi'),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isUsed
                            ? Colors.red.shade700
                            : (_isVerified
                                ? const Color(0xFF2E7D32)
                                : Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                item.namaWisata,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tanggal: ${item.tanggalKunjungan}',
                style: GoogleFonts.poppins(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 20),
              Container(
                width: 200,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  children: [
                    QrImageView(
                      data: item.qrCode.isNotEmpty
                          ? item.qrCode
                          : 'VALID_TICKET',
                      version: QrVersions.auto,
                      size: 160.0,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isUsed
                          ? 'Tiket Telah Hangus'
                          : 'Tunjukkan QR ini ke Petugas',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: isUsed ? Colors.red.shade700 : Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (_displayHash.isNotEmpty || item.hash.isNotEmpty) ...[
                Text(
                  'Hash Tiket (Blockchain):',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 2),
                SelectableText(
                  (_displayHash.isNotEmpty ? _displayHash : item.hash).length >
                          20
                      ? '${(_displayHash.isNotEmpty ? _displayHash : item.hash).substring(0, 16)}...'
                      : (_displayHash.isNotEmpty ? _displayHash : item.hash),
                  style: GoogleFonts.firaCode(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Text(
                'Jumlah Tiket: ${item.jumlahTiket} Orang',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Total: ${_formatTotal(item)}',
                style: GoogleFonts.poppins(
                  color: primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTixIdListView(Color primaryColor) {
    if (_listPesanan.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadUserTickets,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.7,
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.confirmation_number_outlined,
                  size: 64,
                  color: primaryColor,
                ),
                const SizedBox(height: 16),
                Text(
                  'Belum Ada E-Tiket',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tarik ke bawah untuk memuat ulang',
                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadUserTickets,
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _listPesanan.length,
        itemBuilder: (context, index) {
          final item = _listPesanan[index];
          final bool isUsed = item.isUsed;

          return InkWell(
            // 🛑 Mencegah klik apabila tiket sudah hangus
            onTap: isUsed
                ? null
                : () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ETicketScreen(
                          pesanan: item,
                          hashTiket: item.hash,
                        ),
                      ),
                    );
                  },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isUsed
                                  ? 'Sudah Digunakan (Hangus)'
                                  : 'Terverifikasi ✓',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isUsed
                                    ? Colors.red.shade700
                                    : const Color(0xFF2E7D32),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isUsed
                                    ? Colors.red.shade50
                                    : primaryColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                isUsed ? 'HANGUS' : 'Lunas',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isUsed
                                      ? Colors.red.shade700
                                      : primaryColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          item.namaWisata,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          'Tanggal: ${item.tanggalKunjungan}',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      const SizedBox(
                        height: 16,
                        width: 8,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.only(
                              topRight: Radius.circular(8),
                              bottomRight: Radius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return Flex(
                              direction: Axis.horizontal,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: List.generate(
                                (constraints.constrainWidth() / 10).floor(),
                                (_) => const SizedBox(
                                  width: 5,
                                  height: 1,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: Color(0xFFCBD5E1),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(
                        height: 16,
                        width: 8,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(8),
                              bottomLeft: Radius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        QrImageView(
                          data: item.qrCode,
                          version: QrVersions.auto,
                          size: 70.0,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Jumlah Tiket: ${item.jumlahTiket} Orang',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              Text(
                                'Total: ${_formatTotal(item)}',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: isUsed ? Colors.grey : primaryColor,
                                ),
                              ),
                            ],
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
      ),
    );
  }
}