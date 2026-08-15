import 'package:hash_wallet/generated/i18n.dart';
import 'package:hash_wallet/src/screens/base_page.dart';
import 'package:hash_wallet/src/screens/settings/widgets/settings_switcher_cell.dart';
import 'package:hash_wallet/view_model/settings/connection_sync_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';

class DomainLookupsPage extends BasePage {
  DomainLookupsPage(this._connectionsSyncViewModel);

  @override
  String get title => S.current.domain_looks_up;

  final ConnectionSyncViewModel _connectionsSyncViewModel;

  @override
  Widget body(BuildContext context) {
    return SingleChildScrollView(
      child: Observer(builder: (_) {
        return Container(
          padding: EdgeInsets.only(top: 10),
          child: Column(
            children: [
              SettingsSwitcherCell(
                  title: 'OpenAlias',
                  value: _connectionsSyncViewModel.looksUpOpenAlias,
                  onValueChange: (_, bool value) => _connectionsSyncViewModel.setLookupsOpenAlias(value)),
              SettingsSwitcherCell(
                  title: 'Ethereum Name Service',
                  value: _connectionsSyncViewModel.looksUpENS,
                  onValueChange: (_, bool value) => _connectionsSyncViewModel.setLookupsENS(value)),
              SettingsSwitcherCell(
                  title: '.well-known',
                  value: _connectionsSyncViewModel.looksUpWellKnown,
                  onValueChange: (_, bool value) => _connectionsSyncViewModel.setLookupsWellKnown(value)),
            ],
          ),
        );
      }),
    );
  }
}
