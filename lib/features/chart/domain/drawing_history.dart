import 'drawing.dart';

/// A change the Trader made, kept so it can be undone and done again.
sealed class HistoryEntry {
  const HistoryEntry();
}

class CreatedEntry extends HistoryEntry {
  const CreatedEntry(this.drawing);

  final ChartDrawing drawing;
}

class UpdatedEntry extends HistoryEntry {
  const UpdatedEntry(this.id, this.before, this.after);

  final String id;
  final DrawingChange before;
  final DrawingChange after;
}

class RemovedEntry extends HistoryEntry {
  const RemovedEntry(this.drawing);

  final ChartDrawing drawing;
}

/// Undo and redo stacks of one copy (D-149 (3)), as the web's `history.ts`.
/// A removed drawing comes back under a new id, so every entry naming the
/// old one is rewritten.
class DrawingHistory {
  static const limit = 50;

  final _past = <HistoryEntry>[];
  final _future = <HistoryEntry>[];

  bool get canUndo => _past.isNotEmpty;
  bool get canRedo => _future.isNotEmpty;

  /// A new change: what could be redone is forgotten.
  void record(HistoryEntry entry) {
    _past.add(entry);
    if (_past.length > limit) _past.removeAt(0);
    _future.clear();
  }

  HistoryEntry? takeUndo() => _past.isEmpty ? null : _past.removeLast();

  HistoryEntry? takeRedo() => _future.isEmpty ? null : _future.removeLast();

  /// Puts an undone entry where redo finds it.
  void undone(HistoryEntry entry) => _future.add(entry);

  /// Puts a redone entry where undo finds it, keeping what remains to redo.
  void redone(HistoryEntry entry) => _past.add(entry);

  /// An entry whose undo or redo could not be saved, to be tried again.
  void putBack({required bool undo, required HistoryEntry entry}) =>
      undo ? _past.add(entry) : _future.add(entry);

  /// Rewrites every entry that names [from] to name [to].
  void rename(ChartDrawing from, ChartDrawing to) {
    HistoryEntry swap(HistoryEntry entry) => switch (entry) {
      UpdatedEntry(:final id) when id == from.id => UpdatedEntry(
        to.id,
        entry.before,
        entry.after,
      ),
      CreatedEntry(:final drawing) when drawing.id == from.id => CreatedEntry(
        to,
      ),
      RemovedEntry(:final drawing) when drawing.id == from.id => RemovedEntry(
        to,
      ),
      _ => entry,
    };
    for (final list in [_past, _future]) {
      for (var i = 0; i < list.length; i++) {
        list[i] = swap(list[i]);
      }
    }
  }

  void clear() {
    _past.clear();
    _future.clear();
  }
}
