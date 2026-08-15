import 'package:hash_wallet/generated/i18n.dart';
import 'package:hash_wallet/new-ui/widgets/apps_widget.dart';
import 'package:hash_wallet/src/widgets/hash_image_widget.dart';
import 'package:hash_wallet/src/widgets/dashboard_card_widget.dart';
import 'package:hash_wallet/utils/feature_flag.dart';
import 'package:hash_wallet/view_model/dashboard/dashboard_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:hash_wallet/src/widgets/gradient_background.dart';

class CakeFeaturesPage extends StatelessWidget {
  CakeFeaturesPage({required this.dashboardViewModel});

  final DashboardViewModel dashboardViewModel;

  @override
  Widget build(BuildContext context) {
    return GradientBackground(
      scaffold: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: constraints.maxHeight),
                        child: IntrinsicHeight(
                          child: !FeatureFlag.hasNewUi ? _buildOldUi(context) : _buildNewUi(context),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    if (!FeatureFlag.hasNewUi) {
      return Padding(
        padding: const EdgeInsets.only(left: 24, top: 16, bottom: 16),
        child: Text(
          S.of(context).apps,
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      );
    }

    return Align(
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 24),
        child: Text(
          S.of(context).apps,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontSize: 18.0,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  // Hash Bags: gutted Cake Pay, Cupcake, NanoGPT, and dEuro Savings
  // entries — all third-party Cake-affiliate income. dEuro kept out for
  // consistency (also has affiliate revenue, not our relationship).
  // Re-populate this page when we have Hash Bags / Such Software apps
  // to feature here.
  Widget _buildOldUi(BuildContext context) => _emptyState(context);

  Widget _buildNewUi(BuildContext context) => _emptyState(context);

  Widget _emptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 64),
        child: Text(
          'No apps available yet.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ),
    );
  }

}