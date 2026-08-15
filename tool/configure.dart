import 'dart:io';

const bitcoinOutputPath = 'lib/bitcoin/bitcoin.dart';
const moneroOutputPath = 'lib/monero/monero.dart';
const bitcoinCashOutputPath = 'lib/bitcoin_cash/bitcoin_cash.dart';
const nanoOutputPath = 'lib/nano/nano.dart';
const wowneroOutputPath = 'lib/wownero/wownero.dart';
const dogecoinOutputPath = 'lib/dogecoin/dogecoin.dart';
const evmOutputPath = 'lib/evm/evm.dart';
const walletTypesPath = 'lib/wallet_types.g.dart';
const secureStoragePath = 'lib/core/secure_storage.dart';
const pubspecDefaultPath = 'pubspec_default.yaml';
const pubspecOutputPath = 'pubspec.yaml';

Future<void> main(List<String> args) async {
  const prefix = '--';
  final hasBitcoin = args.contains('${prefix}bitcoin');
  final hasMonero = args.contains('${prefix}monero');
  final hasEthereum = args.contains('${prefix}ethereum');
  final hasBitcoinCash = args.contains('${prefix}bitcoinCash');
  final hasNano = args.contains('${prefix}nano');
  final hasBanano = args.contains('${prefix}banano');
  final hasPolygon = args.contains('${prefix}polygon');
  final hasWownero = args.contains('${prefix}wownero');
  final hasDogecoin = args.contains('${prefix}dogecoin');
  final hasBase = args.contains('${prefix}base');
  final hasArbitrum = args.contains('${prefix}arbitrum');
  final hasBsc = args.contains('${prefix}bsc');
  final hasEVM = hasEthereum || hasPolygon || hasBase || hasArbitrum || hasBsc;
  final excludeFlutterSecureStorage = args.contains('${prefix}excludeFlutterSecureStorage');

  await generateBitcoin(hasBitcoin);
  await generateMonero(hasMonero);
  await generateBitcoinCash(hasBitcoinCash);
  await generateNano(hasNano);
  await generateWownero(hasWownero);
  // await generateBanano(hasEthereum);
  await generateDogecoin(hasDogecoin);
  await generateEVM(hasEVM);

  await generatePubspec(
    hasMonero: hasMonero,
    hasBitcoin: hasBitcoin,
    hasEthereum: hasEthereum,
    hasNano: hasNano,
    hasBanano: hasBanano,
    hasBitcoinCash: hasBitcoinCash,
    hasFlutterSecureStorage: !excludeFlutterSecureStorage,
    hasPolygon: hasPolygon,
    hasWownero: hasWownero,
    hasDogecoin: hasDogecoin,
    hasBase: hasBase,
    hasArbitrum: hasArbitrum,
    hasBsc: hasBsc,
  );
  await generateWalletTypes(
    hasMonero: hasMonero,
    hasBitcoin: hasBitcoin,
    hasEthereum: hasEthereum,
    hasNano: hasNano,
    hasBanano: hasBanano,
    hasBitcoinCash: hasBitcoinCash,
    hasPolygon: hasPolygon,
    hasWownero: hasWownero,
    hasDogecoin: hasDogecoin,
    hasBase: hasBase,
    hasArbitrum: hasArbitrum,
    hasBsc: hasBsc,
  );
  await injectSecureStorage(!excludeFlutterSecureStorage);
}

Future<void> generateBitcoin(bool hasImplementation) async {
  final outputFile = File(bitcoinOutputPath);
  const bitcoinCommonHeaders = """
import 'dart:io' show Platform;
import 'dart:typed_data';
import 'package:bitcoin_base/bitcoin_base.dart';
import 'package:hash_wallet/view_model/hardware_wallet/ledger_view_model.dart';
import 'package:hash_wallet/view_model/send/output.dart';
import 'package:cw_core/hardware/hardware_account_data.dart';
import 'package:cw_core/hardware/hardware_wallet_service.dart';
import 'package:cw_core/node.dart';
import 'package:cw_core/payjoin_session.dart';
import 'package:cw_core/output_info.dart';
import 'package:cw_core/pending_transaction.dart';
import 'package:cw_core/receive_page_option.dart';
import 'package:cw_core/transaction_info.dart';
import 'package:cw_core/transaction_priority.dart';
import 'package:cw_core/unspent_coin_type.dart';
import 'package:cw_core/unspent_coins_info.dart';
import 'package:cw_core/unspent_transaction_output.dart';
import 'package:cw_core/wallet_base.dart';
import 'package:cw_core/wallet_credentials.dart';
import 'package:cw_core/wallet_info.dart';
import 'package:cw_core/wallet_service.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:cw_core/utils/print_verbose.dart';
import 'package:cw_core/get_height_by_date.dart';
import 'package:hive/hive.dart';
import 'package:ledger_flutter_plus/ledger_flutter_plus.dart' as ledger;
import 'package:bitbox_flutter/bitbox_flutter.dart' as bitbox;
import 'package:trezor_connect/trezor_connect.dart' as trezor;
import 'package:blockchain_utils/blockchain_utils.dart';
import 'package:bip39/bip39.dart' as bip39;
import 'package:collection/collection.dart';
""";
  const bitcoinCWHeaders = """
import 'package:cw_bitcoin/utils.dart';
import 'package:cw_bitcoin/electrum_derivations.dart';
import 'package:cw_bitcoin/electrum.dart';
import 'package:cw_bitcoin/electrum_transaction_info.dart';
import 'package:cw_bitcoin/pending_bitcoin_transaction.dart';
import 'package:cw_bitcoin/bitcoin_receive_page_option.dart';
import 'package:cw_bitcoin/electrum_wallet.dart';
import 'package:cw_bitcoin/bitcoin_unspent.dart';
import 'package:cw_bitcoin/bitcoin_mnemonic.dart';
import 'package:cw_bitcoin/bitcoin_transaction_priority.dart';
import 'package:cw_bitcoin/bitcoin_wallet.dart';
import 'package:cw_bitcoin/bitcoin_wallet_service.dart';
import 'package:cw_bitcoin/bitcoin_wallet_creation_credentials.dart';
import 'package:cw_bitcoin/bitcoin_amount_format.dart';
import 'package:cw_bitcoin/bitcoin_address_record.dart';
import 'package:cw_bitcoin/bitcoin_wallet_addresses.dart';
import 'package:cw_bitcoin/bitcoin_transaction_credentials.dart';
import 'package:cw_bitcoin/lightning/pending_lightning_transaction.dart';
import 'package:cw_bitcoin/litecoin_wallet_service.dart';
import 'package:cw_bitcoin/litecoin_wallet.dart';
import 'package:cw_bitcoin/hardware/bitcoin_ledger_service.dart';
import 'package:cw_bitcoin/hardware/litecoin_ledger_service.dart';
import 'package:cw_bitcoin/hardware/bitbox_service.dart';
import 'package:cw_bitcoin/hardware/trezor_service.dart';
import 'package:mobx/mobx.dart';
import "package:breez_sdk_spark_flutter/src/rust/errors.dart";
""";
  const bitcoinCwPart = "part 'cw_bitcoin.dart';";
  const bitcoinContent = """

class ElectrumSubAddress {
  ElectrumSubAddress({
    required this.id,
    required this.name,
    required this.address,
    required this.txCount,
    required this.balance,
    required this.isChange,
    this.derivationPath,
    this.isLegacyDerivation = false
  });
  final int id;
  final String name;
  final String address;
  final int txCount;
  final int balance;
  final bool isChange;
  final String? derivationPath;
  final bool isLegacyDerivation;
}

abstract class Bitcoin {
  TransactionPriority getMediumTransactionPriority();

  WalletCredentials createBitcoinRestoreWalletFromSeedCredentials({
    required String name,
    required String mnemonic,
    required String password,
    required DerivationType derivationType,
    required String derivationPath,
    String? passphrase,
  });
  WalletCredentials createBitcoinRestoreWalletFromWIFCredentials({required String name, required String password, required String wif, WalletInfo? walletInfo});
  WalletCredentials createBitcoinWalletFromKeys({required String name, required String password, required String xpub, HardwareWalletType? hardwareWalletType});
  WalletCredentials createLitecoinWalletFromKeys({required String name, required String password, required String xpub, required String scanSecret, required String spendPubkey, HardwareWalletType? hardwareWalletType});
  WalletCredentials createBitcoinNewWalletCredentials({required String name, WalletInfo? walletInfo, String? password, String? passphrase, String? mnemonic});
  WalletCredentials createBitcoinHardwareWalletCredentials({required String name, required HardwareAccountData accountData, WalletInfo? walletInfo});
  List<String> getWordList();
  Map<String, String> getWalletKeys(Object wallet);
  List<TransactionPriority> getTransactionPriorities();
  List<TransactionPriority> getLitecoinTransactionPriorities();
  TransactionPriority deserializeBitcoinTransactionPriority(int raw);
  TransactionPriority deserializeLitecoinTransactionPriority(int raw);
  int getFeeRate(Object wallet, TransactionPriority priority);
  Future<void> generateNewAddress(Object wallet, String label);
  Future<void> updateAddress(Object wallet,String address, String label);
  Object createBitcoinTransactionCredentials(List<Output> outputs, {required TransactionPriority priority, int? feeRate, UnspentCoinType coinTypeToSpendFrom = UnspentCoinType.any, String? payjoinUri});

  String getAddress(Object wallet);
  List<ElectrumSubAddress> getSilentPaymentAddresses(Object wallet);
  List<ElectrumSubAddress> getSilentPaymentReceivedAddresses(Object wallet);

  Future<int> estimateFakeSendAllTxAmount(Object wallet, TransactionPriority priority,
      {UnspentCoinType coinTypeToSpendFrom = UnspentCoinType.any});
  List<ElectrumSubAddress> getSubAddresses(Object wallet);

  String formatterBitcoinAmountToString({required int amount});
  double formatterBitcoinAmountToDouble({required int amount});
  int formatterStringDoubleToBitcoinAmount(String amount);
  String bitcoinTransactionPriorityWithLabel(TransactionPriority priority, int rate, {int? customRate});

  List<Unspent> getUnspents(Object wallet, {UnspentCoinType coinTypeToSpendFrom = UnspentCoinType.any});
  Future<void> updateUnspents(Object wallet);
  WalletService createBitcoinWalletService(
      Box<UnspentCoinsInfo> unspentCoinSource, Box<PayjoinSession> payjoinSessionSource, bool isDirect);
  WalletService createLitecoinWalletService(Box<UnspentCoinsInfo> unspentCoinSource, bool isDirect);
  TransactionPriority getBitcoinTransactionPriorityMedium();
  TransactionPriority getBitcoinTransactionPriorityCustom();
  TransactionPriority getLitecoinTransactionPriorityMedium();
  TransactionPriority getBitcoinTransactionPrioritySlow();
  TransactionPriority getLitecoinTransactionPrioritySlow();
  Future<List<DerivationType>> compareDerivationMethods(
      {required String mnemonic, required Node node});
  Future<List<DerivationInfo>> getDerivationsFromMnemonic(
      {required String mnemonic, required Node node, String? passphrase});
  Map<DerivationType, List<DerivationInfo>> getElectrumDerivations();
  Future<void> setAddressType(Object wallet, dynamic option);
  ReceivePageOption getSelectedAddressType(Object wallet);
  BitcoinAddressType getBitcoinAddressType(ReceivePageOption option);
  ReceivePageOption getBitcoinLightningReceivePageOption();
  ReceivePageOption getBitcoinSegwitPageOption();
  ReceivePageOption getLitecoinMwebReceivePageOption();
  bool isPayjoinAvailable(Object wallet);
  bool hasSelectedSilentPayments(Object wallet);
  bool isBitcoinReceivePageOption(ReceivePageOption option);
  BitcoinAddressType getOptionToType(ReceivePageOption option);
  bool hasTaprootInput(PendingTransaction pendingTransaction);
  bool getScanningActive(Object wallet);
  Future<void> setScanningActive(Object wallet, bool active);
  Future<void> setIsAlwaysScanningSP(Object wallet, bool active);
  bool getIsAlwaysScanningSP(Object wallet);
  bool isTestnet(Object wallet);

  Future<PendingTransaction> replaceByFee(Object wallet, String transactionHash, String fee);
  Future<String?> canReplaceByFee(Object wallet, Object tx);
  int getTransactionVSize(Object wallet, String txHex);
  Future<bool> isChangeSufficientForFee(Object wallet, String txId, String newFee);
  int getFeeAmountForPriority(Object wallet, TransactionPriority priority, int inputsCount, int outputsCount, {int? size});
  int getEstimatedFeeWithFeeRate(Object wallet, int feeRate, int? amount,
      {int? outputsCount, int? size});
  int feeAmountWithFeeRate(Object wallet, int feeRate, int inputsCount, int outputsCount, {int? size});
  Future<bool> checkIfMempoolAPIIsEnabled(Object wallet);
  Future<int> getHeightByDate({required DateTime date, bool? bitcoinMempoolAPIEnabled});
  int getLitecoinHeightByDate({required DateTime date});
  Future<void> rescan(Object wallet, {required int height, bool? doSingleScan});
  Future<bool> getNodeIsElectrsSPEnabled(Object wallet);
  void deleteSilentPaymentAddress(Object wallet, String address);
  Future<void> updateFeeRates(Object wallet);
  int getMaxCustomFeeRate(Object wallet);
  Future<void> setHardwareWalletService(WalletBase wallet, HardwareWalletService service);
  HardwareWalletService getLedgerHardwareWalletService(ledger.LedgerConnection connection, bool isBitcoin);
  HardwareWalletService getBitboxHardwareWalletService(bitbox.BitboxManager manager, bool isBitcoin);
  HardwareWalletService getTrezorHardwareWalletService(trezor.TrezorConnect connect, bool isBitcoin);
  List<Output> updateOutputs(PendingTransaction pendingTransaction, List<Output> outputs);
  bool txIsReceivedSilentPayment(TransactionInfo txInfo);
  bool txIsMweb(TransactionInfo txInfo);
  Future<void> setMwebEnabled(Object wallet, bool enabled);
  bool getMwebEnabled(Object wallet);
  String? getUnusedMwebAddress(Object wallet);
  String? getUnusedSegwitAddress(Object wallet);
  Future<String?> getUnusedSpakDepositAddress(Object wallet);
  Future<void> commitPsbtUR(Object wallet, List<String> urCodes);

  void updatePayjoinState(Object wallet, bool state);
  String getPayjoinEndpoint(Object wallet);
  void resumePayjoinSessions(Object wallet);
  void stopPayjoinSessions(Object wallet);
  Map<String, String> getSilentPaymentKeys(Object wallet);
  List<String>? getTransactionAddresses(Object wallet, TransactionInfo tx);
  String getNetworkName(Object wallet);
  bool useLightning(Object wallet);
  void updateUseLightning(Object wallet, bool value);
  Future<void> setLightningUsername(Object wallet, String username);
  Future<String?> getLightningUsername(Object wallet);
  Future<String?> getLightningInvoice(Object wallet, BigInt amount);
  String? getBreezSdkError(Object exception);
}
  """;

  const bitcoinEmptyDefinition = 'Bitcoin? bitcoin;\n';
  const bitcoinCWDefinition = 'Bitcoin? bitcoin = CWBitcoin();\n';

  final output = '$bitcoinCommonHeaders\n' +
      (hasImplementation ? '$bitcoinCWHeaders\n' : '\n') +
      (hasImplementation ? '$bitcoinCwPart\n\n' : '\n') +
      (hasImplementation ? bitcoinCWDefinition : bitcoinEmptyDefinition) +
      '\n' +
      bitcoinContent;

  if (outputFile.existsSync()) {
    await outputFile.delete();
  }

  await outputFile.writeAsString(output);
}

Future<void> generateMonero(bool hasImplementation) async {
  final outputFile = File(moneroOutputPath);
  const moneroCommonHeaders = """
import 'package:cw_core/unspent_transaction_output.dart';
import 'package:cw_core/unspent_coins_info.dart';
import 'package:mobx/mobx.dart';
import 'package:cw_core/wallet_credentials.dart';
import 'package:cw_core/wallet_info.dart';
import 'package:cw_core/transaction_priority.dart';
import 'package:cw_core/transaction_history.dart';
import 'package:cw_core/transaction_info.dart';
import 'package:cw_core/balance.dart';
import 'package:cw_core/output_info.dart';
import 'package:hash_wallet/view_model/send/output.dart';
import 'package:cw_core/wallet_service.dart';
import 'package:hive/hive.dart';
import 'package:ledger_flutter_plus/ledger_flutter_plus.dart' as ledger;
import 'package:polyseed/polyseed.dart';""";
  const moneroCWHeaders = """
import 'package:cw_core/account.dart' as monero_account;
import 'package:cw_core/get_height_by_date.dart';
import 'package:cw_core/monero_amount_format.dart';
import 'package:cw_core/monero_transaction_priority.dart';
import 'package:cw_monero/api/wallet_manager.dart';
import 'package:cw_monero/api/wallet.dart' as monero_wallet_api;
import 'package:cw_monero/ledger.dart';
import 'package:cw_monero/monero_unspent.dart';
import 'package:cw_monero/api/account_list.dart';
import 'package:cw_monero/monero_wallet_service.dart';
import 'package:cw_monero/monero_wallet.dart';
import 'package:cw_monero/monero_transaction_info.dart';
import 'package:cw_monero/monero_transaction_creation_credentials.dart';
import 'package:cw_core/mnemonics/english.dart';
import 'package:cw_core/mnemonics/chinese_simplified.dart';
import 'package:cw_core/mnemonics/dutch.dart';
import 'package:cw_core/mnemonics/german.dart';
import 'package:cw_core/mnemonics/japanese.dart';
import 'package:cw_core/mnemonics/russian.dart';
import 'package:cw_core/mnemonics/spanish.dart';
import 'package:cw_core/mnemonics/portuguese.dart';
import 'package:cw_core/mnemonics/french.dart';
import 'package:cw_core/mnemonics/italian.dart';
import 'package:cw_monero/pending_monero_transaction.dart';
""";
  const moneroCwPart = "part 'cw_monero.dart';";
  const moneroContent = """
class Account {
  Account({required this.id, required this.label, this.balance});
  final int id;
  final String label;
  final String? balance;
}

class Subaddress {
  Subaddress({
    required this.id,
    required this.label,
    required this.address,
    required this.received,
    required this.txCount});
  final int id;
  final String label;
  final String address;
  final String? received;
  final int txCount;
}

class MoneroBalance extends Balance {
  MoneroBalance({required this.fullBalance, required this.unlockedBalance})
      : formattedFullBalance = monero!.formatterMoneroAmountToString(amount: fullBalance),
        formattedUnlockedBalance =
            monero!.formatterMoneroAmountToString(amount: unlockedBalance),
        super.fromInt(unlockedBalance, fullBalance);

  MoneroBalance.fromString(
      {required this.formattedFullBalance,
      required this.formattedUnlockedBalance})
      : fullBalance = monero!.formatterMoneroParseAmount(amount: formattedFullBalance),
        unlockedBalance = monero!.formatterMoneroParseAmount(amount: formattedUnlockedBalance),
        super.fromInt(monero!.formatterMoneroParseAmount(amount: formattedUnlockedBalance),
            monero!.formatterMoneroParseAmount(amount: formattedFullBalance));

  final int fullBalance;
  final int unlockedBalance;
  final String formattedFullBalance;
  final String formattedUnlockedBalance;

  @override
  String get formattedAvailableBalance => formattedUnlockedBalance;

  @override
  String get formattedAdditionalBalance => formattedFullBalance;
}

abstract class MoneroWalletDetails {
  @observable
  late Account account;

  @observable
  late MoneroBalance balance;
}

abstract class Monero {
  MoneroAccountList getAccountList(Object wallet);

  MoneroSubaddressList getSubaddressList(Object wallet);

  TransactionHistoryBase getTransactionHistory(Object wallet);

  MoneroWalletDetails getMoneroWalletDetails(Object wallet);

  String getTransactionAddress(Object wallet, int accountIndex, int addressIndex);

  String getSubaddressLabel(Object wallet, int accountIndex, int addressIndex);

  int getHeightByDate({required DateTime date});
  TransactionPriority getDefaultTransactionPriority();
  TransactionPriority getMoneroTransactionPrioritySlow();
  TransactionPriority getMoneroTransactionPriorityAutomatic();
  TransactionPriority deserializeMoneroTransactionPriority({required int raw});
  List<TransactionPriority> getTransactionPriorities();
  List<String> getMoneroWordList(String language);

  List<Unspent> getUnspents(Object wallet);
  Future<void> updateUnspents(Object wallet);

  Future<int> getCurrentHeight();

  Future<bool> commitTransactionUR(Object wallet, String ur);

  Map<String, String> exportOutputsUR(Object wallet);

  bool needExportOutputs(Object wallet, int amount);

  bool importKeyImagesUR(Object wallet, String ur);

  WalletCredentials createMoneroRestoreWalletFromKeysCredentials({
    required String name,
    required String spendKey,
    required String viewKey,
    required String address,
    required String password,
    required String language,
    HardwareWalletType? hardwareWalletType,
    required int height});
  WalletCredentials createMoneroRestoreWalletFromSeedCredentials({required String name, required String password, required String passphrase, required int height, required String mnemonic});
  WalletCredentials createMoneroRestoreWalletFromHardwareCredentials({required String name, required String password, required int height, required ledger.LedgerConnection ledgerConnection});
WalletCredentials createMoneroNewWalletCredentials({required String name, required String language, required int seedType, required String? passphrase, String? password, String? mnemonic});
  Map<String, String> getKeys(Object wallet);
  int? getRestoreHeight(Object wallet);
  Object createMoneroTransactionCreationCredentials({required List<Output> outputs, required TransactionPriority priority});
  Object createMoneroTransactionCreationCredentialsRaw({required List<OutputInfo> outputs, required TransactionPriority priority});
  String formatterMoneroAmountToString({required int amount});
  double formatterMoneroAmountToDouble({required int amount});
  int formatterMoneroParseAmount({required String amount});
  Account getCurrentAccount(Object wallet);
  void monerocCheck();
  bool isViewOnly();
  void setCurrentAccount(Object wallet, int id, String label, String? balance);
  void onStartup();
  int getTransactionInfoAccountId(TransactionInfo tx);
  WalletService createMoneroWalletService(Box<UnspentCoinsInfo> unspentCoinSource);
  Map<String, String> pendingTransactionInfo(Object transaction);
  Future<void> setLedgerConnection(Object wallet, ledger.LedgerConnection connection);
  void resetLedgerConnection();
  void setGlobalLedgerConnection(ledger.LedgerConnection connection);
  String? getLastLedgerCommand();
  Map<String, List<int>> debugCallLength();
  Map<String, dynamic> getWalletCacheDebug();
}

abstract class MoneroSubaddressList {
  ObservableList<Subaddress> get subaddresses;
  Future<void> update(Object wallet, {required int accountIndex});
  void refresh(Object wallet, {required int accountIndex});
  Future<List<Subaddress>> getAll(Object wallet);
  Future<void> addSubaddress(Object wallet, {required int accountIndex, required String label});
  Future<void> setLabelSubaddress(Object wallet,
      {required int accountIndex, required int addressIndex, required String label});
}

abstract class MoneroAccountList {
  ObservableList<Account> get accounts;
  void update(Object wallet);
  void refresh(Object wallet);
  List<Account> getAll(Object wallet);
  Future<void> addAccount(Object wallet, {required String label});
  Future<void> setLabelAccount(Object wallet, {required int accountIndex, required String label});
}
  """;

  const moneroEmptyDefinition = 'Monero? monero;\n';
  const moneroCWDefinition = 'Monero? monero = CWMonero();\n';

  final output = '$moneroCommonHeaders\n' +
      (hasImplementation ? '$moneroCWHeaders\n' : '\n') +
      (hasImplementation ? '$moneroCwPart\n\n' : '\n') +
      (hasImplementation ? moneroCWDefinition : moneroEmptyDefinition) +
      '\n' +
      moneroContent;

  if (outputFile.existsSync()) {
    await outputFile.delete();
  }

  await outputFile.writeAsString(output);
}

Future<void> generateWownero(bool hasImplementation) async {
  final outputFile = File(wowneroOutputPath);
  const wowneroCommonHeaders = """
import 'package:cw_core/unspent_transaction_output.dart';
import 'package:cw_core/unspent_coins_info.dart';
import 'package:mobx/mobx.dart';
import 'package:cw_core/wallet_credentials.dart';
import 'package:cw_core/wallet_info.dart';
import 'package:cw_core/transaction_priority.dart';
import 'package:cw_core/transaction_history.dart';
import 'package:cw_core/transaction_info.dart';
import 'package:cw_core/balance.dart';
import 'package:cw_core/output_info.dart';
import 'package:hash_wallet/view_model/send/output.dart';
import 'package:cw_core/crypto_currency.dart';
import 'package:hash_wallet/core/key_service.dart';
import 'package:hash_wallet/core/secure_storage.dart';
import 'package:cw_core/cake_hive.dart';
import 'package:cw_core/wallet_info.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:cw_core/wallet_service.dart';
import 'package:hive/hive.dart';
import 'package:polyseed/polyseed.dart';""";
  const wowneroCWHeaders = """
import 'package:cw_core/get_height_by_date.dart';
import 'package:cw_core/wownero_amount_format.dart';
import 'package:cw_core/monero_transaction_priority.dart';
import 'package:cw_wownero/wownero_unspent.dart';
import 'package:cw_wownero/wownero_wallet_service.dart';
import 'package:cw_wownero/wownero_wallet.dart';
import 'package:cw_wownero/wownero_transaction_info.dart';
import 'package:cw_wownero/wownero_transaction_creation_credentials.dart';
import 'package:cw_core/account.dart' as wownero_account;
import 'package:cw_wownero/api/wallet.dart' as wownero_wallet_api;
import 'package:cw_wownero/api/wallet_manager.dart';
import 'package:cw_core/mnemonics/english.dart';
import 'package:cw_core/mnemonics/chinese_simplified.dart';
import 'package:cw_core/mnemonics/dutch.dart';
import 'package:cw_core/mnemonics/german.dart';
import 'package:cw_core/mnemonics/japanese.dart';
import 'package:cw_core/mnemonics/russian.dart';
import 'package:cw_core/mnemonics/spanish.dart';
import 'package:cw_core/mnemonics/portuguese.dart';
import 'package:cw_core/mnemonics/french.dart';
import 'package:cw_core/mnemonics/italian.dart';
import 'package:cw_wownero/pending_wownero_transaction.dart';
""";
  const wowneroCwPart = "part 'cw_wownero.dart';";
  const wowneroContent = """
class Account {
  Account({required this.id, required this.label, this.balance});
  final int id;
  final String label;
  final String? balance;
}

class Subaddress {
  Subaddress({
    required this.id,
    required this.label,
    required this.address});
  final int id;
  final String label;
  final String address;
}

class WowneroBalance extends Balance {
  WowneroBalance({required this.fullBalance, required this.unlockedBalance})
      : formattedFullBalance = wownero!.formatterWowneroAmountToString(amount: fullBalance),
        formattedUnlockedBalance =
            wownero!.formatterWowneroAmountToString(amount: unlockedBalance),
        super.fromInt(unlockedBalance, fullBalance);

  WowneroBalance.fromString(
      {required this.formattedFullBalance,
      required this.formattedUnlockedBalance})
      : fullBalance = wownero!.formatterWowneroParseAmount(amount: formattedFullBalance),
        unlockedBalance = wownero!.formatterWowneroParseAmount(amount: formattedUnlockedBalance),
        super.fromInt(wownero!.formatterWowneroParseAmount(amount: formattedUnlockedBalance),
            wownero!.formatterWowneroParseAmount(amount: formattedFullBalance));

  final int fullBalance;
  final int unlockedBalance;
  final String formattedFullBalance;
  final String formattedUnlockedBalance;

  @override
  String get formattedAvailableBalance => formattedUnlockedBalance;

  @override
  String get formattedAdditionalBalance => formattedFullBalance;
}

abstract class WowneroWalletDetails {
  @observable
  late Account account;

  @observable
  late WowneroBalance balance;
}

abstract class Wownero {
  WowneroAccountList getAccountList(Object wallet);

  WowneroSubaddressList getSubaddressList(Object wallet);

  TransactionHistoryBase getTransactionHistory(Object wallet);

  WowneroWalletDetails getWowneroWalletDetails(Object wallet);

  String getTransactionAddress(Object wallet, int accountIndex, int addressIndex);

  String getSubaddressLabel(Object wallet, int accountIndex, int addressIndex);

  int getHeightByDate({required DateTime date});
  TransactionPriority getDefaultTransactionPriority();
  TransactionPriority getWowneroTransactionPrioritySlow();
  TransactionPriority getWowneroTransactionPriorityAutomatic();
  TransactionPriority deserializeWowneroTransactionPriority({required int raw});
  List<TransactionPriority> getTransactionPriorities();
  List<String> getWowneroWordList(String language);

  List<Unspent> getUnspents(Object wallet);
  Future<void> updateUnspents(Object wallet);

  Future<int> getCurrentHeight();
  void wownerocCheck();

  WalletCredentials createWowneroRestoreWalletFromKeysCredentials({
    required String name,
    required String spendKey,
    required String viewKey,
    required String address,
    required String password,
    required String language,
    required int height});
  WalletCredentials createWowneroRestoreWalletFromSeedCredentials({required String name, required String password, required String passphrase, required int height, required String mnemonic});
  WalletCredentials createWowneroNewWalletCredentials({required String name, required String language, required bool isPolyseed, String? password, String? passphrase});
  int? getRestoreHeight(Object wallet);
  Map<String, String> getKeys(Object wallet);
  Object createWowneroTransactionCreationCredentials({required List<Output> outputs, required TransactionPriority priority});
  Object createWowneroTransactionCreationCredentialsRaw({required List<OutputInfo> outputs, required TransactionPriority priority});
  String formatterWowneroAmountToString({required int amount});
  double formatterWowneroAmountToDouble({required int amount});
  int formatterWowneroParseAmount({required String amount});
  Account getCurrentAccount(Object wallet);
  void setCurrentAccount(Object wallet, int id, String label, String? balance);
  void onStartup();
  int getTransactionInfoAccountId(TransactionInfo tx);
  WalletService createWowneroWalletService(Box<UnspentCoinsInfo> unspentCoinSource);
  Map<String, String> pendingTransactionInfo(Object transaction);
  String getLegacySeed(Object wallet, String langName);
  Map<String, List<int>> debugCallLength();
}

abstract class WowneroSubaddressList {
  ObservableList<Subaddress> get subaddresses;
  void update(Object wallet, {required int accountIndex});
  void refresh(Object wallet, {required int accountIndex});
  List<Subaddress> getAll(Object wallet);
  Future<void> addSubaddress(Object wallet, {required int accountIndex, required String label});
  Future<void> setLabelSubaddress(Object wallet,
      {required int accountIndex, required int addressIndex, required String label});
}

abstract class WowneroAccountList {
  ObservableList<Account> get accounts;
  void update(Object wallet);
  void refresh(Object wallet);
  List<Account> getAll(Object wallet);
  Future<void> addAccount(Object wallet, {required String label});
  Future<void> setLabelAccount(Object wallet, {required int accountIndex, required String label});
}
  """;

  const wowneroEmptyDefinition = 'Wownero? wownero;\n';
  const wowneroCWDefinition = 'Wownero? wownero = CWWownero();\n';

  final output = '$wowneroCommonHeaders\n' +
      (hasImplementation ? '$wowneroCWHeaders\n' : '\n') +
      (hasImplementation ? '$wowneroCwPart\n\n' : '\n') +
      (hasImplementation ? wowneroCWDefinition : wowneroEmptyDefinition) +
      '\n' +
      wowneroContent;

  if (outputFile.existsSync()) {
    await outputFile.delete();
  }

  await outputFile.writeAsString(output);
}

Future<void> generateBitcoinCash(bool hasImplementation) async {
  final outputFile = File(bitcoinCashOutputPath);
  const bitcoinCashCommonHeaders = """
import 'dart:typed_data';

import 'package:cw_core/unspent_transaction_output.dart';
import 'package:cw_core/transaction_priority.dart';
import 'package:cw_core/unspent_coins_info.dart';
import 'package:cw_core/wallet_credentials.dart';
import 'package:cw_core/wallet_info.dart';
import 'package:cw_core/wallet_service.dart';
import 'package:hive/hive.dart';
""";
  const bitcoinCashCWHeaders = """
import 'package:cw_bitcoin_cash/cw_bitcoin_cash.dart';
import 'package:cw_bitcoin/bitcoin_transaction_priority.dart';
""";
  const bitcoinCashCwPart = "part 'cw_bitcoin_cash.dart';";
  const bitcoinCashContent = """
abstract class BitcoinCash {
  String getCashAddrFormat(String address);

  WalletService createBitcoinCashWalletService(
      Box<UnspentCoinsInfo> unspentCoinSource, bool isDirect);

  WalletCredentials createBitcoinCashNewWalletCredentials(
      {required String name, WalletInfo? walletInfo, String? password, String? passphrase, String? mnemonic});

  WalletCredentials createBitcoinCashRestoreWalletFromSeedCredentials(
      {required String name, required String mnemonic, required String password, String? passphrase});

  TransactionPriority deserializeBitcoinCashTransactionPriority(int raw);

  TransactionPriority getDefaultTransactionPriority();

  List<TransactionPriority> getTransactionPriorities();

  TransactionPriority getBitcoinCashTransactionPrioritySlow();
}
  """;

  const bitcoinCashEmptyDefinition = 'BitcoinCash? bitcoinCash;\n';
  const bitcoinCashCWDefinition = 'BitcoinCash? bitcoinCash = CWBitcoinCash();\n';

  final output = '$bitcoinCashCommonHeaders\n' +
      (hasImplementation ? '$bitcoinCashCWHeaders\n' : '\n') +
      (hasImplementation ? '$bitcoinCashCwPart\n\n' : '\n') +
      (hasImplementation ? bitcoinCashCWDefinition : bitcoinCashEmptyDefinition) +
      '\n' +
      bitcoinCashContent;

  if (outputFile.existsSync()) {
    await outputFile.delete();
  }

  await outputFile.writeAsString(output);
}

Future<void> generateNano(bool hasImplementation) async {
  final outputFile = File(nanoOutputPath);
  const nanoCommonHeaders = """
import 'package:cw_core/cake_hive.dart';
import 'package:cw_core/nano_account.dart';
import 'package:cw_core/account.dart';
import 'package:cw_core/node.dart';
import 'package:cw_core/wallet_credentials.dart';
import 'package:cw_core/wallet_info.dart';
import 'package:cw_core/transaction_info.dart';
import 'package:cw_core/transaction_history.dart';
import 'package:cw_core/wallet_service.dart';
import 'package:cw_core/output_info.dart';
import 'package:cw_core/nano_account_info_response.dart';
import 'package:cw_core/n2_node.dart';
import 'package:cw_core/utils/print_verbose.dart';
import 'package:mobx/mobx.dart';
import 'package:hive/hive.dart';
import 'package:hash_wallet/view_model/send/output.dart';
""";
  const nanoCWHeaders = """
import 'package:cw_nano/nano_client.dart';
import 'package:cw_nano/nano_mnemonic.dart';
import 'package:cw_nano/nano_wallet.dart';
import 'package:cw_nano/nano_wallet_service.dart';
import 'package:cw_nano/nano_transaction_info.dart';
import 'package:cw_nano/nano_transaction_credentials.dart';
import 'package:cw_nano/nano_wallet_creation_credentials.dart';
// needed for nano_util:
import 'dart:convert';
import 'dart:typed_data';
import 'package:convert/convert.dart';
import "package:ed25519_hd_key/ed25519_hd_key.dart";
import 'package:libcrypto/libcrypto.dart';
import 'package:nanodart/nanodart.dart' as ND;
import 'package:nanoutil/nanoutil.dart';
""";
  const nanoCwPart = "part 'cw_nano.dart';";
  const nanoContent = """
abstract class Nano {
  NanoAccountList getAccountList(Object wallet);

  Account getCurrentAccount(Object wallet);

  void setCurrentAccount(Object wallet, int id, String label, String? balance);

  WalletService createNanoWalletService(bool isDirect);

  WalletCredentials createNanoNewWalletCredentials({
    required String name,
    String? password,
    String? mnemonic,
    WalletInfo? walletInfo,
    String? passphrase,
  });

  WalletCredentials createNanoRestoreWalletFromSeedCredentials({
    required String name,
    required String password,
    required String mnemonic,
    required DerivationType derivationType,
    String? passphrase,
  });

  WalletCredentials createNanoRestoreWalletFromKeysCredentials({
    required String name,
    required String password,
    required String seedKey,
    required DerivationType derivationType,
  });

  List<String> getNanoWordList(String language);
  Map<String, String> getKeys(Object wallet);
  Object createNanoTransactionCredentials(List<Output> outputs);
  Future<void> changeRep(Object wallet, String address);
  Future<bool> updateTransactions(Object wallet);
  BigInt getTransactionAmountRaw(TransactionInfo transactionInfo);
  String getRepresentative(Object wallet);
  Future<List<N2Node>> getN2Reps(Object wallet);
  bool isRepOk(Object wallet);
}

abstract class NanoAccountList {
  ObservableList<NanoAccount> get accounts;
  void update(Object wallet);
  void refresh(Object wallet);
  Future<List<NanoAccount>> getAll(Object wallet);
  Future<void> addAccount(Object wallet, {required String label});
  Future<void> setLabelAccount(Object wallet, {required int accountIndex, required String label});
}

abstract class NanoUtil {
  bool isValidBip39Seed(String seed);
  static const int maxDecimalDigits = 6; // Max digits after decimal
  BigInt rawPerNano = BigInt.parse("1000000000000000000000000000000");
  BigInt rawPerNyano = BigInt.parse("1000000000000000000000000");
  BigInt rawPerBanano = BigInt.parse("100000000000000000000000000000");
  BigInt rawPerXMR = BigInt.parse("1000000000000");
  BigInt convertXMRtoNano = BigInt.parse("1000000000000000000");
  String getRawAsUsableString(String? raw, BigInt rawPerCur);
  String getRawAccuracy(String? raw, BigInt rawPerCur);
  String getAmountAsRaw(String amount, BigInt rawPerCur);

  // derivationInfo:
  Future<AccountInfoResponse?> getInfoFromSeedOrMnemonic(
    DerivationType derivationType, {
    String? seedKey,
    String? mnemonic,
    required Node node,
  });
  Future<List<DerivationType>> compareDerivationMethods({
    String? mnemonic,
    String? privateKey,
    required Node node,
  });
  Future<List<DerivationInfo>> getDerivationsFromMnemonic({
    String? mnemonic,
    String? seedKey,
    required Node node,
  });
}
  """;

  const nanoEmptyDefinition = 'Nano? nano;\nNanoUtil? nanoUtil;\n';
  const nanoCWDefinition = 'Nano? nano = CWNano();\nNanoUtil? nanoUtil = CWNanoUtil();\n';

  final output = '$nanoCommonHeaders\n' +
      (hasImplementation ? '$nanoCWHeaders\n' : '\n') +
      (hasImplementation ? '$nanoCwPart\n\n' : '\n') +
      (hasImplementation ? nanoCWDefinition : nanoEmptyDefinition) +
      '\n' +
      nanoContent;

  if (outputFile.existsSync()) {
    await outputFile.delete();
  }

  await outputFile.writeAsString(output);
}

Future<void> generateDogecoin(bool hasImplementation) async {
  final outputFile = File(dogecoinOutputPath);
  const dogecoinCommonHeaders = """
import 'package:cw_core/transaction_priority.dart';
import 'package:cw_core/unspent_coins_info.dart';
import 'package:cw_core/wallet_credentials.dart';
import 'package:cw_core/wallet_info.dart';
import 'package:cw_core/wallet_service.dart';
import 'package:hive/hive.dart';
""";
  const dogecoinCWHeaders = """
import 'package:cw_dogecoin/cw_dogecoin.dart';
""";
  const dogecoinCwPart = "part 'cw_dogecoin.dart';";
  const dogecoinContent = """
abstract class DogeCoin {

  WalletService createDogeCoinWalletService(Box<UnspentCoinsInfo> unspentCoinSource, bool isDirect);

  WalletCredentials createDogeCoinNewWalletCredentials(
      {required String name, WalletInfo? walletInfo, String? password, String? passphrase, String? mnemonic});

  WalletCredentials createDogeCoinRestoreWalletFromSeedCredentials(
      {required String name, required String mnemonic, required String password, String? passphrase});

  TransactionPriority deserializeDogeCoinTransactionPriority(int raw);

  TransactionPriority getDefaultTransactionPriority();

  List<TransactionPriority> getTransactionPriorities();

  TransactionPriority getDogeCoinTransactionPrioritySlow();
}
""";

  const dogecoinEmptyDefinition = 'DogeCoin? dogecoin;\n';
  const dogecoinCWDefinition = 'DogeCoin? dogecoin = CWDogeCoin();\n';

  final output = '$dogecoinCommonHeaders\n' +
      (hasImplementation ? '$dogecoinCWHeaders\n' : '\n') +
      (hasImplementation ? '$dogecoinCwPart\n\n' : '\n') +
      (hasImplementation ? dogecoinCWDefinition : dogecoinEmptyDefinition) +
      '\n' +
      dogecoinContent;

  if (outputFile.existsSync()) {
    await outputFile.delete();
  }

  await outputFile.writeAsString(output);
}

Future<void> generateEVM(bool hasImplementation) async {
  final outputFile = File(evmOutputPath);
  const evmCommonHeaders = """
import 'dart:math' as math;
import 'package:hash_wallet/core/utilities.dart';
import 'package:hash_wallet/view_model/send/output.dart';
import 'package:cw_core/crypto_currency.dart';
import 'package:cw_core/erc20_token.dart';
import 'package:cw_core/hardware/hardware_account_data.dart';
import 'package:cw_core/hardware/hardware_wallet_service.dart';
import 'package:cw_core/output_info.dart';
import 'package:cw_core/pending_transaction.dart';
import 'package:cw_core/transaction_info.dart';
import 'package:cw_core/transaction_priority.dart';
import 'package:cw_core/wallet_base.dart';
import 'package:cw_core/wallet_credentials.dart';
import 'package:cw_core/wallet_info.dart';
import 'package:cw_core/wallet_service.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:cw_core/node.dart';
import 'package:ledger_flutter_plus/ledger_flutter_plus.dart' as ledger;
import 'package:bitbox_flutter/bitbox_flutter.dart' as bitbox;
import 'package:trezor_connect/trezor_connect.dart' as trezor;
import 'package:web3dart/web3dart.dart';

""";
  const evmCWHeaders = """
import 'package:hash_wallet/core/fiat_conversion_service.dart';
import 'package:hash_wallet/di.dart';
import 'package:hash_wallet/entities/fiat_api_mode.dart';
import 'package:hash_wallet/entities/fiat_currency.dart';
import 'package:hash_wallet/store/settings_store.dart';
import 'package:cw_evm/utils/evm_chain_formatter.dart';
import 'package:cw_evm/evm_chain_mnemonics.dart';
import 'package:cw_evm/evm_chain_registry.dart';
import 'package:cw_evm/evm_erc20_balance.dart';
import 'package:cw_evm/evm_chain_transaction_credentials.dart';
import 'package:cw_evm/evm_chain_transaction_info.dart';
import 'package:cw_evm/evm_chain_transaction_priority.dart';
import 'package:cw_evm/hardware/evm_chain_bitbox_credentials.dart';
import 'package:cw_evm/hardware/evm_chain_ledger_credentials.dart';
import 'package:cw_evm/hardware/evm_chain_trezor_credentials.dart';
import 'package:cw_evm/evm_chain_wallet.dart';
import 'package:cw_evm/hardware/evm_chain_bitbox_service.dart';
import 'package:cw_evm/hardware/evm_chain_ledger_service.dart';
import 'package:cw_evm/hardware/evm_chain_trezor_service.dart';
import 'package:cw_evm/evm_chain_wallet_service.dart';
import 'package:cw_evm/evm_chain_wallet_creation_credentials.dart';
import 'package:cw_evm/utils/evm_chain_utils.dart';
import 'package:cw_evm/evm_chain_default_tokens.dart';
import 'package:cw_evm/deuro/deuro_savings.dart';
import 'package:cw_evm/usdt0/usdt0_config.dart';
import 'package:cw_evm/usdt0/usdt0_quote.dart';
import 'package:cw_evm/usdt0/usdt0_service.dart';
import 'package:eth_sig_util/util/utils.dart';
export 'package:cw_evm/evm_chain_transaction_priority.dart';
export 'package:cw_evm/evm_erc20_balance.dart';
export 'package:cw_evm/usdt0/usdt0_quote.dart';

""";
  const evmCwPart = "part 'cw_evm.dart';";
  const evmContent = """
/// Unified abstract class for all EVM chains
/// 
/// This replaces separate proxy classes (Ethereum, Polygon, Base, Arbitrum)
/// with a single unified interface that works for all EVM chains.
/// Methods take WalletType parameter to determine chain-specific behavior.
abstract class EVM {
  List<String> getEVMWordList(String language);
  
  /// Create unified wallet service for any EVM chain
  WalletService createEVMWalletService(WalletType walletType, bool isDirect);
  
  /// Generic credential creation - uses WalletType
  WalletCredentials createEVMNewWalletCredentials({
    required String name,
    WalletInfo? walletInfo,
    String? password,
    String? mnemonic,
    String? passphrase,
  });
  
  WalletCredentials createEVMRestoreWalletFromSeedCredentials({
    required String name,
    required String mnemonic,
    required String password,
    String? passphrase,
  });
  
  WalletCredentials createEVMRestoreWalletFromPrivateKey({
    required String name,
    required String privateKey,
    required String password,
  });
  
  WalletCredentials createEVMHardwareWalletCredentials({
    required String name,
    required HardwareAccountData hwAccountData,
    WalletInfo? walletInfo,
  });
  
  // Generic methods that work for all EVM chains
  String getAddress(WalletBase wallet);
  String getPrivateKey(WalletBase wallet);
  String getPublicKey(WalletBase wallet);
  TransactionPriority getDefaultTransactionPriority();
  TransactionPriority getEVMTransactionPrioritySlow();
  List<TransactionPriority> getTransactionPriorities();
  TransactionPriority deserializeEVMTransactionPriority(int raw);
  
  Object createEVMTransactionCredentials(
    List<Output> outputs, {
    required TransactionPriority? priority,
    required CryptoCurrency currency,
    int? feeRate,
    bool useBlinkProtection = true,
  });
  
  Object createEVMTransactionCredentialsRaw(
    List<OutputInfo> outputs, {
    TransactionPriority? priority,
    required CryptoCurrency currency,
    required int feeRate,
    bool useBlinkProtection = true,
  });
  
  int formatterEVMParseAmount(String amount);
  double formatterEVMAmountToDouble({
    TransactionInfo? transaction,
    BigInt? amount,
    int exponent = 18,
  });
  
  List<Erc20Token> getERC20Currencies(WalletBase wallet);
  Future<void> addErc20Token(WalletBase wallet, CryptoCurrency token);
  Future<void> deleteErc20Token(WalletBase wallet, CryptoCurrency token);
  Future<void> removeTokenTransactionsInHistory(WalletBase wallet, CryptoCurrency token);
  Future<Erc20Token?> getErc20Token(WalletBase wallet, String contractAddress);
  
  CryptoCurrency assetOfTransaction(WalletBase wallet, TransactionInfo transaction);
  void updateScanProviderUsageState(WalletBase wallet, bool isEnabled);
  Web3Client? getWeb3Client(WalletBase wallet);
  String getTokenAddress(CryptoCurrency asset);
  BigInt? getERC20AvailableBalance(Object balance);
  
  Future<bool> isApprovalRequired(
    WalletBase wallet,
    String tokenContract,
    String spender,
    BigInt requiredAmount,
  );
  
  Future<BigInt?> getAllowance(
      WalletBase wallet,
      String tokenContract,
      String spender);
  
  Future<PendingTransaction> createTokenApproval(
    WalletBase wallet,
    BigInt amount,
    String spender,
    CryptoCurrency token,
    TransactionPriority? priority,
    {bool useBlinkProtection = true}
  );
  
  Future<PendingTransaction> createRawCallDataTransaction(
    WalletBase wallet,
    String to,
    String dataHex,
    BigInt valueWei,
    TransactionPriority? priority,
    {bool useBlinkProtection = true,
    String? sourceTokenAddress,
    BigInt? sourceTokenAmount}
  );
  
  // Hardware wallet methods
  Future<void> setHardwareWalletService(WalletBase wallet, HardwareWalletService service);
  HardwareWalletService getLedgerHardwareWalletService(ledger.LedgerConnection connection);
  HardwareWalletService getBitboxHardwareWalletService(bitbox.BitboxManager manager);
  HardwareWalletService getTrezorHardwareWalletService(trezor.TrezorConnect connect);
  
  // Utility methods
  List<Erc20Token> getDefaultTokensByChainId(int chainId);
  List<String> getDefaultTokenContractAddresses(WalletBase wallet);
  List<String> getDefaultTokenSymbols(WalletBase wallet);
  bool isTokenAlreadyAdded(WalletBase wallet, String contractAddress);
  String? getEVMNativeEstimatedFee(WalletBase wallet);
  String? getEVMERC20EstimatedFee(WalletBase wallet);
  
  // Chain-specific integrations (optional, can be null for non-Ethereum chains)
  Future<BigInt>? getDEuroSavingsBalance(WalletBase wallet) => null;
  Future<BigInt>? getDEuroAccruedInterest(WalletBase wallet) => null;
  Future<BigInt>? getDEuroInterestRate(WalletBase wallet) => null;
  Future<BigInt>? getDEuroSavingsApproved(WalletBase wallet) => null;
  Future<PendingTransaction>? addDEuroSaving(WalletBase wallet, BigInt amount, TransactionPriority priority) => null;
  Future<PendingTransaction>? removeDEuroSaving(WalletBase wallet, BigInt amount, TransactionPriority priority) => null;
  Future<PendingTransaction>? reinvestDEuroInterest(WalletBase wallet, TransactionPriority priority) => null;
  Future<PendingTransaction>? enableDEuroSaving(WalletBase wallet, TransactionPriority priority) => null;
  
  // Registry helper methods (for backward compatibility helpers)
  int getChainIdByWalletType(WalletType walletType);
  String getChainNameByWalletType(WalletType walletType);
  String getTokenNameByWalletType(WalletType walletType);
  String getCaip2ByChainId(int chainId);
  int? getChainIdByTag(String tag);
  int? getChainIdByTitle(String title);
  WalletType? getWalletTypeByChainId(int chainId);
  String getChainNameByChainId(int chainId);
  String getTokenNameByChainId(int chainId);
  // Chain selection methods
  List<ChainInfo> getAllChains();
  ChainInfo? getCurrentChain(WalletBase wallet);
  ChainInfo? getChainInfoByChainId(int chainId);


  int? getSelectedChainId(WalletBase wallet);
  Future<void> selectChain(WalletBase wallet, int chainId, {required Node node});
  
  String? getExplorerUrlForChainId(int chainId, {bool showProtocol = true});
  
  Future<bool?> getTransactionReceipt(WalletBase wallet, String txHash);

  bool hasPriorityFee(int chainId);

  bool isUSDT0Token(WalletBase wallet, CryptoCurrency token);
  List<ChainInfo> getUSDT0DestinationChains(WalletBase wallet);

  Future<BridgeQuote> quoteUSDT0Transfer({
    required WalletBase wallet,
    required int sourceChainId,
    required int destinationChainId,
    required BigInt amount,
    required String recipientAddress,
  });

  Future<PendingTransaction> executeUSDT0Transfer({
    required WalletBase wallet,
    required CryptoCurrency token,
    required int sourceChainId,
    required int destinationChainId,
    required BigInt amount,
    required String recipientAddress,
    required BridgeQuote quote,
    required TransactionPriority priority,
    bool useBlinkProtection = true,
  });
  
  Future<EvmWalletConnectFeeQuote?> getWCBufferedFeeQuote(
    WalletBase wallet,
    TransactionPriority priority,
  );

  Future<void> discoverAndAddWalletTokens(WalletBase wallet);
}

class ChainInfo {
  const ChainInfo({
    required this.chainId,
    required this.name,
    required this.shortCode,
    required this.currency,
  });
  
  final int chainId;
  final String name;
  final String shortCode;
  final CryptoCurrency currency;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChainInfo && runtimeType == other.runtimeType && chainId == other.chainId;

  @override
  int get hashCode => chainId.hashCode;
}

class EvmWalletConnectFeeQuote {
  const EvmWalletConnectFeeQuote({
    required this.maxFeePerGasWei,
    required this.maxPriorityFeePerGasWei,
    this.latestBaseFeeWei,
  });

  final int maxFeePerGasWei;
  final int maxPriorityFeePerGasWei;
  final int? latestBaseFeeWei;
}

class BridgeQuote {
  const BridgeQuote({
    required this.nativeFee,
    required this.lzTokenFee,
  });

  final BigInt nativeFee;
  final BigInt lzTokenFee;
}
  """;

  const evmEmptyDefinition = 'EVM? evm;\n';
  const evmCWDefinition = 'EVM? evm = CWEVM();\n';

  final output = '$evmCommonHeaders\n' +
      (hasImplementation ? '$evmCWHeaders\n' : '\n') +
      (hasImplementation ? '$evmCwPart\n\n' : '\n') +
      (hasImplementation ? evmCWDefinition : evmEmptyDefinition) +
      '\n' +
      evmContent;

  if (outputFile.existsSync()) {
    await outputFile.delete();
  }

  await outputFile.writeAsString(output);
}

Future<void> generatePubspec({
  required bool hasMonero,
  required bool hasBitcoin,
  required bool hasEthereum,
  required bool hasNano,
  required bool hasBanano,
  required bool hasBitcoinCash,
  required bool hasFlutterSecureStorage,
  required bool hasPolygon,
  required bool hasWownero,
  required bool hasDogecoin,
  required bool hasBase,
  required bool hasArbitrum,
  required bool hasBsc,
}) async {
  const cwCore = """
  cw_core:
    path: ./cw_core
    """;
  const cwMonero = """
  cw_monero:
    path: ./cw_monero
  """;
  const cwBitcoin = """
  cw_bitcoin:
    path: ./cw_bitcoin
  """;
  const flutterSecureStorage = """
  flutter_secure_storage:
    git:
      url: https://github.com/cake-tech/flutter_secure_storage.git
      path: flutter_secure_storage
      ref: ca897a08677edb443b366352dd7412735e098e7b
  """;
  const cwBitcoinCash = """
  cw_bitcoin_cash:
    path: ./cw_bitcoin_cash
  """;
  const cwNano = """
  cw_nano:
    path: ./cw_nano
  """;
  const cwBanano = """
  cw_banano:
    path: ./cw_banano
  """;
  const cwEVM = """
  cw_evm:
    path: ./cw_evm
    """;
  const cwWownero = """
  cw_wownero:
    path: ./cw_wownero
    """;
  const cwDogecoin = """
  cw_dogecoin:
      path: ./cw_dogecoin
  """;

  final inputFile = File(pubspecOutputPath);
  final inputText = await inputFile.readAsString();
  final inputLines = inputText.split('\n');
  final dependenciesIndex = inputLines.indexWhere((line) => Platform.isWindows
      // On Windows it could contains `\r` (Carriage Return). It could be fixed in newer dart versions.
      ? line.toLowerCase() == 'dependencies:\r' || line.toLowerCase() == 'dependencies:'
      : line.toLowerCase() == 'dependencies:');
  var output = cwCore;

  if (hasMonero) {
    output += '\n$cwMonero';
  }

  if (hasBitcoin) {
    output += '\n$cwBitcoin';
  }

  if (hasNano) {
    output += '\n$cwNano';
  }

  if (hasBanano) {
    output += '\n$cwBanano';
  }

  if (hasBitcoinCash) {
    output += '\n$cwBitcoinCash';
  }

  if (hasFlutterSecureStorage) {
    output += '\n$flutterSecureStorage\n';
  }

  if (hasEthereum || hasPolygon || hasBase || hasArbitrum || hasBsc) {
    output += '\n$cwEVM';
  }

  if (hasWownero) {
    output += '\n$cwWownero';
  }

  if (hasDogecoin) {
    output += '\n$cwDogecoin';
  }

  final outputLines = output.split('\n');
  inputLines.insertAll(dependenciesIndex + 1, outputLines);
  final outputContent = inputLines.join('\n');
  final outputFile = File(pubspecOutputPath);

  if (outputFile.existsSync()) {
    await outputFile.delete();
  }

  await outputFile.writeAsString(outputContent);
}

Future<void> generateWalletTypes({
  required bool hasMonero,
  required bool hasBitcoin,
  required bool hasEthereum,
  required bool hasNano,
  required bool hasBanano,
  required bool hasBitcoinCash,
  required bool hasPolygon,
  required bool hasWownero,
  required bool hasDogecoin,
  required bool hasBase,
  required bool hasArbitrum,
  required bool hasBsc,
}) async {
  final walletTypesFile = File(walletTypesPath);

  if (walletTypesFile.existsSync()) {
    await walletTypesFile.delete();
  }

  const outputHeader = "import 'package:cw_core/wallet_type.dart';";
  const outputDefinition = 'final availableWalletTypes = <WalletType>[';
  var outputContent = outputHeader + '\n\n' + outputDefinition + '\n';

  // Hash Bags: Wownero up top — it's the reason this fork exists.
  if (hasWownero) {
    outputContent += '\tWalletType.wownero,\n';
  }

  if (hasMonero) {
    outputContent += '\tWalletType.monero,\n';
  }

  if (hasBitcoin) {
    outputContent += '\tWalletType.bitcoin,\n';
  }

  if (hasEthereum) {
    outputContent += '\tWalletType.ethereum,\n';
  }

  if (hasBsc) {
    outputContent += '\tWalletType.bsc,\n';
  }

  if (hasDogecoin) {
    outputContent += '\tWalletType.dogecoin,\n';
  }

  if (hasBitcoinCash) {
    outputContent += '\tWalletType.bitcoinCash,\n';
  }

  if (hasBitcoin) {
    outputContent += '\tWalletType.litecoin,\n';
  }

  if (hasBase) {
    outputContent += '\tWalletType.base,\n';
  }

  if (hasArbitrum) {
    outputContent += '\tWalletType.arbitrum,\n';
  }

  if (hasPolygon) {
    outputContent += '\tWalletType.polygon,\n';
  }

  if (hasNano) {
    outputContent += '\tWalletType.nano,\n';
  }

  if (hasBanano) {
    outputContent += '\tWalletType.banano,\n';
  }

  // (Wownero moved to the top of this list — see comment above.)

  outputContent += '];\n';
  await walletTypesFile.writeAsString(outputContent);
}

Future<void> injectSecureStorage(bool hasFlutterSecureStorage) async {
  const flutterSecureStorageHeader = """
import 'dart:async';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
""";
  const abstractSecureStorage = """
abstract class SecureStorage {
  Future<String?> read({required String key});
  Future<void> write({required String key, required String? value});
  Future<void> delete({required String key});
  Future<void> deleteAll();
  // Legacy
  Future<String?> readNoIOptions({required String key});
  Future<Map<String, String>> readAll();
 }""";
  const defaultSecureStorage = """
class DefaultSecureStorage extends SecureStorage {
  DefaultSecureStorage._(this._secureStorage);

  factory DefaultSecureStorage() => _instance;

  static final _instance = DefaultSecureStorage._(FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  ));

  final FlutterSecureStorage _secureStorage;

  @override
  Future<String?> read({required String key}) async => await _readInternal(key, false);

  @override
  Future<void> write({required String key, required String? value}) async {
    // delete the value before writing on macOS because of a weird bug
    // https://github.com/mogol/flutter_secure_storage/issues/581
    if (Platform.isMacOS) {
      await _secureStorage.delete(key: key);
    }
    await _secureStorage.write(key: key, value: value);
  }

  @override
  Future<void> delete({required String key}) async => _secureStorage.delete(key: key);

  @override
  Future<void> deleteAll() async => _secureStorage.deleteAll();

  @override
  Future<String?> readNoIOptions({required String key}) async => await _readInternal(key, true);

  Future<String?> _readInternal(String key, bool useNoIOptions) async {
    return await _secureStorage.read(
      key: key,
      iOptions: useNoIOptions ? IOSOptions() : null,
    );
  }

  @override
  Future<Map<String, String>> readAll() async {
    return await _secureStorage.readAll();
  }
 }""";
  const fakeSecureStorage = """
class FakeSecureStorage extends SecureStorage {
  @override
  Future<String?> read({required String key}) async => null;
  @override
  Future<void> write({required String key, required String? value}) async {}
  @override
  Future<void> delete({required String key}) async {}
  @override
  Future<void> deleteAll() async {}
  @override
  Future<String?> readNoIOptions({required String key}) async => null;
  @override
  Future<Map<String, String>> readAll() async => {};
 }""";
  final outputFile = File(secureStoragePath);
  final header = hasFlutterSecureStorage
      ? '${flutterSecureStorageHeader}\n\nfinal SecureStorage secureStorageShared = DefaultSecureStorage();\n'
      : 'final SecureStorage secureStorageShared = FakeSecureStorage();\n';
  var output = '';
  if (outputFile.existsSync()) {
    await outputFile.delete();
  }

  output += '${header}\n${abstractSecureStorage}\n\n';

  if (hasFlutterSecureStorage) {
    output += '${defaultSecureStorage}\n';
  } else {
    output += '${fakeSecureStorage}\n';
  }

  await outputFile.writeAsString(output);
}
