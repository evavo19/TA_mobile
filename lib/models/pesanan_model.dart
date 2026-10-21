class PesananModel {
  final int? id;
  final String userId;
  final dynamic wisataId; // <-- Diubah menjadi dynamic agar bisa menerima int maupun String
  final String namaWisata;
  final String tanggalKunjungan;
  final int jumlahTiket;
  final double totalHarga;
  final String mataUang;
  final String metodePembayaran;
  final String status;
  final String qrCode;
  final DateTime createdAt;

  PesananModel({
    this.id,
    required this.userId,
    required this.wisataId,
    required this.namaWisata,
    required this.tanggalKunjungan,
    required this.jumlahTiket,
    required this.totalHarga,
    required this.mataUang,
    required this.metodePembayaran,
    required this.status,
    required this.qrCode,
    required this.createdAt,
  });

  factory PesananModel.fromMap(Map<String, dynamic> map) {
    return PesananModel(
      id: map['id'],
      userId: map['user_id'] ?? '',
      wisataId: map['wisata_id'] ?? '',
      namaWisata: map['nama_wisata'] ?? '',
      tanggalKunjungan: map['tanggal_kunjungan'] ?? '',
      jumlahTiket: map['jumlah_tiket'] ?? 1,
      totalHarga: (map['total_harga'] ?? 0).toDouble(),
      mataUang: map['mata_uang'] ?? 'IDR',
      metodePembayaran: map['metode_pembayaran'] ?? '',
      status: map['status'] ?? 'Lunas',
      qrCode: map['qr_code'] ?? map['qr_code_id'] ?? map['ticket_id'] ?? '',
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'wisataId': wisataId, // Disimpan apa adanya
      'nama_wisata': namaWisata,
      'tanggal_kunjungan': tanggalKunjungan,
      'jumlah_tiket': jumlahTiket,
      'total_harga': totalHarga,
      'mata_uang': mataUang,
      'metode_pembayaran': metodePembayaran,
      'status': status,
      'qr_code': qrCode,
      'created_at': createdAt.toIso8601String(),
    };
  }
}