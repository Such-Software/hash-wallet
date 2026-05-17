import 'package:cw_core/enumerable_item.dart';

class BuyProviderDescription extends EnumerableItem<int> with Serializable<int> {
  const BuyProviderDescription({required String title, required int raw, required this.image})
      : super(title: title, raw: raw);

  final String image;

  // raw: 0 was Wyre, removed (provider shut down 2023). Kept the constant
  // for legacy Hive deserialization; do not wire it back into UI/services.
  static const wyre = BuyProviderDescription(title: 'Wyre', raw: 0, image: '');
  static const moonPay = BuyProviderDescription(title: 'MoonPay', raw: 1, image: '');

  static BuyProviderDescription deserialize({required int raw}) {
    switch (raw) {
      case 0:
        return wyre;
      case 1:
        return moonPay;
      default:
        throw Exception('Incorrect token $raw  for BuyProviderDescription deserialize');
    }
  }
}
