import 'package:supabase_flutter/supabase_flutter.dart';

class WisataService {
  // Mengambil instance client supabase yang sudah diinisialisasi di main.dart
  final SupabaseClient _supabase = Supabase.instance.client;

  // Fungsi untuk mengambil semua data wisata
  Future<List<Map<String, dynamic>>> getWisataList() async {
    try {
      final response = await _supabase.from('wisata').select();
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error mengambil data wisata: $e');
      return [];
    }
  }
}