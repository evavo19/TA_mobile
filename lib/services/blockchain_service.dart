import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/blockchain_model.dart';

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

  static Future<bool> verifikasiTiket(String ticketId, String hash) async {
    try {
      final response = await _supabase
          .from('blockchain_tiket')
          .select()
          .eq('ticket_id', ticketId)
          .eq('hash', hash)
          .maybeSingle();

      return response != null;
    } catch (e) {
      debugPrint("Gagal Verifikasi Tiket: $e");
      return false;
    }
  }
}