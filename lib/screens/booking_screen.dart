import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/wisata_model.dart';
import '../services/blockchain_service.dart';
import '../services/notifikasi_service.dart';

class BookingScreen extends StatefulWidget {
  final WisataModel wisata;
  final String selectedCurrency;
  final double currencyRate;
  final String currencySymbol;

  const BookingScreen({
    super.key,
    required this.wisata,
    required this.selectedCurrency,
    required this.currencyRate,
    required this.currencySymbol,
  });

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  DateTime? _selectedDate;
  int _jumlahTiket = 1;
  String _selectedPayment = 'QRIS';
  bool _isLoading = false;
  OverlayEntry? _overlayEntry;

  final List<Map<String, String>> _paymentMethods = [
    {'name': 'QRIS', 'desc': 'Scan QR Code secara cepat'},
    {'name': 'Transfer Bank (BCA/Mandiri)', 'desc': 'Virtual Account Bank'},
    {'name': 'E-Wallet (Gopay/OVO)', 'desc': 'Pembayaran dompet digital'},
  ];

  @override
  void dispose() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFF1550B6)),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  bool _isWeekend(DateTime date) {
    return date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
  }

  double _calculateTotalPrice() {
    int hargaSatuan = _selectedDate != null && _isWeekend(_selectedDate!)
        ? widget.wisata.hargaWeekend
        : widget.wisata.hargaWeekday;

    double hargaKoin = hargaSatuan * widget.currencyRate;
    return hargaKoin * _jumlahTiket;
  }

  void _showTopNotification(String title, String message) {
    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 10,
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF1550B6),
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.notifications_active_rounded, color: Colors.white, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        message,
                        style: GoogleFonts.poppins(fontSize: 11, color: Colors.white70),
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

    Overlay.of(context).insert(_overlayEntry!);

    Future.delayed(const Duration(seconds: 3), () {
      _overlayEntry?.remove();
      _overlayEntry = null;
    });
  }

  Future<void> _prosesPembayaran() async {
    if (_selectedDate == null || _isLoading) return;

    setState(() => _isLoading = true);

    String tanggalFormatted =
        '${_selectedDate!.day.toString().padLeft(2, '0')}/${_selectedDate!.month.toString().padLeft(2, '0')}/${_selectedDate!.year}';

    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    final String qrCodeId =
        'https://lelunganjogja.com/ticket?id=${DateTime.now().millisecondsSinceEpoch}&user=${user?.id ?? "guest"}&wisata=${widget.wisata.nama}';

    try {
      // PROSES SIMPAN CHUKUP DARI SINI (SISTEM BLOCKCHAIN TERINTEGRASI)
      await BlockchainService.tambahBlok(
        ticketId: qrCodeId,
        namaWisata: widget.wisata.nama,
        tanggalKunjungan: tanggalFormatted,
        jumlahTiket: _jumlahTiket,
        totalHarga: _calculateTotalPrice(),
      );

      debugPrint("Berhasil menyimpan tiket secara tunggal ke Supabase!");
    } catch (e) {
      debugPrint("Gagal memproses pembayaran: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }

    NotificationService.show(
      title: 'Pembayaran Berhasil',
      body: 'Tiket ${widget.wisata.nama} ($_jumlahTiket orang) berhasil dipesan!',
    );

    if (mounted) {
      _showTopNotification(
        'Pembayaran Berhasil',
        'Tiket berhasil disimpan!',
      );

      // LANGSUNG TUTUP FORM PEMESANAN
      Future.delayed(const Duration(milliseconds: 800), () {
        if (!mounted) return;
        Navigator.pop(context);
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Form Pemesanan',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 18,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            widget.wisata.gambarUrl,
                            width: 70,
                            height: 70,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                              width: 70,
                              height: 70,
                              color: Colors.grey.shade200,
                              child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.wisata.nama,
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: const Color(0xFF1E293B),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.wisata.kategori,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  Text(
                    'Tanggal Kunjungan',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: () => _selectDate(context),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _selectedDate == null
                                ? 'Pilih Tanggal'
                                : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year} ${_isWeekend(_selectedDate!) ? "(Weekend)" : "(Weekday)"}',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: _selectedDate == null ? Colors.grey : Colors.black87,
                              fontWeight: _selectedDate == null ? FontWeight.normal : FontWeight.bold,
                            ),
                          ),
                          const Icon(Icons.calendar_month_rounded, color: primaryColor),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  Text(
                    'Jumlah Tiket',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Jumlah Orang', style: GoogleFonts.poppins(fontSize: 14)),
                        Row(
                          children: [
                            IconButton(
                              onPressed: _jumlahTiket > 1 ? () => setState(() => _jumlahTiket--) : null,
                              icon: const Icon(Icons.remove_circle_outline),
                              color: primaryColor,
                            ),
                            Text(
                              '$_jumlahTiket',
                              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            IconButton(
                              onPressed: () => setState(() => _jumlahTiket++),
                              icon: const Icon(Icons.add_circle_outline),
                              color: primaryColor,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  Text(
                    'Metode Pembayaran',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Column(
                    children: _paymentMethods.map((method) {
                      final isSelected = _selectedPayment == method['name'];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? primaryColor : Colors.grey.shade300,
                            width: isSelected ? 1.8 : 1,
                          ),
                        ),
                        child: RadioListTile<String>(
                          activeColor: primaryColor,
                          groupValue: _selectedPayment,
                          value: method['name']!,
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedPayment = val);
                          },
                          title: Text(
                            method['name']!,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          subtitle: Text(
                            method['desc']!,
                            style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Total Pembayaran', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                        Text(
                          widget.selectedCurrency == 'IDR'
                              ? '${widget.currencySymbol}${_calculateTotalPrice().toStringAsFixed(0)}'
                              : '${widget.currencySymbol}${_calculateTotalPrice().toStringAsFixed(2)}',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 48,
                    width: 160,
                    child: ElevatedButton(
                      onPressed: (_selectedDate == null || _isLoading) ? null : _prosesPembayaran,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Text(
                              'Bayar Sekarang',
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
        ],
      ),
    );
  }
}