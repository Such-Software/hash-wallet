import 'package:hash_wallet/bitcoin/bitcoin.dart';
import 'package:hash_wallet/bitcoin_cash/bitcoin_cash.dart';
import 'package:hash_wallet/dogecoin/dogecoin.dart';
import 'package:hash_wallet/evm/evm.dart';
import 'package:hash_wallet/monero/monero.dart';
import 'package:hash_wallet/wownero/wownero.dart';
import 'package:cw_core/transaction_priority.dart';
import 'package:cw_core/wallet_type.dart';

List<TransactionPriority> priorityForWalletType(WalletType type) {
  switch (type) {
    case WalletType.monero:
      return monero!.getTransactionPriorities();
    case WalletType.wownero:
      return wownero!.getTransactionPriorities();
    case WalletType.bitcoin:
      return bitcoin!.getTransactionPriorities();
    case WalletType.litecoin:
      return bitcoin!.getLitecoinTransactionPriorities();
    case WalletType.ethereum:
    case WalletType.polygon:
    case WalletType.base:
    case WalletType.bsc:
      return evm!.getTransactionPriorities();
    case WalletType.bitcoinCash:
      return bitcoinCash!.getTransactionPriorities();
    case WalletType.dogecoin:
      return dogecoin!.getTransactionPriorities();
    case WalletType.arbitrum:
    case WalletType.nano:
    case WalletType.banano:
      return [];
    case WalletType.none:
      return [];
  }
}
