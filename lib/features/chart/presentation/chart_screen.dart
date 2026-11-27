import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/message_text.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/cp_colors.dart';
import '../../market/data/market_repository.dart';
import '../../market/domain/candle.dart';
import '../../market/domain/market.dart';
import '../application/chart_prefs.dart';
import '../application/drawing_board_controller.dart';
import '../domain/drawing.dart';
import 'chart_surface.dart';
import 'chart_view.dart';
import 'drawing_bars.dart';
import 'drawing_labels.dart';

/// Where the Chart screen of a pair opens, on [tf].
String chartLocation(Market market, String symbol, Timeframe tf) =>
    '/chart/${market.path}/${Uri.encodeComponent(symbol)}?tf=${tf.wire}';

/// The Chart screen (D-149, T-153; the web's T-152): one pair's chart on the
/// whole screen with the drawing tools, opened from its analysis. Its page is
/// its own, so the analysis card under it keeps its chart.
class ChartScreen extends ConsumerStatefulWidget {
  const ChartScreen({
    required this.market,
    required this.symbol,
    this.timeframe = Timeframe.h1,
    super.key,
  });

  final Market market;
  final String symbol;
  final Timeframe timeframe;

  @override
  ConsumerState<ChartScreen> createState() => _ChartScreenState();
}

class _ChartScreenState extends ConsumerState<ChartScreen> {
  late Timeframe _tf = widget.timeframe;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final board = marketRepositoryProvider(widget.market);
    final pairs = ref.watch(board.select((s) => s.pairs));
    final failure = ref.watch(board.select((s) => s.failure));
    final pair = pairs?.where((p) => p.symbol == widget.symbol).firstOrNull;
    // Kept while the screen is open; the page goes with it.
    final surface = ref.watch(fullChartSurfaceProvider);

    if (pair == null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.symbol)),
        body: Center(
          child: pairs != null
              ? Text(l.analysisPairGone)
              : failure != null
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(failureText(l, failure), textAlign: TextAlign.center),
                    TextButton(
                      onPressed: () => ref.read(board.notifier).load(),
                      child: Text(l.commonRetry),
                    ),
                  ],
                )
              : const CircularProgressIndicator(key: Key('chart-loading')),
        ),
      );
    }
    return _DrawingScreen(
      pair: pair,
      timeframe: _tf,
      onTimeframe: (tf) => setState(() => _tf = tf),
      surface: surface,
    );
  }
}

class _DrawingScreen extends ConsumerWidget {
  const _DrawingScreen({
    required this.pair,
    required this.timeframe,
    required this.onTimeframe,
    required this.surface,
  });

  final MarketPair pair;
  final Timeframe timeframe;
  final ValueChanged<Timeframe> onTimeframe;
  final ChartSurface surface;

  String get _pairId => pair.pairId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final provider = drawingBoardProvider(_pairId);
    final state = ref.watch(provider);
    final board = ref.read(provider.notifier);
    ref
      ..listen(provider.select((s) => s.noticeCount), (_, _) {
        final notice = ref.read(provider).notice;
        if (notice == null) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(_noticeText(l, notice))));
      })
      ..listen(provider.select((s) => s.textDraft), (_, draft) async {
        if (draft == null) return;
        final text = await showDrawingTextDialog(context);
        if (text == null) {
          board.cancelText();
        } else {
          board.submitText(text);
        }
      });
    final selected = state.tool == null ? state.selected : null;
    final tool = state.tool;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.drawingChartTitle(pair.symbol)),
        actions: [
          TextButton.icon(
            key: const Key('drawing-copies'),
            onPressed: state.layouts == null
                ? null
                : () => unawaited(_showCopies(context, ref)),
            icon: const Icon(Icons.layers_outlined),
            label: Text(
              state.active == null
                  ? l.drawingCopyName(1)
                  : layoutName(l, state.active!),
            ),
          ),
          _OptionsMenu(pair: pair),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
              child: SegmentedButton<Timeframe>(
                key: const Key('chart-timeframes'),
                showSelectedIcon: false,
                segments: [
                  for (final tf in chartTimeframes)
                    ButtonSegment(value: tf, label: Text(tf.wire)),
                ],
                selected: {timeframe},
                onSelectionChanged: (picked) => onTimeframe(picked.first),
              ),
            ),
            if (state.failure != null && !state.ready)
              MaterialBanner(
                key: const Key('drawing-load-failed'),
                content: Text(l.drawingLoadFailed),
                actions: [
                  TextButton(
                    onPressed: () => unawaited(board.load()),
                    child: Text(l.commonRetry),
                  ),
                ],
              ),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DrawingRail(pairId: _pairId),
                  Expanded(
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: ChartView(
                            candleKey: (
                              market: pair.market,
                              symbol: pair.symbol,
                              tf: timeframe,
                            ),
                            precision: decimalsOf(pair.tickSize),
                            indicators: ref.watch(chartIndicatorsProvider),
                            drawingPairId: _pairId,
                            editable: true,
                            expand: true,
                            surface: surface,
                          ),
                        ),
                        if (tool != null)
                          Positioned(
                            top: 8,
                            left: 8,
                            right: 8,
                            child: Center(
                              child: DrawingHint(
                                tool: tool,
                                onCancel: () {
                                  board.setTool(null);
                                  unawaited(surface.cancelDrawing());
                                },
                              ),
                            ),
                          )
                        else if (selected != null)
                          Positioned(
                            top: 8,
                            left: 8,
                            right: 8,
                            child: Center(
                              child: DrawingFloatingBar(
                                pairId: _pairId,
                                drawing: selected,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCopies(BuildContext context, WidgetRef ref) =>
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (_) => _CopiesSheet(pair: pair),
      );
}

String _noticeText(AppLocalizations l, DrawingNotice notice) =>
    switch (notice) {
      DrawingNotice.saveFailed => l.drawingSaveFailed,
      DrawingNotice.drawingLimit => l.drawingLimitReached,
      DrawingNotice.layoutLimit => l.drawingLayoutLimit,
      DrawingNotice.layoutFailed => l.drawingLayoutFailed,
    };

/// Magnet, stay in drawing, lock all, hide all, show hidden, remove all.
class _OptionsMenu extends ConsumerWidget {
  const _OptionsMenu({required this.pair});

  final MarketPair pair;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final provider = drawingBoardProvider(pair.pairId);
    final state = ref.watch(provider);
    final board = ref.read(provider.notifier);
    final options = state.options;
    return PopupMenuButton<String>(
      key: const Key('drawing-options'),
      tooltip: l.drawingMore,
      onSelected: (choice) async {
        switch (choice) {
          case 'magnet':
            board.setOptions(options.copyWith(magnet: !options.magnet));
          case 'stay':
            board.setOptions(
              options.copyWith(stayInDrawing: !options.stayInDrawing),
            );
          case 'lockAll':
            board.setOptions(options.copyWith(lockAll: !options.lockAll));
          case 'hideAll':
            board.setOptions(options.copyWith(hideAll: !options.hideAll));
          case 'showHidden':
            board.showHidden();
          case 'removeAll':
            final layout = state.active;
            if (layout == null) return;
            final sure = await _confirm(
              context,
              title: l.drawingRemoveAllTitle,
              body: l.drawingRemoveAllBody(layoutName(l, layout), pair.symbol),
              action: l.drawingRemoveAllConfirm,
            );
            if (sure) board.removeAll();
        }
      },
      itemBuilder: (_) => [
        CheckedPopupMenuItem(
          value: 'magnet',
          checked: options.magnet,
          child: Text(l.drawingMagnet),
        ),
        CheckedPopupMenuItem(
          value: 'stay',
          checked: options.stayInDrawing,
          child: Text(l.drawingStayInDrawing),
        ),
        CheckedPopupMenuItem(
          value: 'lockAll',
          checked: options.lockAll,
          child: Text(l.drawingLockAll),
        ),
        CheckedPopupMenuItem(
          value: 'hideAll',
          checked: options.hideAll,
          child: Text(l.drawingHideAll),
        ),
        if (state.hiddenCount > 0)
          PopupMenuItem(
            value: 'showHidden',
            child: Text(l.drawingShowHidden(state.hiddenCount)),
          ),
        PopupMenuItem(
          value: 'removeAll',
          enabled: state.shown.isNotEmpty,
          child: Text(l.drawingRemoveAll),
        ),
      ],
    );
  }
}

/// The copies of the pair (D-149 (5)): show one, open a new or duplicate,
/// rename, remove.
class _CopiesSheet extends ConsumerWidget {
  const _CopiesSheet({required this.pair});

  final MarketPair pair;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final cp = context.cp;
    final provider = drawingBoardProvider(pair.pairId);
    final state = ref.watch(provider);
    final board = ref.read(provider.notifier);
    final layouts = state.layouts ?? const <ChartLayout>[];
    return SafeArea(
      child: Column(
        key: const Key('drawing-copies-sheet'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              l.drawingCopies(pair.symbol),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final layout in layouts)
                  ListTile(
                    key: Key('drawing-copy-${layout.number}'),
                    selected: layout.id == state.activeId,
                    leading: Icon(
                      layout.id == state.activeId
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                    ),
                    title: Text(layoutName(l, layout)),
                    subtitle: Text(l.drawingCopyCount(layout.drawings)),
                    onTap: () {
                      unawaited(board.selectLayout(layout.id));
                      Navigator.of(context).pop();
                    },
                    trailing: PopupMenuButton<String>(
                      onSelected: (choice) async {
                        if (choice == 'rename') {
                          final name = await _rename(context, l, layout);
                          if (name != null) {
                            await board.renameLayout(layout.id, name);
                          }
                        } else {
                          final sure = await _confirm(
                            context,
                            title: l.drawingRemoveCopyTitle(
                              layoutName(l, layout),
                            ),
                            body: l.drawingRemoveCopyBody(layout.drawings),
                            action: l.drawingRemoveCopyConfirm,
                          );
                          if (sure) await board.removeLayout(layout.id);
                        }
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'rename',
                          child: Text(l.drawingRename),
                        ),
                        PopupMenuItem(
                          value: 'remove',
                          child: Text(
                            l.drawingRemoveCopy,
                            style: TextStyle(color: cp.negative),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const Divider(),
          ListTile(
            key: const Key('drawing-new-copy'),
            enabled: !state.full,
            leading: const Icon(Icons.add),
            title: Text(l.drawingNewCopy),
            subtitle: state.full ? Text(l.drawingCopyLimit) : null,
            onTap: () {
              unawaited(board.createLayout());
              Navigator.of(context).pop();
            },
          ),
          ListTile(
            key: const Key('drawing-duplicate-copy'),
            enabled: !state.full && state.activeId != null,
            leading: const Icon(Icons.copy_all_outlined),
            title: Text(l.drawingDuplicate),
            onTap: () {
              unawaited(board.createLayout(duplicate: true));
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
}

Future<String?> _rename(
  BuildContext context,
  AppLocalizations l,
  ChartLayout layout,
) {
  final name = TextEditingController(text: layout.name ?? '');
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l.drawingRename),
      content: TextField(
        key: const Key('drawing-copy-name'),
        controller: name,
        autofocus: true,
        maxLength: 60,
        decoration: InputDecoration(
          labelText: l.drawingNameLabel,
          hintText: l.drawingCopyName(layout.number),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.drawingCancel),
        ),
        FilledButton(
          key: const Key('drawing-copy-name-save'),
          onPressed: () => Navigator.of(context).pop(name.text),
          child: Text(l.drawingSave),
        ),
      ],
    ),
  ).whenComplete(name.dispose);
}

Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String body,
  required String action,
}) async {
  final l = AppLocalizations.of(context);
  final sure = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l.drawingCancel),
        ),
        FilledButton(
          key: const Key('drawing-confirm'),
          style: FilledButton.styleFrom(backgroundColor: context.cp.negative),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(action),
        ),
      ],
    ),
  );
  return sure ?? false;
}
