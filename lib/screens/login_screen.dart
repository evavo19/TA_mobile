import 'dart:convert';

import 'package:crypto/crypto.dart'; // package: crypto/crypto.dart
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart'; // package: local_auth/local_auth.dart

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final LocalAuthentication auth = LocalAuthentication();

  // Fungsi Enkripsi Password (SHA-256)
  String _hashPassword(String password) {
    var bytes = utf8.encode(password);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Fungsi Login Biasa
  void _handleLogin() {
    String email = _emailController.text.trim();
    String password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email dan Password wajib diisi!')),
      );
      return;
    }

    // Enkripsi password sebelum diproses/disimpan
    String hashedPassword = _hashPassword(password);
    print("Password Terenkripsi (SHA-256): $hashedPassword");

    // Lanjut ke MainScreen setelah login berhasil
    Navigator.pushReplacementNamed(context, '/main');
  }

  // Fungsi Login Biometric
  Future<void> _handleBiometricLogin() async {
    try {
      bool canAuthenticate =
          await auth.canCheckBiometrics || await auth.isDeviceSupported();
      if (!canAuthenticate) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perangkat tidak mendukung Biometric!')),
        );
        return;
      }

      bool authenticated = await auth.authenticate(
        localizedReason: 'Pindai sidik jari/wajah untuk masuk ke Jogja Go!',
        options: const AuthenticationOptions(biometricOnly: true),
      );

      if (authenticated) {
        Navigator.pushReplacementNamed(context, '/main');
      }
    } catch (e) {
      print("Error Biometric: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header Atas (Gambar / Visual Jogja + Gradasi Biru)
            Stack(
              children: [
                Container(
                  height: 280,
                  decoration: const BoxDecoration(
                    color: Color(0xFF0D47A1), // Warna Biru Utama
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(32),
                      bottomRight: Radius.circular(32),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Opacity(
                    opacity: 0.2,
                    child: Image.network(
                      'https://res.cloudinary.com/dfciqrwpe/image/upload/v1748938870/candi-prambanan_cpukic.jpg',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 40,
                  left: 24,
                  child: Column(
                    crossAxisAlignment: CrossAlignment.start,
                    children: const [
                      Text(
                        'Selamat Datang di',
                        style: TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Jogja Go!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Jelajahi keindahan wisata Yogyakarta',
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Form Input Login
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  // Field Email
                  TextField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      prefixIcon: const Icon(Icons.email_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Field Password
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Tombol Login Utama
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _handleLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D47A1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Masuk',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Pembatas Atau
                  Row(
                    children: const [
                      Expanded(child: Divider()),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8.0),
                        child: Text(
                          'atau masuk dengan',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                      Expanded(child: Divider()),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Tombol Opsi Lain (Biometric & Google)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Tombol Biometric (Fingerprint)
                      InkWell(
                        onTap: _handleBiometricLogin,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.fingerprint,
                            size: 36,
                            color: Color(0xFF0D47A1),
                          ),
                        ),
                      ),

                      // Tombol Google Login
                      InkWell(
                        onTap: () {
                          // Simulasi Login Google langsung masuk
                          Navigator.pushReplacementNamed(context, '/main');
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: const [
                              Icon(
                                Icons.g_mobiledata,
                                size: 36,
                                color: Colors.red,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Google',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
