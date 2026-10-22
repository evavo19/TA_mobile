import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'pembayaran_channel',
    'Pembayaran Tiket',
    description: 'Notifikasi konfirmasi pembayaran tiket wisata',
    importance: Importance.high,
  );

  /// Panggil sekali di main() sebelum runApp.
  static Future<void> init() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(const InitializationSettings(android: androidSettings));

    // Daftarkan channel agar muncul di setelan notifikasi Android
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    _initialized = true;
  }

  /// Menampilkan notifikasi sistem (status bar & laci notifikasi).
  static Future<void> show({
    required String title,
    required String body,
  }) async {
    try {
      await init();

      final id = DateTime.now().millisecondsSinceEpoch.remainder(100000);

      await _plugin.show(
        id,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            styleInformation: BigTextStyleInformation(body),
          ),
        ),
      );
    } catch (e) {
      debugPrint('Gagal menampilkan notifikasi: $e');
    }
  }
}