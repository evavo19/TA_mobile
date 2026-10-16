import 'package:flutter/material.dart';
import '../models/wisata_model.dart';

class BookingScreen extends StatelessWidget {
  final WisataModel wisata;
  final String selectedCurrency;
  final double currencyRate;
  final String currencySymbol;

  const BookingScreen({
    super.key,
    required this.wisata,
    required this.selectedCurrency,
    required this.currencyRate,
    required this.currencySymbol,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Form Pemesanan - ${wisata.nama}'),
        backgroundColor: const Color(0xFF1550B6),
      ),
      body: Center(
        child: Text('Halaman Form Pemesanan Tiket (${wisata.nama})'),
      ),
    );
  }
}