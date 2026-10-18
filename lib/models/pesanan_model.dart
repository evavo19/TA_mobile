class PesananModel {
  final String? id;
  final String userId;
  final int wisataId;
  final String namaWisata;
  final String tanggalKunjungan;
  final int jumlahTiket;
  final double totalHarga;
  final String mataUang;
  final String metodePembayaran;
  final String status;
  final String? qrCode;
  final DateTime? createdAt;

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
    this.status = 'Lunas',
    this.qrCode,
    this.createdAt,
  });

  factory PesananModel.fromMap(Map<String, dynamic> map) {
    return PesananModel(
      id: map['id']?.toString(),
      userId: map['user_id'] ?? '',
      wisataId: map['wisata_id'] ?? 0,
      namaWisata: map['nama_wisata'] ?? '',
      tanggalKunjungan: map['tanggal_kunjungan'] ?? '',
      jumlahTiket: map['jumlah_tiket'] ?? 1,
      totalHarga: (map['total_harga'] ?? 0).toDouble(),
      mataUang: map['mata_uang'] ?? 'IDR',
      metodePembayaran: map['metode_pembayaran'] ?? 'QRIS',
      status: map['status'] ?? 'Lunas',
      qrCode: map['qr_code'],
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'wisata_id': wisataId,
      'nama_wisata': namaWisata,
      'tanggal_kunjungan': tanggalKunjungan,
      'jumlah_tiket': jumlahTiket,
      'total_harga': totalHarga,
      'mata_uang': mataUang,
      'metode_pembayaran': metodePembayaran,
      'status': status,
      'qr_code': qrCode,
    };
  }
}
