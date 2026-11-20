import 'package:cryptopilot_mobile/features/journal/data/journal_api.dart';
import 'package:cryptopilot_mobile/features/journal/domain/journal.dart';
import 'package:cryptopilot_mobile/features/market/domain/market.dart';
import 'package:cryptopilot_mobile/features/plans/data/plan_detail_api.dart';
import 'package:cryptopilot_mobile/features/plans/domain/plan.dart';
import 'package:cryptopilot_mobile/features/plans/domain/plan_detail.dart';

import 'fakes.dart';

PlanPosition positionOf({
  PositionState status = PositionState.open,
  String? unrealizedPnl = '6.150000000000',
  String? netPnl,
  CloseReason? closeReason,
}) => PlanPosition(
  status: status,
  fillPrice: '66800.000000000000',
  quantity: '0.015000000000',
  entryTime: now.subtract(const Duration(hours: 2)),
  entryFee: '0.501000000000',
  liquidationPrice: '60150.000000000000',
  currentPrice: '67210.000000000000',
  unrealizedPnl: status == PositionState.open ? unrealizedPnl : null,
  exitPrice: status == PositionState.closed ? '69000.000000000000' : null,
  exitTime: status == PositionState.closed ? now : null,
  closeReason: closeReason,
  realizedPnl: status == PositionState.closed ? '19.900000000000' : null,
  feeAmount: status == PositionState.closed ? '1.200000000000' : null,
  fundingFeeAmount: '-0.300000000000',
  netPnl: netPnl,
  stopLoss: '66000.000000000000',
  takeProfit: '69000.000000000000',
  originalStopLoss: '65800.000000000000',
  originalTakeProfit: '69000.000000000000',
  breakevenPrice: '66870.000000000000',
);

PlanDetail planDetailOf(
  String id, {
  String base = 'BTC',
  Market market = Market.futures,
  PlanDirection direction = PlanDirection.long,
  PlanStatus status = PlanStatus.executed,
  PlanPosition? position,
  bool editable = false,
  bool blocks = false,
  List<PlanWarning> warnings = const [],
  String entryType = 'LIMIT',
}) => PlanDetail(
  id: id,
  pairId: 'pair-$base',
  market: market,
  direction: direction,
  entryType: entryType,
  status: status,
  editable: editable,
  blocksActivation: blocks,
  entryPrice: '66800.000000000000',
  stopLoss: '65800.000000000000',
  takeProfit: '69000.000000000000',
  capital: '1000.000000000000',
  riskPercent: '1.500000000000',
  leverage: market == Market.futures ? 5 : null,
  analysisTimeframe: '4h',
  snapshot: const PlanSnapshot(
    positionQuantity: '0.015000000000',
    riskAmount: '15.000000000000',
    riskRewardRatio: '2.200000000000',
    estimatedLiquidationPrice: '60150.000000000000',
  ),
  warnings: warnings,
  statusHistory: [
    PlanStatusChange(status: PlanStatus.draft, at: now),
    if (status != PlanStatus.draft) PlanStatusChange(status: status, at: now),
  ],
  position: position,
);

CloseEstimate estimateOf({String net = '4.850000000000'}) => CloseEstimate(
  currentPrice: '67210.000000000000',
  estimatedExitPrice: '67190.000000000000',
  priceResult: '5.850000000000',
  entryFee: '0.501000000000',
  estimatedExitFee: '0.503000000000',
  fundingSoFar: '-0.300000000000',
  estimatedNetPnl: net,
  at: now,
);

/// `/plans/{id}` and its actions in memory, with one queued failure per
/// method name.
class FakePlanDetailApi implements PlanDetailApi {
  final Map<String, PlanDetail> plans = {
    'p1': planDetailOf('p1', status: PlanStatus.active),
    'p2': planDetailOf('p2', position: positionOf()),
    'd1': planDetailOf(
      'd1',
      status: PlanStatus.draft,
      editable: true,
      entryType: 'MARKET',
    ),
  };
  final List<String> calls = [];
  final Map<String, Object> failNext = {};
  CloseEstimate estimate = estimateOf();

  void _fail(String method) {
    final error = failNext.remove(method);
    if (error != null) throw error;
  }

  PlanDetail _get(String id) =>
      plans[id] ?? (throw problem(404, 'RESOURCE_NOT_FOUND', 'MSG41'));

  @override
  Future<PlanDetail> plan(String id) async {
    calls.add('plan $id');
    _fail('plan');
    return _get(id);
  }

  @override
  Future<PlanDetail> activate(
    String id, {
    bool confirmDeviation = false,
  }) async {
    calls.add('activate $id $confirmDeviation');
    _fail('activate');
    final old = _get(id);
    return plans[id] = planDetailOf(
      id,
      status: PlanStatus.active,
      market: old.market,
      entryType: old.entryType,
    );
  }

  @override
  Future<PlanDetail> cancel(String id) async {
    calls.add('cancel $id');
    _fail('cancel');
    return plans[id] = planDetailOf(id, status: PlanStatus.cancelled);
  }

  @override
  Future<CloseEstimate> closeEstimate(String id) async {
    calls.add('estimate $id');
    _fail('estimate');
    return estimate;
  }

  @override
  Future<PlanDetail> closePosition(String id) async {
    calls.add('close $id');
    _fail('close');
    return plans[id] = planDetailOf(
      id,
      position: positionOf(
        status: PositionState.closed,
        closeReason: CloseReason.manual,
        netPnl: '4.850000000000',
      ),
    );
  }

  @override
  Future<PlanDetail> changeLevels(
    String id, {
    String? stopLoss,
    String? takeProfit,
  }) async {
    calls.add('levels $id $stopLoss $takeProfit');
    _fail('levels');
    return _get(id);
  }
}

JournalEntry journalOf(
  String id, {
  TradeSource source = TradeSource.simulated,
  PositionState status = PositionState.closed,
  String? netPnl = '18.400000000000',
  String base = 'BTC',
  Market market = Market.futures,
}) => JournalEntry(
  id: id,
  planId: source == TradeSource.simulated ? 'p2' : null,
  strategyId: 's1',
  strategyName: 'Breakout',
  pairId: 'pair-$base',
  market: market,
  direction: PlanDirection.long,
  source: source,
  status: status,
  leverage: market == Market.futures ? 5 : null,
  entryPrice: '66800.000000000000',
  quantity: '0.015000000000',
  entryTime: now.subtract(const Duration(days: 1)),
  entryFee: '0.501000000000',
  exitPrice: status == PositionState.closed ? '69000.000000000000' : null,
  exitTime: status == PositionState.closed ? now : null,
  closeReason: status == PositionState.closed ? CloseReason.takeProfit : null,
  realizedPnl: status == PositionState.closed ? '19.900000000000' : null,
  feeAmount: status == PositionState.closed ? '1.200000000000' : null,
  fundingFeeAmount: '-0.300000000000',
  netPnl: status == PositionState.closed ? netPnl : null,
);

/// `/journal` and `/strategies` in memory.
class FakeJournalApi implements JournalApi {
  List<JournalEntry> entries = [
    journalOf('j1'),
    journalOf('j2', source: TradeSource.manual, netPnl: '-3.100000000000'),
    journalOf('j3', status: PositionState.open),
  ];
  final Map<String, JournalDetail> details = {};
  final List<String> calls = [];
  final List<Map<String, Object?>> reviews = [];
  final Map<String, Object> failNext = {};

  void _fail(String method) {
    final error = failNext.remove(method);
    if (error != null) throw error;
  }

  JournalDetail _detail(String id) =>
      details[id] ??
      JournalDetail(
        entry: entries.firstWhere(
          (e) => e.id == id,
          orElse: () => throw problem(404, 'RESOURCE_NOT_FOUND', 'MSG41'),
        ),
        setupDescription: 'Breakout above 66k',
      );

  @override
  Future<JournalPage> list({
    JournalFilter filter = const JournalFilter(),
    DateTime? from,
    DateTime? to,
    int page = 1,
    int pageSize = 20,
  }) async {
    calls.add(
      'list ${filter.source?.wire} ${filter.result?.wire} '
      '${from?.toIso8601String().substring(0, 10)} $page',
    );
    _fail('list');
    final rows = [
      for (final e in entries)
        if ((filter.source == null || e.source == filter.source) &&
            (filter.result == null || e.result == filter.result) &&
            (filter.market == null || e.market == filter.market) &&
            (filter.pairId == null || e.pairId == filter.pairId))
          e,
    ];
    return JournalPage(
      items: rows.skip((page - 1) * pageSize).take(pageSize).toList(),
      page: page,
      pageSize: pageSize,
      total: rows.length,
    );
  }

  @override
  Future<JournalDetail> entry(String id) async {
    calls.add('entry $id');
    _fail('entry');
    return _detail(id);
  }

  @override
  Future<JournalDetail> review(
    String id, {
    String? strategyId,
    String? setupDescription,
    String? lessonsLearned,
    String? mistakes,
    String? chartImagePublicId,
  }) async {
    calls.add('review $id');
    _fail('review');
    reviews.add({
      'strategyId': strategyId,
      'setupDescription': setupDescription,
      'lessonsLearned': lessonsLearned,
      'mistakes': mistakes,
      // As the adapter: left out when null.
      'chartImagePublicId': ?chartImagePublicId,
    });
    return details[id] = JournalDetail(
      entry: _detail(id).entry,
      setupDescription: setupDescription,
      lessonsLearned: lessonsLearned,
      mistakes: mistakes,
      chartImageUrl: chartImagePublicId == null
          ? null
          : '$storageBase/v2/$chartImagePublicId.png',
    );
  }

  /// The storage's addresses (Cloudinary's shape).
  static const storageBase = 'https://res.cloudinary.com/demo/image/upload';

  int maxBytes = 5 * 1024 * 1024;
  final List<String> uploads = [];

  /// Each upload fails while this holds.
  bool refuseUploads = false;

  @override
  Future<ChartImageForm> chartImageForm(String id) async {
    calls.add('chartImageForm $id');
    _fail('chartImageForm');
    return ChartImageForm(
      uploadUrl: 'https://api.cloudinary.com/v1_1/demo/image/upload',
      apiKey: 'key',
      timestamp: 1,
      signature: 'sig',
      publicId:
          'cryptopilot/journal/owner/'
          '0b6f1c2e-1111-4222-8333-${(uploads.length + 1).toString().padLeft(12, '0')}',
      allowedFormats: const ['jpg', 'jpeg', 'png', 'webp'],
      maxBytes: maxBytes,
    );
  }

  @override
  Future<void> uploadChartImage(
    ChartImageForm form,
    String path, {
    void Function(double share)? onProgress,
  }) async {
    calls.add('upload $path');
    if (refuseUploads) throw const ChartImageRefused();
    onProgress?.call(0.5);
    onProgress?.call(1);
    uploads.add(form.publicId);
  }

  @override
  Future<void> delete(String id) async {
    calls.add('delete $id');
    _fail('delete');
    entries = [
      for (final e in entries)
        if (e.id != id) e,
    ];
  }

  @override
  Future<List<Strategy>> strategies() async {
    calls.add('strategies');
    return const [
      Strategy(id: 's1', name: 'Breakout'),
      Strategy(id: 's2', name: 'Pullback'),
    ];
  }
}
