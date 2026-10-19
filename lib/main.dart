import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // 1. Tambahkan import ini
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth/login_screen.dart';
import 'screens/main_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Load file .env sebelum app/Supabase dinyalakan
  await dotenv.load(fileName: ".env");

  await Supabase.initialize(
    url: 'https://lzpgyrrowgsyvkcuzara.supabase.co',
    anonKey: 'sb_publishable_SzlzZWRt5-PU0Zll-bUdnw_dM_M7Toi',
  );

  runApp(const MyApp());
}

final supabase = Supabase.instance.client;

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
        '/': (context) => const LoginScreen(),
        '/main': (context) => const MainScreen(),
      },
    );
  }
}