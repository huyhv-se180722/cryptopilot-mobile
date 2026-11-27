/// The tools of the drawing bar (D-149 (2)), as the web's `tools.ts` names
/// them: the chart page knows each id and what it places. A ray and an
/// extended line are trend lines whose style extends them.
enum DrawingTool {
  trendLine('TREND_LINE'),
  ray('TREND_LINE'),
  extendedLine('TREND_LINE'),
  horizontalLine('HORIZONTAL_LINE'),
  horizontalRay('HORIZONTAL_RAY'),
  verticalLine('VERTICAL_LINE'),
  parallelChannel('PARALLEL_CHANNEL'),
  arrow('ARROW'),
  fibRetracement('FIB_RETRACEMENT'),
  fibExtension('FIB_EXTENSION'),
  rectangle('RECTANGLE'),
  longPosition('LONG_POSITION'),
  shortPosition('SHORT_POSITION'),
  priceRange('PRICE_RANGE'),
  dateRange('DATE_RANGE'),
  text('TEXT'),
  xabcd('XABCD_PATTERN'),
  cypher('CYPHER_PATTERN'),
  abcd('ABCD_PATTERN'),
  threeDrives('THREE_DRIVES_PATTERN'),
  headAndShoulders('HEAD_AND_SHOULDERS'),
  trianglePattern('TRIANGLE_PATTERN'),
  elliottImpulse('ELLIOTT_IMPULSE_WAVE'),
  elliottCorrection('ELLIOTT_CORRECTION_WAVE'),
  elliottTriangle('ELLIOTT_TRIANGLE_WAVE'),
  elliottDoubleCombo('ELLIOTT_DOUBLE_COMBO'),
  elliottTripleCombo('ELLIOTT_TRIPLE_COMBO');

  const DrawingTool(this.type);

  /// The backend's `DrawingType`.
  final String type;

  /// The tool a saved drawing was made with, for its settings title.
  static DrawingTool ofDrawing(
    String type, {
    required bool extendLeft,
    required bool extendRight,
  }) {
    if (type == 'TREND_LINE') {
      if (extendLeft && extendRight) return extendedLine;
      if (extendRight) return ray;
      return trendLine;
    }
    return values.firstWhere(
      (tool) => tool.type == type,
      orElse: () => trendLine,
    );
  }
}

/// The groups of the bar, in the web's order.
enum DrawingToolGroup {
  lines([
    DrawingTool.trendLine,
    DrawingTool.ray,
    DrawingTool.extendedLine,
    DrawingTool.horizontalLine,
    DrawingTool.horizontalRay,
    DrawingTool.verticalLine,
    DrawingTool.parallelChannel,
    DrawingTool.arrow,
  ]),
  fibonacci([DrawingTool.fibRetracement, DrawingTool.fibExtension]),
  shapes([DrawingTool.rectangle]),
  positions([DrawingTool.longPosition, DrawingTool.shortPosition]),
  measure([DrawingTool.priceRange, DrawingTool.dateRange]),
  patterns([
    DrawingTool.xabcd,
    DrawingTool.cypher,
    DrawingTool.abcd,
    DrawingTool.threeDrives,
    DrawingTool.headAndShoulders,
    DrawingTool.trianglePattern,
  ]),
  elliott([
    DrawingTool.elliottImpulse,
    DrawingTool.elliottCorrection,
    DrawingTool.elliottTriangle,
    DrawingTool.elliottDoubleCombo,
    DrawingTool.elliottTripleCombo,
  ]),
  annotation([DrawingTool.text]);

  const DrawingToolGroup(this.tools);

  final List<DrawingTool> tools;
}

/// Types whose zone is filled.
const filledTypes = {
  'RECTANGLE',
  'PARALLEL_CHANNEL',
  'PRICE_RANGE',
  'DATE_RANGE',
  'XABCD_PATTERN',
  'CYPHER_PATTERN',
  'HEAD_AND_SHOULDERS',
  'TRIANGLE_PATTERN',
};

/// Drawings that show a note written in their settings.
const notedTypes = {
  'TREND_LINE',
  'ARROW',
  'HORIZONTAL_LINE',
  'HORIZONTAL_RAY',
  'VERTICAL_LINE',
  'RECTANGLE',
  'TEXT',
};

/// Types whose line may extend past its anchors.
const extendableTypes = {
  'TREND_LINE',
  'RECTANGLE',
  'PARALLEL_CHANNEL',
  'FIB_RETRACEMENT',
  'FIB_EXTENSION',
};

/// The palette of the floating bar (`#RRGGBB`).
const drawingPalette = [
  '#2962FF',
  '#26A69A',
  '#EF5350',
  '#FF9800',
  '#9C27B0',
  '#787B86',
  '#FFFFFF',
  '#000000',
];

const drawingWidths = [1, 2, 3, 4];

/// D-161: the font sizes a text drawing may take.
const minFontSize = 12;
const maxFontSize = 48;

/// D-149 (2): a text holds at most this many characters.
const maxTextLength = 500;
