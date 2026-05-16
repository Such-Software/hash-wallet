import 'package:cw_core/utils/proxy_wrapper.dart';
import 'package:cw_core/crypto_currency.dart';
import 'package:hash_wallet/entities/fiat_currency.dart';
import 'dart:convert';

// Hash Wallet price endpoint. Backed by the Cloudflare Worker in
// github.com/Such-Software/hash-wallet-prices — Kraken for majors, NonKYC for
// WOW, KV-cached every 60s.
//
// USD-only. The wallet still lets the user pick other fiats from the UI, but
// non-USD requests will return price=0 until forex conversion is added on the
// server side.
//
// TODO: add a .onion mirror once we deploy a Tor hidden service and update
// _fiatApiOnionAuthority — Tor users currently fall back to clearnet.
const _fiatApiClearNetAuthority = 'prices.neroswap.com';
const _fiatApiOnionAuthority = '';
const _fiatApiPath = '/v2/rates';

Future<double> _fetchPrice(String crypto, String fiat, bool torOnly) async {

  final Map<String, String> queryParams = {
    'base': crypto.split(".").first,
    'quote': fiat,
  };

  num price = 0.0;

  try {
    final clearnetUri = Uri.https(_fiatApiClearNetAuthority, _fiatApiPath, queryParams);
    final onionUri = _fiatApiOnionAuthority.isEmpty
        ? clearnetUri
        : Uri.http(_fiatApiOnionAuthority, _fiatApiPath, queryParams);

    final response = await ProxyWrapper().get(
      onionUri: onionUri,
      clearnetUri: torOnly ? onionUri : clearnetUri,
    );

    if (response.statusCode != 200) {
      return 0.0;
    }

    final responseJSON = json.decode(response.body) as Map<String, dynamic>;
    final results = responseJSON['results'] as Map<String, dynamic>;

    if (results.isNotEmpty) {
      price = results.values.first as num;
    }

    return price.toDouble();
  } catch (e) {
    return price.toDouble();
  }
}

/// Override specific [CryptoCurrency] to fix its price to the price of another
/// e.g. nDEPS should have the same price as DEPS, but only DEPS is tracked
CryptoCurrency _overrideCryptoCurrency(CryptoCurrency crypto) {
  if (crypto.title == CryptoCurrency.ndeps.title)
      return CryptoCurrency.deps;
    return crypto;
}

class FiatConversionService {
  static Future<double> fetchPrice({
    required CryptoCurrency crypto,
    required FiatCurrency fiat,
    required bool torOnly,
  }) async =>
      await _fetchPrice(_overrideCryptoCurrency(crypto).toString(), fiat.toString(), torOnly);
}
