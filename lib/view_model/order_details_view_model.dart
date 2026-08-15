import 'dart:async';

import 'package:hash_wallet/buy/buy_provider_description.dart';
import 'package:hash_wallet/core/utilities.dart';
import 'package:hash_wallet/generated/i18n.dart';
import 'package:hash_wallet/order/order.dart';
import 'package:hash_wallet/order/order_provider.dart';
import 'package:hash_wallet/order/order_source_description.dart';
import 'package:hash_wallet/src/screens/trade_details/track_trade_list_item.dart';
import 'package:hash_wallet/src/screens/trade_details/trade_details_status_item.dart';
import 'package:hash_wallet/src/screens/transaction_details/standart_list_item.dart';
import 'package:cw_core/utils/print_verbose.dart';
import 'package:cw_core/wallet_base.dart';
import 'package:hive/hive.dart';
import 'package:mobx/mobx.dart';
import 'package:url_launcher/url_launcher.dart';

part 'order_details_view_model.g.dart';

class OrderDetailsViewModel = OrderDetailsViewModelBase with _$OrderDetailsViewModel;

abstract class OrderDetailsViewModelBase with Store {
  OrderDetailsViewModelBase({
    required WalletBase wallet,
    required Order orderForDetails,
    required this.orders,
  })  : items = ObservableList<StandartListItem>(),
        order = orderForDetails {
    switch (order.source) {
      case OrderSourceDescription.buy:
        if (order.buyProvider == BuyProviderDescription.moonPay) {
          //_provider = MoonPayOrderProviderAdapter(appStore: null /* provide if needed */, wallet: wallet);
        }
        break;

      case OrderSourceDescription.order:
        // Cake Pay orders: the Cake Pay integration was removed, so stored
        // orders are shown from persisted data only (_provider stays null).
        break;
    }

    _updateItems();
    _updateOrder();
    timer = Timer.periodic(const Duration(seconds: 20), (_) async => _updateOrder());
  }

  @observable
  Order order;

  @observable
  ObservableList<StandartListItem> items;

  final Box<Order> orders;
  OrderProvider? _provider;

  Timer? timer;

  @action
  Future<void> _updateOrder() async {
    try {
      if (_provider == null) return;

      final updatedOrderObj = await _provider!.findOrderById(order.id);
      final updatedOrder = updatedOrderObj.$1;

      final existing = orders.values.firstWhereOrNull((e) => e.id == updatedOrder.id);
      if (existing != null) {
        existing.stateRaw = updatedOrder.stateRaw;
        await existing.save();

        order = existing;
      } else {
        await orders.add(updatedOrder);
        order = updatedOrder;
      }

      _updateItems();
    } catch (e) {
      printV(e.toString());
    }
  }

  void _updateItems() {
    items.clear();

    items.add(
        DetailsListStatusItem(title: S.current.trade_details_state, value: order.state.toString()));

    items.add(StandartListItem(title: 'Order provider', value: _provider?.title ?? ''));

    final trackUrl = _provider?.trackUrl ?? '';
    if (trackUrl.isNotEmpty) {
      final buildURL = trackUrl + '${order.transferId}';
      items.add(TrackTradeListItem(
          title: S.current.track,
          value: buildURL,
          onTap: () async {
            try {
              final uri = Uri.parse(buildURL);
              if (await canLaunchUrl(uri))
                await launchUrl(uri, mode: LaunchMode.externalApplication);
            } catch (e) {}
          }));
    }
  }
}
