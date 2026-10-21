import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Contoh fungsi enkripsi password dengan SHA-256 (sesuai package crypto di pubspec.yaml)
  String hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Fungsi Login ke Supabase
  Future<AuthResponse> login(String email, String password) async {
    // Jika menggunakan Supabase Auth bawaan:
    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  // Fungsi Register
  Future<AuthResponse> register(String email, String password) async {
    return await _supabase.auth.signUp(
      email: email,
      password: password,
    );
  }

  // Logout & Hapus Session
  Future<void> logout() async {
    await _supabase.auth.signOut();
  }
}