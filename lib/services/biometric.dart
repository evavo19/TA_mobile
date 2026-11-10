import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

// LOGIN BIOMETRIK (SIDIK JARI / WAJAH)
// Penjelasan ke Dosen: "Service ini mengecek ketersediaan sensor perangkat 
// dan memproses autentikasi biometrik murni menggunakan package local_auth."
class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();

  // Cek apakah perangkat mendukung sensor biometrik (sidik jari/face id)
  static Future<bool> apakahBiometrikTersedia() async {
    try {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool canAuthenticate =
          canAuthenticateWithBiometrics || await _auth.isDeviceSupported();
      return canAuthenticate;
    } on PlatformException catch (e) {
      print("Error cek biometrik: $e");
      return false;
    }
  }

  // Menjalankan proses pemindaian biometrik
  static Future<bool> autentikasiBiometrik() async {
    try {
      final bool didAuthenticate = await _auth.authenticate(
        localizedReason: 'Gunakan sidik jari atau wajah Anda untuk masuk',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
      return didAuthenticate;
    } on PlatformException catch (e) {
      print("Error autentikasi: $e");
      return false;
    }
  }
}