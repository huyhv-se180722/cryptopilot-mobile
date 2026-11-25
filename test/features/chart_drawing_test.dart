import 'dart:async';

import 'package:cryptopilot_mobile/core/auth/token_store.dart';
import 'package:cryptopilot_mobile/core/i18n/app_localizations.dart';
import 'package:cryptopilot_mobile/core/settings/settings.dart';
import 'package:cryptopilot_mobile/core/theme/app_theme.dart';
import 'package:cryptopilot_mobile/features/chart/application/drawing_board_controller.dart';
import 'package:cryptopilot_mobile/features/chart/data/chart_drawing_api.dart';
import 'package:cryptopilot_mobile/features/chart/domain/drawing.dart';
import 'package:cryptopilot_mobile/features/chart/domain/drawing_history.dart';
import 'package:cryptopilot_mobile/features/chart/domain/drawing_tools.dart';
import 'package:cryptopilot_mobile/features/chart/presentation/chart_screen.dart';
import 'package:cryptopilot_mobile/features/chart/presentation/chart_surface.dart';
import 'package:cryptopilot_mobile/features/market/domain/candle.dart';
import 'package:cryptopilot_mobile/features/market/domain/market.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/chart_fakes.dart';
import '../support/fakes.dart';
import '../support/realtime_fakes.dart';

const pairId = 'pair-btc';

DrawingPoint at(int hour, String price) =>
    DrawingPoint(time: DateTime.utc(2026, 11, 1, hour), price: price);

DrawingDraft line({String a = '100', String b = '110'}) => DrawingDraft(
  type: 'TREND_LINE',
  change: DrawingChange(
    points: [at(1, a), at(3, b)],
    style: const DrawingStyle(),
  ),
);

void main() {
  group('drawing bodies', () {
    test('a drawing reads its decimals as text, written either way', () {
      final drawing = ChartDrawing.fromJson({
        'id': 'd1',
        'layoutId': 'l1',
        'type': 'FIB_RETRACEMENT',
        'points': [
          {'time': '2026-11-01T01:00:00Z', 'price': '76166.02'},
          {'time': '2026-11-01T03:00:00Z', 'price': 76000.5},
        ],
        'style': {
          'lineColor': '#787B86',
          'lineWidth': 2,
          'lineStyle': 'DASHED',
          'fillColor': null,
          'extendLeft': false,
          'extendRight': true,
          'fontSize': null,
          'fibLevels': ['0', 0.618, '1'],
        },
        'text': null,
        'locked': true,
        'hidden': false,
        'version': 3,
        'createdAt': '2026-11-01T00:00:00Z',
      });
      expect(drawing.points.map((p) => p.price), ['76166.02', '76000.5']);
      expect(drawing.style.lineStyle, DrawingLineStyle.dashed);
      expect(drawing.style.fibLevels, ['0', '0.618', '1']);
      expect(drawing.locked, isTrue);
      expect(drawing.version, 3);
      // What the chart page reads back is the web's shape.
      final page = drawing.toJson();
      expect(page['points'], [
        {'time': '2026-11-01T01:00:00.000Z', 'price': '76166.02'},
        {'time': '2026-11-01T03:00:00.000Z', 'price': '76000.5'},
      ]);
      expect((page['style']! as Map)['lineStyle'], 'DASHED');
    });

    test('copies come by number', () {
      final layouts = decodeChartLayouts([
        {
          'id': 'b',
          'pairId': pairId,
          'number': 2,
          'name': 'Swing',
          'drawings': 4,
        },
        {'id': 'a', 'pairId': pairId, 'number': 1, 'name': null, 'drawings': 0},
      ]);
      expect(layouts.map((l) => l.id), ['a', 'b']);
      expect(layouts.last.name, 'Swing');
    });

    test('the page events become drawing events; others are ignored', () {
      final placed = DrawingEvent.fromJson({
        'type': 'drawing.create',
        'draft': {
          'type': 'HORIZONTAL_LINE',
          'points': [
            {'time': '2026-11-01T01:00:00.000Z', 'price': '100'},
          ],
          'style': const DrawingStyle().toJson(),
          'text': null,
          'locked': false,
          'hidden': false,
        },
      });
      expect(placed, isA<DrawingPlaced>());
      expect((placed! as DrawingPlaced).draft.type, 'HORIZONTAL_LINE');
      final moved = DrawingEvent.fromJson({
        'type': 'drawing.change',
        'id': 'd1',
        'points': [
          {'time': '2026-11-01T02:00:00.000Z', 'price': '105'},
        ],
      });
      expect((moved! as DrawingMoved).points.single.price, '105');
      expect(DrawingEvent.fromJson({'type': 'more'}), isNull);
      expect(
        DrawingEvent.fromJson({'type': 'drawing.change', 'id': 'd1'}),
        isNull,
      );
    });

    test('a tool of a saved trend line follows its extension', () {
      expect(
        DrawingTool.ofDrawing(
          'TREND_LINE',
          extendLeft: true,
          extendRight: true,
        ),
        DrawingTool.extendedLine,
      );
      expect(
        DrawingTool.ofDrawing(
          'TREND_LINE',
          extendLeft: false,
          extendRight: true,
        ),
        DrawingTool.ray,
      );
      expect(
        DrawingTool.ofDrawing('ARROW', extendLeft: false, extendRight: false),
        DrawingTool.arrow,
      );
    });
  });

  test('the history renames a drawing that came back under a new id', () {
    final history = DrawingHistory();
    final old = ChartDrawing(
      id: 'old',
      layoutId: 'l1',
      type: 'TREND_LINE',
      change: line().change,
      version: 0,
    );
    final back = ChartDrawing(
      id: 'new',
      layoutId: 'l1',
      type: 'TREND_LINE',
      change: line().change,
      version: 0,
    );
    history
      ..record(UpdatedEntry('old', line().change, line(b: '120').change))
      ..record(RemovedEntry(old))
      ..rename(old, back);
    expect((history.takeUndo()! as RemovedEntry).drawing.id, 'new');
    expect((history.takeUndo()! as UpdatedEntry).id, 'new');
    expect(history.canUndo, isFalse);
  });

  group('the drawing board', () {
    late FakeChartDrawingApi api;
    late MemorySettingsStore settings;
    late ProviderContainer container;
    late ProviderSubscription<DrawingBoardState> keep;

    setUp(() {
      api = FakeChartDrawingApi();
      settings = MemorySettingsStore();
    });

    tearDown(() {
      keep.close();
      container.dispose();
    });

    Future<DrawingBoardController> start() async {
      container = ProviderContainer(
        overrides: [
          chartDrawingApiProvider.overrideWithValue(api),
          settingsStoreProvider.overrideWithValue(settings),
        ],
      );
      keep = container.listen(drawingBoardProvider(pairId), (_, _) {});
      await pumpEventQueue();
      return container.read(drawingBoardProvider(pairId).notifier);
    }

    DrawingBoardState read() => container.read(drawingBoardProvider(pairId));

    test('shows the copy remembered on the device, else the lowest', () async {
      final first = api.addLayout(pairId);
      final second = api.addLayout(pairId, name: 'Swing');
      api.addDrawing(second.id, line());
      settings.values[DrawingBoardController.layoutKey(pairId)] = second.id;
      await start();
      expect(read().activeId, second.id);
      expect(read().shown, hasLength(1));

      settings.values[DrawingBoardController.layoutKey(pairId)] = 'gone';
      container.invalidate(drawingBoardProvider(pairId));
      await pumpEventQueue();
      expect(read().activeId, first.id);
    });

    test('the first drawing of a pair opens "Copy 1" once, for two quick '
        'drawings too', () async {
      final board = await start();
      expect(read().ready, isTrue);
      expect(read().activeId, isNull);
      api.holdCreates = Completer<void>();
      board
        ..placed(line())
        ..placed(line(a: '90'));
      await pumpEventQueue();
      api.holdCreates!.complete();
      await pumpEventQueue();
      expect(api.calls.where((c) => c == 'createLayout'), hasLength(1));
      expect(read().layouts!.single.number, 1);
      expect(read().shown, hasLength(2));
      expect(
        settings.values[DrawingBoardController.layoutKey(pairId)],
        read().activeId,
      );
      expect(read().canUndo, isTrue);
    });

    test('a move shows at once and saves with the version last read', () async {
      final layout = api.addLayout(pairId);
      final saved = api.addDrawing(layout.id, line());
      final board = await start();
      board
        ..moved(saved.id, [at(2, '101'), at(4, '111')])
        ..moved(saved.id, [at(2, '102'), at(4, '112')]);
      expect(read().shown.single.points.first.price, '102');
      await pumpEventQueue();
      expect(api.calls.where((c) => c.startsWith('update')), [
        'update ${saved.id} v0',
        'update ${saved.id} v1',
      ]);
      expect(read().shown.single.version, 2);
    });

    test('a failed write takes its change back and says so', () async {
      final layout = api.addLayout(pairId);
      final saved = api.addDrawing(layout.id, line());
      final board = await start();
      api.failNextWrite = FakeChartDrawingApi.problem('CONFLICT');
      board.moved(saved.id, [at(2, '101'), at(4, '111')]);
      await pumpEventQueue();
      expect(read().shown.single.points.first.price, '100');
      expect(read().notice, DrawingNotice.saveFailed);
      final count = read().noticeCount;

      api.failNextWrite = FakeChartDrawingApi.problem(
        'CHART_DRAWING_LIMIT_REACHED',
      );
      board.placed(line());
      await pumpEventQueue();
      expect(read().notice, DrawingNotice.drawingLimit);
      expect(read().noticeCount, count + 1);
      expect(read().shown, hasLength(1));
    });

    test('undo and redo replay creates, moves and removals', () async {
      final layout = api.addLayout(pairId);
      final board = await start();
      board.placed(line());
      await pumpEventQueue();
      final created = read().shown.single;
      board.moved(created.id, [at(2, '101'), at(4, '111')]);
      await pumpEventQueue();
      board.removed(created.id);
      await pumpEventQueue();
      expect(read().shown, isEmpty);

      await board.undo(); // the removal: back under a new id
      expect(read().shown.single.points.first.price, '101');
      final back = read().shown.single.id;
      expect(back, isNot(created.id));
      await board.undo(); // the move, on the drawing that came back
      expect(read().shown.single.points.first.price, '100');
      expect(api.drawingRows[layout.id]!.single.id, back);
      await board.undo(); // the create
      expect(read().shown, isEmpty);
      expect(read().canUndo, isFalse);
      await board.redo();
      expect(read().shown, hasLength(1));
      expect(read().canRedo, isTrue);
    });

    test('copies: open, duplicate, switch, rename, remove', () async {
      final layout = api.addLayout(pairId);
      api.addDrawing(layout.id, line());
      final board = await start();
      await board.createLayout(duplicate: true);
      expect(read().layouts!.map((l) => l.number), [1, 2]);
      expect(read().active!.number, 2);
      expect(read().shown, hasLength(1));

      await board.renameLayout(read().activeId!, '  Swing ');
      expect(read().active!.name, 'Swing');

      await board.removeLayout(read().activeId!);
      expect(read().activeId, layout.id);
      expect(read().layouts, hasLength(1));

      for (var i = 0; i < 9; i++) {
        await board.createLayout();
      }
      expect(read().full, isTrue);
      await board.createLayout();
      expect(read().notice, DrawingNotice.layoutLimit);
    });

    test('remove all, hidden drawings and options', () async {
      final layout = api.addLayout(pairId);
      final hidden = api.addDrawing(
        layout.id,
        DrawingDraft(
          type: 'HORIZONTAL_LINE',
          change: DrawingChange(
            points: [at(1, '100')],
            style: const DrawingStyle(),
            hidden: true,
          ),
        ),
      );
      api.addDrawing(layout.id, line());
      final board = await start();
      expect(read().hiddenCount, 1);
      board.showHidden();
      await pumpEventQueue();
      expect(api.calls, contains('update ${hidden.id} v0'));
      expect(read().hiddenCount, 0);

      board.removeAll();
      await pumpEventQueue();
      expect(read().shown, isEmpty);
      expect(api.drawingRows[layout.id], isEmpty);
      expect(read().canUndo, isFalse);

      board.setOptions(const DrawingOptions(magnet: true, hideAll: true));
      await pumpEventQueue();
      expect(
        DrawingOptions.parse(
          settings.values[DrawingBoardController.optionsKey],
        ),
        const DrawingOptions(magnet: true, hideAll: true),
      );
    });

    test('a text drawing waits for its text', () async {
      api.addLayout(pairId);
      final board = await start();
      board.placed(
        DrawingDraft(
          type: 'TEXT',
          change: DrawingChange(
            points: [at(1, '100')],
            style: const DrawingStyle(fontSize: 14),
          ),
        ),
      );
      expect(read().textDraft, isNotNull);
      expect(api.calls.where((c) => c.startsWith('create')), isEmpty);
      board.submitText('  Breakout  ');
      await pumpEventQueue();
      expect(read().textDraft, isNull);
      expect(read().shown.single.change.text, 'Breakout');
    });
  });

  group('Chart screen', () {
    late FakeChartDrawingApi api;
    late FakeChartSurface page;
    late FakeTransport transport;
    late FakeMarketApi market;

    setUp(() {
      api = FakeChartDrawingApi();
      page = FakeChartSurface();
      transport = FakeTransport();
      market = FakeMarketApi()..candlesBy['SPOT BTCUSDT 1h'] = candleRun(500);
    });

    Future<void> mount(
      WidgetTester tester,
      Widget home, {
      Brightness brightness = Brightness.light,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...baseOverrides(
              store: MemoryTokenStore(storedFor('saved')),
              tokens: FakeAuthTokenApi(),
              transport: transport,
              market: market,
              drawings: api,
              fullChart: page,
            ),
          ],
          retry: (_, _) => null,
          child: MaterialApp(
            theme: appTheme(brightness),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: home,
          ),
        ),
      );
      for (var i = 0; i < 8; i++) {
        await tester.pump();
      }
    }

    String btcPair() => market.pairsBy[Market.spot]!
        .firstWhere((p) => p.symbol == 'BTCUSDT')
        .pairId;

    testWidgets('draws with a tool from the bar, then saves what was placed', (
      tester,
    ) async {
      await mount(
        tester,
        const ChartScreen(market: Market.spot, symbol: 'BTCUSDT'),
      );
      expect(page.fullScreen, isTrue);
      expect(page.layer.editable, isTrue);
      expect(page.calls, contains('barSeconds 3600'));

      await tester.tap(find.byKey(const Key('drawing-group-lines')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('drawing-tool-ray')));
      await tester.pumpAndSettle();
      expect(page.layer.tool, DrawingTool.ray);
      expect(find.byKey(const Key('drawing-hint')), findsOneWidget);

      page
        ..draw(DrawingPlaced(line()))
        ..draw(const DrawingToolDone());
      await tester.pumpAndSettle();
      expect(api.calls, containsAll(['createLayout', 'create TREND_LINE']));
      expect(page.layer.drawings, hasLength(1));
      expect(page.layer.tool, isNull);
      expect(find.byKey(const Key('drawing-hint')), findsNothing);
      expect(api.layoutRows.single.pairId, btcPair());
    });

    testWidgets('the selected drawing gets its bar: lock, hide, settings', (
      tester,
    ) async {
      final layout = api.addLayout(_btcId(market));
      final saved = api.addDrawing(layout.id, line());
      await mount(
        tester,
        const ChartScreen(market: Market.spot, symbol: 'BTCUSDT'),
      );
      page.draw(DrawingSelected(saved.id));
      await tester.pumpAndSettle();
      expect(page.layer.selectedId, saved.id);
      expect(find.byKey(const Key('drawing-floating-bar')), findsOneWidget);

      await tester.tap(find.byKey(const Key('drawing-lock')));
      await tester.pumpAndSettle();
      expect(api.drawingRows[layout.id]!.single.locked, isTrue);

      await tester.tap(find.byKey(const Key('drawing-settings')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('drawing-price-0')), '0');
      await tester.tap(find.byKey(const Key('drawing-settings-save')));
      await tester.pumpAndSettle();
      expect(find.text('Enter a price greater than 0.'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('drawing-price-0')), '95.5');
      await tester.tap(find.byKey(const Key('drawing-settings-save')));
      await tester.pumpAndSettle();
      expect(api.drawingRows[layout.id]!.single.points.first.price, '95.5');

      await tester.tap(find.byKey(const Key('drawing-hide')));
      await tester.pumpAndSettle();
      expect(api.drawingRows[layout.id]!.single.hidden, isTrue);
    });

    testWidgets('a text tool asks for the text before it saves', (
      tester,
    ) async {
      api.addLayout(_btcId(market));
      await mount(
        tester,
        const ChartScreen(market: Market.spot, symbol: 'BTCUSDT'),
      );
      page.draw(
        DrawingPlaced(
          DrawingDraft(
            type: 'TEXT',
            change: DrawingChange(
              points: [at(1, '100')],
              style: const DrawingStyle(fontSize: 14),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('drawing-text-input')),
        'Breakout',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('drawing-text-add')));
      await tester.pumpAndSettle();
      expect(api.calls, contains('create TEXT'));
      expect(page.layer.drawings.single.change.text, 'Breakout');
    });

    testWidgets('the copies sheet opens and switches copies', (tester) async {
      final id = _btcId(market);
      api.addLayout(id);
      final second = api.addLayout(id, name: 'Swing');
      api.addDrawing(second.id, line());
      await mount(
        tester,
        const ChartScreen(market: Market.spot, symbol: 'BTCUSDT'),
      );
      expect(find.text('Copy 1'), findsOneWidget);
      await tester.tap(find.byKey(const Key('drawing-copies')));
      await tester.pumpAndSettle();
      expect(find.text('Swing'), findsOneWidget);
      await tester.tap(find.byKey(const Key('drawing-copy-2')));
      await tester.pumpAndSettle();
      expect(find.text('Swing'), findsOneWidget);
      expect(page.layer.drawings, hasLength(1));
    });

    for (final brightness in Brightness.values) {
      testWidgets('360 dp, ${brightness.name}: the bar, the selected '
          "drawing's bar and the copies fit", (tester) async {
        tester.view
          ..physicalSize = const Size(360 * 3, 760 * 3)
          ..devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        final layout = api.addLayout(_btcId(market), name: 'A long copy name');
        final saved = api.addDrawing(layout.id, line());
        await mount(
          tester,
          const ChartScreen(market: Market.spot, symbol: 'BTCUSDT'),
          brightness: brightness,
        );
        page.draw(DrawingSelected(saved.id));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('drawing-floating-bar')), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(const Key('drawing-copies')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('a pair the market no longer lists says so', (tester) async {
      await mount(
        tester,
        const ChartScreen(market: Market.spot, symbol: 'NOPEUSDT'),
      );
      expect(find.text('This pair is no longer available.'), findsOneWidget);
    });

    test('the location carries the timeframe', () {
      expect(
        chartLocation(Market.futures, 'BTCUSDT', Timeframe.h4),
        '/chart/futures/BTCUSDT?tf=4h',
      );
    });
  });
}

String _btcId(FakeMarketApi market) => market.pairsBy[Market.spot]!
    .firstWhere((p) => p.symbol == 'BTCUSDT')
    .pairId;
