import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_failure.dart';
import '../../../core/errors/message_text.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/cp_colors.dart';
import '../../market/application/market_board.dart';
import '../../market/domain/market.dart';
import '../application/watchlist_controller.dart';

Future<void> showAddPairSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) =>
          const FractionallySizedBox(heightFactor: 0.85, child: AddPairSheet()),
    );

/// "Add pair" (the web's SCR-12 dialog; Binance "Add to Favorites"): every
/// enabled pair once, Spot and Futures merged by pair id, searchable; a pair
/// already watched says Added. MSG45 / MSG27 / MSG41 stay in the sheet.
class AddPairSheet extends ConsumerStatefulWidget {
  const AddPairSheet({super.key});

  @override
  ConsumerState<AddPairSheet> createState() => _AddPairSheetState();
}

class _AddPairSheetState extends ConsumerState<AddPairSheet> {
  String _query = '';
  String? _pending;
  String? _error;

  Future<void> _add(MarketPair pair) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _pending = pair.pairId;
      _error = null;
    });
    try {
      final item = await ref
          .read(watchlistControllerProvider.notifier)
          .add(pair.pairId);
      messenger.showSnackBar(SnackBar(content: Text(l.msg25(item.symbol))));
    } on ApiFailure catch (failure) {
      if (mounted) setState(() => _error = failureText(l, failure));
    } finally {
      if (mounted) setState(() => _pending = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final spot =
        ref.watch(marketBoardProvider(Market.spot).select((s) => s.pairs)) ??
        const [];
    final futures =
        ref.watch(marketBoardProvider(Market.futures).select((s) => s.pairs)) ??
        const [];
    final watchlist = ref.watch(watchlistControllerProvider);
    final byId = <String, MarketPair>{};
    final markets = <String, Set<Market>>{};
    for (final pair in [...spot, ...futures]) {
      byId.putIfAbsent(pair.pairId, () => pair);
      markets.putIfAbsent(pair.pairId, () => {}).add(pair.market);
    }
    final rows = [
      for (final pair in byId.values)
        if (pair.matches(_query)) pair,
    ];
    final count = watchlist.items.length;
    final limit = watchlist.watchlist?.limit;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(l.watchAddPair, style: text.titleLarge),
                const Spacer(),
                Text(
                  limit == null
                      ? l.watchCountNoLimit(count)
                      : l.watchCount(count, limit),
                  style: text.bodySmall,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              key: const Key('add-pair-search'),
              autofocus: false,
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(Icons.search, size: 20),
                hintText: l.watchSearchPairs,
              ),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                _error!,
                style: TextStyle(color: context.cp.negative),
              ),
            ),
          Expanded(
            child: rows.isEmpty
                ? Center(child: Text(l.msg41))
                : ListView.builder(
                    itemCount: rows.length,
                    itemBuilder: (_, index) {
                      final pair = rows[index];
                      final watched = watchlist.watches(pair.pairId);
                      final on = markets[pair.pairId] ?? const {};
                      return ListTile(
                        key: Key('add-${pair.symbol}'),
                        title: Text('${pair.baseAsset}/${pair.quoteAsset}'),
                        subtitle: Text(
                          [
                            pair.baseAssetName,
                            if (on.contains(Market.spot)) l.marketSpot,
                            if (on.contains(Market.futures)) l.marketFutures,
                          ].join(' · '),
                        ),
                        trailing: watched
                            ? OutlinedButton(
                                onPressed: null,
                                child: Text(l.watchAdded),
                              )
                            : FilledButton.tonal(
                                onPressed: _pending == null
                                    ? () => _add(pair)
                                    : null,
                                child: _pending == pair.pairId
                                    ? const SizedBox.square(
                                        dimension: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(l.watchAdd),
                              ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
