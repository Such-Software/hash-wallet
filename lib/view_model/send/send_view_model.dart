import 'dart:async';

import 'package:hash_wallet/bitcoin/bitcoin.dart';
import 'package:hash_wallet/core/address_validator.dart';
import 'package:hash_wallet/core/amount_parsing_proxy.dart';
import 'package:hash_wallet/core/amount_validator.dart';
import 'package:hash_wallet/core/execution_state.dart';
import 'package:hash_wallet/core/open_crypto_pay/exceptions.dart';
import 'package:hash_wallet/core/open_crypto_pay/models.dart';
import 'package:hash_wallet/core/open_crypto_pay/open_cryptopay_service.dart';
import 'package:hash_wallet/core/validator.dart';
import 'package:hash_wallet/core/wallet_change_listener_view_model.dart';
import 'package:hash_wallet/entities/calculate_fiat_amount.dart';
import 'package:hash_wallet/entities/contact.dart';
import 'package:hash_wallet/entities/contact_record.dart';
import 'package:hash_wallet/entities/evm_transaction_error_fees_handler.dart';
import 'package:hash_wallet/entities/fiat_currency.dart';
import 'package:hash_wallet/entities/parsed_address.dart';
import 'package:hash_wallet/entities/preferences_key.dart';
import 'package:hash_wallet/entities/template.dart';
import 'package:hash_wallet/entities/transaction_description.dart';
import 'package:hash_wallet/entities/wallet_contact.dart';
import 'package:hash_wallet/evm/evm.dart';
import 'package:hash_wallet/exchange/provider/exchange_provider.dart';
import 'package:hash_wallet/exchange/provider/near_Intents_exchange_provider.dart';
import 'package:hash_wallet/exchange/trade.dart';
import 'package:hash_wallet/generated/i18n.dart';
import 'package:hash_wallet/monero/monero.dart';
import 'package:hash_wallet/nano/nano.dart';
import 'package:hash_wallet/reactions/wallet_connect.dart';
import 'package:hash_wallet/routes.dart';
import 'package:hash_wallet/store/app_store.dart';
import 'package:hash_wallet/store/dashboard/fiat_conversion_store.dart';
import 'package:hash_wallet/store/settings_store.dart';
import 'package:hash_wallet/utils/payment_request.dart';
import 'package:hash_wallet/view_model/contact_list/contact_list_view_model.dart';
import 'package:hash_wallet/view_model/dashboard/balance_view_model.dart';
import 'package:hash_wallet/view_model/hardware_wallet/hardware_wallet_view_model.dart';
import 'package:hash_wallet/view_model/send/fees_view_model.dart';
import 'package:hash_wallet/view_model/send/output.dart';
import 'package:hash_wallet/view_model/send/send_template_view_model.dart';
import 'package:hash_wallet/view_model/send/send_view_model_state.dart';
import 'package:hash_wallet/view_model/unspent_coins/unspent_coins_list_view_model.dart';
import 'package:hash_wallet/wownero/wownero.dart';
import 'package:cw_core/crypto_currency.dart';
import 'package:cw_core/currency_for_wallet_type.dart';
import 'package:cw_core/exceptions.dart';
import 'package:cw_core/lnurl.dart';
import 'package:cw_core/pending_transaction.dart';
import 'package:cw_core/sync_status.dart';
import 'package:cw_core/transaction_info.dart';
import 'package:cw_core/unspent_coin_type.dart';
import 'package:cw_core/utils/print_verbose.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:mobx/mobx.dart';
import 'package:hash_wallet/utils/token_utilities.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'send_view_model.g.dart';

class SendViewModel = SendViewModelBase with _$SendViewModel;

abstract class SendViewModelBase extends WalletChangeListenerViewModel with Store {
  @override
  void onWalletChange(wallet) {
    currencies = wallet.balance.keys.toList();
    selectedCryptoCurrency =
        coinTypeToSpendFrom == UnspentCoinType.lightning ? CryptoCurrency.btcln : wallet.currency;
    hasMultipleTokens = isEVMWallet;

    for (final output in outputs) {
      output.updateWallet(wallet);
    }

    // Update unspent coins list view model with the new wallet reference
    unspentCoinsListViewModel.updateWallet(wallet);

    // Update sending balance to reflect the new wallet's balance
    updateSendingBalance();
  }

  UnspentCoinsListViewModel unspentCoinsListViewModel;

  SendViewModelBase(
    this._appStore,
    this.sendTemplateViewModel,
    this._fiatConversationStore,
    this.balanceViewModel,
    this.contactListViewModel,
    this.transactionDescriptionBox,
    this.hardwareWalletViewModel,
    this.unspentCoinsListViewModel,
    this.feesViewModel, {
    this.coinTypeToSpendFrom = UnspentCoinType.nonMweb,
  })  : state = InitialExecutionState(),
        currencies = _appStore.wallet!.balance.keys.toList(),
        selectedCryptoCurrency = coinTypeToSpendFrom == UnspentCoinType.lightning
            ? CryptoCurrency.btcln
            : _appStore.wallet!.currency,
        hasMultipleTokens = isEVMCompatibleChain(_appStore.wallet!.type),
        selectedChainId = _appStore.wallet!.chainId,
        outputs = ObservableList<Output>(),
        fiatFromSettings = _appStore.settingsStore.fiatCurrency,
        fiatCurrencies = FiatCurrency.all,
        super(appStore: _appStore) {
    outputs.add(Output(wallet, _appStore, _fiatConversationStore, () => selectedCryptoCurrency));

    unspentCoinsListViewModel
        .initialSetup()
        .then((_) => unspentCoinsListViewModel.resetUnspentCoinsInfoSelections());

    reaction((_) {
      if (isEVMCompatibleChain(wallet.type)) {
        // Access currency which depends on selectedChainId, so MobX tracks the change
        return wallet.currency;
      }
      return null;
    }, (_) async {
      // When chain changes, update currencies and selected currency
      await Future.delayed(const Duration(milliseconds: 100));
      currencies = wallet.balance.keys.toList();
      selectedCryptoCurrency = wallet.currency;
      updateSendingBalance();
    });
  }

  @observable
  ExecutionState state;

  ObservableList<Output> outputs;

  @observable
  UnspentCoinType coinTypeToSpendFrom;

  bool get showAddressBookPopup => _settingsStore.showAddressBookPopupEnabled;

  bool get isMwebEnabled => balanceViewModel.mwebEnabled;

  bool get isMwebAvailable => wallet.currency == CryptoCurrency.ltc && balanceViewModel.mwebEnabled;

  bool get isEVMWallet => isEVMCompatibleChain(walletType);

  @action
  void setShowAddressBookPopup(bool value) => _settingsStore.showAddressBookPopupEnabled = value;

  @action
  void addOutput() =>
      outputs.add(Output(wallet, _appStore, _fiatConversationStore, () => selectedCryptoCurrency));

  @action
  void removeOutput(Output output) {
    if (isBatchSending) outputs.remove(output);
  }

  @action
  void clearOutputs() {
    outputs.clear();
    addOutput();
  }

  @action
  void setAllowMwebCoins(bool allow) {
    if (wallet.type == WalletType.litecoin) {
      coinTypeToSpendFrom = allow ? UnspentCoinType.any : UnspentCoinType.nonMweb;
    }
  }

  @computed
  bool get isBatchSending => outputs.length > 1;

  bool get shouldDisplaySendALL {
    // if (walletType == WalletType.ethereum && selectedCryptoCurrency == CryptoCurrency.eth)
    // return false;

    // if (walletType == WalletType.polygon && selectedCryptoCurrency == CryptoCurrency.maticpoly)
    // return false;

    return true;
  }

  @computed
  String get pendingTransactionFiatAmount {
    if (pendingTransaction == null) return '0.00';

    try {
      final selectedCurrency = selectedCryptoCurrency == CryptoCurrency.btcln
          ? CryptoCurrency.btc
          : selectedCryptoCurrency;
      var currency = _fiatConversationStore.prices.keys
          .firstWhere((k) => k.titleAndTagEqual(selectedCurrency));

      final fiat = calculateFiatAmount(
          price: _fiatConversationStore.prices[currency],
          cryptoAmount: pendingTransaction!.amountFormatted);
      return fiat;
    } catch (_) {
      return '0.00';
    }
  }

  String calculateTransactionFiatAmount(String amountValue) {
    try {
      final fiat = calculateFiatAmount(
          price: _fiatConversationStore.prices[_fiatConversationStore.prices.keys
              .firstWhere((k) => k.titleAndTagEqual(selectedCryptoCurrency))],
          cryptoAmount: amountValue);
      return fiat;
    } catch (_) {
      return '0.00';
    }
  }

  @computed
  String get pendingTransactionFeeFiatAmount {
    try {
      if (pendingTransaction != null) {
        final currency = pendingTransactionFeeCurrency(walletType);
        final fiat = calculateFiatAmount(
          price: _fiatConversationStore.prices[currency]!,
          cryptoAmount: pendingTransaction!.feeFormattedValue,
        );
        return fiat;
      } else {
        return '0.00';
      }
    } catch (_) {
      return '0.00';
    }
  }

  CryptoCurrency pendingTransactionFeeCurrency(WalletType type) {
    switch (type) {
      case WalletType.ethereum:
      case WalletType.polygon:
      case WalletType.base:
      case WalletType.arbitrum:
      case WalletType.bsc:
      case WalletType.bitcoin:
        return wallet.currency;
      default:
        return selectedCryptoCurrency;
    }
  }

  FiatCurrency get fiat => _settingsStore.fiatCurrency;

  CryptoCurrency get currency =>
      selectedCryptoCurrency == CryptoCurrency.btcln ? CryptoCurrency.btcln : wallet.currency;

  String get currencySymbol => _appStore.amountParsingProxy.getCryptoSymbol(currency);

  Validator<String> amountValidator(Output output) => AmountValidator(
        currency: wallet.currency,
        amountParsingProxy: _appStore.amountParsingProxy,
        minValue: isSendToSilentPayments(output)
            ?
            //  TODO: get from server
            // bitcoin!.silentPaymentsMinAmount
            '0.00001'
            : null,
      );

  Validator<String> get allAmountValidator => AllAmountValidator();

  Validator<String> get addressValidator =>
      AddressValidator(type: selectedCryptoCurrency, isTestnet: wallet.isTestnet);

  Validator<String> get textValidator => TextValidator();

  final FiatCurrency fiatFromSettings;

  @observable
  PendingTransaction? pendingTransaction;

  @computed
  String get balance {
    if (walletType == WalletType.litecoin && coinTypeToSpendFrom == UnspentCoinType.mweb) {
      return balanceViewModel.balances.values.first.secondAvailableBalance;
    } else if (walletType == WalletType.litecoin &&
        coinTypeToSpendFrom == UnspentCoinType.nonMweb) {
      return balanceViewModel.balances.values.first.availableBalance;
    }

    // Handle case where balance might not be available yet (e.g., during chain switch)
    final balanceForCurrency = wallet.balance[selectedCryptoCurrency];
    if (balanceForCurrency == null) {
      return _appStore.amountParsingProxy.getDisplayCryptoString(0, selectedCryptoCurrency);
    }
    return _appStore.amountParsingProxy.getDisplayCryptoStringFromBigInt(
        wallet.balance[selectedCryptoCurrency]!.fullAvailableBalance, selectedCryptoCurrency);
  }

  @action
  Future<void> updateSendingBalance() async {
    // force the sendingBalance to recompute since unspent coins aren't observable
    // or at least mobx can't detect the changes

    final currentType = coinTypeToSpendFrom;

    if (currentType == UnspentCoinType.any) {
      coinTypeToSpendFrom = UnspentCoinType.nonMweb;
    } else if (currentType == UnspentCoinType.nonMweb) {
      coinTypeToSpendFrom = UnspentCoinType.any;
    } else if (currentType == UnspentCoinType.mweb) {
      coinTypeToSpendFrom = UnspentCoinType.nonMweb;
    }

    // set it back to the original value:
    coinTypeToSpendFrom = currentType;
  }

  @computed
  Future<String> get sendingBalance async {
    // only for electrum, monero, wownero wallets atm:
    switch (wallet.type) {
      case WalletType.bitcoin:
        if (coinTypeToSpendFrom == UnspentCoinType.lightning) return balance;
        return _appStore.amountParsingProxy.getDisplayCryptoString(
            await unspentCoinsListViewModel.getSendingBalance(coinTypeToSpendFrom),
            walletTypeToCryptoCurrency(walletType));
      case WalletType.litecoin:
      case WalletType.bitcoinCash:
      case WalletType.dogecoin:
      case WalletType.monero:
      case WalletType.wownero:
        final sendingBalance =
            await unspentCoinsListViewModel.getSendingBalance(coinTypeToSpendFrom);
        return walletTypeToCryptoCurrency(walletType).formatAmount(BigInt.from(sendingBalance));
      default:
        return balance;
    }
  }

  @computed
  bool get isFiatDisabled => balanceViewModel.isFiatDisabled;

  @computed
  String get pendingTransactionFiatAmountFormatted =>
      isFiatDisabled ? '' : '$pendingTransactionFiatAmount ${fiat.title}';

  @computed
  String get pendingTransactionFeeFiatAmountFormatted =>
      isFiatDisabled ? '' : '$pendingTransactionFeeFiatAmount ${fiat.title}';

  @computed
  bool get isReadyForSend =>
      wallet.syncStatus is SyncedSyncStatus ||
      // If silent payments scanning, can still send payments
      (wallet.type == WalletType.bitcoin && wallet.syncStatus is SyncingSyncStatus);

  bool isSendToSilentPayments(Output output) =>
      wallet.type == WalletType.bitcoin &&
      (RegExp(AddressValidator.silentPaymentAddressPatternMainnet).hasMatch(output.address) ||
          RegExp(AddressValidator.silentPaymentAddressPatternMainnet)
              .hasMatch(output.extractedAddress) ||
          (output.parsedAddress.addresses.isNotEmpty &&
              RegExp(AddressValidator.silentPaymentAddressPatternMainnet)
                  .hasMatch(output.parsedAddress.addresses[0])));

  @computed
  List<Template> get templates => sendTemplateViewModel.templates
      .where((template) => _isEqualCurrency(template.cryptoCurrency))
      .toList();

  @computed
  bool get hasCoinControl =>
      [
        WalletType.bitcoin,
        WalletType.litecoin,
        WalletType.monero,
        WalletType.wownero,
        WalletType.bitcoinCash,
        WalletType.dogecoin
      ].contains(wallet.type) &&
      coinTypeToSpendFrom != UnspentCoinType.lightning;

  @computed
  bool get hasFees => feesViewModel.hasFees && coinTypeToSpendFrom != UnspentCoinType.lightning;

  @computed
  bool get isElectrumWallet => [
        WalletType.bitcoin,
        WalletType.litecoin,
        WalletType.bitcoinCash,
        WalletType.dogecoin
      ].contains(wallet.type);

  @observable
  CryptoCurrency selectedCryptoCurrency;

  @computed
  String get selectedCryptoCurrencySymbol =>
      amountParsingProxy.getCryptoSymbol(selectedCryptoCurrency);

  List<CryptoCurrency> currencies;

  WalletType get walletType => wallet.type;

  String? get walletCurrencyName => wallet.currency.fullName?.toLowerCase() ?? wallet.currency.name;

  @computed
  FiatCurrency get fiatCurrency => _settingsStore.fiatCurrency;

  set fiatCurrency(FiatCurrency value) {
      _settingsStore.fiatCurrency = value;
  }

  List<FiatCurrency> fiatCurrencies;

  final AppStore _appStore;
  SettingsStore get _settingsStore => _appStore.settingsStore;
  final SendTemplateViewModel sendTemplateViewModel;
  final BalanceViewModel balanceViewModel;
  final ContactListViewModel contactListViewModel;
  final HardwareWalletViewModel? hardwareWalletViewModel;
  final FeesViewModel feesViewModel;
  final FiatConversionStore _fiatConversationStore;
  final Box<TransactionDescription> transactionDescriptionBox;

  @computed
  AmountParsingProxy get amountParsingProxy => _appStore.amountParsingProxy;

  @computed
  bool get hasMultiRecipient =>
      sendTemplateViewModel.hasMultiRecipient && coinTypeToSpendFrom != UnspentCoinType.lightning;

  @computed
  String get languageCode => _appStore.settingsStore.languageCode;

  @observable
  bool hasMultipleTokens;

  @observable
  int? selectedChainId;

  @computed
  List<ContactRecord> get contactsToShow => contactListViewModel.contacts
      .where((element) => element.type == selectedCryptoCurrency)
      .toList();

  @computed
  List<WalletContact> get walletContactsToShow => contactListViewModel.walletContacts
      .where((element) => element.type == selectedCryptoCurrency)
      .toList();

  @action
  bool checkIfAddressIsAContact(String address) =>
      contactsToShow.where((element) => element.address == address).toList().isNotEmpty;

  @action
  bool checkIfWalletIsAnInternalWallet(String address) =>
      walletContactsToShow.where((element) => element.address == address).toList().isNotEmpty;

  @computed
  bool get shouldDisplayTOTP2FAForContact => _settingsStore.shouldRequireTOTP2FAForSendsToContact;

  @computed
  bool get shouldDisplayTOTP2FAForNonContact =>
      _settingsStore.shouldRequireTOTP2FAForSendsToNonContact;

  @computed
  bool get shouldDisplayTOTP2FAForSendsToInternalWallet =>
      _settingsStore.shouldRequireTOTP2FAForSendsToInternalWallets;

  //* Still open to further optimize these checks
  //* It works but can be made better
  @action
  bool checkThroughChecksToDisplayTOTP(String address) {
    final isContact = checkIfAddressIsAContact(address);
    final isInternalWallet = checkIfWalletIsAnInternalWallet(address);

    if (isContact) {
      return shouldDisplayTOTP2FAForContact;
    } else if (isInternalWallet) {
      return shouldDisplayTOTP2FAForSendsToInternalWallet;
    } else {
      return shouldDisplayTOTP2FAForNonContact;
    }
  }

  bool shouldDisplayTotp() {
    List<bool> conditionsList = [];

    for (var output in outputs) {
      final show = checkThroughChecksToDisplayTOTP(output.extractedAddress);
      conditionsList.add(show);
    }

    return conditionsList.contains(true);
  }

  final _ocpService = OpenCryptoPayService();

  @observable
  OpenCryptoPayRequest? ocpRequest;

  @action
  Future<void> dismissTransaction() async {
    state = InitialExecutionState();
    if (ocpRequest != null) {
      clearOutputs();
      _ocpService.cancelOpenCryptoPayRequest(ocpRequest!);
      ocpRequest = null;
    }
  }

  @action
  Future<PaymentRequest?> getOpenCryptoPayRequest(String uri) async {
    try {
      final originalOCPRequest = await _ocpService.getOpenCryptoPayInvoice(uri.toString());
      final paymentUri = await _ocpService.getOpenCryptoPayAddress(
        originalOCPRequest,
        selectedCryptoCurrency,
      );

      ocpRequest = originalOCPRequest;

      clearOutputs();
      return PaymentRequest.fromUri(paymentUri);
    } on OpenCryptoPayNotSupportedException catch (e) {
      printV(e.message);
      if (walletType == WalletType.bitcoin) {
        state = InitialExecutionState();
      } else {
        state = FailureState(translateErrorMessage(e, walletType, currency));
      }
    } catch (e) {
      printV(e);
      state = FailureState(translateErrorMessage(e, walletType, currency));
    }
    return null;
  }

  @action
  Future<PendingTransaction?> createOpenCryptoPayTransaction(String uri) async {
    state = IsExecutingState();

    try {
      final originalOCPRequest = await _ocpService.getOpenCryptoPayInvoice(uri.toString());
      final paymentUri = await _ocpService.getOpenCryptoPayAddress(
        originalOCPRequest,
        selectedCryptoCurrency,
      );

      ocpRequest = originalOCPRequest;

      final paymentRequest = PaymentRequest.fromUri(paymentUri);
      clearOutputs();

      outputs.first.address = paymentRequest.address;
      outputs.first.parsedAddress =
          ParsedAddress(addresses: [paymentRequest.address], name: ocpRequest!.receiverName);
      outputs.first.setCryptoAmount(paymentRequest.amount);
      outputs.first.note = ocpRequest!.receiverName;

      return createTransaction();
    } on OpenCryptoPayNotSupportedException catch (e) {
      printV(e.message);
      if (walletType == WalletType.bitcoin) {
        state = InitialExecutionState();
      } else {
        state = FailureState(translateErrorMessage(e, walletType, currency));
      }
    } catch (e) {
      printV(e);
      state = FailureState(translateErrorMessage(e, walletType, currency));
    }
    return null;
  }

  static bool isLightningInvoice(String txt) {
    return RegExp(AddressValidator.bolt11InvoiceMatcher, caseSensitive: false).hasMatch(txt);
  }

  static bool isNonZeroAmountLightningInvoice(String txt) {
    return RegExp(AddressValidator.bolt11InvoiceMatcher, caseSensitive: false).hasMatch(txt) &&
        !isBolt11ZeroInvoice(txt);
  }

  static bool isLnurlInvoice(String txt) {
    return RegExp(AddressValidator.lnurlMatcher, caseSensitive: false).hasMatch(txt);
  }

  Timer? _ledgerTxStateTimer;

  @action
  Future<PendingTransaction?> createTransaction({ExchangeProvider? provider, Trade? trade}) async {
    pendingTransaction = null;

    try {
      if (!(state is IsExecutingState)) state = IsExecutingState();

      if (wallet.isHardwareWallet) {
        state = IsAwaitingDeviceResponseState();
        if (walletType == WalletType.monero) {
          _ledgerTxStateTimer = Timer.periodic(Duration(seconds: 1), (timer) {
            if (monero!.getLastLedgerCommand() == "INS_CLSAG") {
              timer.cancel();
              state = IsDeviceSigningResponseState();
            }
          });
        }
      }

      // Regular flow


      final isSendAll = outputs.any((output) => output.sendAll);
      
      if (!isSendAll) {
        final estimateTxAmountDouble = outputs.fold<double>(0, (acc, output) =>
        acc + (double.tryParse(output.cryptoAmount) ?? 0));
        if (estimateTxAmountDouble <= 0) throw Exception(
            'Amount must be greater than 0');
      }

      pendingTransaction = await wallet.createTransaction(_credentials(provider));

      final txAmountDouble = double.tryParse(pendingTransaction?.amountFormatted ?? '0') ?? 0.0;
      final bool isTradeTx = trade != null && provider != null;

      if (isTradeTx) {
        final tradeAmountDouble = double.tryParse(trade.amount) ?? 0.0;
        if (tradeAmountDouble <= 0) throw Exception('Trade amount must be greater than 0');

        if (trade.isSendAll == true) {
          if (provider is NearIntentsExchangeProvider) {
            if (txAmountDouble != tradeAmountDouble) {
              throw Exception(
                  'Transaction amount $txAmountDouble does not match expected trade amount $tradeAmountDouble');
            }
          }
        }

      }


      if (wallet.type == WalletType.bitcoin) {
        final updatedOutputs = bitcoin!.updateOutputs(pendingTransaction!, outputs);

        if (outputs.length == updatedOutputs.length) {
          outputs.replaceRange(0, outputs.length, updatedOutputs);
        }
      }

      state = ExecutedSuccessfullyState();
      return pendingTransaction;
    } catch (e) {
      _ledgerTxStateTimer?.cancel();
      // if (e is LedgerException) {
      //   final errorCode = e.errorCode.toRadixString(16);
      //   final fallbackMsg =
      //       e.message.isNotEmpty ? e.message : "Unexpected Ledger Error Code: $errorCode";
      //   final errorMsg = ledgerViewModel!.interpretErrorCode(errorCode) ?? fallbackMsg;
      //
      //   state = FailureState(errorMsg);
      // } else {
      state = FailureState(translateErrorMessage(e, wallet.type, wallet.currency));
      // }
    }
    return null;
  }

  @action
  Future<void> replaceByFee(TransactionInfo tx, String newFee) async {
    state = IsExecutingState();

    try {
      final isSufficient = await bitcoin!.isChangeSufficientForFee(wallet, tx.id, newFee);

      if (!isSufficient) {
        state = AwaitingConfirmationState(
            title: S.current.confirm_fee_deduction,
            message: S.current.confirm_fee_deduction_content,
            onConfirm: () async => await _executeReplaceByFee(tx, newFee),
            onCancel: () => state = FailureState('Insufficient change for fee'));
      } else {
        await _executeReplaceByFee(tx, newFee);
      }
    } catch (e) {
      state = FailureState(e.toString());
    }
  }

  Future<void> _executeReplaceByFee(TransactionInfo tx, String newFee) async {
    clearOutputs();
    final output = outputs.first;
    output.address = tx.outputAddresses?.first ?? '';

    try {
      pendingTransaction = await bitcoin!.replaceByFee(wallet, tx.id, newFee);
      state = ExecutedSuccessfullyState();
    } catch (e) {
      state = FailureState(e.toString());
    }
  }

  Future<void> _handleOcpRequest() async {
    if (OpenCryptoPayService.requiresClientCommit(selectedCryptoCurrency)) {
      await pendingTransaction!.commit();
    }

    await _ocpService.commitOpenCryptoPayRequest(
      pendingTransaction!.hex,
      txId: pendingTransaction!.id,
      request: ocpRequest!,
      asset: selectedCryptoCurrency,
    );
  }

  Future<void> _commitUR(BuildContext context) async {
    final urstr = await pendingTransaction!.commitUR();
    final result = await Navigator.of(context).pushNamed(Routes.urqrAnimatedPage, arguments: urstr);
    if (result == null) {
      throw "Canceled by user";
    }
  }

  @action
  Future<void> commitTransaction(BuildContext context) async {
    if (pendingTransaction == null) {
      throw Exception("Pending transaction doesn't exist. It should not be happened.");
    }

    try {
      state = TransactionCommitting();

      if (ocpRequest != null) {
        await _handleOcpRequest();
      } else if (pendingTransaction!.shouldCommitUR()) {
        await _commitUR(context);
      } else {
        await pendingTransaction!.commit();
      }

      state = TransactionCommitted();

      // Immediate transaction update for EVM chains and Nano
      if (isEVMWallet || [WalletType.bitcoin, WalletType.nano].contains(walletType)) {
        Future.delayed(Duration(seconds: 4), () async {
          try {
            await Future.wait([
              wallet.updateTransactionsHistory(),
              wallet.updateBalance() as Future<void>,
            ]);
          } catch (e) {
            printV('Failed to update transactions after send: $e');
          }
        });
      }

      if (pendingTransaction!.id.isNotEmpty) {
        _addTransactionDescription();
      }
      final sharedPreferences = await SharedPreferences.getInstance();
      await sharedPreferences.setString(PreferencesKey.backgroundSyncLastTrigger(wallet.name),
          DateTime.now().add(Duration(minutes: 1)).toIso8601String());
    } catch (e) {
      state = FailureState(translateErrorMessage(e, wallet.type, wallet.currency));
    }
  }

  @action
  Future<void> updateWalletBalance() async => await wallet.updateBalance();

  Future<void> _addTransactionDescription() async {
    String address = outputs.fold('', (acc, value) {
      return value.isParsedAddress
          ? '$acc${value.address}\n${value.extractedAddress}\n\n'
          : '$acc${value.address}\n\n';
    });

    address = address.trim();

    String note = outputs.fold('', (acc, value) => '$acc${value.note}\n');

    note = note.trim();

    TransactionInfo? tx;
    if (walletType == WalletType.monero) {
      await Future.delayed(Duration(milliseconds: 450));
      await wallet.fetchTransactions();
      final txhistory = monero!.getTransactionHistory(wallet);
      tx = txhistory.transactions.values.last;
    }
    final descriptionKey = '${pendingTransaction!.id}_${wallet.walletAddresses.primaryAddress}';
    _settingsStore.shouldSaveRecipientAddress
        ? await transactionDescriptionBox.add(TransactionDescription(
            id: descriptionKey,
            recipientAddress: address,
            transactionNote: note,
            transactionKey: tx?.additionalInfo["key"] as String?,
          ))
        : await transactionDescriptionBox.add(TransactionDescription(
            id: descriptionKey,
            transactionNote: note,
            transactionKey: tx?.additionalInfo["key"] as String?,
          ));
  }

  Object _credentials([ExchangeProvider? provider]) {
    final priority = _settingsStore.getPriority(wallet.type, chainId: wallet.chainId);

    if (priority == null &&
        ![
          WalletType.nano,
          WalletType.banano,
          WalletType.arbitrum,
        ].contains(wallet.type)) {
      throw Exception('Priority is null for wallet type: ${wallet.type}');
    }

    switch (wallet.type) {
      case WalletType.bitcoin:
      case WalletType.bitcoinCash:
      case WalletType.dogecoin:
        return bitcoin!.createBitcoinTransactionCredentials(
          outputs,
          priority: priority!,
          feeRate: feesViewModel.customBitcoinFeeRate,
          coinTypeToSpendFrom: coinTypeToSpendFrom,
          payjoinUri: _settingsStore.usePayjoin ? payjoinUri : null,
        );
      case WalletType.litecoin:
        return bitcoin!.createBitcoinTransactionCredentials(
          outputs,
          priority: priority!,
          feeRate: feesViewModel.customBitcoinFeeRate,
          // if it's an exchange flow then disable sending from mweb coins
          coinTypeToSpendFrom: provider != null ? UnspentCoinType.nonMweb : coinTypeToSpendFrom,
        );

      case WalletType.monero:
        return monero!
            .createMoneroTransactionCreationCredentials(outputs: outputs, priority: priority!);

      case WalletType.wownero:
        return wownero!
            .createWowneroTransactionCreationCredentials(outputs: outputs, priority: priority!);

      case WalletType.ethereum:
      case WalletType.polygon:
      case WalletType.base:
      case WalletType.arbitrum:
      case WalletType.bsc:
        return evm!.createEVMTransactionCredentials(
          outputs,
          priority: priority,
          currency: selectedCryptoCurrency,
          useBlinkProtection: canSupportBlinkProtection(selectedChainId)
              ? _settingsStore.useBlinkProtection
              : false,
        );
      case WalletType.nano:
        return nano!.createNanoTransactionCredentials(outputs);
      default:
        throw Exception('Unexpected wallet type: ${wallet.type} for send');
    }
  }

  bool _isEqualCurrency(String currency) =>
      wallet.balance.keys.any((e) => currency.toLowerCase() == e.title.toLowerCase());

  void onClose() => _settingsStore.fiatCurrency = fiatFromSettings;

  @action
  FiatCurrency setFiatCurrency(FiatCurrency fiat) {
    _settingsStore.fiatCurrency = fiat;
    return fiat;
  }

  @action
  void setSelectedCryptoCurrency(String cryptoCurrency) {
    try {
      selectedCryptoCurrency = wallet.balance.keys
          .firstWhere((e) => cryptoCurrency.toLowerCase() == e.title.toLowerCase());
    } catch (e) {
      selectedCryptoCurrency = wallet.currency;
    }
  }

  @computed
  bool get hasMemos => false;

  final Map<WalletType, int> _maxMemoLengths = {};

  @computed
  int get maxMemoLength => _maxMemoLengths[wallet.type] ?? 9999999;


  ContactRecord? newContactAddress() {
    final Set<String> contactAddresses =
        Set.from(contactListViewModel.contacts.map((contact) => contact.address))
          ..addAll(contactListViewModel.walletContacts.map((contact) => contact.address));

    for (final output in outputs) {
      final address =
          output.isParsedAddress ? output.parsedAddress.addresses.first : output.address;

      if (address.isNotEmpty &&
          !contactAddresses.contains(address) &&
          selectedCryptoCurrency.raw != -1) {
        return ContactRecord(
          contactListViewModel.contactSource,
          Contact(
            name: '',
            address: address,
            type: selectedCryptoCurrency,
          ),
        );
      }
    }
    return null;
  }

  String translateErrorMessage(
    Object error,
    WalletType walletType,
    CryptoCurrency currency,
  ) {
    String errorMessage = error.toString();

    if (isEVMWallet) {
      if (errorMessage.contains('gas required exceeds allowance')) {
        return S.current.gas_exceeds_allowance;
      }

      if (errorMessage.contains('insufficient funds')) {
        final feeCurrency = switch (walletType) {
          WalletType.bsc => "BNB",
          WalletType.polygon => "POL",
          _ => "ETH",
        };

        final parsedErrorMessageResult =
            EVMTransactionErrorFeesHandler.parseEthereumFeesErrorMessage(
          errorMessage,
          _fiatConversationStore.prices[currency] ?? 0.0,
        );

        // Handle generic insufficient funds error (no specific values available)
        if (parsedErrorMessageResult.error == 'generic_insufficient_funds') {
          return S.current.insufficient_funds_for_tx;
        }

        // Handle parsing errors (couldn't parse the error message)
        if (parsedErrorMessageResult.error != null) {
          return S.current.insufficient_funds_for_tx;
        }

        // Handle successfully parsed errors with specific values
        return '''${S.current.insufficient_funds_for_tx} \n\n'''
            '''${S.current.balance}: ${parsedErrorMessageResult.balanceEth} ${feeCurrency} (${parsedErrorMessageResult.balanceUsd} ${fiatFromSettings.name})\n\n'''
            '''${S.current.transaction_cost}: ${parsedErrorMessageResult.txCostEth} ${feeCurrency} (${parsedErrorMessageResult.txCostUsd} ${fiatFromSettings.name})\n\n'''
            '''${S.current.overshot}: ${parsedErrorMessageResult.overshotEth} ${feeCurrency} (${parsedErrorMessageResult.overshotUsd} ${fiatFromSettings.name})''';
      }

      if (errorMessage.contains('max fee per gas less than block base fee')) {
        return S.current.tx_retry_message;
      }

      return errorMessage;
    }

    if (error is TransactionWrongBalanceException) {
      if (error.amount != null)
        return S.current
            .tx_wrong_balance_with_amount_exception(currency.toString(), error.amount.toString());

      return S.current.tx_wrong_balance_exception(currency.toString());
    }
    if (error is TransactionNoInputsException) {
      return S.current.tx_not_enough_inputs_exception;
    }
    if (error is TransactionNoFeeException) {
      return S.current.tx_zero_fee_exception;
    }
    if (error is TransactionNoDustException) {
      return S.current.tx_no_dust_exception;
    }
    if (error is TransactionCommitFailedBIP68Final) {
      return S.current.trying_to_spend_locked_funds;
    }
    if (error is TransactionCommitFailed) {
      if (error.errorMessage != null && error.errorMessage!.contains("no peers replied")) {
        return S.current.tx_commit_failed_no_peers;
      }
      return "${S.current.tx_commit_failed}\nsupport@such.software${error.errorMessage != null ? "\n\n${error.errorMessage}" : ""}";
    }
    if (error is TransactionCommitFailedDustChange) {
      return S.current.tx_rejected_dust_change;
    }
    if (error is TransactionCommitFailedDustOutput) {
      return S.current.tx_rejected_dust_output;
    }
    if (error is TransactionCommitFailedDustOutputSendAll) {
      return S.current.tx_rejected_dust_output_send_all;
    }
    if (error is TransactionCommitFailedVoutNegative) {
      return S.current.tx_rejected_vout_negative;
    }
    if (error is TransactionCommitFailedBIP68Final) {
      return S.current.tx_rejected_bip68_final;
    }
    if (error is TransactionCommitFailedLessThanMin) {
      return S.current.fee_less_than_min;
    }
    if (error is TransactionNoDustOnChangeException) {
      return S.current.tx_commit_exception_no_dust_on_change(error.min, error.max);
    }
    if (error is TransactionInputNotSupported) {
      return S.current.tx_invalid_input;
    }

    if(wallet.type == WalletType.bitcoin) {
      final lnError = getLightningErrorMessage(error);
      if(lnError != null) return lnError;
    }

    return errorMessage;
  }

  String? getLightningErrorMessage(Object error) {
    // TODO add more patterns
    Map<String, String> errorPatterns = {
      "insufficient funds": S.current.insufficient_funds_for_tx
    };

    for(final pattern in errorPatterns.keys) {
      if(error.toString().contains(pattern)) return errorPatterns[pattern]!;
    }

    return null;
  }
  @computed
  bool get usePayjoin => _settingsStore.usePayjoin;

  @observable
  String? payjoinUri;

  @action
  Future<void> fetchTokenForContractAddress(String contractAddress) async {
    final token = await TokenUtilities.findTokenByAddress(
      walletType: wallet.type,
      address: contractAddress,
    );

    if (token != null) {
      selectedCryptoCurrency = token;
    }
  }

}
