class WisataModel {
  final int id;
  final String nama;
  final String kategori;
  final double rating;
  final int jumlahUlasan;
  final int hargaWeekday;
  final int hargaWeekend;
  final double latitude;
  final double longitude;
  final String gambarUrl;
  final String deskripsi;
  final String jamBuka; 

  WisataModel({
    required this.id,
    required this.nama,
    required this.kategori,
    required this.rating,
    required this.jumlahUlasan,
    required this.hargaWeekday,
    required this.hargaWeekend,
    required this.latitude,
    required this.longitude,
    required this.gambarUrl,
    required this.deskripsi,
    required this.jamBuka,
  });

  factory WisataModel.fromMap(Map<String, dynamic> m) => WisataModel(
        id: (m['id'] ?? 0) as int,
        nama: m['nama'] ?? '',
        kategori: m['kategori'] ?? '',
        rating: (m['rating'] ?? 0).toDouble(),
        jumlahUlasan: (m['jumlah_ulasan'] ?? 0) as int,
        hargaWeekday: (m['harga_weekday'] ?? 0) as int,
        hargaWeekend: (m['harga_weekend'] ?? 0) as int,
        latitude: (m['latitude'] ?? 0).toDouble(),
        longitude: (m['longitude'] ?? 0).toDouble(),
        // Mendukung kolom gambar_url, foto_url, maupun foto
        gambarUrl: m['gambar_url'] ?? m['foto_url'] ?? m['foto'] ?? '',
        deskripsi: m['deskripsi'] ?? '',
        jamBuka: m['jam_buka'] ?? m['jamBuka'] ?? '08.00 - 17.00 WIB',
      );
}