class PesananModel {
  final dynamic id;
  final String? userId; // 👈 Tambahan user_id
  final String qrCode;
  final String namaWisata;
  final String tanggalKunjungan;
  final int jumlahTiket;
  final double totalHarga;
  final String mataUang; // 👈 Mata uang yang dipilih user (IDR, USD, EUR, JPY)
  final String previousHash;
  final String hash;
  final String createdAt;
  final bool isUsed; // 👈 Tambahan status penggunaan tiket (menyesuaikan kolom 'status' di database)

  PesananModel({
    this.id,
    this.userId,
    required this.qrCode,
    required this.namaWisata,
    required this.tanggalKunjungan,
    required this.jumlahTiket,
    required this.totalHarga,
    this.mataUang = 'IDR', // 👈 Default IDR untuk tiket lama
    this.previousHash = '',
    this.hash = '',
    required this.createdAt,
    this.isUsed = false, // 👈 Default false (belum digunakan)
  });

  factory PesananModel.fromMap(Map<String, dynamic> map) {
    final rawMataUang = (map['mata_uang'] ?? 'IDR').toString().trim();

    return PesananModel(
      id: map['id'],
      userId: map['user_id'], // 👈 Mapping dari Supabase
      qrCode: map['ticket_id'] ?? map['qr_code'] ?? '',
      namaWisata: map['nama_wisata'] ?? '',
      tanggalKunjungan: map['tanggal_kunjungan'] ?? '',
      jumlahTiket: map['jumlah_tiket'] != null
          ? int.parse(map['jumlah_tiket'].toString())
          : 1,
      totalHarga: map['total_harga'] != null
          ? double.parse(map['total_harga'].toString())
          : 0.0,
      mataUang: rawMataUang.isEmpty ? 'IDR' : rawMataUang.toUpperCase(),
      previousHash: map['previous_hash'] ?? '',
      hash: map['hash'] ?? '',
      createdAt: map['created_at']?.toString() ?? DateTime.now().toIso8601String(),
      isUsed: (map['status'] ?? map['is_used']) == true, // 👈 Membaca status boolean dari kolom 'status' database
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId, // 👈 Disimpan ke Supabase
      'ticket_id': qrCode,
      'nama_wisata': namaWisata,
      'tanggal_kunjungan': tanggalKunjungan,
      'jumlah_tiket': jumlahTiket,
      'total_harga': totalHarga,
      'mata_uang': mataUang,
      'previous_hash': previousHash,
      'hash': hash,
      'created_at': createdAt,
      'status': isUsed, // 👈 Disimpan ke kolom 'status' database Supabase
    };
  }
}