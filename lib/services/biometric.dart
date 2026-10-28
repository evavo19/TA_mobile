import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();

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