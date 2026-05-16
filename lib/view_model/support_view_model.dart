import 'package:hash_wallet/.secrets.g.dart' as secrets;
import 'package:hash_wallet/generated/i18n.dart';
import 'package:hash_wallet/store/app_store.dart';
import 'package:hash_wallet/view_model/settings/link_list_item.dart';
import 'package:hash_wallet/view_model/settings/settings_list_item.dart';
import 'package:hash_wallet/wallet_type_utils.dart';
import 'package:mobx/mobx.dart';

part 'support_view_model.g.dart';

class SupportViewModel = SupportViewModelBase with _$SupportViewModel;

abstract class SupportViewModelBase with Store {
  final AppStore _appStore;

  SupportViewModelBase(this._appStore)
      : items = [
          // Hash Wallet: Cake's own support channels (email, website, forum,
          // Discord, Telegram, Telegram bot) gutted — those are Cake Labs
          // properties, not ours. Replaced with the only channel we have right
          // now: GitHub Issues. The third-party provider support links below
          // are kept because they're genuinely useful when a user has trouble
          // with a swap/buy via that provider.
          LinkListItem(
              title: 'GitHub Issues',
              icon: 'assets/images/github.png',
              hasIconColor: true,
              linkTitle: 'github.com/Such-Software/hash-wallet/issues',
              link: 'https://github.com/Such-Software/hash-wallet/issues'),
          LinkListItem(
              title: 'GitHub Releases',
              icon: 'assets/images/github.png',
              hasIconColor: true,
              linkTitle: S.current.apk_update,
              link: 'https://github.com/Such-Software/hash-wallet/releases'),
          LinkListItem(
              title: 'ChangeNow',
              icon: 'assets/images/change_now.png',
              linkTitle: 'support@changenow.io',
              link: 'mailto:support@changenow.io'),
          LinkListItem(
              title: 'SideShift',
              icon: 'assets/images/sideshift.png',
              linkTitle: 'help.sideshift.ai',
              link: 'https://help.sideshift.ai/en/'),
          LinkListItem(
              title: 'SimpleSwap',
              icon: 'assets/images/simpleSwap.png',
              linkTitle: 'support@simpleswap.io',
              link: 'mailto:support@simpleswap.io'),
          LinkListItem(
              title: 'Exolix',
              icon: 'assets/images/exolix.png',
              linkTitle: 'support@exolix.com',
              link: 'mailto:support@exolix.com'),
          LinkListItem(
              title: 'SwapTrade',
              icon: 'assets/images/swap_trade.png',
              linkTitle: 'help.swaptrade.io',
              link: 'mailto:support@exolix.com'),
          LinkListItem(
              title: 'Trocador',
              icon: 'assets/images/trocador.png',
              linkTitle: 'mail@trocador.app',
              link: 'mailto:mail@trocador.app'),
        ];

  final docsUrl = 'https://github.com/Such-Software/hash-wallet';

  String fetchUrl({String locale = "en", String authToken = ""}) {
    var supportUrl =
        "https://app.chatwoot.com/widget?website_token=${secrets.chatwootWebsiteToken}&locale=${locale}";

    if (authToken.isNotEmpty) supportUrl += "&cw_conversation=$authToken";

    return supportUrl;
  }

  String get appVersion =>
      "${isMoneroOnly ? "Monero.com" : "Hash Wallet"} - ${_appStore.settingsStore.appVersion}";

  String get fiatApiMode => _appStore.settingsStore.fiatApiMode.title;

  String get walletType => _appStore.wallet?.type.name ?? 'Unknown';

  String get walletSyncState => _appStore.wallet?.syncStatus.toString() ?? 'Unknown';

  String get builtInTorState => _appStore.settingsStore.currentBuiltinTor ? 'Enabled' : 'Disabled';

  List<SettingsListItem> items;
}
