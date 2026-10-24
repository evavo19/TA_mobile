import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/blockchain_model.dart';

/// Hasil pemeriksaan blockchain: valid atau tidak, beserta alasannya.
class HasilVerifikasi {
  final bool valid;
  final String pesan;
  final dynamic idBlokBermasalah;

  const HasilVerifikasi(this.valid, this.pesan, [this.idBlokBermasalah]);
}

class BlockchainService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  static const String _genesisHash =
      "0000000000000000000000000000000000000000000000000000000000000000";

  static Future<String> _getPreviousHash() async {
    try {
      final response = await _supabase
          .from('blockchain_tiket')
          .select('hash')
          .order('id', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response != null && response['hash'] != null) {
        return response['hash'] as String;
      }
    } catch (e) {
      debugPrint("Gagal mengambil previous hash: $e");
    }
    return _genesisHash;
  }

  /// Mengembalikan hash blok yang BENAR-BENAR tersimpan di Supabase.
  /// Jika gagal, error di-lempar ulang (rethrow) supaya layar pemesanan
  /// tahu bahwa penyimpanan gagal dan tidak menampilkan "Pembayaran Berhasil".
  static Future<String> tambahBlok({
    String? userId,
    required String ticketId,
    required String namaWisata,
    required String tanggalKunjungan,
    required int jumlahTiket,
    required double totalHarga,
    required String mataUang,
  }) async {
    if (userId == null || userId.isEmpty) {
      throw Exception('User belum login. Silakan login terlebih dahulu.');
    }

    // Rapikan angka desimal (contoh: 95.99999999 -> 96.0)
    final double hargaBersih = double.parse(totalHarga.toStringAsFixed(2));

    final String previousHash = await _getPreviousHash();
    final String createdAt = DateTime.now().toIso8601String();

    final String currentHash = BlockchainModel.calculateHash(
      ticketId: ticketId,
      namaWisata: namaWisata,
      tanggalKunjungan: tanggalKunjungan,
      jumlahTiket: jumlahTiket,
      totalHarga: hargaBersih,
      previousHash: previousHash,
      createdAt: createdAt,
    );

    final newBlock = BlockchainModel(
      userId: userId,
      ticketId: ticketId,
      namaWisata: namaWisata,
      tanggalKunjungan: tanggalKunjungan,
      jumlahTiket: jumlahTiket,
      totalHarga: hargaBersih,
      previousHash: previousHash,
      hash: currentHash,
      createdAt: createdAt,
    );

    final mapData = newBlock.toMap();
    mapData.remove('id'); // biarkan database yang mengisi id (auto increment)
    mapData['user_id'] = userId;
    mapData['mata_uang'] = mataUang;

    try {
      await _supabase.from('blockchain_tiket').insert(mapData);
      debugPrint("Blok tiket tersimpan. Hash: $currentHash");
      return currentHash;
    } on PostgrestException catch (e) {
      debugPrint(
        "INSERT GAGAL -> code: ${e.code}, message: ${e.message}, details: ${e.details}, hint: ${e.hint}",
      );
      rethrow;
    } catch (e) {
      debugPrint("Error Tambah Blok Blockchain: $e");
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // VERIFIKASI BLOCKCHAIN
  // ---------------------------------------------------------------------------

  /// Kandidat format `created_at`. Kalau kolom di database bertipe timestamptz,
  /// Supabase mengembalikan format berbeda dari string aslinya, jadi kita coba
  /// beberapa bentuk yang setara sebelum menyatakan hash tidak cocok.
  static List<String> _kandidatCreatedAt(String raw) {
    final hasil = <String>{raw};
    try {
      if (raw.contains('T')) {
        final tanpaZona = raw.replaceFirst(
          RegExp(r'(Z|[+-]\d{2}:\d{2}|[+-]\d{2})$'),
          '',
        );
        hasil.add(DateTime.parse(tanpaZona).toIso8601String());
      }
    } catch (_) {}
    return hasil.toList();
  }

  /// Menghitung ulang hash sebuah blok dari data yang tersimpan,
  /// lalu membandingkannya dengan hash yang tersimpan di database.
  static bool _hashBlokValid(Map<String, dynamic> row) {
    final blok = BlockchainModel.fromMap(row);
    for (final createdAt in _kandidatCreatedAt(blok.createdAt)) {
      final hitung = BlockchainModel.calculateHash(
        ticketId: blok.ticketId,
        namaWisata: blok.namaWisata,
        tanggalKunjungan: blok.tanggalKunjungan,
        jumlahTiket: blok.jumlahTiket,
        totalHarga: blok.totalHarga,
        previousHash: blok.previousHash,
        createdAt: createdAt,
      );
      if (hitung == blok.hash) return true;
    }
    return false;
  }

  /// Verifikasi satu tiket:
  /// 1. blok ada di database,
  /// 2. hash dihitung ulang dari isi data (mendeteksi data yang diubah),
  /// 3. previous_hash cocok dengan hash blok sebelumnya (mendeteksi rantai putus).
  static Future<HasilVerifikasi> verifikasiDetail(
    String ticketId,
    String hash,
  ) async {
    try {
      final row = await _supabase
          .from('blockchain_tiket')
          .select()
          .eq('ticket_id', ticketId)
          .eq('hash', hash)
          .maybeSingle();

      if (row == null) {
        return const HasilVerifikasi(
          false,
          'Tiket tidak ditemukan di blockchain.',
        );
      }

      if (!_hashBlokValid(row)) {
        return HasilVerifikasi(
          false,
          'Isi tiket tidak sesuai dengan hash (data kemungkinan diubah).',
          row['id'],
        );
      }

      final sebelumnya = await _supabase
          .from('blockchain_tiket')
          .select('hash')
          .lt('id', row['id'])
          .order('id', ascending: false)
          .limit(1)
          .maybeSingle();

      // Blok pertama di tabel tidak punya blok sebelumnya, jadi dilewati.
      if (sebelumnya != null && sebelumnya['hash'] != row['previous_hash']) {
        return HasilVerifikasi(
          false,
          'Rantai terputus: previous hash tidak cocok dengan blok sebelumnya.',
          row['id'],
        );
      }

      return const HasilVerifikasi(true, 'Tiket valid dan rantai utuh.');
    } catch (e) {
      debugPrint("Gagal Verifikasi Tiket: $e");
      return HasilVerifikasi(false, 'Verifikasi gagal: $e');
    }
  }

  static Future<bool> verifikasiTiket(String ticketId, String hash) async {
    final hasil = await verifikasiDetail(ticketId, hash);
    return hasil.valid;
  }

  /// Memeriksa seluruh rantai dari blok pertama sampai terakhir.
  /// Berhenti di blok pertama yang rusak dan mengembalikan id-nya.
  static Future<HasilVerifikasi> validasiRantai() async {
    try {
      final data = await _supabase
          .from('blockchain_tiket')
          .select()
          .order('id', ascending: true);

      String? hashSebelumnya;
      int jumlah = 0;

      for (final row in List<Map<String, dynamic>>.from(data)) {
        if (!_hashBlokValid(row)) {
          return HasilVerifikasi(
            false,
            'Blok #${row['id']} rusak: isi data tidak cocok dengan hash.',
            row['id'],
          );
        }
        if (hashSebelumnya != null && row['previous_hash'] != hashSebelumnya) {
          return HasilVerifikasi(
            false,
            'Rantai putus di blok #${row['id']}: previous hash tidak cocok.',
            row['id'],
          );
        }
        hashSebelumnya = row['hash'] as String?;
        jumlah++;
      }

      return HasilVerifikasi(true, 'Rantai valid. $jumlah blok diperiksa.');
    } catch (e) {
      debugPrint("Gagal validasi rantai: $e");
      return HasilVerifikasi(false, 'Validasi gagal: $e');
    }
  }
}