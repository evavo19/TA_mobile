import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth/login_screen.dart';
import 'auth/splas_screen.dart';
import 'screens/main_screen.dart';
import 'screens/scan_ticket_screen.dart'; // 👈 Import halaman scan petugas

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  await Supabase.initialize(
    url: 'https://lzpgyrrowgsyvkcuzara.supabase.co',
    publishableKey: 'sb_publishable_SzlzZWRt5-PU0Zll-bUdnw_dM_M7Toi',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pemesanan Tiket Wisata Jogja',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/main': (context) => const MainScreen(),
        '/scan': (context) => const ScanTicketScreen(), // 👈 Daftarkan rute scan
      },
    );
  }
}