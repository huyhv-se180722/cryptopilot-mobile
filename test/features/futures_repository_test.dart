import 'package:cryptopilot_mobile/core/auth/token_store.dart';
import 'package:cryptopilot_mobile/core/errors/api_failure.dart';
import 'package:cryptopilot_mobile/features/paper/data/futures_repository.dart';
import 'package:cryptopilot_mobile/features/paper/domain/futures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';
import '../support/futures_fakes.dart';
import '../support/realtime_fakes.dart';

void main() {
  late FakeTransport transport;
  late FakeFuturesApi api;
  late ProviderContainer container;

  Future<void> pump(
    WidgetTester tester,
    List<ProviderListenable<Object?>> watched,
  ) async {
    transport = FakeTransport();
    await tester.pumpWidget(
      ProviderScope(
        overrides: baseOverrides(
          store: MemoryTokenStore(storedFor('saved')),
          tokens: FakeAuthTokenApi(),
          transport: transport,
          futures: api,
        ),
        retry: (_, _) => null,
        child: Consumer(
          builder: (context, ref, _) {
            for (final provider in watched) {
              ref.watch(provider);
            }
            return const SizedBox();
          },
        ),
      ),
    );
    container = ProviderScope.containerOf(
      tester.element(find.byType(Consumer)),
    );
    for (var i = 0; i < 8; i++) {
      await tester.pump();
    }
    transport.last.onConnected();
    await tester.pump();
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 31));
  }

  setUp(() => api = FakeFuturesApi()..positionList = [positionOf()]);

  testWidgets('read once the account is open; pushes of one change are read '
      'again once, 500 ms later', (tester) async {
    await pump(tester, [futuresProvider]);
    expect(container.read(futuresProvider).positions, hasLength(1));
    expect(api.calls.where((c) => c == 'positions'), hasLength(1));
    for (final queue in futuresQueues) {
      transport.last.push(queue, {'any': 1});
    }
    await tester.pump(const Duration(milliseconds: 400));
    expect(api.calls.where((c) => c == 'positions'), hasLength(1));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();
    expect(api.calls.where((c) => c == 'positions'), hasLength(2));
    await unmount(tester);
  });

  testWidgets('a margin call is kept and counted for the banner', (
    tester,
  ) async {
    await pump(tester, [futuresProvider]);
    transport.last.push(marginCallQueue, {
      'symbol': 'BTCUSDT',
      'positionSide': 'BOTH',
      'marginType': 'CROSSED',
      'markPrice': '62000',
      'marginRatio': '0.81',
      'maintenanceMargin': '3',
      'marginBalance': '3.7',
      'eventTime': '2026-11-19T02:00:00Z',
    });
    await tester.pump();
    final state = container.read(futuresProvider);
    expect(state.marginCalls, 1);
    expect(state.marginCall!.marginRatio, '0.81');
    await unmount(tester);
  });

  testWidgets('closing all of a position by Market takes it out; TP and SL '
      'close the whole position on the other side', (tester) async {
    await pump(tester, [futuresProvider]);
    final repository = container.read(futuresProvider.notifier);
    final position = container.read(futuresProvider).positions!.single;
    var keys = 0;
    await repository.setTpSl(
      position,
      takeProfit: '80000.0',
      stopLoss: '72000.0',
      working: WorkingType.mark,
      key: () => 'k${keys++}',
    );
    expect(api.placedAlgo.map((r) => r.type), [
      'TAKE_PROFIT_MARKET',
      'STOP_MARKET',
    ]);
    expect(
      api.placedAlgo.every((r) => r.closePosition && r.side.wire == 'SELL'),
      isTrue,
    );
    await repository.close(position, percent: 100);
    expect(api.calls, contains('close BTCUSDT BOTH 100'));
    expect(container.read(futuresProvider).positions, isEmpty);
    await unmount(tester);
  });

  testWidgets('settings: leverage within the bracket; a refusal throws', (
    tester,
  ) async {
    await pump(tester, [futuresSettingsProvider('BTCUSDT')]);
    final settings = container.read(futuresSettingsProvider('BTCUSDT'));
    expect(settings.config!.leverage, 20);
    expect(settings.maxLeverage, 125);
    await container
        .read(futuresSettingsProvider('BTCUSDT').notifier)
        .setLeverage(50);
    expect(
      container.read(futuresSettingsProvider('BTCUSDT')).config!.leverage,
      50,
    );
    api.changeError = problem(409, 'PAPER_MARGIN_TYPE', 'MSG43');
    await expectLater(
      container
          .read(futuresSettingsProvider('BTCUSDT').notifier)
          .setMarginType(MarginType.isolated),
      throwsA(isA<ProblemFailure>()),
    );
    await unmount(tester);
  });
}
