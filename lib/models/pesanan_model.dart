class PesananModel {
  final dynamic id; // int8 di supabase
  final String qrCode; // Berfungsi sebagai ticket_id
  final String namaWisata;
  final String tanggalKunjungan;
  final int jumlahTiket;
  final double totalHarga;
  final String previousHash;
  final String hash;
  final String createdAt;

  PesananModel({
    this.id,
    required this.qrCode,
    required this.namaWisata,
    required this.tanggalKunjungan,
    required this.jumlahTiket,
    required this.totalHarga,
    this.previousHash = '',
    this.hash = '',
    required this.createdAt,
  });

  factory PesananModel.fromMap(Map<String, dynamic> map) {
    return PesananModel(
      id: map['id'],
      qrCode: map['ticket_id'] ?? '',
      namaWisata: map['nama_wisata'] ?? '',
      tanggalKunjungan: map['tanggal_kunjungan'] ?? '',
      jumlahTiket: map['jumlah_tiket'] != null
          ? int.parse(map['jumlah_tiket'].toString())
          : 1,
      totalHarga: map['total_harga'] != null
          ? double.parse(map['total_harga'].toString())
          : 0.0,
      previousHash: map['previous_hash'] ?? '',
      hash: map['hash'] ?? '',
      createdAt: map['created_at']?.toString() ?? DateTime.now().toIso8601String(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ticket_id': qrCode,
      'nama_wisata': namaWisata,
      'tanggal_kunjungan': tanggalKunjungan,
      'jumlah_tiket': jumlahTiket,
      'total_harga': totalHarga,
      'previous_hash': previousHash,
      'hash': hash,
      'created_at': createdAt,
    };
  }
}