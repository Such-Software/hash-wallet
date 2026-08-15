import 'package:hash_wallet/buy/buy_provider.dart';
import 'package:hash_wallet/buy/payment_method.dart';
import 'package:hash_wallet/core/selectable_option.dart';
import 'package:hash_wallet/entities/calculate_fiat_amount.dart';
import 'package:hash_wallet/entities/fiat_currency.dart';
import 'package:hash_wallet/entities/provider_types.dart';
import 'package:hash_wallet/exchange/limits.dart';
import 'package:cw_core/crypto_currency.dart';

enum ProviderRecommendation { bestRate, lowKyc, successRate }

extension RecommendationTitle on ProviderRecommendation {
  String get title {
    switch (this) {
      case ProviderRecommendation.bestRate:
        return 'BEST RATE';
      case ProviderRecommendation.lowKyc:
        return 'LOW KYC';
      case ProviderRecommendation.successRate:
        return 'HIGHEST SUCCESS RATE';
    }
  }
}

class Quote extends SelectableOption {
  Quote({
    required this.rate,
    required this.feeAmount,
    required this.networkFee,
    required this.transactionFee,
    required this.payout,
    required this.provider,
    required this.paymentType,
    required this.recommendations,
    this.isBuyAction = true,
    this.quoteId,
    this.rampId,
    this.rampName,
    this.rampIconPath,
    this.limits,
    this.customPaymentMethodType,
  }) : super(title: provider.isAggregator ? rampName ?? '' : provider.title);

  final double rate;
  final double feeAmount;
  final double networkFee;
  final double transactionFee;
  final double payout;
  final PaymentType paymentType;
  final BuyProvider provider;
  final String? quoteId;
  final List<ProviderRecommendation> recommendations;
  String? rampId;
  String? rampName;
  String? rampIconPath;
  bool _isSelected = false;
  bool _isBestRate = false;
  bool isBuyAction;
  Limits? limits;
  String? customPaymentMethodType;

  late FiatCurrency _fiatCurrency;
  late CryptoCurrency _cryptoCurrency;

  bool get isSelected => _isSelected;

  bool get isBestRate => _isBestRate;

  FiatCurrency get fiatCurrency => _fiatCurrency;

  CryptoCurrency get cryptoCurrency => _cryptoCurrency;

  @override
  bool get isOptionSelected => this._isSelected;

  @override
  String get lightIconPath =>
      provider.isAggregator ? rampIconPath ?? provider.lightIcon : provider.lightIcon;

  @override
  String get darkIconPath =>
      provider.isAggregator ? rampIconPath ?? provider.darkIcon : provider.darkIcon;

  @override
  List<String> get badges => recommendations.map((e) => e.title).toList();

  @override
  String get topLeftSubTitle => this.rate > 0
      ? '1 ${cryptoCurrency.toString()} = ${formatWithCommas(rate.toStringAsFixed(2))} ${fiatCurrency.toString()}'
      : '';

  @override
  String get bottomLeftSubTitle {
    if (limits != null) {
      final min = limits!.min;
      final max = limits!.max;
      return 'min: ${formatWithCommas(min?.toString())} ${fiatCurrency.toString()} | max: ${max == double.infinity ? '' : '${formatWithCommas(max?.toString())} ${fiatCurrency.toString()}'}';
    }
    return '';
  }

  @override
  String? get topRightSubTitle => '';

  @override
  String get topRightSubTitleLightIconPath => provider.isAggregator ? provider.lightIcon : '';

  @override
  String get topRightSubTitleDarkIconPath => provider.isAggregator ? provider.darkIcon : '';

  String get quoteTitle => '${provider.title} - ${paymentType.name}';

  String get formatedFee => '$feeAmount ${isBuyAction ? fiatCurrency : cryptoCurrency}';

  set setIsSelected(bool isSelected) => _isSelected = isSelected;

  set setIsBestRate(bool isBestRate) => _isBestRate = isBestRate;

  set setFiatCurrency(FiatCurrency fiatCurrency) => _fiatCurrency = fiatCurrency;

  set setCryptoCurrency(CryptoCurrency cryptoCurrency) => _cryptoCurrency = cryptoCurrency;

  set setLimits(Limits limits) => this.limits = limits;

  factory Quote.fromMoonPayJson(
      Map<String, dynamic> json, bool isBuyAction, PaymentType paymentType) {
    final rate = isBuyAction
        ? json['quoteCurrencyPrice'] as double? ?? 0.0
        : json['baseCurrencyPrice'] as double? ?? 0.0;
    final fee = _toDouble(json['feeAmount']) ?? 0.0;
    final networkFee = _toDouble(json['networkFeeAmount']) ?? 0.0;
    final transactionFee = _toDouble(json['extraFeeAmount']) ?? 0.0;
    final feeAmount = double.parse((fee + networkFee + transactionFee).toStringAsFixed(2));

    final baseCurrency = json['baseCurrency'] as Map<String, dynamic>?;

    double minLimit = 0.0;
    double maxLimit = double.infinity;

    if (baseCurrency != null) {
      minLimit = _toDouble(baseCurrency['minAmount']) ?? minLimit;
      maxLimit = _toDouble(baseCurrency['maxAmount']) ?? maxLimit;
    }

    return Quote(
      rate: rate,
      feeAmount: feeAmount,
      networkFee: networkFee,
      transactionFee: transactionFee,
      payout: _toDouble(json['quoteCurrencyAmount']) ?? 0.0,
      paymentType: paymentType,
      recommendations: [],
      quoteId: json['signature'] as String? ?? '',
      provider: ProvidersHelper.getProviderByType(ProviderType.moonpay),
      isBuyAction: isBuyAction,
      limits: Limits(min: minLimit, max: maxLimit),
    );
  }

  static double? _toDouble(dynamic value) {
    if (value is int) {
      return value.toDouble();
    } else if (value is double) {
      return value;
    } else if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }

  @override
  String toString() =>
      'Quote: rate: $rate, feeAmount: $feeAmount, networkFee: $networkFee, transactionFee: $transactionFee, payout: $payout, paymentType: $paymentType, provider: $provider, quoteId: $quoteId, recommendations: $recommendations, isBuyAction: $isBuyAction, rampId: $rampId, rampName: $rampName, rampIconPath: $rampIconPath, [limits: min: ${limits?.min}, max: ${limits?.max}]';
}
