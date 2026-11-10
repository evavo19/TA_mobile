import 'package:flutter_dotenv/flutter_dotenv.dart';

class Web3Config {
  static const String rpcUrl = 'https://ethereum-sepolia-rpc.publicnode.com';
  static const int chainId = 11155111;

  static const String contractAddress =
      '0xd9F28D7b2D3B29392BDd80c2192C2123255bFECC';

  static const String defaultHolder =
      '0x3552578d34E880D1aC6544b2017E473bB1Da8B1d';

  // Dibaca dari file .env
  static String get privateKey => dotenv.env['SEPOLIA_PRIVATE_KEY'] ?? '';

  static const String explorerTx = 'https://sepolia.etherscan.io/tx/';
}