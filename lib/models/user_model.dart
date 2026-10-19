class UserModel {
  final String id;
  final String email;
  final String namaLengkap;
  final String noTelepon;
  final int? usia;
  final String jenisKelamin;
  final String alamat;
  final String? fotoUrl;

  const UserModel({
    required this.id,
    required this.email,
    this.namaLengkap = '',
    this.noTelepon = '',
    this.usia,
    this.jenisKelamin = 'Perempuan',
    this.alamat = '',
    this.fotoUrl,
  });

  /// Dari baris tabel `users` di Supabase
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String? ?? '',
      namaLengkap: json['nama_lengkap'] as String? ?? '',
      noTelepon: json['no_telepon'] as String? ?? '',
      usia: json['usia'] as int?,
      jenisKelamin: json['jenis_kelamin'] as String? ?? 'Perempuan',
      alamat: json['alamat'] as String? ?? '',
      fotoUrl: json['foto_url'] as String?,
    );
  }

  /// Hanya kolom yang boleh diubah pengguna (dipakai untuk update)
  Map<String, dynamic> toUpdateJson() {
    return {
      'nama_lengkap': namaLengkap,
      'no_telepon': noTelepon,
      'usia': usia,
      'jenis_kelamin': jenisKelamin,
      'alamat': alamat,
    };
  }

  UserModel copyWith({
    String? namaLengkap,
    String? noTelepon,
    int? usia,
    String? jenisKelamin,
    String? alamat,
    String? fotoUrl,
  }) {
    return UserModel(
      id: id,
      email: email,
      namaLengkap: namaLengkap ?? this.namaLengkap,
      noTelepon: noTelepon ?? this.noTelepon,
      usia: usia ?? this.usia,
      jenisKelamin: jenisKelamin ?? this.jenisKelamin,
      alamat: alamat ?? this.alamat,
      fotoUrl: fotoUrl ?? this.fotoUrl,
    );
  }
}