import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('lelungan_jogja.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2, // DIUBAH: naik dari 1 ke 2 karena kolom foto_uri -> foto_url
      onCreate: _createDB,
      onUpgrade: (db, oldVersion, newVersion) async {
        // Cache saja, jadi aman dibuat ulang. Data terisi lagi saat online.
        await db.execute('DROP TABLE IF EXISTS wisata');
        await _createDB(db, newVersion);
      },
    );
  }

  Future _createDB(Database db, int version) async {
    // Nama kolom disamakan dengan Supabase: foto_url
    await db.execute('''
      CREATE TABLE wisata (
        id INTEGER PRIMARY KEY,
        nama TEXT,
        kategori TEXT,
        rating REAL,
        jumlah_ulasan INTEGER,
        harga_weekday INTEGER,
        harga_weekend INTEGER,
        latitude REAL,
        longitude REAL,
        foto_url TEXT,
        deskripsi TEXT
      )
    ''');
  }

  // Simpan / update satu data
  Future<void> insertWisata(Map<String, dynamic> row) async {
    final db = await instance.database;
    await db.insert(
      'wisata',
      _toLocalRow(row),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Ambil semua data dari SQLite lokal
  Future<List<Map<String, dynamic>>> getLocalWisata() async {
    final db = await instance.database;
    return await db.query('wisata', orderBy: 'id ASC');
  }

  // Simpan banyak data sekaligus (dipanggil setelah fetch dari Supabase)
  // DIUBAH: tabel dikosongkan dulu dalam batch yang sama, supaya data yang
  // dihapus di Supabase ikut hilang di SQLite.
  Future<void> saveAllWisataToLocal(List<dynamic> wisataList) async {
    final db = await instance.database;
    final batch = db.batch();
    batch.delete('wisata');
    for (final item in wisataList) {
      batch.insert(
        'wisata',
        _toLocalRow(Map<String, dynamic>.from(item)),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  // Cek apakah cache lokal sudah terisi
  Future<bool> hasLocalData() async {
    final db = await instance.database;
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM wisata'),
    );
    return (count ?? 0) > 0;
  }

  // Hapus semua data (misal sebelum sinkronisasi ulang)
  Future<void> clearWisata() async {
    final db = await instance.database;
    await db.delete('wisata');
  }

  // Ambil hanya kolom yang ada di tabel lokal
  Map<String, dynamic> _toLocalRow(Map<String, dynamic> item) {
    return {
      'id': item['id'],
      'nama': item['nama'],
      'kategori': item['kategori'],
      'rating': item['rating'],
      'jumlah_ulasan': item['jumlah_ulasan'],
      'harga_weekday': item['harga_weekday'],
      'harga_weekend': item['harga_weekend'],
      'latitude': item['latitude'],
      'longitude': item['longitude'],
      'foto_url': item['foto_url'], // DIUBAH: dari foto_uri
      'deskripsi': item['deskripsi'],
    };
  }
}