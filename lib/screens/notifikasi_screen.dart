import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/pesanan_model.dart';

class NotificationScreen extends StatefulWidget {
  final PesananModel? pesananBaru;

  const NotificationScreen({super.key, this.pesananBaru});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  @override
  void initState() {
    super.initState();
    
    if (widget.pesananBaru != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showTopNotificationBanner(
          context,
          'Pembayaran Berhasil',
          'Tiket ${widget.pesananBaru!.namaWisata} sejumlah ${widget.pesananBaru!.jumlahTiket} orang berhasil dipesan.',
        );
      });
    }
  }

  // Fungsi Pop-up muncul di ATAS layar
  void _showTopNotificationBanner(BuildContext context, String title, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.notifications_rounded, color: Colors.white, size: 22),
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
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1550B6),
        behavior: SnackBarBehavior.floating,
        // Kunci agar posisinya nempel di ATAS (menggunakan MediaQuery untuk melewati status bar)
        margin: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 10,
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).size.height - 180, // Mendorong posisi ke atas
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        duration: const Duration(seconds: 4),
        elevation: 8,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF1550B6);

    final List<Map<String, dynamic>> notifications = [];

    if (widget.pesananBaru != null) {
      notifications.add({
        'title': 'Pembayaran Berhasil',
        'message': 'Tiket wisata ${widget.pesananBaru!.namaWisata} (${widget.pesananBaru!.jumlahTiket} Orang) untuk tanggal ${widget.pesananBaru!.tanggalKunjungan} telah dikonfirmasi.',
        'time': 'Baru saja',
        'icon': Icons.check_circle_rounded,
        'color': Colors.green,
      });
    }

    notifications.addAll([
      {
        'title': 'Promo Spesial Yogyakarta',
        'message': 'Gunakan kode promo khusus untuk potongan harga pada kunjungan wisata berikutnya.',
        'time': '2 jam yang lalu',
        'icon': Icons.local_offer_rounded,
        'color': Colors.amber.shade700,
      },
      {
        'title': 'Pengingat Kunjungan',
        'message': 'Pastikan e-tiket sudah siap discan saat tiba di lokasi pintu masuk wisata.',
        'time': 'Kemarin',
        'icon': Icons.notifications_active_rounded,
        'color': primaryColor,
      },
    ]);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: primaryColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Notifikasi',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: notifications.length,
        itemBuilder: (context, index) {
          final notif = notifications[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(20),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (notif['color'] as Color).withAlpha(26),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    notif['icon'],
                    color: notif['color'],
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            notif['title'],
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                          Text(
                            notif['time'],
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notif['message'],
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}