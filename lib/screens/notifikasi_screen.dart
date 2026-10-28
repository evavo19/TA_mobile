import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/pesanan_model.dart';

class NotificationScreen extends StatefulWidget {
  final PesananModel? pesananBaru;

  const NotificationScreen({super.key, this.pesananBaru});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  Future<void> _requestSystemNotificationPermission() async {
    try {
      debugPrint("Mencoba meminta izin notifikasi...");

      PermissionStatus status = await Permission.notification.request();
      debugPrint("Status izin saat ini: $status");

      if (!mounted) return;

      if (status.isGranted) {
        debugPrint("Izin notifikasi aktif");
      } else {
        bool isOpened = await openAppSettings();
        debugPrint("Membuka setelan aplikasi: $isOpened");
      }
    } catch (e) {
      debugPrint("Error request permission: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF1550B6);

    final List<Map<String, dynamic>> notifications = [];

    if (widget.pesananBaru != null) {
      notifications.add({
        'title': 'Pembayaran Berhasil',
        'message':
            'Tiket wisata ${widget.pesananBaru!.namaWisata} (${widget.pesananBaru!.jumlahTiket} Orang) untuk tanggal ${widget.pesananBaru!.tanggalKunjungan} telah dikonfirmasi.',
        'time': 'Baru saja',
        'icon': Icons.check_circle_rounded,
        'color': Colors.green,
      });
    }

    notifications.addAll([
      {
        'title': 'Promo Spesial Yogyakarta',
        'message':
            'Gunakan kode promo khusus untuk potongan harga pada kunjungan wisata berikutnya.',
        'time': '2 jam lalu',
        'icon': Icons.local_offer_rounded,
        'color': Colors.amber.shade700,
      },
       {
    'title': 'Tips Berkunjung di Akhir Pekan',
    'message': 'Akhir pekan biasanya lebih ramai. Datang lebih pagi agar lebih nyaman menikmati wisata.',
    'time': '2 hari lalu',
    'icon': Icons.lightbulb_rounded,
    'color': Colors.deepPurple,
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
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
    
          GestureDetector(
            onTap: () {
              debugPrint("Tombol izin diklik!");
              _requestSystemNotificationPermission();
            },
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withAlpha(80),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.notifications_active, color: Colors.white, size: 28),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Izinkan Notifikasi Sistem',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Ketuk untuk mengaktifkan izin pemberitahuan.',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          Text(
            'Riwayat Notifikasi',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 12),

          ...notifications.map((notif) {
            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(15),
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
                      
                            Expanded(
                              child: Text(
                                notif['title'],
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: const Color(0xFF1E293B),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
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
          }),
        ],
      ),
    );
  }
}