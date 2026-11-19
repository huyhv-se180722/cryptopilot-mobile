import 'dart:async';

import 'package:cryptopilot_mobile/core/errors/api_failure.dart';
import 'package:cryptopilot_mobile/core/errors/api_problem.dart';
import 'package:cryptopilot_mobile/features/paper/data/paper_api.dart';
import 'package:cryptopilot_mobile/features/paper/domain/paper.dart';

PaperOrder paperOrderOf(
  String id, {
  String pairId = 'pair-BTC',
  String symbol = 'BTCUSDT',
  OrderSide side = OrderSide.buy,
  SpotOrderType type = SpotOrderType.limit,
  OrderStatus status = OrderStatus.newOrder,
  String price = '70000.00',
  String quantity = '0.01000',
  String? listId,
  DateTime? placedAt,
}) => PaperOrder(
  orderId: id,
  pairId: pairId,
  symbol: symbol,
  side: side,
  type: type,
  price: price,
  quantity: quantity,
  executedQuantity: '0',
  cumQuote: '0',
  status: status,
  placedAt: placedAt ?? DateTime.utc(2026, 11, 19, 2),
  listId: listId,
);

Wallet walletOf(
  Map<String, (String free, String locked)> coins, {
  PaperWallet wallet = PaperWallet.spot,
}) => Wallet(
  wallet: wallet,
  balances: [
    for (final MapEntry(key: asset, value: (free, locked)) in coins.entries)
      Balance(
        asset: asset,
        free: free,
        locked: locked,
        total: free,
        usdtValue: asset == 'USDT' ? free : null,
      ),
  ],
  estimatedUsdt: '10000',
  complete: true,
);

/// The paper exchange in memory, shaped as backend develop 5c2398cb answers.
class FakePaperApi implements PaperApi {
  bool opened = false;
  Wallet spot = walletOf({
    'USDT': ('10000.00000000', '0'),
    'BTC': ('0.10000000', '0'),
  });
  Wallet futures = walletOf({
    'USDT': ('5000.00000000', '0'),
  }, wallet: PaperWallet.futures);
  List<PaperOrder> open = [];

  /// Calls in order, e.g. `open`, `wallet SPOT`, `place LIMIT BUY`.
  final List<String> calls = [];
  final List<SpotOrderRequest> placed = [];
  final List<SpotOrderListRequest> placedLists = [];
  final List<String> transferKeys = [];

  Object? openError;
  Object? placeError;
  Object? cancelError;
  Object? transferError;

  /// While set, `placeOrder` and `transfer` wait for it.
  Completer<void>? hold;

  @override
  Future<DateTime> openAccount() async {
    calls.add('open');
    if (openError case final error?) throw error;
    opened = true;
    return DateTime.utc(2026, 11, 19);
  }

  @override
  Future<Wallet> wallet(PaperWallet wallet) async {
    calls.add('wallet ${wallet.wire}');
    return wallet == PaperWallet.spot ? spot : futures;
  }

  @override
  Future<Transfer> transfer({
    required PaperWallet from,
    required String amount,
    required String clientTransferId,
  }) async {
    calls.add('transfer ${from.wire} $amount');
    transferKeys.add(clientTransferId);
    if (hold case final gate?) await gate.future;
    if (transferError case final error?) throw error;
    return Transfer(
      transferId: 't-${transferKeys.length}',
      asset: 'USDT',
      from: from,
      to: from == PaperWallet.spot ? PaperWallet.futures : PaperWallet.spot,
      amount: amount,
      transferredAt: DateTime.utc(2026, 11, 19, 3),
    );
  }

  @override
  Future<PaperPage<Transfer>> transfers({
    int page = 1,
    int pageSize = 20,
  }) async {
    calls.add('transfers page=$page');
    return const PaperPage(items: [], page: 1, total: 0);
  }

  List<LedgerEntry> ledgerEntries = [];

  @override
  Future<PaperPage<LedgerEntry>> ledger({
    PaperWallet? wallet,
    LedgerType? type,
    DateTime? from,
    DateTime? to,
    int page = 1,
    int pageSize = 20,
  }) async {
    calls.add(
      ['ledger page=$page', if (type != null) 'type=${type.wire}'].join(' '),
    );
    return PaperPage(
      items: [
        for (final entry in ledgerEntries)
          if (type == null || entry.type == type) entry,
      ],
      page: page,
      total: ledgerEntries.length,
    );
  }

  @override
  Future<PaperOrder> placeOrder(SpotOrderRequest request) async {
    calls.add('place ${request.type.wire} ${request.side.wire}');
    placed.add(request);
    if (hold case final gate?) await gate.future;
    if (placeError case final error?) throw error;
    final order = paperOrderOf(
      'o-${placed.length}',
      pairId: request.pairId,
      side: request.side,
      type: request.type,
      price: request.price ?? '0',
      quantity: request.quantity ?? '0',
      status: request.type == SpotOrderType.market
          ? OrderStatus.filled
          : OrderStatus.newOrder,
      placedAt: DateTime.utc(2026, 11, 19, 3, placed.length),
    );
    if (order.status.open) open = [order, ...open];
    return order;
  }

  final List<SpotOtoRequest> placedOtos = [];

  @override
  Future<List<PaperOrder>> placeOto(SpotOtoRequest request) async {
    calls.add('place list OTO');
    placedOtos.add(request);
    if (placeError case final error?) throw error;
    final orders = [
      paperOrderOf(
        'oto-w',
        side: request.working.side,
        listId: 'list-oto',
        type: request.working.type,
        price: request.working.price ?? '0',
      ),
    ];
    open = [...open, ...orders];
    return orders;
  }

  @override
  Future<List<PaperOrder>> placeOrderList(SpotOrderListRequest request) async {
    calls.add('place list ${request.otoco ? 'OTOCO' : 'OCO'}');
    placedLists.add(request);
    if (placeError case final error?) throw error;
    final orders = [
      paperOrderOf(
        'l-tp',
        side: request.side,
        listId: 'list-1',
        type: SpotOrderType.limitMaker,
        price: request.takeProfitPrice,
      ),
      paperOrderOf(
        'l-sl',
        side: request.side,
        listId: 'list-1',
        type: SpotOrderType.stopLossLimit,
        price: request.stopPrice,
      ),
    ];
    open = [...orders, ...open];
    return orders;
  }

  PaperOrder _closed(PaperOrder order) => PaperOrder(
    orderId: order.orderId,
    pairId: order.pairId,
    symbol: order.symbol,
    side: order.side,
    type: order.type,
    price: order.price,
    quantity: order.quantity,
    executedQuantity: order.executedQuantity,
    cumQuote: order.cumQuote,
    status: OrderStatus.canceled,
    placedAt: order.placedAt,
    listId: order.listId,
  );

  @override
  Future<PaperOrder> cancelOrder(String orderId) async {
    calls.add('cancel $orderId');
    if (cancelError case final error?) throw error;
    final order = open.firstWhere((o) => o.orderId == orderId);
    open = [
      for (final o in open)
        if (o.orderId != orderId) o,
    ];
    return _closed(order);
  }

  @override
  Future<List<PaperOrder>> cancelOrderList(String listId) async {
    calls.add('cancel list $listId');
    if (cancelError case final error?) throw error;
    final group = [
      for (final o in open)
        if (o.listId == listId) o,
    ];
    open = [
      for (final o in open)
        if (o.listId != listId) o,
    ];
    return [for (final o in group) _closed(o)];
  }

  @override
  Future<List<PaperOrder>> cancelAll(String pairId) async {
    calls.add('cancel all $pairId');
    if (cancelError case final error?) throw error;
    final gone = [
      for (final o in open)
        if (o.pairId == pairId) o,
    ];
    open = [
      for (final o in open)
        if (o.pairId != pairId) o,
    ];
    return [for (final o in gone) _closed(o)];
  }

  @override
  Future<List<PaperOrder>> openOrders({String? pairId}) async {
    calls.add('open orders');
    return [
      for (final o in open)
        if (pairId == null || o.pairId == pairId) o,
    ];
  }

  List<PaperOrder> history = [];
  List<PaperFill> fillList = [];

  @override
  Future<PaperPage<PaperOrder>> orders({
    String? pairId,
    OrderStatus? status,
    DateTime? from,
    DateTime? to,
    int page = 1,
    int pageSize = 20,
  }) async {
    calls.add('orders page=$page');
    return PaperPage(items: history, page: page, total: history.length);
  }

  @override
  Future<PaperPage<PaperFill>> fills({
    String? pairId,
    DateTime? from,
    DateTime? to,
    int page = 1,
    int pageSize = 20,
  }) async {
    calls.add('fills page=$page');
    return PaperPage(items: fillList, page: page, total: fillList.length);
  }

  @override
  Future<PaperEquity> equity({int days = 1}) async {
    calls.add(days == 1 ? 'equity' : 'equity days=$days');
    if (equityAnswer case final answer? when opened) return answer;
    if (!opened) {
      throw const ProblemFailure(
        ApiProblem(
          status: 404,
          code: 'NOT_FOUND',
          messageCode: 'MSG41',
          messageArgs: [],
          fieldErrors: {},
        ),
      );
    }
    return const PaperEquity(
      totalEquity: '15000.00',
      todayPnl: '-12.50',
      todayPnlPercent: '-0.08',
    );
  }

  /// Set to answer the equity with a history (T-123).
  PaperEquity? equityAnswer;
  SpotPnl pnlAnswer = const SpotPnl(coins: [], complete: true);
  Object? pnlError;

  @override
  Future<SpotPnl> spotPnl() async {
    calls.add('spot pnl');
    if (pnlError case final error?) throw error;
    return pnlAnswer;
  }
}
