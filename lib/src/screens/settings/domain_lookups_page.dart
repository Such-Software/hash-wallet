import 'package:hash_wallet/core/address_resolver/address_sources.dart';
import 'package:hash_wallet/generated/i18n.dart';
import 'package:hash_wallet/src/screens/base_page.dart';
import 'package:hash_wallet/src/screens/settings/widgets/settings_switcher_cell.dart';
import 'package:hash_wallet/src/widgets/hash_image_widget.dart';
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
            // Hash Bags: only domain-anchored resolvers get a toggle (see PRIVACY.md).
            children: _connectionsSyncViewModel.domainLookupSources
                .where((source) => const [
                      AddressSource.openAlias,
                      AddressSource.ens,
                      AddressSource.wellKnown,
                    ].contains(source))
                .map(
                  (source) => SettingsSwitcherCell(
                    title: source.label,
                    leading: source.iconPath.isNotEmpty
                        ? HashImageWidget(
                            imageUrl: source.iconPath,
                            width: 24,
                            height: 24,
                          )
                        : SizedBox(width: 24, height: 24),
                    value: _connectionsSyncViewModel.lookupValue(source),
                    onValueChange: (_, bool value) =>
                        _connectionsSyncViewModel.setLookupValue(source, value),
                  ),
                )
                .toList(),
          ),
        );
      }),
    );
  }
}
