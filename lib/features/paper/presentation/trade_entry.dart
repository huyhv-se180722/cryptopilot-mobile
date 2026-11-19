import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../market/domain/market.dart';
import '../application/trade_controller.dart';

/// "Trade (demo)" on a Spot pair (plan 9.9): the Trade tab on that pair.
/// Futures pairs get it with T-129. An icon, so the analysis bar keeps
/// room at 360 dp; no Buy or Sell wording outside Trade and Assets.
class TradeDemoButton extends ConsumerWidget {
  const TradeDemoButton({required this.pair, super.key});

  final MarketPair pair;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (pair.market != Market.spot) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    return IconButton.outlined(
      key: Key('trade-demo-${pair.symbol}'),
      tooltip: l.assetsTradeDemo,
      icon: const Icon(Icons.swap_horiz),
      onPressed: () {
        ref.read(tradePairProvider.notifier).select(pair.symbol);
        context.go('/trade');
      },
    );
  }
}
