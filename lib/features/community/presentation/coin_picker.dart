import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../market/data/market_repository.dart';
import '../../market/domain/market.dart';
import '../../market/presentation/market_widgets.dart';

/// The coins of the listed pairs, one each, by symbol; watched, so the
/// pair lists stay while the screen is open.
List<MarketPair> listedCoins(WidgetRef ref) {
  final seen = <String, MarketPair>{};
  for (final market in Market.values) {
    for (final pair
        in ref.watch(marketRepositoryProvider(market).select((s) => s.pairs)) ??
            const <MarketPair>[]) {
      seen.putIfAbsent(pair.baseAsset, () => pair);
    }
  }
  return seen.values.toList()
    ..sort((a, b) => a.baseAsset.compareTo(b.baseAsset));
}

/// A coin from [coins]; '' for "All coins" when [allowAll], null when
/// dismissed. Rows are keyed `[keyPrefix]-<coin>`.
Future<String?> showCoinPicker(
  BuildContext context,
  List<MarketPair> coins, {
  required String keyPrefix,
  String? current,
  Set<String> chosen = const {},
  bool allowAll = false,
}) {
  final l = AppLocalizations.of(context);
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            if (allowAll)
              ListTile(
                key: Key('$keyPrefix-all'),
                title: Text(l.communityCoinAll),
                selected: current == null,
                onTap: () => Navigator.of(context).pop(''),
              ),
            for (final pair in coins)
              ListTile(
                key: Key('$keyPrefix-${pair.baseAsset}'),
                leading: CoinLogo(
                  symbol: pair.baseAsset,
                  url: pair.logoUrl,
                  size: 24,
                ),
                title: Text(pair.baseAsset),
                subtitle: Text(pair.baseAssetName),
                selected:
                    pair.baseAsset == current ||
                    chosen.contains(pair.baseAsset),
                onTap: () => Navigator.of(context).pop(pair.baseAsset),
              ),
          ],
        ),
      ),
    ),
  );
}
