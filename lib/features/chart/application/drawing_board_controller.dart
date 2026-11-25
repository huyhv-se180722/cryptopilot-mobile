import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_failure.dart';
import '../../../core/settings/settings.dart';
import '../../../core/state/load_after_build.dart';
import '../data/chart_drawing_api.dart';
import '../domain/drawing.dart';
import '../domain/drawing_history.dart';
import '../domain/drawing_tools.dart';

/// The switches of the drawing bar, remembered on the device.
@immutable
class DrawingOptions {
  const DrawingOptions({
    this.magnet = false,
    this.stayInDrawing = false,
    this.lockAll = false,
    this.hideAll = false,
  });

  factory DrawingOptions.parse(String? saved) {
    try {
      final json = saved == null ? null : jsonDecode(saved);
      if (json is! Map) return const DrawingOptions();
      return DrawingOptions(
        magnet: json['magnet'] == true,
        stayInDrawing: json['stayInDrawing'] == true,
        lockAll: json['lockAll'] == true,
        hideAll: json['hideAll'] == true,
      );
    } on FormatException {
      return const DrawingOptions();
    }
  }

  final bool magnet;
  final bool stayInDrawing;
  final bool lockAll;
  final bool hideAll;

  DrawingOptions copyWith({
    bool? magnet,
    bool? stayInDrawing,
    bool? lockAll,
    bool? hideAll,
  }) => DrawingOptions(
    magnet: magnet ?? this.magnet,
    stayInDrawing: stayInDrawing ?? this.stayInDrawing,
    lockAll: lockAll ?? this.lockAll,
    hideAll: hideAll ?? this.hideAll,
  );

  Map<String, Object?> toJson() => {
    'magnet': magnet,
    'stayInDrawing': stayInDrawing,
    'lockAll': lockAll,
    'hideAll': hideAll,
  };

  @override
  bool operator ==(Object other) =>
      other is DrawingOptions &&
      other.magnet == magnet &&
      other.stayInDrawing == stayInDrawing &&
      other.lockAll == lockAll &&
      other.hideAll == hideAll;

  @override
  int get hashCode => Object.hash(magnet, stayInDrawing, lockAll, hideAll);
}

/// What the screen tells the Trader once, as a snack bar.
enum DrawingNotice {
  /// A write failed: the change was taken back and the drawings read again.
  saveFailed,

  /// MSG43: the copy holds 200 drawings.
  drawingLimit,

  /// MSG43: the pair holds 10 copies.
  layoutLimit,

  /// A copy could not be opened, renamed or removed.
  layoutFailed,
}

@immutable
class DrawingBoardState {
  const DrawingBoardState({
    this.layouts,
    this.activeId,
    this.drawings,
    this.failure,
    this.selectedId,
    this.tool,
    this.options = const DrawingOptions(),
    this.canUndo = false,
    this.canRedo = false,
    this.textDraft,
    this.notice,
    this.noticeCount = 0,
  });

  /// By number; null until read.
  final List<ChartLayout>? layouts;
  final String? activeId;

  /// Of the copy shown; null while it is read. A pair without copies has
  /// none, and its first drawing opens "Copy 1".
  final List<ChartDrawing>? drawings;

  /// The copies or drawings could not be read.
  final ApiFailure? failure;
  final String? selectedId;
  final DrawingTool? tool;
  final DrawingOptions options;
  final bool canUndo;
  final bool canRedo;

  /// A text drawing waits for its text.
  final DrawingDraft? textDraft;

  /// The last notice; [noticeCount] tells a repeated one apart.
  final DrawingNotice? notice;
  final int noticeCount;

  bool get ready => layouts != null && (activeId == null || drawings != null);

  ChartLayout? get active =>
      layouts?.where((layout) => layout.id == activeId).firstOrNull;

  bool get full => (layouts?.length ?? 0) >= ChartLayout.maxPerPair;

  List<ChartDrawing> get shown => drawings ?? const [];

  ChartDrawing? get selected =>
      shown.where((drawing) => drawing.id == selectedId).firstOrNull;

  int get hiddenCount => shown.where((drawing) => drawing.hidden).length;

  DrawingBoardState copyWith({
    List<ChartLayout>? layouts,
    String? activeId,
    bool clearActive = false,
    List<ChartDrawing>? drawings,
    bool clearDrawings = false,
    ApiFailure? failure,
    bool clearFailure = false,
    String? selectedId,
    bool clearSelected = false,
    DrawingTool? tool,
    bool clearTool = false,
    DrawingOptions? options,
    bool? canUndo,
    bool? canRedo,
    DrawingDraft? textDraft,
    bool clearTextDraft = false,
    DrawingNotice? notice,
  }) => DrawingBoardState(
    layouts: layouts ?? this.layouts,
    activeId: clearActive ? null : activeId ?? this.activeId,
    drawings: clearDrawings ? null : drawings ?? this.drawings,
    failure: clearFailure ? null : failure ?? this.failure,
    selectedId: clearSelected ? null : selectedId ?? this.selectedId,
    tool: clearTool ? null : tool ?? this.tool,
    options: options ?? this.options,
    canUndo: canUndo ?? this.canUndo,
    canRedo: canRedo ?? this.canRedo,
    textDraft: clearTextDraft ? null : textDraft ?? this.textDraft,
    notice: notice ?? this.notice,
    noticeCount: notice == null ? noticeCount : noticeCount + 1,
  );
}

final drawingBoardProvider = NotifierProvider.autoDispose
    .family<DrawingBoardController, DrawingBoardState, String>(
      DrawingBoardController.new,
    );

/// The Trader's drawings on one pair's chart (D-149, T-153), as the web's
/// `useDrawingLayer`: the copies of the pair and the one shown (remembered
/// on the device), the drawings of that copy, the tool in hand and an undo
/// history per copy.
///
/// Every change shows at once and is saved in the background; writes run one
/// after another, so an update always sends the version the last one
/// returned. A failed write takes its change back, reads the drawings again
/// and raises [DrawingNotice.saveFailed].
class DrawingBoardController extends Notifier<DrawingBoardState> {
  DrawingBoardController(this.pairId);

  final String pairId;

  static const optionsKey = 'chart_drawing_options';
  static String layoutKey(String pairId) => 'chart_layout:$pairId';

  final _histories = <String, DrawingHistory>{};
  Future<void> _queue = Future.value();
  Future<ChartLayout>? _opening;

  ChartDrawingApi get _api => ref.read(chartDrawingApiProvider);
  SettingsStore get _settings => ref.read(settingsStoreProvider);

  @override
  DrawingBoardState build() {
    ref.loadAfterBuild(load);
    return const DrawingBoardState();
  }

  /// Reads the copies, then the drawings of the one shown.
  Future<void> load() async {
    final saved = DrawingOptions.parse(await _settings.read(optionsKey));
    if (!ref.mounted) return;
    state = state.copyWith(options: saved);
    try {
      final layouts = await _api.layouts(pairId);
      final remembered = await _settings.read(layoutKey(pairId));
      if (!ref.mounted) return;
      final active =
          layouts.where((layout) => layout.id == remembered).firstOrNull ??
          layouts.firstOrNull;
      state = state.copyWith(
        layouts: layouts,
        activeId: active?.id,
        clearActive: active == null,
        clearDrawings: true,
        clearFailure: true,
      );
      if (active != null) await _readDrawings(active.id);
    } on ApiFailure catch (failure) {
      if (ref.mounted) state = state.copyWith(failure: failure);
    }
  }

  Future<void> _readDrawings(String layoutId) async {
    try {
      final drawings = await _api.drawings(layoutId);
      if (!ref.mounted || state.activeId != layoutId) return;
      state = state.copyWith(drawings: drawings, clearFailure: true);
      _count(layoutId, drawings.length);
    } on ApiFailure catch (failure) {
      if (!ref.mounted || state.activeId != layoutId) return;
      // A list read once stays: only a list never read is an error.
      state = state.drawings == null ? state.copyWith(failure: failure) : state;
    }
  }

  void _count(String layoutId, int count) {
    final layouts = state.layouts;
    if (layouts == null) return;
    state = state.copyWith(
      layouts: [
        for (final layout in layouts)
          layout.id == layoutId && layout.drawings != count
              ? layout.copyWith(drawings: count)
              : layout,
      ],
    );
  }

  // ---- Copies ---------------------------------------------------------

  Future<void> selectLayout(String id) async {
    if (id == state.activeId) return;
    unawaited(_settings.write(layoutKey(pairId), id));
    state = state.copyWith(
      activeId: id,
      clearDrawings: true,
      clearSelected: true,
      clearTool: true,
    );
    _syncStacks();
    await _readDrawings(id);
  }

  /// Opens a copy, empty or a duplicate of the one shown, and shows it.
  Future<void> createLayout({bool duplicate = false}) async {
    try {
      final created = await _api.createLayout(
        pairId,
        copyFrom: duplicate ? state.activeId : null,
      );
      if (!ref.mounted) return;
      _putLayout(created);
      await selectLayout(created.id);
    } on ApiFailure catch (failure) {
      _layoutFailed(failure);
    }
  }

  Future<void> renameLayout(String id, String name) async {
    try {
      final trimmed = name.trim();
      final renamed = await _api.renameLayout(
        id,
        trimmed.isEmpty ? null : trimmed,
      );
      if (!ref.mounted) return;
      _putLayout(renamed);
    } on ApiFailure catch (failure) {
      _layoutFailed(failure);
    }
  }

  /// With its drawings; the lowest copy left is shown next.
  Future<void> removeLayout(String id) async {
    try {
      await _api.removeLayout(id);
      if (!ref.mounted) return;
      _histories.remove(id);
      final left = [...?state.layouts]..removeWhere((each) => each.id == id);
      state = state.copyWith(layouts: left);
      if (state.activeId == id) {
        final next = left.firstOrNull;
        if (next == null) {
          state = state.copyWith(
            clearActive: true,
            clearDrawings: true,
            clearSelected: true,
          );
          _syncStacks();
        } else {
          await selectLayout(next.id);
        }
      }
    } on ApiFailure catch (failure) {
      _layoutFailed(failure);
    }
  }

  void _putLayout(ChartLayout layout) {
    final others = [...?state.layouts]
      ..removeWhere((each) => each.id == layout.id);
    state = state.copyWith(
      layouts: [...others, layout]
        ..sort((a, b) => a.number.compareTo(b.number)),
    );
  }

  void _layoutFailed(ApiFailure failure) {
    if (!ref.mounted) return;
    final limit =
        failure is ProblemFailure &&
        failure.code == 'CHART_LAYOUT_LIMIT_REACHED';
    state = state.copyWith(
      notice: limit ? DrawingNotice.layoutLimit : DrawingNotice.layoutFailed,
    );
  }

  /// The copy shown, opening "Copy 1" first when the pair has none; a second
  /// drawing saved right after the first waits for the same copy.
  Future<String> _ensureLayout() async {
    final shown = state.activeId;
    if (shown != null) return shown;
    final opening = _opening ??= _api.createLayout(pairId).whenComplete(() {
      _opening = null;
    });
    final created = await opening;
    if (ref.mounted && state.activeId == null) {
      _putLayout(created);
      unawaited(_settings.write(layoutKey(pairId), created.id));
      state = state.copyWith(activeId: created.id, drawings: const []);
    }
    return created.id;
  }

  // ---- Tool bar -------------------------------------------------------

  void setTool(DrawingTool? tool) => state = tool == null
      ? state.copyWith(clearTool: true)
      : state.copyWith(tool: tool, clearSelected: true);

  void setOptions(DrawingOptions options) {
    state = state.copyWith(options: options, clearSelected: options.hideAll);
    unawaited(_settings.write(optionsKey, jsonEncode(options.toJson())));
  }

  // ---- What the chart page reports -----------------------------------

  void placed(DrawingDraft draft) {
    if (draft.type == 'TEXT') {
      state = state.copyWith(textDraft: draft);
    } else {
      unawaited(_create(draft));
    }
  }

  void toolDone() => state = state.copyWith(clearTool: true);

  void selected(String? id) => state = id == null
      ? state.copyWith(clearSelected: true)
      : state.copyWith(selectedId: id);

  void moved(String id, List<DrawingPoint> points) {
    final drawing = _find(id);
    if (drawing == null) return;
    _save(id, drawing.change, drawing.change.copyWith(points: points));
  }

  void removed(String id) {
    final drawing = _find(id);
    if (drawing != null) _remove(drawing);
  }

  // ---- Text ----------------------------------------------------------

  void submitText(String text) {
    final draft = state.textDraft;
    state = state.copyWith(clearTextDraft: true);
    final trimmed = text.trim();
    if (draft != null && trimmed.isNotEmpty) {
      unawaited(_create(draft.withText(trimmed)));
    }
  }

  void cancelText() => state = state.copyWith(clearTextDraft: true);

  // ---- The selected drawing ------------------------------------------

  void updateSelected(DrawingChange Function(DrawingChange) edit) {
    final drawing = state.selected;
    if (drawing == null) return;
    _save(drawing.id, drawing.change, edit(drawing.change));
  }

  void removeSelected() {
    final drawing = state.selected;
    if (drawing != null) _remove(drawing);
  }

  void showHidden() {
    for (final drawing in state.shown.where((each) => each.hidden)) {
      _save(drawing.id, drawing.change, drawing.change.copyWith(hidden: false));
    }
  }

  /// Every drawing of the copy shown, locked ones too (the screen confirms).
  void removeAll() {
    final layoutId = state.activeId;
    if (layoutId == null) return;
    final before = state.shown;
    _historyOf(layoutId).clear();
    _syncStacks();
    state = state.copyWith(drawings: const [], clearSelected: true);
    unawaited(
      _write(
        () => _api.removeAll(layoutId),
        undo: () => state = state.copyWith(drawings: before),
      ),
    );
  }

  // ---- Undo and redo -------------------------------------------------

  Future<void> undo() => _replay(undo: true);

  Future<void> redo() => _replay(undo: false);

  Future<void> _replay({required bool undo}) {
    final step = _queue.then((_) async {
      final layoutId = state.activeId;
      if (layoutId == null || !ref.mounted) return;
      final history = _historyOf(layoutId);
      final entry = undo ? history.takeUndo() : history.takeRedo();
      if (entry == null) return;
      void done(HistoryEntry next) =>
          undo ? history.undone(next) : history.redone(next);
      try {
        final removing = (entry is CreatedEntry) == undo;
        switch (entry) {
          case UpdatedEntry(:final id, :final before, :final after):
            await _put(id, undo ? before : after);
            done(entry);
          case CreatedEntry(:final drawing) || RemovedEntry(:final drawing)
              when removing:
            _drop(drawing.id);
            await _api.remove(drawing.id);
            done(entry);
          case CreatedEntry(:final drawing) || RemovedEntry(:final drawing):
            final back = await _api.create(
              layoutId,
              DrawingDraft(type: drawing.type, change: drawing.change),
            );
            _add(back);
            history.rename(drawing, back);
            done(
              entry is CreatedEntry ? CreatedEntry(back) : RemovedEntry(back),
            );
        }
      } on ApiFailure catch (failure) {
        // Not saved: the step stays where it was, to be tried again.
        history.putBack(undo: undo, entry: entry);
        await _failed(failure, layoutId);
      }
      _syncStacks();
    });
    _queue = step.catchError((Object _) {});
    return step;
  }

  // ---- Writes --------------------------------------------------------

  ChartDrawing? _find(String id) =>
      state.shown.where((drawing) => drawing.id == id).firstOrNull;

  DrawingHistory _historyOf(String layoutId) =>
      _histories.putIfAbsent(layoutId, DrawingHistory.new);

  void _record(HistoryEntry entry, String layoutId) {
    _historyOf(layoutId).record(entry);
    _syncStacks();
  }

  void _syncStacks() {
    if (!ref.mounted) return;
    final layoutId = state.activeId;
    final history = layoutId == null ? null : _histories[layoutId];
    state = state.copyWith(
      canUndo: history?.canUndo ?? false,
      canRedo: history?.canRedo ?? false,
    );
  }

  void _replace(ChartDrawing drawing) {
    state = state.copyWith(
      drawings: [
        for (final each in state.shown) each.id == drawing.id ? drawing : each,
      ],
    );
  }

  void _add(ChartDrawing drawing) {
    if (!ref.mounted || state.activeId != drawing.layoutId) return;
    state = state.copyWith(drawings: [...state.shown, drawing]);
    _count(drawing.layoutId, state.shown.length);
  }

  void _drop(String id) {
    state = state.copyWith(
      drawings: [...state.shown]..removeWhere((each) => each.id == id),
      clearSelected: state.selectedId == id,
    );
    final layoutId = state.activeId;
    if (layoutId != null) _count(layoutId, state.shown.length);
  }

  /// Shows [change] at once, then writes it with the version known then.
  Future<void> _put(String id, DrawingChange change) async {
    final current = _find(id);
    if (current == null) return;
    _replace(current.withChange(change));
    final saved = await _api.update(
      id,
      _find(id)?.version ?? current.version,
      change,
    );
    if (ref.mounted) _replace(saved);
  }

  Future<void> _create(DrawingDraft draft) => _write(() async {
    final layoutId = await _ensureLayout();
    final created = await _api.create(layoutId, draft);
    _add(created);
    // The first drawing of a pair opens its copy: record it there.
    _record(CreatedEntry(created), created.layoutId);
  });

  void _save(String id, DrawingChange before, DrawingChange after) {
    final layoutId = state.activeId;
    final previous = _find(id);
    if (layoutId == null || previous == null || before == after) return;
    _record(UpdatedEntry(id, before, after), layoutId);
    _replace(previous.withChange(after));
    unawaited(
      _write(
        () async {
          final saved = await _api.update(
            id,
            _find(id)?.version ?? previous.version,
            after,
          );
          if (ref.mounted) _replace(saved);
        },
        undo: () {
          if (_find(id) != null) _replace(previous);
        },
      ),
    );
  }

  void _remove(ChartDrawing drawing) {
    final layoutId = state.activeId;
    if (layoutId == null) return;
    final index = state.shown.indexWhere((each) => each.id == drawing.id);
    _record(RemovedEntry(drawing), layoutId);
    _drop(drawing.id);
    unawaited(
      _write(
        () => _api.remove(drawing.id),
        // Back in its place, so it is painted under and over the same ones.
        undo: () {
          if (_find(drawing.id) != null) return;
          final list = [...state.shown];
          list.insert(index.clamp(0, list.length), drawing);
          state = state.copyWith(drawings: list);
        },
      ),
    );
  }

  /// Runs [write] after the writes before it; on a failure takes the change
  /// back with [undo], reads the drawings again and raises a notice.
  Future<void> _write(Future<void> Function() write, {void Function()? undo}) {
    final layoutId = state.activeId;
    final next = _queue.then((_) async {
      try {
        await write();
      } on ApiFailure catch (failure) {
        if (!ref.mounted) return;
        undo?.call();
        await _failed(failure, layoutId ?? state.activeId);
      }
    });
    _queue = next.catchError((Object _) {});
    return next;
  }

  Future<void> _failed(ApiFailure failure, String? layoutId) async {
    if (!ref.mounted) return;
    final limit =
        failure is ProblemFailure &&
        failure.code == 'CHART_DRAWING_LIMIT_REACHED';
    state = state.copyWith(
      notice: limit ? DrawingNotice.drawingLimit : DrawingNotice.saveFailed,
    );
    if (layoutId != null && layoutId == state.activeId) {
      await _readDrawings(layoutId);
    }
  }
}
