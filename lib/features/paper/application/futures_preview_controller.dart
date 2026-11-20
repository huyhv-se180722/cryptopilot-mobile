import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_failure.dart';
import '../data/futures_api.dart';
import '../data/futures_repository.dart';
import '../domain/futures.dart';
import '../domain/paper.dart';
import 'futures_form_controller.dart';

/// What one side of the Futures form would meet (plan 9.2): its TR-26
/// warnings with the cost, and the Max a balance opens.
@immutable
class SidePreview {
  const SidePreview({this.warnings, this.max});

  /// Null until the form holds an order the server can judge.
  final OrderWarnings? warnings;

  /// Null until the price and the leverage are known.
  final MaxOpen? max;

  bool get blocked => warnings?.blocked ?? false;
}

@immutable
class FuturesPreview {
  const FuturesPreview({this.sides = const {}, this.loading = false});

  final Map<OrderSide, SidePreview> sides;

  /// A newer answer is on its way; the figures shown are the previous ones.
  final bool loading;

  SidePreview of(OrderSide side) => sides[side] ?? const SidePreview();

  /// The smaller Max of the two sides, so a share of it suits either one.
  MaxOpen? get sharedMax {
    final long = sides[OrderSide.buy]?.max;
    final short = sides[OrderSide.sell]?.max;
    if (long == null || short == null) return long ?? short;
    return Decimal.parse(long.maxQuantity) <= Decimal.parse(short.maxQuantity)
        ? long
        : short;
  }
}

final futuresPreviewProvider = NotifierProvider.autoDispose
    .family<FuturesPreviewController, FuturesPreview, String>(
      FuturesPreviewController.new,
    );

/// Asks again, [settle] after the inputs, the leverage, the margin mode or
/// the balance last changed, the warnings of Buy/Long and Sell/Short and
/// their Max (`/order/warnings`, `/calculator/maxOpen`). A failed ask
/// leaves that figure out: the order is still judged when tapped.
class FuturesPreviewController extends Notifier<FuturesPreview> {
  FuturesPreviewController(this.symbol);

  final String symbol;
  static const settle = Duration(milliseconds: 400);

  Timer? _timer;
  int _generation = 0;

  @override
  FuturesPreview build() {
    final form = futuresFormProvider(symbol);
    ref
      ..listen(
        form.select(
          (s) => (
            s.kind,
            s.price,
            s.size,
            s.sizeInUsdt,
            s.trigger,
            s.working,
            s.reduceOnly,
            s.tpSl,
            s.takeProfit,
            s.stopLoss,
            s.closing,
            s.timeInForce,
          ),
        ),
        (_, _) => _soon(),
      )
      ..listen(
        futuresSettingsProvider(symbol).select((s) => s.config),
        (_, _) => _soon(),
      )
      ..listen(
        futuresProvider.select((s) => s.account?.availableBalance),
        (_, _) => _soon(),
      )
      ..onDispose(() => _timer?.cancel());
    _soon();
    return const FuturesPreview();
  }

  void _soon() {
    _timer?.cancel();
    _timer = Timer(settle, () => unawaited(refresh()));
  }

  Future<void> refresh() async {
    final generation = ++_generation;
    final form = ref.read(futuresFormProvider(symbol).notifier);
    final config = ref.read(futuresSettingsProvider(symbol)).config;
    final available = ref.read(futuresProvider).account?.availableBalance;
    final api = ref.read(futuresApiProvider);
    final entry = form.entryPrice();
    state = FuturesPreview(sides: state.sides, loading: true);

    Future<SidePreview> preview(OrderSide side) async {
      final draft = form.draft(side);
      OrderWarnings? warnings;
      if (draft != null) {
        try {
          warnings = await api.warnings(draft);
        } on ApiFailure {
          warnings = null;
        }
      }
      final budget = warnings?.budget ?? available;
      MaxOpen? max;
      if (config != null &&
          entry != null &&
          budget != null &&
          (Decimal.tryParse(budget) ?? Decimal.zero) > Decimal.zero) {
        try {
          max = await api.maxOpen(
            MaxOpenRequest(
              symbol: symbol,
              long: side == OrderSide.buy,
              leverage: config.leverage,
              entryPrice: entry,
              walletBalance: budget,
            ),
          );
        } on ApiFailure {
          max = null;
        }
      }
      return SidePreview(warnings: warnings, max: max);
    }

    late final SidePreview buy;
    late final SidePreview sell;
    await Future.wait([
      preview(OrderSide.buy).then((v) => buy = v),
      preview(OrderSide.sell).then((v) => sell = v),
    ]);
    if (!ref.mounted || generation != _generation) return;
    state = FuturesPreview(sides: {OrderSide.buy: buy, OrderSide.sell: sell});
  }
}
