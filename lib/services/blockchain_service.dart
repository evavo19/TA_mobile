import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:web3dart/crypto.dart';
import 'package:web3dart/web3dart.dart';
import '../config/web3_config.dart';

class HasilVerifikasi {
  final bool valid;
  final String pesan;
  final dynamic idBlokBermasalah;
  final bool dipakai;
  final DateTime? waktuDipakai;

  const HasilVerifikasi(
    this.valid,
    this.pesan, [
    this.idBlokBermasalah,
    this.dipakai = false,
    this.waktuDipakai,
  ]);

  /// Teks status siap tampil di layar
  String get status {
    if (dipakai) return 'Tiket Terpakai';
    if (valid) return 'Tiket Valid';
    return 'Tiket Tidak Valid';
  }
}

class BlockchainService {
  static final Web3Client _web3 =
      Web3Client(Web3Config.rpcUrl, http.Client());

  static DeployedContract? _contract;

  static const String _alamatNol =
      '0x0000000000000000000000000000000000000000';

  static const String _genesisHash =
      "0000000000000000000000000000000000000000000000000000000000000000";

  // ---------------------------------------------------------------------------
  // Helper internal (koneksi ke smart contract)
  // ---------------------------------------------------------------------------

  static Future<DeployedContract> _getContract() async {
    if (_contract != null) return _contract!;
    final abi =
        await rootBundle.loadString('blockchain/abi/TicketRegistryV2.json');
    _contract = DeployedContract(
      ContractAbi.fromJson(abi, 'TicketRegistryV2'),
      EthereumAddress.fromHex(Web3Config.contractAddress),
    );
    return _contract!;
  }

  static EthPrivateKey _credentials() {
    if (Web3Config.privateKey.isEmpty) {
      throw Exception(
        'Private key belum diisi. Isi SEPOLIA_PRIVATE_KEY di file .env.',
      );
    }
    return EthPrivateKey.fromHex(Web3Config.privateKey);
  }

  static Future<TransactionReceipt> _tungguKonfirmasi(String txHash) async {
    for (var i = 0; i < 45; i++) {
      final r = await _web3.getTransactionReceipt(txHash);
      if (r != null) {
        if (r.status == false) {
          throw Exception('Transaksi gagal/ditolak di blockchain.');
        }
        return r;
      }
      await Future.delayed(const Duration(seconds: 2));
    }
    throw Exception('Timeout menunggu konfirmasi transaksi.');
  }

  /// Ambil ID tiket on-chain dari event TicketIssued pada sebuah transaksi.
  /// Mengembalikan null kalau transaksi itu bukan penerbitan tiket.
  static Future<BigInt?> _ticketIdDariReceipt(
    TransactionReceipt receipt,
  ) async {
    final contract = await _getContract();
    final event = contract.event('TicketIssued');
    final signature =
        bytesToHex(event.signature, include0x: true).toLowerCase();

    for (final log in receipt.logs) {
      final topics = log.topics;
      if (topics == null || topics.isEmpty || log.data == null) continue;
      if (topics[0]?.toLowerCase() != signature) continue;

      final hasil = event.decodeResults(topics, log.data!);
      return hasil[0] as BigInt;
    }
    return null;
  }

  /// Baca tiket dari smart contract (gratis, tanpa gas).
  /// Mengembalikan null kalau tiket tidak ada.
  /// Urutan hasil: 0 holder, 1 eventName, 2 visitDate, 3 quantity,
  /// 4 totalPrice, 5 currency, 6 issuedAt, 7 used, 8 usedAt
  static Future<List<dynamic>?> _bacaTiket(BigInt id) async {
    final contract = await _getContract();
    final r = await _web3.call(
      contract: contract,
      function: contract.function('tickets'),
      params: [id],
    );
    final holder = (r[0] as EthereumAddress).hex.toLowerCase();
    if (holder == _alamatNol) return null;
    return r;
  }

  /// Waktu pemakaian dari field usedAt (null kalau belum dipakai)
  static DateTime? _waktuDipakai(List<dynamic> tiket) {
    final detik = (tiket[8] as BigInt).toInt();
    if (detik == 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(detik * 1000);
  }

  /// Ubah string tanggal dari aplikasi menjadi DateTime.
  /// Mendukung "2026-12-20", "20/12/2026", dan "20-12-2026".
  static DateTime _parseTanggal(String raw) {
    final langsung = DateTime.tryParse(raw);
    if (langsung != null) return langsung;

    final m = RegExp(r'^(\d{1,2})[/-](\d{1,2})[/-](\d{4})$')
        .firstMatch(raw.trim());
    if (m != null) {
      return DateTime(
        int.parse(m.group(3)!),
        int.parse(m.group(2)!),
        int.parse(m.group(1)!),
      );
    }
    throw Exception('Format tanggal kunjungan tidak dikenali: "$raw"');
  }

  /// IDR dan JPY tanpa desimal, mata uang lain disimpan dalam satuan terkecil
  /// (mis. USD 12.50 -> 1250).
  static BigInt _hargaKeRaw(double harga, String mataUang) {
    final m = mataUang.toUpperCase();
    final desimal = (m == 'IDR' || m == 'JPY') ? 0 : 2;
    final faktor = desimal == 0 ? 1 : 100;
    return BigInt.from((harga * faktor).round());
  }

  // ---------------------------------------------------------------------------
  // Tambah blok: catat tiket ke smart contract Sepolia, lalu simpan ke Supabase
  // Mengembalikan hash transaksi (menggantikan hash lama)
  // ---------------------------------------------------------------------------

  static Future<String> tambahBlok({
    String? userId,
    required String ticketId,
    required String namaWisata,
    required String tanggalKunjungan,
    required int jumlahTiket,
    required double totalHarga,
    required String mataUang,
  }) async {
    if (userId == null || userId.isEmpty) {
      throw Exception('User belum login. Silakan login terlebih dahulu.');
    }

    final double hargaBersih = double.parse(totalHarga.toStringAsFixed(2));
    final DateTime tanggal = _parseTanggal(tanggalKunjungan);

    String? txHash;

    try {
      final contract = await _getContract();

      // 1. Catat ke smart contract Sepolia
      txHash = await _web3.sendTransaction(
        _credentials(),
        Transaction.callContract(
          contract: contract,
          function: contract.function('issueTicket'),
          parameters: [
            EthereumAddress.fromHex(Web3Config.defaultHolder),
            namaWisata,
            BigInt.from(tanggal.millisecondsSinceEpoch ~/ 1000),
            BigInt.from(jumlahTiket),
            _hargaKeRaw(hargaBersih, mataUang),
            mataUang,
          ],
        ),
        chainId: Web3Config.chainId,
      );
      debugPrint("Tx issueTicket terkirim: $txHash");

      final receipt = await _tungguKonfirmasi(txHash);
      final onchainId = await _ticketIdDariReceipt(receipt);

      // 2. Simpan ke Supabase supaya muncul di e-ticket dan bisa di-scan.
      //    Kolom hash berisi hash transaksi Sepolia.
      await Supabase.instance.client.from('blockchain_tiket').insert({
        'user_id': userId,
        'ticket_id': ticketId,
        'nama_wisata': namaWisata,
        'tanggal_kunjungan': tanggalKunjungan,
        'jumlah_tiket': jumlahTiket,
        'total_harga': hargaBersih,
        'mata_uang': mataUang,
        'previous_hash': _genesisHash,
        'hash': txHash,
        'created_at': DateTime.now().toIso8601String(),
      });

      debugPrint(
        "Blok tiket tersimpan di Sepolia. Tx: $txHash | ID on-chain: $onchainId",
      );
      return txHash;
    } on PostgrestException catch (e) {
      debugPrint(
        "INSERT SUPABASE GAGAL (tx sudah di chain: $txHash) -> "
        "code: ${e.code}, message: ${e.message}, details: ${e.details}, hint: ${e.hint}",
      );
      rethrow;
    } catch (e) {
      debugPrint("Error Tambah Blok Blockchain: $e");
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Verifikasi
  // [hash] = hash transaksi (yang dikembalikan tambahBlok)
  // ---------------------------------------------------------------------------

  static Future<HasilVerifikasi> verifikasiDetail(
    String ticketId,
    String hash,
  ) async {
    try {
      final txHash = hash.startsWith('0x') ? hash : '0x$hash';

      final receipt = await _web3.getTransactionReceipt(txHash);
      if (receipt == null) {
        return const HasilVerifikasi(
          false,
          'Tiket tidak ditemukan di blockchain.',
        );
      }

      if (receipt.status == false) {
        return const HasilVerifikasi(
          false,
          'Transaksi tiket gagal di blockchain.',
        );
      }

      final onchainId = await _ticketIdDariReceipt(receipt);
      if (onchainId == null) {
        return const HasilVerifikasi(
          false,
          'Hash ini bukan transaksi penerbitan tiket.',
        );
      }

      final tiket = await _bacaTiket(onchainId);
      if (tiket == null) {
        return HasilVerifikasi(
          false,
          'Data tiket tidak ada di smart contract.',
          onchainId.toString(),
        );
      }

      final bool dipakai = tiket[7] as bool;
      if (dipakai) {
        return HasilVerifikasi(
          false,
          'Tiket asli, tetapi sudah dipakai.',
          onchainId.toString(),
          true,
          _waktuDipakai(tiket),
        );
      }

      return const HasilVerifikasi(
        true,
        'Tiket valid dan terdaftar di blockchain Sepolia.',
      );
    } catch (e) {
      debugPrint("Gagal Verifikasi Tiket: $e");
      return HasilVerifikasi(false, 'Verifikasi gagal: $e');
    }
  }

  static Future<bool> verifikasiTiket(String ticketId, String hash) async {
    final hasil = await verifikasiDetail(ticketId, hash);
    return hasil.valid;
  }

  // ---------------------------------------------------------------------------
  // Gunakan tiket: tandai terpakai di smart contract (useTicket)
  // [hash] = hash transaksi tiket (yang dikembalikan tambahBlok)
  // Mengembalikan hash transaksi pemakaian
  // ---------------------------------------------------------------------------

  static Future<String> gunakanTiket(String hash) async {
    try {
      final txHashTiket = hash.startsWith('0x') ? hash : '0x$hash';

      final receipt = await _web3.getTransactionReceipt(txHashTiket);
      if (receipt == null) {
        throw Exception('Tiket tidak ditemukan di blockchain.');
      }

      final onchainId = await _ticketIdDariReceipt(receipt);
      if (onchainId == null) {
        throw Exception('Hash ini bukan transaksi penerbitan tiket.');
      }

      // Cek dulu agar tidak membuang gas pada tiket yang sudah dipakai
      final tiket = await _bacaTiket(onchainId);
      if (tiket == null) {
        throw Exception('Data tiket tidak ada di smart contract.');
      }
      if (tiket[7] as bool) {
        throw Exception('Tiket sudah dipakai.');
      }

      final contract = await _getContract();
      final String txHashPakai = await _web3.sendTransaction(
        _credentials(),
        Transaction.callContract(
          contract: contract,
          function: contract.function('useTicket'),
          parameters: [onchainId],
        ),
        chainId: Web3Config.chainId,
      );
      debugPrint("Tx useTicket terkirim: $txHashPakai");

      await _tungguKonfirmasi(txHashPakai);
      debugPrint("Tiket #$onchainId berhasil ditandai terpakai.");
      return txHashPakai;
    } catch (e) {
      debugPrint("Gagal menandai tiket terpakai: $e");
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Validasi seluruh tiket yang tercatat di smart contract
  // ---------------------------------------------------------------------------

  static Future<HasilVerifikasi> validasiRantai() async {
    try {
      final contract = await _getContract();
      final res = await _web3.call(
        contract: contract,
        function: contract.function('nextTicketId'),
        params: [],
      );
      final total = (res[0] as BigInt).toInt();

      int jumlah = 0;
      for (var i = 0; i < total; i++) {
        final tiket = await _bacaTiket(BigInt.from(i));
        if (tiket == null) {
          return HasilVerifikasi(
            false,
            'Blok #$i rusak: data tiket tidak ditemukan di smart contract.',
            i,
          );
        }
        jumlah++;
      }

      return HasilVerifikasi(true, 'Rantai valid. $jumlah blok diperiksa.');
    } catch (e) {
      debugPrint("Gagal validasi rantai: $e");
      return HasilVerifikasi(false, 'Validasi gagal: $e');
    }
  }
}