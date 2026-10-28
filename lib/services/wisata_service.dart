import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'database_helper.dart'; 

class WisataService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getWisataList() async {
    List<Map<String, dynamic>> data;

    try {
      final response = await _supabase.from('wisata').select();
      data = List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Supabase gagal ($e), pakai data SQLITE lokal');
      final lokal = await DatabaseHelper.instance.getLocalWisata();
      debugPrint('WISATA: data dari SQLITE (${lokal.length} baris)');
      return lokal;
    }

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