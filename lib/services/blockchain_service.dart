import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/blockchain_model.dart';

class BlockchainService {
  static final SupabaseClient _supabase = Supabase.instance.client;

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
    return "0000000000000000000000000000000000000000000000000000000000000000";
  }

  static Future<String> tambahBlok({
    String? userId, // 👈 1. Parameter opsional userId
    required String ticketId,
    required String namaWisata,
    required String tanggalKunjungan,
    required int jumlahTiket,
    required double totalHarga,
    required String mataUang, // 👈 2. Ditambahkan untuk menerima mata uang dari booking screen
  }) async {
    try {
      final String previousHash = await _getPreviousHash();
      final String createdAt = DateTime.now().toIso8601String();

      final String currentHash = BlockchainModel.calculateHash(
        ticketId: ticketId,
        namaWisata: namaWisata,
        tanggalKunjungan: tanggalKunjungan,
        jumlahTiket: jumlahTiket,
        totalHarga: totalHarga,
        previousHash: previousHash,
        createdAt: createdAt,
      );

      final newBlock = BlockchainModel(
        userId: userId, // 👈 3. Masukkan userId ke dalam model blok
        ticketId: ticketId,
        namaWisata: namaWisata,
        tanggalKunjungan: tanggalKunjungan,
        jumlahTiket: jumlahTiket,
        totalHarga: totalHarga,
        previousHash: previousHash,
        hash: currentHash,
        createdAt: createdAt,
      );

      // Memasukkan data ke Map dan menyertakan mata_uang untuk disimpan ke Supabase
      final mapData = newBlock.toMap();
      mapData['mata_uang'] = mataUang;

      await _supabase.from('blockchain_tiket').insert(mapData);

      debugPrint("Blok Tiket Berhasil Ditambahkan ke Blockchain! Hash: $currentHash");
      return currentHash;
    } catch (e) {
      debugPrint("Error Tambah Blok Blockchain: $e");
      return BlockchainModel.calculateHash(
        ticketId: ticketId,
        namaWisata: namaWisata,
        tanggalKunjungan: tanggalKunjungan,
        jumlahTiket: jumlahTiket,
        totalHarga: totalHarga,
        previousHash: "0",
        createdAt: DateTime.now().toIso8601String(),
      );
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