import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/cp_colors.dart';
import '../application/drawing_board_controller.dart';
import '../domain/drawing.dart';
import '../domain/drawing_tools.dart';
import 'drawing_labels.dart';

/// A horseshoe magnet: Material has no icon for it.
class MagnetIcon extends StatelessWidget {
  const MagnetIcon({required this.color, super.key});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final size = IconTheme.of(context).size ?? 24;
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _MagnetPainter(color)),
    );
  }
}

class _MagnetPainter extends CustomPainter {
  _MagnetPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * s
      ..strokeCap = StrokeCap.round;
    // Legs up, the bend at the bottom, tilted like the web's icon.
    canvas
      ..save()
      ..translate(12 * s, 12 * s)
      ..rotate(0.785398) // 45 degrees
      ..translate(-12 * s, -12 * s);
    final body = Path()
      ..moveTo(5 * s, 3 * s)
      ..lineTo(5 * s, 13 * s)
      ..arcToPoint(
        Offset(19 * s, 13 * s),
        radius: Radius.circular(7 * s),
        clockwise: false,
      )
      ..lineTo(19 * s, 3 * s)
      ..moveTo(9 * s, 3 * s)
      ..lineTo(9 * s, 13 * s)
      ..arcToPoint(
        Offset(15 * s, 13 * s),
        radius: Radius.circular(3 * s),
        clockwise: false,
      )
      ..lineTo(15 * s, 3 * s)
      ..moveTo(5 * s, 3 * s)
      ..lineTo(9 * s, 3 * s)
      ..moveTo(15 * s, 3 * s)
      ..lineTo(19 * s, 3 * s)
      // The poles.
      ..moveTo(5 * s, 7 * s)
      ..lineTo(9 * s, 7 * s)
      ..moveTo(15 * s, 7 * s)
      ..lineTo(19 * s, 7 * s);
    canvas
      ..drawPath(body, paint)
      ..restore();
  }

  @override
  bool shouldRepaint(_MagnetPainter old) => old.color != color;
}

/// The tool bar on the left of the Chart screen (D-149 (3)): one button per
/// group, which opens the group's tools; magnet, undo, redo and the cancel
/// of the tool in hand below.
class DrawingRail extends ConsumerWidget {
  const DrawingRail({required this.pairId, super.key});

  final String pairId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final cp = context.cp;
    final board = ref.watch(drawingBoardProvider(pairId));
    final controller = ref.read(drawingBoardProvider(pairId).notifier);
    final tool = board.tool;
    final enabled = board.ready && board.failure == null;
    return Material(
      key: const Key('drawing-rail'),
      color: cp.surface,
      child: SizedBox(
        width: 48,
        child: SingleChildScrollView(
          child: Column(
            children: [
              for (final group in DrawingToolGroup.values)
                IconButton(
                  key: Key('drawing-group-${group.name}'),
                  tooltip: group.label(l),
                  isSelected: tool != null && group.tools.contains(tool),
                  color: cp.muted,
                  selectedIcon: Icon(group.icon, color: cp.primary),
                  icon: Icon(group.icon),
                  onPressed: enabled
                      ? () => unawaited(_pick(context, ref, group))
                      : null,
                ),
              const Divider(height: 8, indent: 10, endIndent: 10),
              // Within reach as on the web's bar; the options menu has it too.
              IconButton(
                key: const Key('drawing-magnet'),
                tooltip: l.drawingMagnet,
                isSelected: board.options.magnet,
                icon: MagnetIcon(color: cp.muted),
                selectedIcon: MagnetIcon(color: cp.primary),
                onPressed: () => controller.setOptions(
                  board.options.copyWith(magnet: !board.options.magnet),
                ),
              ),
              IconButton(
                key: const Key('drawing-undo'),
                tooltip: l.drawingUndo,
                icon: const Icon(Icons.undo),
                onPressed: board.canUndo ? controller.undo : null,
              ),
              IconButton(
                key: const Key('drawing-redo'),
                tooltip: l.drawingRedo,
                icon: const Icon(Icons.redo),
                onPressed: board.canRedo ? controller.redo : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pick(
    BuildContext context,
    WidgetRef ref,
    DrawingToolGroup group,
  ) async {
    final l = AppLocalizations.of(context);
    final current = ref.read(drawingBoardProvider(pairId)).tool;
    final picked = await showModalBottomSheet<DrawingTool>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          key: Key('drawing-tools-${group.name}'),
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                group.label(l),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            for (final tool in group.tools)
              ListTile(
                key: Key('drawing-tool-${tool.name}'),
                leading: Icon(group.icon),
                title: Text(tool.label(l)),
                trailing: tool == current ? const Icon(Icons.check) : null,
                onTap: () => Navigator.of(context).pop(tool),
              ),
          ],
        ),
      ),
    );
    if (picked != null) {
      ref.read(drawingBoardProvider(pairId).notifier).setTool(picked);
    }
  }
}

/// While a tool is in hand: what to do, and Cancel.
class DrawingHint extends StatelessWidget {
  const DrawingHint({required this.tool, required this.onCancel, super.key});

  final DrawingTool tool;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cp = context.cp;
    return Material(
      key: const Key('drawing-hint'),
      color: cp.raised,
      elevation: 2,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.only(left: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                l.drawingPlaceHint(tool.label(l)),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            TextButton(
              key: const Key('drawing-cancel'),
              onPressed: onCancel,
              child: Text(l.drawingCancel),
            ),
          ],
        ),
      ),
    );
  }
}

/// The bar of the selected drawing (D-149 (3)): colour, width, line style,
/// settings, lock, hide and remove.
class DrawingFloatingBar extends ConsumerWidget {
  const DrawingFloatingBar({
    required this.pairId,
    required this.drawing,
    super.key,
  });

  final String pairId;
  final ChartDrawing drawing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final cp = context.cp;
    final board = ref.read(drawingBoardProvider(pairId).notifier);
    final style = drawing.style;
    void edit(DrawingChange Function(DrawingChange) change) =>
        board.updateSelected(change);
    return Material(
      key: const Key('drawing-floating-bar'),
      color: cp.surface,
      elevation: 3,
      borderRadius: BorderRadius.circular(8),
      child: Semantics(
        label: l.drawingSelected,
        container: true,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PopupMenuButton<String>(
                key: const Key('drawing-color'),
                tooltip: l.drawingColor,
                icon: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: colorOf(style.lineColor),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: cp.border),
                  ),
                ),
                onSelected: (color) => edit(
                  (c) => c.copyWith(
                    style: c.style.copyWith(
                      lineColor: color,
                      fillColor: recolorFill(c.style.fillColor, color),
                    ),
                  ),
                ),
                itemBuilder: (_) => [
                  for (final color in drawingPalette)
                    PopupMenuItem(
                      value: color,
                      child: Row(
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: colorOf(color),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: cp.border),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(color),
                        ],
                      ),
                    ),
                ],
              ),
              PopupMenuButton<int>(
                key: const Key('drawing-width'),
                tooltip: l.drawingWidth,
                icon: Text(l.drawingWidthOption(style.lineWidth)),
                onSelected: (width) => edit(
                  (c) => c.copyWith(style: c.style.copyWith(lineWidth: width)),
                ),
                itemBuilder: (_) => [
                  for (final width in drawingWidths)
                    CheckedPopupMenuItem(
                      value: width,
                      checked: width == style.lineWidth,
                      child: Text(l.drawingWidthOption(width)),
                    ),
                ],
              ),
              PopupMenuButton<DrawingLineStyle>(
                key: const Key('drawing-line-style'),
                tooltip: l.drawingLineStyle,
                icon: const Icon(Icons.line_style),
                onSelected: (line) => edit(
                  (c) => c.copyWith(style: c.style.copyWith(lineStyle: line)),
                ),
                itemBuilder: (_) => [
                  for (final line in DrawingLineStyle.values)
                    CheckedPopupMenuItem(
                      value: line,
                      checked: line == style.lineStyle,
                      child: Text(line.label(l)),
                    ),
                ],
              ),
              IconButton(
                key: const Key('drawing-settings'),
                tooltip: l.drawingSettings,
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => unawaited(
                  showDrawingSettings(context, ref, pairId, drawing),
                ),
              ),
              IconButton(
                key: const Key('drawing-lock'),
                tooltip: drawing.locked ? l.drawingUnlock : l.drawingLock,
                isSelected: drawing.locked,
                selectedIcon: Icon(Icons.lock, color: cp.primary),
                icon: const Icon(Icons.lock_open),
                onPressed: () =>
                    edit((c) => c.copyWith(locked: !drawing.locked)),
              ),
              IconButton(
                key: const Key('drawing-hide'),
                tooltip: l.drawingHide,
                icon: const Icon(Icons.visibility_off_outlined),
                onPressed: () => edit((c) => c.copyWith(hidden: true)),
              ),
              IconButton(
                key: const Key('drawing-remove'),
                tooltip: l.drawingRemove,
                icon: Icon(Icons.delete_outline, color: cp.negative),
                onPressed: drawing.locked ? null : board.removeSelected,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The settings of a drawing (D-149 (3)): exact prices, text, font size,
/// extension and fill, saved together.
Future<void> showDrawingSettings(
  BuildContext context,
  WidgetRef ref,
  String pairId,
  ChartDrawing drawing,
) async {
  final change = await showModalBottomSheet<DrawingChange>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _SettingsSheet(drawing: drawing),
  );
  if (change != null) {
    ref
        .read(drawingBoardProvider(pairId).notifier)
        .updateSelected((_) => change);
  }
}

class _SettingsSheet extends StatefulWidget {
  const _SettingsSheet({required this.drawing});

  final ChartDrawing drawing;

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  final _form = GlobalKey<FormState>();
  late final List<TextEditingController> _prices = [
    for (final point in widget.drawing.points)
      TextEditingController(text: point.price),
  ];
  late final _text = TextEditingController(text: widget.drawing.change.text);
  late int _fontSize = widget.drawing.style.fontSize ?? 14;
  late bool _extendLeft = widget.drawing.style.extendLeft;
  late bool _extendRight = widget.drawing.style.extendRight;
  late bool _fill = widget.drawing.style.fillColor != null;
  String? _positionError;

  ChartDrawing get _drawing => widget.drawing;
  bool get _position =>
      _drawing.type == 'LONG_POSITION' || _drawing.type == 'SHORT_POSITION';

  @override
  void dispose() {
    for (final price in _prices) {
      price.dispose();
    }
    _text.dispose();
    super.dispose();
  }

  String _priceLabel(AppLocalizations l, int i) {
    if (!_position) return l.drawingPointPrice(i + 1);
    return switch (i) {
      0 => l.drawingEntryPrice,
      1 => l.drawingStopPrice,
      _ => l.drawingTargetPrice,
    };
  }

  void _save() {
    final l = AppLocalizations.of(context);
    setState(() => _positionError = null);
    if (!(_form.currentState?.validate() ?? false)) return;
    final prices = [
      for (final price in _prices) Decimal.parse(price.text.trim()),
    ];
    if (_position) {
      final [entry, stop, target] = prices;
      final valid = _drawing.type == 'LONG_POSITION'
          ? stop < entry && entry < target
          : target < entry && entry < stop;
      if (!valid) {
        setState(() => _positionError = l.drawingInvalidPosition);
        return;
      }
    }
    final style = _drawing.style;
    final type = _drawing.type;
    final change = _drawing.change;
    final text = _text.text.trim();
    Navigator.of(context).pop(
      DrawingChange(
        points: [
          for (final (i, point) in _drawing.points.indexed)
            point.withPrice(_prices[i].text.trim()),
        ],
        text: notedTypes.contains(type)
            ? (text.isEmpty ? null : text)
            : change.text,
        locked: change.locked,
        hidden: change.hidden,
        style: style.copyWith(
          fontSize: type == 'TEXT' ? _fontSize : null,
          extendLeft: extendableTypes.contains(type) ? _extendLeft : null,
          extendRight: extendableTypes.contains(type) ? _extendRight : null,
          fillColor: filledTypes.contains(type) && _fill
              ? style.fillColor ?? recolorFill('#00000033', style.lineColor)
              : null,
          clearFill: filledTypes.contains(type) && !_fill,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final type = _drawing.type;
    // A vertical line keeps no price of its own.
    final priced = type != 'VERTICAL_LINE';
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            key: const Key('drawing-settings-sheet'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l.drawingSettingsTitle(toolOf(_drawing).label(l)),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              if (priced)
                for (final (i, price) in _prices.indexed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: TextFormField(
                      key: Key('drawing-price-$i'),
                      controller: price,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      decoration: InputDecoration(labelText: _priceLabel(l, i)),
                      validator: (value) {
                        final parsed = Decimal.tryParse(value?.trim() ?? '');
                        return parsed == null || parsed <= Decimal.zero
                            ? l.drawingInvalidPrice
                            : null;
                      },
                    ),
                  ),
              if (_positionError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _positionError!,
                    key: const Key('drawing-position-error'),
                    style: TextStyle(color: context.cp.negative),
                  ),
                ),
              if (notedTypes.contains(type))
                TextFormField(
                  key: const Key('drawing-text'),
                  controller: _text,
                  maxLength: maxTextLength,
                  maxLines: 3,
                  minLines: 1,
                  decoration: InputDecoration(
                    labelText: l.drawingText,
                    hintText: l.drawingTextPlaceholder,
                  ),
                ),
              if (type == 'TEXT') ...[
                Text(l.drawingFontSize),
                Slider(
                  key: const Key('drawing-font-size'),
                  value: _fontSize.toDouble(),
                  min: minFontSize.toDouble(),
                  max: maxFontSize.toDouble(),
                  divisions: maxFontSize - minFontSize,
                  label: '$_fontSize',
                  onChanged: (value) =>
                      setState(() => _fontSize = value.round()),
                ),
              ],
              if (extendableTypes.contains(type)) ...[
                SwitchListTile(
                  key: const Key('drawing-extend-left'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.drawingExtendLeft),
                  value: _extendLeft,
                  onChanged: (value) => setState(() => _extendLeft = value),
                ),
                SwitchListTile(
                  key: const Key('drawing-extend-right'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.drawingExtendRight),
                  value: _extendRight,
                  onChanged: (value) => setState(() => _extendRight = value),
                ),
              ],
              if (filledTypes.contains(type))
                SwitchListTile(
                  key: const Key('drawing-fill'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.drawingFill),
                  value: _fill,
                  onChanged: (value) => setState(() => _fill = value),
                ),
              const SizedBox(height: 8),
              FilledButton(
                key: const Key('drawing-settings-save'),
                onPressed: _save,
                child: Text(l.drawingSave),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The text of a text drawing just placed; null when cancelled.
Future<String?> showDrawingTextDialog(BuildContext context) =>
    showDialog<String>(
      context: context,
      builder: (context) => const _TextDialog(),
    );

class _TextDialog extends StatefulWidget {
  const _TextDialog();

  @override
  State<_TextDialog> createState() => _TextDialogState();
}

class _TextDialogState extends State<_TextDialog> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.drawingTextTitle),
      content: TextField(
        key: const Key('drawing-text-input'),
        controller: _text,
        autofocus: true,
        maxLength: maxTextLength,
        maxLines: 4,
        minLines: 1,
        decoration: InputDecoration(hintText: l.drawingTextPlaceholder),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.drawingCancel),
        ),
        ListenableBuilder(
          listenable: _text,
          builder: (context, _) => FilledButton(
            key: const Key('drawing-text-add'),
            onPressed: _text.text.trim().isEmpty
                ? null
                : () => Navigator.of(context).pop(_text.text),
            child: Text(l.drawingAdd),
          ),
        ),
      ],
    );
  }
}
