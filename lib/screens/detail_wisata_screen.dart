import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/wisata_model.dart';
import 'booking_screen.dart';

class DetailWisataScreen extends StatefulWidget {
  final WisataModel wisata;

  const DetailWisataScreen({super.key, required this.wisata});

  @override
  State<DetailWisataScreen> createState() => _DetailWisataScreenState();
}

class _DetailWisataScreenState extends State<DetailWisataScreen> {
  // Pilihan Mata Uang & Kurs Konversi (Simulasi)
  String _selectedCurrency = 'IDR';
  final Map<String, double> _currencyRates = {
    'IDR': 1.0,
    'USD': 0.000064,
    'EUR': 0.000059,
    'JPY': 0.0096,
  };

  final Map<String, String> _currencySymbols = {
    'IDR': 'Rp ',
    'USD': '\$ ',
    'EUR': '€ ',
    'JPY': '¥ ',
  };

  // Pilihan Zona Waktu & Perbedaan Jam dari WIB
  String _selectedTimeZone = 'WIB';
  final Map<String, int> _timeZoneOffsets = {
    'WIB': 0,
    'WITA': 1,
    'WIT': 2,
    'London': -6,
  };

  // Helper Menghitung Harga Terkonversi
  String _getFormattedPrice(int hargaRupiah) {
    double rate = _currencyRates[_selectedCurrency] ?? 1.0;
    String symbol = _currencySymbols[_selectedCurrency] ?? 'Rp ';
    double convertedPrice = hargaRupiah * rate;

    if (_selectedCurrency == 'IDR') {
      return '$symbol${hargaRupiah.toStringAsFixed(0)}';
    } else {
      return '$symbol${convertedPrice.toStringAsFixed(2)}';
    }
  }

  // Helper Menghitung Konversi Jam Buka
  String _getConvertedJamBuka(String jamBukaWib) {
    int offset = _timeZoneOffsets[_selectedTimeZone] ?? 0;
    if (offset == 0) return jamBukaWib;

    try {
      // Mengambil angka jam dari string seperti "08.00 - 17.00 WIB"
      final parts = jamBukaWib.replaceAll('WIB', '').trim().split('-');
      if (parts.length != 2) return '$jamBukaWib ($_selectedTimeZone)';

      String startStr = parts[0].trim().replaceAll('.', ':');
      String endStr = parts[1].trim().replaceAll('.', ':');

      int startHour = int.parse(startStr.split(':')[0]) + offset;
      int endHour = int.parse(endStr.split(':')[0]) + offset;

      // Normalisasi 24 jam
      startHour = (startHour + 24) % 24;
      endHour = (endHour + 24) % 24;

      String formatHour(int hour) => hour.toString().padLeft(2, '0');

      return '${formatHour(startHour)}:00 - ${formatHour(endHour)}:00 $_selectedTimeZone';
    } catch (e) {
      return '$jamBukaWib ($_selectedTimeZone)';
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF1550B6);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Foto Wisata
                Stack(
                  children: [
                    Image.network(
                      widget.wisata.gambarUrl,
                      height: 320,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 320,
                        color: Colors.grey.shade300,
                        child: const Icon(Icons.image, size: 60),
                      ),
                    ),
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withOpacity(0.4),
                              Colors.transparent,
                              Colors.black.withOpacity(0.2),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Tombol Back
                    Positioned(
                      top: 48,
                      left: 16,
                      child: CircleAvatar(
                        backgroundColor: Colors.black.withOpacity(0.4),
                        child: IconButton(
                          icon: const Icon(
                            Icons.arrow_back_ios_new,
                            color: Colors.white,
                            size: 18,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                    ),
                  ],
                ),

                // Konten Detail
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Kategori & Rating
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F1FF),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              widget.wisata.kategori,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: primaryColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                color: Color(0xFFF59E0B),
                                size: 22,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${widget.wisata.rating}',
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                ' (${widget.wisata.jumlahUlasan} ulasan)',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Nama Wisata
                      Text(
                        widget.wisata.nama,
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1E293B),
                        ),
                      ),

                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 12),

                      // Filter Konversi Mata Uang & Jam
                      Row(
                        children: [
                          // Dropdown Mata Uang
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Mata Uang:',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF6F8FB),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _selectedCurrency,
                                      isExpanded: true,
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        color: Colors.black87,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      items: _currencyRates.keys.map((code) {
                                        return DropdownMenuItem(
                                          value: code,
                                          child: Text(code),
                                        );
                                      }).toList(),
                                      onChanged: (val) {
                                        if (val != null) {
                                          setState(
                                            () => _selectedCurrency = val,
                                          );
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Dropdown Zona Waktu
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Zona Waktu:',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF6F8FB),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _selectedTimeZone,
                                      isExpanded: true,
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        color: Colors.black87,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      items: _timeZoneOffsets.keys.map((zone) {
                                        return DropdownMenuItem(
                                          value: zone,
                                          child: Text(zone),
                                        );
                                      }).toList(),
                                      onChanged: (val) {
                                        if (val != null) {
                                          setState(
                                            () => _selectedTimeZone = val,
                                          );
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Jam Buka Terkonversi
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.access_time_rounded,
                              color: primaryColor,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Jam Buka: ',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              _getConvertedJamBuka(widget.wisata.jamBuka),
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Deskripsi Wisata
                      Text(
                        'Deskripsi',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.wisata.deskripsi.isEmpty
                            ? 'Tidak ada deskripsi tersedia.'
                            : widget.wisata.deskripsi,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                          height: 1.6,
                        ),
                      ),

                      const SizedBox(height: 100), // Spasi Bottom Bar
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Bottom Bar Harga & Tombol Pesan Tiket
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    // Informasi Harga
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Harga Tiket',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          Text(
                            _getFormattedPrice(widget.wisata.hargaWeekday),
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Tombol Pesan
                    SizedBox(
                      height: 48,
                      width: 160,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => BookingScreen(
                                wisata: widget.wisata,
                                selectedCurrency: _selectedCurrency,
                                currencyRate:
                                    _currencyRates[_selectedCurrency] ?? 1.0,
                                currencySymbol:
                                    _currencySymbols[_selectedCurrency] ??
                                    'Rp ',
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        child: Text(
                          'Pesan Tiket',
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
          ),
        ],
      ),
    );
  }
}
