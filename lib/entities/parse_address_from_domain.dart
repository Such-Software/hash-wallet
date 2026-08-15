import 'package:hash_wallet/core/address_validator.dart';
import 'package:hash_wallet/entities/ens_record.dart';
import 'package:hash_wallet/entities/lnurlpay_record.dart';
import 'package:hash_wallet/entities/openalias_record.dart';
import 'package:hash_wallet/entities/parsed_address.dart';
import 'package:hash_wallet/entities/wellknown_record.dart';
import 'package:hash_wallet/store/settings_store.dart';
import 'package:cw_core/crypto_currency.dart';
import 'package:cw_core/utils/print_verbose.dart';
import 'package:cw_core/wallet_base.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:flutter/cupertino.dart';

import 'bip_353_record.dart';

/// Resolves human-readable names typed into the address field.
///
/// Privacy contract: every lookup here either queries DNS (OpenAlias,
/// BIP-353), the domain the user explicitly typed (.well-known, LNURL-pay),
/// or the wallet's own configured RPC node (ENS). Resolvers that shipped the
/// typed input to unrelated third-party services (Twitter, Mastodon, Nostr,
/// Yat, Unstoppable Domains, FIO, ThorChain names, zcash.me, Zano aliases)
/// were removed deliberately — do not reintroduce one without updating
/// PRIVACY.md and gating it behind an off-by-default setting.
class AddressResolver {
  AddressResolver({required this.wallet, required this.settingsStore})
      : walletType = wallet.type;

  final WalletType walletType;
  final WalletBase wallet;
  final SettingsStore settingsStore;

  static String? extractAddressByType(
      {required String raw,
      required CryptoCurrency type,
      bool requireSurroundingWhitespaces = true}) {
    var addressPattern = AddressValidator.getAddressFromStringPattern(type);

    if (addressPattern == null) {
      return null;
    }

    if (requireSurroundingWhitespaces)
      addressPattern = "$BEFORE_REGEX$addressPattern$AFTER_REGEX";

    final match = RegExp(addressPattern, multiLine: true).firstMatch(raw);
    return match?.group(0)?.replaceAllMapped(RegExp('[^0-9a-zA-Z]|bitcoincash:|nano_|ban_'),
        (Match match) {
      String group = match.group(0)!;
      if (group.startsWith('bitcoincash:') ||
          group.startsWith('nano_') ||
          group.startsWith('ban_')) {
        return group;
      }
      return '';
    });
  }

  bool isEmailFormat(String address) {
    final RegExp emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
      caseSensitive: false,
    );
    return emailRegex.hasMatch(address);
  }

  Future<ParsedAddress> resolve(BuildContext context, String text, CryptoCurrency currency) async {
    final ticker = currency.title;
    try {
      // user@domain identifiers: resolved against the domain the user typed.
      if (text.contains('.') && text.contains('@')) {
        if (settingsStore.lookupsWellKnown) {
          final record =
              await WellKnownRecord.fetchAddressAndName(formattedName: text, currency: currency);
          if (record != null) {
            return ParsedAddress.fetchWellKnownAddress(address: record.address, name: text);
          }
        }

        if (walletType == WalletType.bitcoin) {
          final record =
              await LNUrlPayRecord.fetchAddressAndName(formattedName: text, currency: currency);
          if (record != null) {
            return ParsedAddress.fetchLNUrlPayAddress(address: record.address, name: text);
          }
        }
      }

      final formattedName = OpenaliasRecord.formatDomainName(text);
      final domainParts = formattedName.split('.');
      final name = domainParts.last;

      if (domainParts.length <= 1 || domainParts.first.isEmpty || name.isEmpty) {
        return ParsedAddress(addresses: [text]);
      }

      final bip353AddressMap = await Bip353Record.fetchUriByCryptoCurrency(text, ticker);

      if (bip353AddressMap != null && bip353AddressMap.isNotEmpty) {
        final chosenAddress = await Bip353Record.pickBip353AddressChoice(context, text, bip353AddressMap);
        if (chosenAddress != null) {
          try {
            final dnsProof = await Bip353Record.fetchDnsProof(text);
            return ParsedAddress.fetchBip353AddressAddress(address: chosenAddress, name: text, dnsProof: dnsProof);
          } catch (e) {
            printV('Bip353Record.fetchBip353AddressAddress error: $e');
            return ParsedAddress.fetchBip353AddressAddress(address: chosenAddress, name: text);
          }
        }
      }

      if (text.endsWith(".eth")) {
        if (settingsStore.lookupsENS) {
          final address = await EnsRecord.fetchEnsAddress(text, wallet: wallet);
          if (address.isNotEmpty && address != "0x0000000000000000000000000000000000000000") {
            return ParsedAddress.fetchEnsAddress(name: text, address: address);
          }
        }
      }

      if (formattedName.contains(".")) {
        if (settingsStore.lookupsOpenAlias) {
          final txtRecord = await OpenaliasRecord.lookupOpenAliasRecord(formattedName);

          if (txtRecord != null) {
            final record = await OpenaliasRecord.fetchAddressAndName(
                formattedName: formattedName, ticker: ticker.toLowerCase(), txtRecord: txtRecord);
            return ParsedAddress.fetchOpenAliasAddress(record: record, name: text);
          }
        }
      }
    } catch (e) {
      printV(e.toString());
    }

    return ParsedAddress(addresses: [text]);
  }
}
