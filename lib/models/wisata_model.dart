class WisataModel {
  final int id;
  final String nama;
  final String kategori;
  final double rating;
  final int jumlahUlasan;
  final int hargaWeekday;
  final int hargaWeekend;
  final String deskripsi;
  final String gambarUrl;
  final String jamBuka;
  final double? latitude;
  final double? longitude;

  WisataModel({
    required this.id,
    required this.nama,
    required this.kategori,
    required this.rating,
    required this.jumlahUlasan,
    required this.hargaWeekday,
    required this.hargaWeekend,
    required this.deskripsi,
    required this.gambarUrl,
    required this.jamBuka,
    this.latitude,
    this.longitude,
  });

  // Mengubah Map/JSON dari Supabase ke WisataModel
  factory WisataModel.fromMap(Map<String, dynamic> map) {
    return WisataModel(
      id: map['id'] ?? 0,
      nama: map['nama'] ?? '',
      kategori: map['kategori'] ?? '',
      rating: (map['rating'] ?? 0.0).toDouble(),
      jumlahUlasan: map['jumlah_ulasan'] ?? 0,
      hargaWeekday: map['harga_weekday'] ?? 0,
      hargaWeekend: map['harga_weekend'] ?? 0,
      deskripsi: map['deskripsi'] ?? '',
      gambarUrl: map['gambar_url'] ?? map['foto'] ?? '',
      jamBuka: map['jam_buka'] ?? '08.00 - 17.00 WIB',
      latitude: map['latitude'] != null ? (map['latitude']).toDouble() : null,
      longitude: map['longitude'] != null ? (map['longitude']).toDouble() : null,
    );
  }

  // Mengubah WisataModel ke Map (jika butuh simpan/update ke Supabase)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nama': nama,
      'kategori': kategori,
      'rating': rating,
      'jumlah_ulasan': jumlahUlasan,
      'harga_weekday': hargaWeekday,
      'harga_weekend': hargaWeekend,
      'deskripsi': deskripsi,
      'gambar_url': gambarUrl,
      'jam_buka': jamBuka,
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}