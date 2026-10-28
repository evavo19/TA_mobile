import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../models/wisata_model.dart';
import 'booking_screen.dart';
import 'main_screen.dart';

class DetailWisataScreen extends StatefulWidget {
  final WisataModel wisata;

  const DetailWisataScreen({super.key, required this.wisata});

  @override
  State<DetailWisataScreen> createState() => _DetailWisataScreenState();
}

class _DetailWisataScreenState extends State<DetailWisataScreen> {
  final _supabase = Supabase.instance.client;
  bool _isCheckingProfile = false;

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

  String _selectedTimeZone = 'WIB';
  final Map<String, int> _timeZoneOffsets = {
    'WIB': 0,
    'WITA': 1,
    'WIT': 2,
    'London': -6,
  };

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

  String _getConvertedJamBuka(String jamBukaWib) {
    int offset = _timeZoneOffsets[_selectedTimeZone] ?? 0;
    if (offset == 0) return jamBukaWib;

    try {
      final parts = jamBukaWib.replaceAll('WIB', '').trim().split('-');
      if (parts.length != 2) return '$jamBukaWib ($_selectedTimeZone)';

      String startStr = parts[0].trim().replaceAll('.', ':');
      String endStr = parts[1].trim().replaceAll('.', ':');

      int startHour = int.parse(startStr.split(':')[0]) + offset;
      int endHour = int.parse(endStr.split(':')[0]) + offset;

      startHour = (startHour + 24) % 24;
      endHour = (endHour + 24) % 24;

      String formatHour(int hour) => hour.toString().padLeft(2, '0');

      return '${formatHour(startHour)}:00 - ${formatHour(endHour)}:00 $_selectedTimeZone';
    } catch (e) {
      return '$jamBukaWib ($_selectedTimeZone)';
    }
  }

  Future<void> _checkProfileAndBooking() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    setState(() => _isCheckingProfile = true);

    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      setState(() => _isCheckingProfile = false);

      bool isProfileIncomplete = false;

      if (response == null) {
        isProfileIncomplete = true;
      } else {

        final model = UserModel.fromJson(Map<String, dynamic>.from(response));
        final String fullName = (model.fullName as String?) ?? '';
        final String phone = (model.phone as String?) ?? '';
        final String age = (model.age as String?) ?? '';
        final String address = (model.address as String?) ?? '';

        debugPrint(
          'Cek profil -> nama:"$fullName" hp:"$phone" usia:"$age" alamat:"$address"',
        );

        if (fullName.trim().isEmpty ||
            phone.trim().isEmpty ||
            age.trim().isEmpty ||
            address.trim().isEmpty) {
          isProfileIncomplete = true;
        }
      }

      if (!mounted) return;

      if (isProfileIncomplete) {
  
        showDialog(
          context: context,
          builder: (dialogContext) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.amber.withAlpha(30),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.amber,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Identitas Belum Lengkap',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Mohon lengkapi identitas diri Anda di halaman profil terlebih dahulu sebelum melakukan pemesanan tiket.',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      // TOMBOL BATAL: Menutup pop-up dan tetap di halaman detail wisata
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                          child: Text(
                            'Batal',
                            style: GoogleFonts.poppins(
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // TOMBOL LENGKAPI PROFIL: Menutup pop-up lalu masuk ke halaman profil
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            Navigator.pop(dialogContext); 
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                
                                builder: (context) =>
                                    const MainScreen(initialIndex: 3),
                              ),
                            );

                            if (!mounted) return;
                            _checkProfileAndBooking();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1550B6),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Lengkapi Profil',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      } else {

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BookingScreen(
              wisata: widget.wisata,
              selectedCurrency: _selectedCurrency,
              currencyRate: _currencyRates[_selectedCurrency] ?? 1.0,
              currencySymbol: _currencySymbols[_selectedCurrency] ?? 'Rp ',
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _isCheckingProfile = false);
      debugPrint('Error cek profil: $e');
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
                              Colors.black.withValues(alpha: 0.4),
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.2),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 48,
                      left: 16,
                      child: CircleAvatar(
                        backgroundColor: Colors.black.withValues(alpha: 0.4),
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

                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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

                      Row(
                        children: [
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
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Bottom Bar Tombol Pesan
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 16,
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
                    SizedBox(
                      height: 48,
                      width: 160,
                      child: ElevatedButton(
                        onPressed: _isCheckingProfile
                            ? null
                            : _checkProfileAndBooking,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        child: _isCheckingProfile
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
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
