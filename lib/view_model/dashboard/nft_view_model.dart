import "dart:async";
import 'dart:convert';

import "package:hash_wallet/entities/saved_nfts.dart";
import 'package:hash_wallet/entities/solana_nft_asset_model.dart';
import 'package:hash_wallet/generated/i18n.dart';
import 'package:hash_wallet/reactions/wallet_connect.dart';
import 'package:hash_wallet/src/screens/wallet_connect/services/bottom_sheet_service.dart';
import 'package:hash_wallet/src/screens/wallet_connect/widgets/bottom_sheet/bottom_sheet_message_display_widget.dart';
import 'package:hash_wallet/evm/evm.dart';
import 'package:hash_wallet/utils/debounce.dart';
import "package:cw_core/utils/print_verbose.dart";
import 'package:cw_core/wallet_type.dart';
import 'package:cw_core/utils/proxy_wrapper.dart';
import 'package:mobx/mobx.dart';
import 'package:hash_wallet/.secrets.g.dart' as secrets;

import 'package:hash_wallet/entities/wallet_nft_response.dart';
import 'package:hash_wallet/store/app_store.dart';

part 'nft_view_model.g.dart';

class NFTViewModel = NFTViewModelBase with _$NFTViewModel;

abstract class NFTViewModelBase with Store {
  NFTViewModelBase(this.appStore, this.bottomSheetService)
      : isLoading = false,
        isImportNFTLoading = false,
        nftAssetByWalletModels = ObservableList(),
        solanaNftAssetModels = ObservableList() {
    if (isEVMCompatibleChain(appStore.wallet!.type)) {
      reaction((_) {
        final wallet = appStore.wallet;
        if (wallet != null) return wallet.chainId;

        return null;
      }, (_) => _fetchDebounce.run(() => getNFTAssetByWallet()));
    }
  }

  final AppStore appStore;
  bool _nftErrorPopupShown = false;
  final BottomSheetService bottomSheetService;
  final Debounce _fetchDebounce = Debounce(const Duration(milliseconds: 500));

  Future<void> _lastFetch = Future.value();
  Completer<void>? _queuedFetch;

  final SavedNFTs _savedNFTs = SavedNFTs();
  int _currentRefreshId = 0;

  static const _requestTimeout = Duration(seconds: 20);

  Map<String, String> get _moralisHeaders => {
        "Accept": "application/json",
        "X-API-Key": secrets.moralisApiKey,
      };

  @observable
  bool isLoading;

  @observable
  bool isImportNFTLoading;

  @observable
  int unresolvedNFTCount = 0;

  ObservableList<NFTAssetModel> nftAssetByWalletModels;

  ObservableList<SolanaNFTAssetModel> solanaNftAssetModels;

  // Hash Bags: Solana is not supported.
  bool get isSolanaWallet => false;

  String? get currentWalletName => appStore.wallet?.name;

  @action
  void onWalletChanged() {
    nftAssetByWalletModels.clear();
    solanaNftAssetModels.clear();
    unresolvedNFTCount = 0;
    _nftErrorPopupShown = false;
    _fetchDebounce.run(getNFTAssetByWallet);
  }

  @action
  Future<void> getNFTAssetByWallet() {
    final queued = _queuedFetch;

    if (queued != null) {
      return queued.future;
    }

    final done = Completer<void>();
    _queuedFetch = done;

    final waitFor = _lastFetch;
    _lastFetch = done.future;

    unawaited(_fetchAfterPreviousRun(waitFor, done));

    return done.future;
  }

  Future<void> _fetchAfterPreviousRun(Future<void> waitFor, Completer<void> done) async {
    await waitFor;

    if (identical(_queuedFetch, done)) {
      _queuedFetch = null;
    }

    try {
      final wallet = appStore.wallet!;

      if (!isNFTACtivatedChain(wallet.type, chainId: wallet.chainId)) {
        return;
      }

      final walletAddress = wallet.walletInfo.address;
      final chainName = getChainNameBasedOnWalletType(wallet.type, chainId: wallet.chainId);
      isLoading = true;

      final refreshId = ++_currentRefreshId;

      await _getEvmNFTAssets(wallet.name, walletAddress, chainName, refreshId);

      _nftErrorPopupShown = false;
    } catch (e) {
      printV("Fetching wallet NFTs failed: ${e.toString()}");
      if (!_nftErrorPopupShown) {
        _nftErrorPopupShown = true;
        bottomSheetService.queueBottomSheet(
          isModalDismissible: true,
          widget: BottomSheetMessageDisplayWidget(
            message: S.current.moralis_nft_error,
          ),
        );
      }
    } finally {
      isLoading = false;
      done.complete();
    }
  }

  Future<void> _getEvmNFTAssets(
    String walletName,
    String walletAddress,
    String chainName,
    int refreshId,
  ) async {
    final saved = await _savedNFTs.evmNFTs(walletName, chainName);

    var result = const <NFTAssetModel>[];
    Object? indexerError;

    try {
      final response = await ProxyWrapper()
          .get(
            clearnetUri: Uri.https(
              "deep-index.moralis.io",
              "/api/v2.2/$walletAddress/nft",
              {
                "chain": chainName,
                "format": "decimal",
                "media_items": "false",
                "exclude_spam": "true",
                "normalizeMetadata": "true",
              },
            ),
            headers: _moralisHeaders,
          )
          .timeout(_requestTimeout);

      result = WalletNFTsResponseModel.fromJson(
            jsonDecode(response.body) as Map<String, dynamic>,
          ).result ??
          [];
    } catch (e) {
      indexerError = e;
    }

    if (appStore.wallet?.walletInfo.address != walletAddress || refreshId != _currentRefreshId) {
      return;
    }

    final listed = result.map(SavedNFTs.evmIdentifier).toSet();

    nftAssetByWalletModels.clear();
    nftAssetByWalletModels.addAll(result);
    nftAssetByWalletModels
        .addAll(saved.where((asset) => !listed.contains(SavedNFTs.evmIdentifier(asset))));

    if (indexerError != null) {
      throw indexerError;
    }
  }

  @action
  Future<void> onNFTSent(String walletName, String mint) async {
    await _savedNFTs.removeSolana(walletName, mint);

    if (appStore.wallet?.name == walletName) {
      solanaNftAssetModels.removeWhere((asset) => asset.mint == mint);
    }
  }

  Future<void> _importEvmNFT(
    String walletName,
    String tokenAddress,
    String? tokenId,
    String chainName,
  ) async {
    final response = await ProxyWrapper()
        .get(
          clearnetUri: Uri.https(
            "deep-index.moralis.io",
            "/api/v2.2/nft/$tokenAddress/$tokenId",
            {
              "chain": chainName,
              "format": "decimal",
              "media_items": "false",
              "normalizeMetadata": "true",
            },
          ),
          headers: _moralisHeaders,
        )
        .timeout(_requestTimeout);

    final asset = NFTAssetModel.fromJson(jsonDecode(response.body) as Map<String, dynamic>);

    nftAssetByWalletModels.add(asset);

    await _savedNFTs.addEvm(walletName, chainName, asset);
  }

  @action
  Future<void> importNFT(String tokenAddress, String? tokenId) async {
    final wallet = appStore.wallet!;
    int? chainId;
    if (isEVMCompatibleChain(wallet.type)) {
      chainId = evm!.getSelectedChainId(wallet);
    }
    final chainName = getChainNameBasedOnWalletType(wallet.type, chainId: chainId);
    try {
      isImportNFTLoading = true;

      await _importEvmNFT(wallet.name, tokenAddress, tokenId, chainName);
    } catch (e) {
      printV("Importing NFT $tokenAddress failed: ${e.toString()}");
      bottomSheetService.queueBottomSheet(
        isModalDismissible: true,
        widget: BottomSheetMessageDisplayWidget(
          message: S.current.nft_import_failed,
        ),
      );
    } finally {
      isImportNFTLoading = false;
    }
  }
}
