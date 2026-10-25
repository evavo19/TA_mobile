import 'dart:convert';
import 'package:crypto/crypto.dart';

class BlockchainModel {
  final int? id;
  final String? userId;
  final String ticketId; 
  final String namaWisata;
  final String tanggalKunjungan;
  final int jumlahTiket;
  final double totalHarga;
  final String previousHash; 
  final String hash; 
  final String createdAt;

  BlockchainModel({
    this.id,
    this.userId,
    required this.ticketId,
    required this.namaWisata,
    required this.tanggalKunjungan,
    required this.jumlahTiket,
    required this.totalHarga,
    required this.previousHash,
    required this.hash,
    required this.createdAt,
  });

  static String calculateHash({
    required String ticketId,
    required String namaWisata,
    required String tanggalKunjungan,
    required int jumlahTiket,
    required double totalHarga,
    required String previousHash,
    required String createdAt,
  }) {
    final rawData =
        '$ticketId|$namaWisata|$tanggalKunjungan|$jumlahTiket|$totalHarga|$previousHash|$createdAt';
    final bytes = utf8.encode(rawData);
    return sha256.convert(bytes).toString();
  }

  factory BlockchainModel.fromMap(Map<String, dynamic> map) {
    return BlockchainModel(
      id: map['id'],
      userId: map['user_id'],
      ticketId: map['ticket_id'] ?? '',
      namaWisata: map['nama_wisata'] ?? '',
      tanggalKunjungan: map['tanggal_kunjungan'] ?? '',
      jumlahTiket: map['jumlah_tiket'] ?? 0,
      totalHarga: (map['total_harga'] ?? 0).toDouble(),
      previousHash: map['previous_hash'] ?? '0',
      hash: map['hash'] ?? '',
      createdAt: map['created_at'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId, 
      'ticket_id': ticketId,
      'nama_wisata': namaWisata,
      'tanggal_kunjungan': tanggalKunjungan,
      'jumlah_tiket': jumlahTiket,
      'total_harga': totalHarga,
      'previous_hash': previousHash,
      'hash': hash,
      'created_at': createdAt,
    };
  }
}