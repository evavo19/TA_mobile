import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/pesanan_model.dart';
import '../services/blockchain_service.dart';

class ETicketScreen extends StatefulWidget {
  final PesananModel? pesanan;
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
  PesananModel? _directPesanan;
  List<PesananModel> _listPesanan = [];
  bool _isVerified = false;
  bool _isLoading = true;
  String _displayHash = '';

  @override
  void initState() {
    super.initState();
    if (widget.pesanan != null) {
      _directPesanan = widget.pesanan;
      _verifyBlockchainData(_directPesanan!.qrCode, widget.hashTiket ?? '');
    } else {
      _loadAllTickets();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.pesanan == null) {
      _loadAllTickets();
    }
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

  Future<void> _loadAllTickets() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final supabase = Supabase.instance.client;

    try {
      final response = await supabase
          .from('blockchain_tiket')
          .select()
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
      debugPrint("Gagal mengambil data dari blockchain_tiket: $e");
      if (mounted) setState(() => _isLoading = false);
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
          widget.pesanan != null ? 'Detail Tiket' : 'Tiket Saya',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: [
          if (widget.pesanan == null)
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _loadAllTickets,
            ),
        ],
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
                color: Colors.black.withOpacity(0.06),
                blurRadius: 12,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                      color: _isVerified ? const Color(0xFF2E7D32) : Colors.red,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _isVerified ? 'Terverifikasi ✓' : 'Belum Terverifikasi',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _isVerified ? const Color(0xFF2E7D32) : Colors.red,
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
                      data: item.qrCode.isNotEmpty ? item.qrCode : 'VALID_TICKET',
                      version: QrVersions.auto,
                      size: 160.0,
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
                'Jumlah Tiket: ${item.jumlahTiket} Orang',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Total: IDR ${item.totalHarga.toStringAsFixed(0)}',
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
        onRefresh: _loadAllTickets,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.7,
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.confirmation_number_outlined, size: 64, color: primaryColor),
                const SizedBox(height: 16),
                Text(
                  'Belum Ada E-Tiket',
                  style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
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
      onRefresh: _loadAllTickets,
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _listPesanan.length,
        itemBuilder: (context, index) {
          final item = _listPesanan[index];
          return InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ETicketScreen(
                    pesanan: item,
                    hashTiket: item.hash.isNotEmpty ? item.hash : item.qrCode,
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
                    color: Colors.black.withOpacity(0.06),
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
                              'Terverifikasi ✓',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF2E7D32),
                              ),
                            ),
                            Text(
                              'Lunas',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
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
                                    decoration:
                                        BoxDecoration(color: Color(0xFFCBD5E1)),
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
                                ),
                              ),
                              Text(
                                'Total: IDR ${item.totalHarga.toStringAsFixed(0)}',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor,
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