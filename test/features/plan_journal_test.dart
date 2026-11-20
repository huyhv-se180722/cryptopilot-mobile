import 'package:cryptopilot_mobile/core/errors/api_failure.dart';
import 'package:cryptopilot_mobile/core/errors/message_text.dart';
import 'package:cryptopilot_mobile/core/i18n/app_localizations_en.dart';
import 'package:cryptopilot_mobile/core/json/json_read.dart';
import 'package:cryptopilot_mobile/features/journal/data/journal_api.dart';
import 'package:cryptopilot_mobile/features/journal/domain/journal.dart';
import 'package:cryptopilot_mobile/features/market/domain/market.dart';
import 'package:cryptopilot_mobile/features/plans/data/plan_detail_api.dart';
import 'package:cryptopilot_mobile/features/plans/domain/plan.dart';
import 'package:cryptopilot_mobile/features/plans/domain/plan_detail.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/http_fakes.dart';

/// Shapes of backend develop 5c2398cb (`trading/dto/response`,
/// `journal/dto/response`).
Map<String, Object?> positionJson({
  Object? status = 'OPEN',
  Object? closeReason,
  Object? netPnl,
}) => {
  'status': status,
  'fillPrice': '66800.000000000000',
  'quantity': '0.015000000000',
  'entryTime': '2026-11-06T08:00:00Z',
  'entryFee': '0.501000000000',
  'liquidationPrice': '60150.000000000000',
  'currentPrice': '67210.000000000000',
  'unrealizedPnl': '6.150000000000',
  'exitPrice': null,
  'exitTime': null,
  'closeReason': closeReason,
  'realizedPnl': null,
  'feeAmount': null,
  'fundingFeeAmount': '-0.300000000000',
  'netPnl': netPnl,
  'provisional': false,
  'stopLoss': '66000.000000000000',
  'takeProfit': '69000.000000000000',
  'originalStopLoss': '65800.000000000000',
  'originalTakeProfit': '69000.000000000000',
  'stopWidened': false,
  'levelChangeCount': 1,
  'levelChanges': [
    {
      'changedAt': '2026-11-06T09:00:00Z',
      'oldStopLoss': '65800.000000000000',
      'oldTakeProfit': null,
      'newStopLoss': '66000.000000000000',
      'newTakeProfit': null,
    },
  ],
  'breakevenPrice': '66870.000000000000',
  'breakevenProvisional': false,
  'levelWarnings': [],
  'levelsEffectiveFrom': '2026-11-06T09:00:00Z',
};

Map<String, Object?> planJson({
  Object? status = 'EXECUTED',
  Object? position,
  Object? warnings = const <Object?>[],
  bool blocks = false,
}) => {
  'id': 'plan-1',
  'pairId': 'pair-BTC',
  'market': 'FUTURES',
  'direction': 'LONG',
  'entryType': 'LIMIT',
  'entryPrice': '66800.000000000000',
  'expectedFillPrice': '66800.000000000000',
  'plannedEntryPrice': null,
  'stopLoss': '65800.000000000000',
  'takeProfit': '69000.000000000000',
  'capital': '1000.000000000000',
  'riskPercent': '1.500000000000',
  'leverage': 5,
  'marginMode': 'ISOLATED',
  'expiresAt': null,
  'note': null,
  'invalidationPrice': null,
  'maxEntryDeviationR': null,
  'analysisTimeframe': '4h',
  'status': status,
  'invalidationReason': null,
  'setupScoreAtPlan': '72.500000000000',
  'setupScorePreset': 'BALANCED',
  'editable': status == 'DRAFT',
  'snapshot': {
    'positionQuantity': '0.015000000000',
    'notionalValue': '1002.000000000000',
    'initialMargin': '200.400000000000',
    'maintenanceMarginRateUsed': '0.004000000000',
    'riskAmount': '15.000000000000',
    'rewardAmount': '33.000000000000',
    'riskRewardRatio': '2.200000000000',
    'estimatedLiquidationPrice': '60150.000000000000',
    'estimatedEntryFee': '0.501000000000',
    'estimatedStopLossExitFee': null,
    'estimatedTakeProfitExitFee': null,
    'estimatedSlippage': null,
    'lossAtStopLoss': '15.990000000000',
    'feeShareOfRisk': null,
    'netRiskReward': '2.050000000000',
  },
  'warnings': warnings,
  'blocksActivation': blocks,
  'statusHistory': [
    {'status': 'DRAFT', 'at': '2026-11-06T07:00:00Z'},
    {'status': 'ACTIVE', 'at': '2026-11-06T07:30:00Z'},
    {'status': 'EXECUTED', 'at': '2026-11-06T08:00:00Z'},
  ],
  'position': position,
};

Map<String, Object?> journalJson({
  String id = 'j1',
  Object? source = 'SIMULATED',
  Object? status = 'CLOSED',
  Object? netPnl = '18.400000000000',
}) => {
  'id': id,
  'planId': source == 'SIMULATED' ? 'plan-1' : null,
  'strategyId': 's1',
  'strategyName': 'Breakout',
  'pairId': 'pair-BTC',
  'market': 'FUTURES',
  'direction': 'LONG',
  'source': source,
  'status': status,
  'leverage': 5,
  'entryPrice': '66800.000000000000',
  'quantity': '0.015000000000',
  'entryTime': '2026-11-05T09:15:00Z',
  'entryFee': '0.501000000000',
  'stopLoss': '65800.000000000000',
  'takeProfit': '69000.000000000000',
  'exitPrice': status == 'CLOSED' ? '69000.000000000000' : null,
  'exitTime': status == 'CLOSED' ? '2026-11-06T02:00:00Z' : null,
  'closeReason': status == 'CLOSED' ? 'TAKE_PROFIT' : null,
  'realizedPnl': status == 'CLOSED' ? '19.900000000000' : null,
  'feeAmount': status == 'CLOSED' ? '1.200000000000' : null,
  'fundingFeeAmount': '-0.300000000000',
  'netPnl': status == 'CLOSED' ? netPnl : null,
  'provisional': false,
};

void main() {
  group('plan decoders (backend develop 5c2398cb)', () {
    test('an executed plan with its open position, levels and history', () {
      final plan = decodePlanDetail(planJson(position: positionJson()));
      expect(plan.market, Market.futures);
      expect(plan.leverage, 5);
      expect(plan.snapshot?.riskRewardRatio, '2.200000000000');
      expect(plan.statusHistory.map((c) => c.status), [
        PlanStatus.draft,
        PlanStatus.active,
        PlanStatus.executed,
      ]);
      final position = plan.position!;
      expect(plan.hasOpenPosition, isTrue);
      expect(position.unrealizedPnl, '6.150000000000');
      expect(position.liquidationPrice, '60150.000000000000');
      expect(position.levelChanges.single.newStopLoss, '66000.000000000000');
      expect(position.breakevenPrice, '66870.000000000000');
    });

    test('a closed position carries how it ended', () {
      final plan = decodePlanDetail(
        planJson(
          position: positionJson(
            status: 'CLOSED',
            closeReason: 'TAKE_PROFIT',
            netPnl: '18.400000000000',
          ),
        ),
      );
      expect(plan.hasOpenPosition, isFalse);
      expect(plan.position?.closeReason, CloseReason.takeProfit);
      expect(plan.position?.netPnl, '18.400000000000');
    });

    test('a draft with a BLOCKING warning', () {
      final plan = decodePlanDetail(
        planJson(
          status: 'DRAFT',
          blocks: true,
          warnings: [
            {
              'type': 'INSUFFICIENT_CAPITAL',
              'severity': 'BLOCKING',
              'message': 'The capital does not cover the margin.',
            },
          ],
        ),
      );
      expect(plan.editable, isTrue);
      expect(plan.blocksActivation, isTrue);
      expect(plan.warnings.single.severity, WarningSeverity.blocking);
      expect(plan.position, isNull);
    });

    test('a close estimate; funding is null on Spot', () {
      final estimate = decodeCloseEstimate({
        'currentPrice': '67210',
        'estimatedExitPrice': '67190',
        'priceResult': '5.85',
        'entryFee': '0.50',
        'estimatedExitFee': '0.50',
        'fundingSoFar': null,
        'fundingProvisional': false,
        'estimatedNetPnl': '4.85',
        'at': '2026-11-06T10:00:00Z',
      });
      expect(estimate.fundingSoFar, isNull);
      expect(estimate.estimatedNetPnl, '4.85');
    });

    test('bad shapes and unknown values are refused', () {
      void refuses(void Function() decode) =>
          expect(decode, throwsA(isA<DecodeException>()));
      refuses(() => decodePlanDetail(planJson(status: 'PAUSED')));
      refuses(() => decodePlanDetail({...planJson(), 'leverage': 5.5}));
      refuses(() => decodePlanDetail({...planJson(), 'stopLoss': 'low'}));
      refuses(
        () => decodePlanDetail(
          planJson(position: positionJson(closeReason: 'EXPIRED')),
        ),
      );
      refuses(
        () => decodePlanDetail(
          planJson(position: {...positionJson(), 'fillPrice': null}),
        ),
      );
      refuses(() => decodePositionUpdate({'planId': 'p', 'status': 'GONE'}));
    });
  });

  group('journal decoders', () {
    test('a page with the result of BR-42 by the sign of the net P/L', () {
      final page = decodeJournalPage({
        'items': [
          journalJson(),
          journalJson(id: 'j2', netPnl: '-3.100000000000'),
          journalJson(id: 'j3', netPnl: '0E-12'),
          journalJson(id: 'j4', status: 'OPEN'),
        ],
        'page': 1,
        'pageSize': 20,
        'total': 4,
      });
      expect(page.items.map((e) => e.result), [
        TradeResult.win,
        TradeResult.loss,
        TradeResult.breakeven,
        null,
      ]);
      expect(page.items.first.closeReason, CloseReason.takeProfit);
      expect(page.items.first.strategyName, 'Breakout');
    });

    test('a manual trade has no plan; the detail carries its review', () {
      final detail = decodeJournalDetail({
        ...journalJson(source: 'MANUAL'),
        'setupDescription': 'Breakout above 66k',
        'lessonsLearned': null,
        'mistakes': null,
        'chartImageUrl': null,
        'learning': null,
      });
      expect(detail.entry.source, TradeSource.manual);
      expect(detail.entry.planId, isNull);
      expect(detail.setupDescription, 'Breakout above 66k');
    });

    test('strategies; bad shapes refused', () {
      expect(
        decodeStrategies([
          {'id': 's1', 'name': 'Breakout'},
        ]).single.name,
        'Breakout',
      );
      expect(
        () => decodeJournalEntry(journalJson(source: 'COPY')),
        throwsA(isA<DecodeException>()),
      );
      expect(
        () => decodeJournalEntry({...journalJson(), 'leverage': '5'}),
        throwsA(isA<DecodeException>()),
      );
      expect(() => decodeStrategies({}), throwsA(isA<DecodeException>()));
    });
  });

  group('DioPlanDetailApi', () {
    late RecordingAdapter adapter;
    late PlanDetailApi api;

    setUp(() {
      adapter = RecordingAdapter();
      api = DioPlanDetailApi(dioOn(adapter));
    });

    test(
      'reads, activates with the confirmation flag, cancels and closes',
      () async {
        for (var i = 0; i < 5; i++) {
          adapter.answers.add((200, planJson(position: positionJson())));
        }
        await api.plan('plan-1');
        await api.activate('plan-1');
        await api.activate('plan-1', confirmDeviation: true);
        await api.cancel('plan-1');
        await api.closePosition('plan-1');
        expect(adapter.requests.map((r) => '${r.method} ${r.path}'), [
          'GET plans/plan-1',
          'POST plans/plan-1/activate',
          'POST plans/plan-1/activate',
          'POST plans/plan-1/cancel',
          'POST plans/plan-1/close-position',
        ]);
        expect(adapter.requests[1].queryParameters, {
          'confirmDeviation': false,
        });
        expect(adapter.requests[2].queryParameters, {'confirmDeviation': true});
      },
    );

    test('sends only the levels it changes', () async {
      adapter.answers.add((200, planJson(position: positionJson())));
      await api.changeLevels('plan-1', stopLoss: '66000');
      expect(adapter.requests.single.method, 'PATCH');
      expect(adapter.requests.single.path, 'plans/plan-1/position-levels');
      expect(adapter.requests.single.data, {'stopLoss': '66000'});
    });

    test(
      'MSG51 keeps its arguments for the confirmation; MSG52, MSG18',
      () async {
        adapter.answers.addAll([
          (
            400,
            {
              'status': 400,
              'code': 'ENTRY_DEVIATION_CONFIRMATION_REQUIRED',
              'messageCode': 'MSG51',
              'messageArgs': ['0.4', '0.0142', '2.05'],
              'deviationR': '0.4',
            },
          ),
          (
            409,
            {
              'status': 409,
              'code': 'TRADING_BLOCKING_WARNING',
              'messageCode': 'MSG18',
            },
          ),
        ]);
        final l = AppLocalizationsEn();
        Future<ProblemFailure> failure(Future<Object?> call) async {
          try {
            await call;
          } on ProblemFailure catch (error) {
            return error;
          }
          fail('expected a ProblemFailure');
        }

        final confirm = await failure(api.activate('plan-1'));
        expect(confirm.code, 'ENTRY_DEVIATION_CONFIRMATION_REQUIRED');
        expect(
          failureText(l, confirm),
          'The price has moved 0.4R from your plan. New quantity 0.0142, '
          'risk/reward 2.05. Activate anyway?',
        );
        final blocked = await failure(api.activate('plan-1'));
        expect(
          failureText(l, blocked),
          'This plan has blocking warnings and cannot be activated.',
        );
        expect(
          messageText(l, 'MSG52', args: ['1.2', '1']),
          'The price has moved 1.2R from your plan, beyond the allowed 1R or '
          'past the take profit. The plan was not activated.',
        );
      },
    );
  });

  group('DioJournalApi', () {
    late RecordingAdapter adapter;
    late JournalApi api;

    setUp(() {
      adapter = RecordingAdapter();
      api = DioJournalApi(dioOn(adapter));
    });

    test('the filters go out as GET /journal takes them', () async {
      adapter.answers.add((
        200,
        {'items': <Object?>[], 'page': 1, 'pageSize': 20, 'total': 0},
      ));
      await api.list(
        filter: const JournalFilter(
          market: Market.spot,
          source: TradeSource.manual,
          result: TradeResult.win,
          pairId: 'pair-BTC',
        ),
        from: DateTime.utc(2026, 10, 7),
        to: DateTime.utc(2026, 11, 6),
      );
      expect(adapter.requests.single.queryParameters, {
        'market': 'SPOT',
        'source': 'MANUAL',
        'result': 'WIN',
        'pairId': 'pair-BTC',
        'from': '2026-10-07',
        'to': '2026-11-06',
        'page': 1,
        'pageSize': 20,
      });
    });

    test('a review replaces every review field; delete', () async {
      adapter.answers.addAll([
        (
          200,
          {
            ...journalJson(),
            'setupDescription': 'Breakout',
            'lessonsLearned': null,
            'mistakes': null,
            'chartImageUrl': null,
            'learning': null,
          },
        ),
        (204, null),
      ]);
      await api.review('j1', strategyId: 's1', setupDescription: 'Breakout');
      await api.delete('j1');
      expect(adapter.requests[0].method, 'PUT');
      expect(adapter.requests[0].path, 'journal/j1/review');
      expect(adapter.requests[0].data, {
        'strategyId': 's1',
        'setupDescription': 'Breakout',
        'lessonsLearned': null,
        'mistakes': null,
      });
      expect(adapter.requests[1].method, 'DELETE');
    });
  });
}
