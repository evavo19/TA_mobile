import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';

// ══════════════════════════════════════════════════════
//  Alur pembayaran (simulasi) — Lelungan Jogja
//
//  1. BookingScreen membuat PaymentSession (metode, total, rincian, dan
//     fungsi `onPaid` yang menerbitkan tiket) lalu membuka
//     PaymentWaitingScreen.
//  2. PaymentWaitingScreen   : status pembayaran (cincin hitung mundur 15
//     menit, langkah Pesan → Bayar → Tiket, rincian bergaya struk).
//  3. PaymentInstructionScreen: kartu bergaya tiket berisi QR (QRIS) /
//     nomor Virtual Account / kode e-wallet, plus panduan bergaya garis waktu.
//  4. `onPaid` dijalankan HANYA setelah pembayaran dinyatakan berhasil,
//     jadi tiket tidak terbit sebelum dibayar.
//
//  Belum ada payment gateway sungguhan, jadi ada tombol
//  "Simulasikan Pembayaran Berhasil" untuk demo.
//
//  Halaman ini tidak mengembalikan nilai khusus. Pemanggil cukup memeriksa
//  `session.status == PaymentStatus.paid` setelah halaman ditutup.
// ══════════════════════════════════════════════════════

const _primary = Color(0xFF1550B6);
const _pageBg = Color(0xFFF8FAFC);
const _ink = Color(0xFF1E293B);
const _muted = Color(0xFF64748B);
const _success = Color(0xFF16A34A);
const _danger = Color(0xFFDC2626);

TextStyle _ts(
  double size, {
  FontWeight weight = FontWeight.normal,
  Color color = _ink,
  double? height,
  double? letterSpacing,
}) =>
    GoogleFonts.poppins(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );

const _monthsFull = [
  'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
  'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
];
const _monthsShort = [
  'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
  'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
];
const _days = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];

String _two(int n) => n.toString().padLeft(2, '0');

/// Contoh: "30 Oktober 2026 - 15:43"
String _formatDate(DateTime d) =>
    '${d.day} ${_monthsFull[d.month - 1]} ${d.year} - ${_two(d.hour)}:${_two(d.minute)}';

/// Contoh: "Jumat, 30 Okt 2026 15:58"
String _formatBannerDeadline(DateTime d) =>
    '${_days[d.weekday - 1]}, ${d.day} ${_monthsShort[d.month - 1]} ${d.year} ${_two(d.hour)}:${_two(d.minute)}';

final _rng = Random();
String _randomDigits(int n) => List.generate(n, (_) => _rng.nextInt(10)).join();

const _vaPrefixes = {'BCA': '39358', 'Mandiri': '88908'};

String _generatePaymentCode(String method) {
  if (method == 'QRIS') return '';
  if (method.contains('Virtual Account')) {
    final bank = method.replaceAll(' Virtual Account', '');
    final prefix = _vaPrefixes[bank] ?? '8800';
    return prefix + _randomDigits(16 - prefix.length);
  }
  return _randomDigits(12); // kode e-wallet
}

String _groupDigits(String s) =>
    RegExp(r'.{1,4}').allMatches(s).map((m) => m.group(0)!).join(' ');

// ══════════════════════════════════════════════════════
//  Model sesi pembayaran
// ══════════════════════════════════════════════════════

enum PaymentStatus { pending, paid, expired }

enum PaymentKind { qr, virtualAccount, eWallet }

class PaymentSession extends ChangeNotifier {
  PaymentSession({
    required this.method,
    required this.amount,
    required this.amountText,
    required this.referenceId,
    required this.onPaid,
    this.title = 'Pembayaran Tiket',
    this.items = const <MapEntry<String, String>>[],
  })  : createdAt = DateTime.now(),
        code = _generatePaymentCode(method) {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  static const Duration validity = Duration(minutes: 15);

  /// 'QRIS', 'BCA Virtual Account', 'Mandiri Virtual Account',
  /// atau 'E-Wallet (Gopay/OVO)'.
  final String method;
  final double amount;

  /// Total yang sudah diformat (mis. "Rp 150000"), supaya mata uang apa pun
  /// bisa dipakai tanpa mengubah halaman ini.
  final String amountText;
  final String title;

  /// Rincian pesanan yang ditampilkan di halaman status (label → nilai).
  final List<MapEntry<String, String>> items;

  /// Dijalankan setelah pembayaran berhasil (mis. menerbitkan tiket).
  /// Lempar exception kalau gagal.
  final Future<void> Function() onPaid;

  final DateTime createdAt;

  /// Nomor pesanan. Diturunkan dari timestamp tiket (mis. "LJ-1762345678901"),
  /// jadi sama dengan angka `id=` di ticketId yang nanti tersimpan.
  final String referenceId;

  /// Nomor VA atau kode e-wallet. Kosong untuk QRIS.
  final String code;

  Timer? _timer;
  PaymentStatus _status = PaymentStatus.pending;

  PaymentStatus get status => _status;
  bool get isPending => _status == PaymentStatus.pending;

  PaymentKind get kind {
    if (method == 'QRIS') return PaymentKind.qr;
    if (method.contains('Virtual Account')) return PaymentKind.virtualAccount;
    return PaymentKind.eWallet;
  }

  String get bankName => method.replaceAll(' Virtual Account', '');
  DateTime get expiresAt => createdAt.add(validity);
  String get qrPayload => 'LELUNGAN-QRIS|$referenceId|$amountText';

  Duration get remaining {
    final d = expiresAt.difference(DateTime.now());
    return d.isNegative ? Duration.zero : d;
  }

  void markPaid() {
    if (_status == PaymentStatus.paid) return;
    _status = PaymentStatus.paid;
    _timer?.cancel();
    notifyListeners();
  }

  void _tick() {
    if (!isPending) return;
    if (remaining == Duration.zero) {
      _status = PaymentStatus.expired;
      _timer?.cancel();
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

// ══════════════════════════════════════════════════════
//  Tampilan (desain khas Lelungan Jogja)
//
//  Halaman status  : header gradasi biru + cincin hitung mundur + langkah
//                    Pesan → Bayar → Tiket, lalu lembar rincian bergaya struk.
//  Halaman instruksi: kartu bergaya tiket (berlubang) + panduan berbentuk
//                    garis waktu, tombol aksi menempel di bawah.
// ══════════════════════════════════════════════════════

const _primaryDeep = Color(0xFF0B3A8A);
const _lineSoft = Color(0xFFE2E8F0);

String _formatMinSec(Duration d) =>
    '${_two(d.inMinutes)}:${_two(d.inSeconds.remainder(60))}';

IconData _methodIcon(PaymentKind kind) {
  switch (kind) {
    case PaymentKind.qr:
      return Icons.qr_code_2_rounded;
    case PaymentKind.virtualAccount:
      return Icons.account_balance_rounded;
    case PaymentKind.eWallet:
      return Icons.account_balance_wallet_rounded;
  }
}

/// Garis putus-putus (pemisah bergaya struk / tiket).
class _DashedLine extends StatelessWidget {
  const _DashedLine();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = (constraints.maxWidth / 9).floor();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
            count,
            (_) => Container(width: 5, height: 1.5, color: const Color(0xFFCBD5E1)),
          ),
        );
      },
    );
  }
}

/// Cincin hitung mundur.
class _RingPainter extends CustomPainter {
  final double progress; // 0..1
  const _RingPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 10.0;
    final rect = const Offset(stroke / 2, stroke / 2) &
        Size(size.width - stroke, size.height - stroke);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = Colors.white.withValues(alpha: 0.2);
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = Colors.white;

    canvas.drawArc(rect, 0, 2 * pi, false, track);
    canvas.drawArc(rect, -pi / 2, 2 * pi * progress, false, arc);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}

// ══════════════════════════════════════════════════════
//  Halaman 1 — Selesaikan pembayaran (status & rincian)
// ══════════════════════════════════════════════════════

class PaymentWaitingScreen extends StatefulWidget {
  final PaymentSession session;

  const PaymentWaitingScreen({super.key, required this.session});

  @override
  State<PaymentWaitingScreen> createState() => _PaymentWaitingScreenState();
}

class _PaymentWaitingScreenState extends State<PaymentWaitingScreen> {
  @override
  void dispose() {
    widget.session.dispose();
    super.dispose();
  }

  /// Lembar konfirmasi dari bawah saat pengguna menekan kembali di
  /// pembayaran yang masih berjalan.
  Future<void> _confirmLeave() async {
    final leave = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: _lineSoft,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text('Tinggalkan pembayaran?',
                  style: _ts(17, weight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                'Kode pembayaran yang sekarang akan hangus. Kamu bisa memilih '
                'metode lain di form pemesanan.',
                textAlign: TextAlign.center,
                style: _ts(12.5, color: _muted, height: 1.5),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24)),
                  ),
                  child: Text('Lanjutkan pembayaran',
                      style: _ts(14, weight: FontWeight.bold, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text('Ya, keluar',
                    style: _ts(13, weight: FontWeight.w600, color: _danger)),
              ),
            ],
          ),
        ),
      ),
    );
    if (leave == true && mounted) Navigator.of(context).pop();
  }

  /// Kembali ke form pemesanan untuk memilih metode lain.
  void _changeMethod() => Navigator.of(context).pop();

  Future<void> _copyOrderNumber() async {
    await Clipboard.setData(
        ClipboardData(text: widget.session.referenceId));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Nomor pesanan disalin', style: _ts(12, color: Colors.white))),
    );
  }

  Future<void> _openInstructions() async {
    final changeMethod = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PaymentInstructionScreen(session: widget.session),
      ),
    );
    // Pengguna menekan "Ganti metode" di halaman instruksi.
    if (changeMethod == true && mounted) _changeMethod();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.session,
      builder: (context, _) {
        final s = widget.session;
        return PopScope(
          canPop: !s.isPending,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _confirmLeave();
          },
          child: Scaffold(
            backgroundColor: _primary,
            body: Column(
              children: [
                _buildTop(s),
                Expanded(child: _buildSheet(s)),
              ],
            ),
            bottomNavigationBar: _buildCta(s),
          ),
        );
      },
    );
  }

  // ── Header gradasi ──
  Widget _buildTop(PaymentSession s) {
    final fraction = s.isPending
        ? (s.remaining.inSeconds / PaymentSession.validity.inSeconds)
            .clamp(0.0, 1.0)
        : 0.0;

    late final Widget centerpiece;
    late final String pillText;
    late final Color pillDot;

    switch (s.status) {
      case PaymentStatus.pending:
        centerpiece = SizedBox(
          width: 136,
          height: 136,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size.square(136),
                painter: _RingPainter(fraction),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Sisa waktu',
                      style: _ts(11, color: Colors.white70)),
                  Text(_formatMinSec(s.remaining),
                      style: _ts(28,
                          weight: FontWeight.w800, color: Colors.white)),
                ],
              ),
            ],
          ),
        );
        pillText = 'Menunggu pembayaran';
        pillDot = const Color(0xFFFBBF24);
      case PaymentStatus.paid:
        centerpiece = Container(
          width: 96,
          height: 96,
          decoration:
              const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          child: const Icon(Icons.check_rounded, size: 60, color: _success),
        );
        pillText = 'Pembayaran berhasil';
        pillDot = const Color(0xFF4ADE80);
      case PaymentStatus.expired:
        centerpiece = Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.timer_off_outlined,
              size: 48, color: Colors.white),
        );
        pillText = 'Waktu pembayaran habis';
        pillDot = const Color(0xFFF87171);
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
          12, MediaQuery.of(context).padding.top + 4, 12, 22),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_primaryDeep, _primary],
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new,
                    color: Colors.white, size: 20),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              Expanded(
                child: Text(
                  s.title,
                  textAlign: TextAlign.center,
                  style: _ts(16, weight: FontWeight.bold, color: Colors.white),
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
          const SizedBox(height: 6),
          _buildSteps(s.status),
          const SizedBox(height: 18),
          centerpiece,
          const SizedBox(height: 14),
          Text('Total pembayaran', style: _ts(11, color: Colors.white70)),
          Text(s.amountText,
              style: _ts(26, weight: FontWeight.w800, color: Colors.white)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white24),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration:
                      BoxDecoration(color: pillDot, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Text(pillText,
                    style: _ts(12, weight: FontWeight.w600, color: Colors.white)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Langkah: Pesan → Bayar → Tiket.
  Widget _buildSteps(PaymentStatus status) {
    final paid = status == PaymentStatus.paid;
    // 2 = selesai, 1 = sedang berjalan, 0 = belum
    final states = [2, paid ? 2 : 1, paid ? 2 : 0];
    const labels = ['Pesan', 'Bayar', 'Tiket'];

    Widget node(int i) {
      final st = states[i];
      return Column(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: st == 2 ? Colors.white : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(
                color: st == 0 ? Colors.white30 : Colors.white,
                width: 2,
              ),
            ),
            child: st == 2
                ? const Icon(Icons.check_rounded, size: 16, color: _primary)
                : st == 1
                    ? Center(
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                              color: Colors.white, shape: BoxShape.circle),
                        ),
                      )
                    : null,
          ),
          const SizedBox(height: 4),
          Text(
            labels[i],
            style: _ts(10,
                weight: st == 1 ? FontWeight.bold : FontWeight.normal,
                color: st == 0 ? Colors.white54 : Colors.white),
          ),
        ],
      );
    }

    Widget line(bool active) => Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 12, left: 6, right: 6),
            child: Container(
              height: 2,
              color: active ? Colors.white : Colors.white24,
            ),
          ),
        );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          node(0),
          line(states[1] >= 1),
          node(1),
          line(states[2] >= 1),
          node(2),
        ],
      ),
    );
  }

  // ── Lembar rincian bergaya struk ──
  Widget _buildSheet(PaymentSession s) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: _pageBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
        children: [
          Text('Rincian Pesanan', style: _ts(14, weight: FontWeight.bold)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _lineSoft),
            ),
            child: Column(
              children: [
                for (final item in s.items)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(item.key, style: _ts(12, color: _muted)),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(item.value,
                              textAlign: TextAlign.right,
                              style: _ts(12, weight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                const _DashedLine(),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total', style: _ts(13, weight: FontWeight.bold)),
                    Text(s.amountText,
                        style: _ts(15, weight: FontWeight.w800, color: _primary)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _infoTile(
                  icon: _methodIcon(s.kind),
                  label: 'Metode',
                  value: s.method,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _infoTile(
                  icon: Icons.tag_rounded,
                  label: 'No. Pesanan',
                  value: s.referenceId,
                  onTap: _copyOrderNumber,
                  trailing: Icons.copy_rounded,
                ),
              ),
            ],
          ),
          if (s.isPending) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.schedule_rounded, size: 18, color: _primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Bayar sebelum ${_formatDate(s.expiresAt)}',
                      style: _ts(12, color: _primary, weight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoTile({
    required IconData icon,
    required String label,
    required String value,
    VoidCallback? onTap,
    IconData? trailing,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _lineSoft),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFDBEAFE),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: _primary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: _ts(10, color: _muted)),
                  Text(
                    value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: _ts(11.5, weight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            if (trailing != null)
              Icon(trailing, size: 15, color: _muted),
          ],
        ),
      ),
    );
  }

  // ── Tombol aksi menempel di bawah ──
  Widget _buildCta(PaymentSession s) {
    final String label;
    final VoidCallback onPressed;
    switch (s.status) {
      case PaymentStatus.pending:
        label = 'Lihat Cara Bayar';
        onPressed = _openInstructions;
      case PaymentStatus.paid:
        label = 'Selesai';
        onPressed = () => Navigator.of(context).pop();
      case PaymentStatus.expired:
        label = 'Pilih Metode Lain';
        onPressed = _changeMethod;
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: onPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24)),
                ),
                child: Text(label,
                    style: _ts(15, weight: FontWeight.bold, color: Colors.white)),
              ),
            ),
            if (s.isPending)
              TextButton(
                onPressed: _changeMethod,
                child: Text('Ganti metode pembayaran',
                    style: _ts(12.5, weight: FontWeight.w600, color: _primary)),
              ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════
//  Halaman 2 — Cara pembayaran (kartu tiket + garis waktu)
// ══════════════════════════════════════════════════════

class PaymentInstructionScreen extends StatefulWidget {
  final PaymentSession session;

  const PaymentInstructionScreen({super.key, required this.session});

  @override
  State<PaymentInstructionScreen> createState() =>
      _PaymentInstructionScreenState();
}

class _PaymentInstructionScreenState extends State<PaymentInstructionScreen> {
  bool _isProcessing = false;

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg, style: _ts(12, color: Colors.white))),
    );
  }

  void _checkStatus() {
    switch (widget.session.status) {
      case PaymentStatus.paid:
        Navigator.of(context).pop();
      case PaymentStatus.expired:
        _snack('Waktu pembayaran sudah habis.');
      case PaymentStatus.pending:
        _snack('Pembayaranmu belum kami terima. '
            'Selesaikan dulu, lalu cek lagi ya.');
    }
  }

  Future<void> _copyCode() async {
    await Clipboard.setData(ClipboardData(text: widget.session.code));
    if (mounted) _snack('Berhasil disalin');
  }

  /// Mode demo: anggap pembayaran lunas, lalu jalankan `onPaid`
  /// (menerbitkan tiket).
  Future<void> _simulatePaid() async {
    final s = widget.session;
    if (_isProcessing || !s.isPending) return;

    setState(() => _isProcessing = true);
    try {
      await s.onPaid();
      s.markPaid();
      if (!mounted) return;
      Navigator.of(context).pop(); // kembali ke halaman status
    } catch (e) {
      if (mounted) {
        _snack('Pembayaran gagal: '
            '${e.toString().replaceFirst('Exception: ', '')}');
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.session,
      builder: (context, _) {
        final s = widget.session;
        return Scaffold(
          backgroundColor: _pageBg,
          appBar: AppBar(
            backgroundColor: _primary,
            elevation: 0,
            scrolledUnderElevation: 0,
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new,
                  color: Colors.white, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text('Cara Pembayaran',
                style: _ts(16, weight: FontWeight.bold, color: Colors.white)),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              _buildDeadlineStrip(s),
              const SizedBox(height: 16),
              _buildTicketCard(s),
              const SizedBox(height: 22),
              Text('Cara membayar', style: _ts(14, weight: FontWeight.bold)),
              const SizedBox(height: 14),
              _buildTimeline(_stepsFor(s)),
              const SizedBox(height: 8),
              _buildDemoStrip(s),
            ],
          ),
          bottomNavigationBar: _buildBottomBar(s),
        );
      },
    );
  }

  Widget _buildDeadlineStrip(PaymentSession s) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.timer_outlined, size: 18, color: _primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              s.isPending
                  ? 'Bayar sebelum ${_formatBannerDeadline(s.expiresAt)}'
                  : 'Batas waktu: ${_formatBannerDeadline(s.expiresAt)}',
              style: _ts(11.5, color: _primary, weight: FontWeight.w600),
            ),
          ),
          Text(
            s.isPending ? _formatMinSec(s.remaining) : '00:00',
            style: _ts(14, weight: FontWeight.w800, color: _primary),
          ),
        ],
      ),
    );
  }

  // ── Kartu bergaya tiket ──
  Widget _buildTicketCard(PaymentSession s) {
    Widget notch() => Container(
          width: 20,
          height: 20,
          decoration:
              const BoxDecoration(color: _pageBg, shape: BoxShape.circle),
        );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDBEAFE),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_methodIcon(s.kind), size: 22, color: _primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.method,
                          style: _ts(13, weight: FontWeight.w700)),
                      Text('Total yang harus dibayar',
                          style: _ts(10.5, color: _muted)),
                    ],
                  ),
                ),
                Text(s.amountText,
                    style: _ts(15, weight: FontWeight.w800, color: _primary)),
              ],
            ),
          ),
          SizedBox(
            height: 20,
            child: Row(
              children: [
                Transform.translate(offset: const Offset(-10, 0), child: notch()),
                const Expanded(child: _DashedLine()),
                Transform.translate(offset: const Offset(10, 0), child: notch()),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
            child: s.isPending ? _buildPayload(s) : _inactivePanel(s),
          ),
        ],
      ),
    );
  }

  Widget _buildPayload(PaymentSession s) {
    switch (s.kind) {
      case PaymentKind.qr:
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _lineSoft, width: 1.5),
              ),
              child: QrImageView(
                data: s.qrPayload,
                version: QrVersions.auto,
                size: 190,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Scan dengan aplikasi apa pun yang mendukung QRIS',
              textAlign: TextAlign.center,
              style: _ts(11, color: _muted),
            ),
          ],
        );
      case PaymentKind.virtualAccount:
        return _codeBlock(
          s,
          label: 'Nomor Virtual Account ${s.bankName}',
          hint: 'Transfer sesuai nominal ke nomor di atas.',
        );
      case PaymentKind.eWallet:
        return _codeBlock(
          s,
          label: 'Kode Pembayaran E-Wallet',
          hint: 'Masukkan kode ini di menu Bayar pada Gopay / OVO.',
        );
    }
  }

  Widget _codeBlock(
    PaymentSession s, {
    required String label,
    required String hint,
  }) {
    return Column(
      children: [
        Text(label, style: _ts(11.5, color: _muted)),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            _groupDigits(s.code),
            style: _ts(24, weight: FontWeight.w800, letterSpacing: 1.5),
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _copyCode,
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: Text('Salin',
              style: _ts(12, weight: FontWeight.w600, color: _primary)),
          style: OutlinedButton.styleFrom(
            foregroundColor: _primary,
            side: const BorderSide(color: _primary),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
          ),
        ),
        const SizedBox(height: 8),
        Text(hint,
            textAlign: TextAlign.center, style: _ts(11, color: _muted)),
      ],
    );
  }

  Widget _inactivePanel(PaymentSession s) {
    final paid = s.status == PaymentStatus.paid;
    return Column(
      children: [
        const SizedBox(height: 8),
        Icon(
          paid ? Icons.check_circle_rounded : Icons.timer_off_outlined,
          size: 44,
          color: paid ? _success : _danger,
        ),
        const SizedBox(height: 8),
        Text(
          paid ? 'Pembayaran sudah diterima' : 'Waktu pembayaran habis',
          style: _ts(13, weight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  List<String> _stepsFor(PaymentSession s) {
    switch (s.kind) {
      case PaymentKind.qr:
        return const [
          'Buka e-wallet atau mobile banking yang mendukung QRIS '
              '(Gopay, OVO, Dana, LinkAja, ShopeePay, dll).',
          'Pilih menu Scan atau Bayar, lalu arahkan kamera ke QR di atas.',
          'Cocokkan nominalnya, lalu konfirmasi pembayaran.',
          'Balik ke aplikasi ini dan tekan "Saya Sudah Bayar".',
        ];
      case PaymentKind.virtualAccount:
        return [
          'Buka mobile banking ${s.bankName} atau datangi ATM terdekat.',
          'Pilih Transfer, lalu Virtual Account.',
          'Masukkan nomor Virtual Account di atas.',
          'Cek nominalnya, konfirmasi, lalu masukkan PIN.',
          'Balik ke aplikasi ini dan tekan "Saya Sudah Bayar".',
        ];
      case PaymentKind.eWallet:
        return const [
          'Buka aplikasi Gopay atau OVO di ponselmu.',
          'Pilih menu Bayar, lalu masukkan kode pembayaran di atas.',
          'Cek nominalnya, lalu konfirmasi.',
          'Balik ke aplikasi ini dan tekan "Saya Sudah Bayar".',
        ];
    }
  }

  // ── Panduan berbentuk garis waktu ──
  Widget _buildTimeline(List<String> steps) {
    return Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 28,
                  child: Column(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: _primary,
                          shape: BoxShape.circle,
                        ),
                        child: Text('${i + 1}',
                            style: _ts(11,
                                weight: FontWeight.bold, color: Colors.white)),
                      ),
                      if (i < steps.length - 1)
                        Expanded(
                          child: Container(
                            width: 2,
                            color: const Color(0xFFBFDBFE),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16, top: 2),
                    child: Text(steps[i], style: _ts(12, height: 1.5)),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildDemoStrip(PaymentSession s) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.science_outlined, size: 18, color: _muted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Mode demo: belum terhubung ke payment gateway.',
              style: _ts(11, color: _muted, height: 1.4),
            ),
          ),
          _isProcessing
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : TextButton(
                  onPressed: s.isPending ? _simulatePaid : null,
                  child: Text('Tandai Lunas',
                      style: _ts(12, weight: FontWeight.w700, color: _primary)),
                ),
        ],
      ),
    );
  }

  // ── Tombol aksi menempel di bawah ──
  Widget _buildBottomBar(PaymentSession s) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            if (s.isPending)
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text('Ganti metode',
                    style: _ts(12.5, weight: FontWeight.w600, color: _primary)),
              ),
            if (s.isPending) const SizedBox(width: 8),
            Expanded(
              child: SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _checkStatus,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24)),
                  ),
                  child: Text('Saya Sudah Bayar',
                      style: _ts(15, weight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}