import 'package:flutter/material.dart';

import 'screens/login_screen.dart'; // Menunjuk ke folder screens/
import 'screens/main_screen.dart'; // Menunjuk ke folder screens/

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

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
