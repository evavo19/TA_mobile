import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'database_helper.dart'; // satu folder: lib/services/

class WisataService {
  // Mengambil instance client supabase yang sudah diinisialisasi di main.dart
  final SupabaseClient _supabase = Supabase.instance.client;

  // Alur: coba Supabase (online) -> simpan ke SQLite -> kalau Supabase gagal, baca SQLite (offline)
  // DIUBAH: error Supabase dan error SQLite dipisah supaya log tidak menyesatkan.
  Future<List<Map<String, dynamic>>> getWisataList() async {
    List<Map<String, dynamic>> data;

    // 1. Ambil dari Supabase
    try {
      final response = await _supabase.from('wisata').select();
      data = List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Supabase gagal ($e), pakai data SQLITE lokal');
      final lokal = await DatabaseHelper.instance.getLocalWisata();
      debugPrint('WISATA: data dari SQLITE (${lokal.length} baris)');
      return lokal;
    }

    // 2. Simpan ke SQLite (kalau gagal, user tetap lihat data Supabase)
    try {
      await DatabaseHelper.instance.saveAllWisataToLocal(data);
      debugPrint('SQLITE: tersimpan ${data.length} baris');
    } catch (e) {
      debugPrint('SIMPAN KE SQLITE GAGAL: $e');
    }

    debugPrint('WISATA: data dari SUPABASE (${data.length} baris)');
    return data;
  }
}