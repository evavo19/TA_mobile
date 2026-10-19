import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth/login_screen.dart';
import 'screens/main_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://lzpgyrrowgsyvkcuzara.supabase.co',
    publishableKey: 'sb_publishable_SzlzZWRt5-PU0Zll-bUdnw_dM_M7Toi',
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