import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../domain/drawing.dart';
import '../domain/drawing_tools.dart';

/// The names and icons of the drawing bar (D-149 (1): the web's behaviour
/// and layout, never TradingView's icons).
extension DrawingToolLabel on DrawingTool {
  String label(AppLocalizations l) => switch (this) {
    DrawingTool.trendLine => l.drawingToolTrendLine,
    DrawingTool.ray => l.drawingToolRay,
    DrawingTool.extendedLine => l.drawingToolExtendedLine,
    DrawingTool.horizontalLine => l.drawingToolHorizontalLine,
    DrawingTool.horizontalRay => l.drawingToolHorizontalRay,
    DrawingTool.verticalLine => l.drawingToolVerticalLine,
    DrawingTool.parallelChannel => l.drawingToolParallelChannel,
    DrawingTool.arrow => l.drawingToolArrow,
    DrawingTool.fibRetracement => l.drawingToolFibRetracement,
    DrawingTool.fibExtension => l.drawingToolFibExtension,
    DrawingTool.rectangle => l.drawingToolRectangle,
    DrawingTool.longPosition => l.drawingToolLongPosition,
    DrawingTool.shortPosition => l.drawingToolShortPosition,
    DrawingTool.priceRange => l.drawingToolPriceRange,
    DrawingTool.dateRange => l.drawingToolDateRange,
    DrawingTool.text => l.drawingToolText,
    DrawingTool.xabcd => l.drawingToolXabcd,
    DrawingTool.cypher => l.drawingToolCypher,
    DrawingTool.abcd => l.drawingToolAbcd,
    DrawingTool.threeDrives => l.drawingToolThreeDrives,
    DrawingTool.headAndShoulders => l.drawingToolHeadAndShoulders,
    DrawingTool.trianglePattern => l.drawingToolTrianglePattern,
    DrawingTool.elliottImpulse => l.drawingToolElliottImpulse,
    DrawingTool.elliottCorrection => l.drawingToolElliottCorrection,
    DrawingTool.elliottTriangle => l.drawingToolElliottTriangle,
    DrawingTool.elliottDoubleCombo => l.drawingToolElliottDoubleCombo,
    DrawingTool.elliottTripleCombo => l.drawingToolElliottTripleCombo,
  };
}

extension DrawingToolGroupLabel on DrawingToolGroup {
  String label(AppLocalizations l) => switch (this) {
    DrawingToolGroup.lines => l.drawingGroupLines,
    DrawingToolGroup.fibonacci => l.drawingGroupFibonacci,
    DrawingToolGroup.shapes => l.drawingGroupShapes,
    DrawingToolGroup.positions => l.drawingGroupPositions,
    DrawingToolGroup.measure => l.drawingGroupMeasure,
    DrawingToolGroup.patterns => l.drawingGroupPatterns,
    DrawingToolGroup.elliott => l.drawingGroupElliott,
    DrawingToolGroup.annotation => l.drawingGroupAnnotation,
  };

  IconData get icon => switch (this) {
    DrawingToolGroup.lines => Icons.show_chart,
    DrawingToolGroup.fibonacci => Icons.stacked_line_chart,
    DrawingToolGroup.shapes => Icons.crop_square,
    DrawingToolGroup.positions => Icons.swap_vert,
    DrawingToolGroup.measure => Icons.straighten,
    DrawingToolGroup.patterns => Icons.timeline,
    DrawingToolGroup.elliott => Icons.waves,
    DrawingToolGroup.annotation => Icons.text_fields,
  };
}

extension DrawingLineStyleLabel on DrawingLineStyle {
  String label(AppLocalizations l) => switch (this) {
    DrawingLineStyle.solid => l.drawingLineSolid,
    DrawingLineStyle.dashed => l.drawingLineDashed,
    DrawingLineStyle.dotted => l.drawingLineDotted,
  };
}

/// "Copy n" until the Trader names it.
String layoutName(AppLocalizations l, ChartLayout layout) {
  final name = layout.name?.trim();
  return name == null || name.isEmpty ? l.drawingCopyName(layout.number) : name;
}

/// `#RRGGBB` or `#RRGGBBAA` as a colour.
Color colorOf(String hex) {
  final digits = hex.replaceFirst('#', '');
  final rgb = int.tryParse(digits.substring(0, 6), radix: 16) ?? 0x2962FF;
  final alpha = digits.length >= 8
      ? int.tryParse(digits.substring(6, 8), radix: 16) ?? 0xFF
      : 0xFF;
  return Color((alpha << 24) | rgb);
}

/// A zone's fill in [color], keeping the fill's own transparency (`33`, a
/// fifth, when it has none); null stays null.
String? recolorFill(String? fill, String color) {
  if (fill == null) return null;
  final alpha = fill.length >= 9 ? fill.substring(7, 9) : '33';
  return '${color.substring(0, 7)}$alpha';
}

/// The tool a drawing was made with, for its settings title.
DrawingTool toolOf(ChartDrawing drawing) => DrawingTool.ofDrawing(
  drawing.type,
  extendLeft: drawing.style.extendLeft,
  extendRight: drawing.style.extendRight,
);
