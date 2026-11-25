import 'package:flutter/foundation.dart';

import '../../../core/json/json_read.dart';

/// The Trader's drawings on a pair's chart (D-149, T-153), as
/// `/chart-layouts` and `/chart-drawings` hold them (backend `develop`
/// `e02a7c3b`). Prices and Fibonacci levels stay decimal strings (D-141);
/// only the chart page turns them into numbers, to draw.

/// One anchor: a candle open time (UTC) and a price.
@immutable
class DrawingPoint {
  const DrawingPoint({required this.time, required this.price});

  factory DrawingPoint.fromJson(Object? body) {
    final json = asJsonObject(body, 'point');
    return DrawingPoint(
      time: readInstant(json, 'time'),
      price: _decimal(json, 'price'),
    );
  }

  final DateTime time;
  final String price;

  DrawingPoint withPrice(String price) =>
      DrawingPoint(time: time, price: price);

  Map<String, Object?> toJson() => {
    'time': time.toUtc().toIso8601String(),
    'price': price,
  };

  @override
  bool operator ==(Object other) =>
      other is DrawingPoint &&
      other.time.isAtSameMomentAs(time) &&
      other.price == price;

  @override
  int get hashCode => Object.hash(time.millisecondsSinceEpoch, price);
}

enum DrawingLineStyle { solid, dashed, dotted }

extension DrawingLineStyleWire on DrawingLineStyle {
  String get wire => name.toUpperCase();

  static DrawingLineStyle parse(String wire) =>
      DrawingLineStyle.values.firstWhere(
        (style) => style.wire == wire,
        orElse: () => throw DecodeException('lineStyle $wire is unknown'),
      );
}

@immutable
class DrawingStyle {
  const DrawingStyle({
    this.lineColor = '#2962FF',
    this.lineWidth = 2,
    this.lineStyle = DrawingLineStyle.solid,
    this.fillColor,
    this.extendLeft = false,
    this.extendRight = false,
    this.fontSize,
    this.fibLevels,
  });

  factory DrawingStyle.fromJson(Object? body) {
    final json = asJsonObject(body, 'style');
    final levels = json['fibLevels'];
    return DrawingStyle(
      lineColor: readString(json, 'lineColor'),
      lineWidth: _int(json, 'lineWidth'),
      lineStyle: DrawingLineStyleWire.parse(readString(json, 'lineStyle')),
      fillColor: readOptionalString(json, 'fillColor'),
      extendLeft: json['extendLeft'] == true,
      extendRight: json['extendRight'] == true,
      fontSize: json['fontSize'] == null ? null : _int(json, 'fontSize'),
      fibLevels: levels == null
          ? null
          : [
              for (final (i, level) in _list(levels, 'fibLevels').indexed)
                _decimalValue(level, 'fibLevels[$i]'),
            ],
    );
  }

  /// `#RRGGBB` or `#RRGGBBAA`.
  final String lineColor;

  /// 1…4 px.
  final int lineWidth;
  final DrawingLineStyle lineStyle;
  final String? fillColor;
  final bool extendLeft;
  final bool extendRight;

  /// 12…48 px, text only.
  final int? fontSize;

  /// null: the default levels of the tool.
  final List<String>? fibLevels;

  DrawingStyle copyWith({
    String? lineColor,
    int? lineWidth,
    DrawingLineStyle? lineStyle,
    String? fillColor,
    bool clearFill = false,
    bool? extendLeft,
    bool? extendRight,
    int? fontSize,
  }) => DrawingStyle(
    lineColor: lineColor ?? this.lineColor,
    lineWidth: lineWidth ?? this.lineWidth,
    lineStyle: lineStyle ?? this.lineStyle,
    fillColor: clearFill ? null : fillColor ?? this.fillColor,
    extendLeft: extendLeft ?? this.extendLeft,
    extendRight: extendRight ?? this.extendRight,
    fontSize: fontSize ?? this.fontSize,
    fibLevels: fibLevels,
  );

  Map<String, Object?> toJson() => {
    'lineColor': lineColor,
    'lineWidth': lineWidth,
    'lineStyle': lineStyle.wire,
    'fillColor': fillColor,
    'extendLeft': extendLeft,
    'extendRight': extendRight,
    'fontSize': fontSize,
    'fibLevels': fibLevels,
  };

  @override
  bool operator ==(Object other) =>
      other is DrawingStyle &&
      other.lineColor == lineColor &&
      other.lineWidth == lineWidth &&
      other.lineStyle == lineStyle &&
      other.fillColor == fillColor &&
      other.extendLeft == extendLeft &&
      other.extendRight == extendRight &&
      other.fontSize == fontSize &&
      listEquals(other.fibLevels, fibLevels);

  @override
  int get hashCode => Object.hash(
    lineColor,
    lineWidth,
    lineStyle,
    fillColor,
    extendLeft,
    extendRight,
    fontSize,
    fibLevels == null ? null : Object.hashAll(fibLevels!),
  );
}

/// Everything the Trader may change on a drawing; a write replaces it all.
@immutable
class DrawingChange {
  const DrawingChange({
    required this.points,
    required this.style,
    this.text,
    this.locked = false,
    this.hidden = false,
  });

  final List<DrawingPoint> points;
  final DrawingStyle style;
  final String? text;
  final bool locked;
  final bool hidden;

  DrawingChange copyWith({
    List<DrawingPoint>? points,
    DrawingStyle? style,
    String? text,
    bool? locked,
    bool? hidden,
  }) => DrawingChange(
    points: points ?? this.points,
    style: style ?? this.style,
    text: text ?? this.text,
    locked: locked ?? this.locked,
    hidden: hidden ?? this.hidden,
  );

  Map<String, Object?> toJson() => {
    'points': [for (final point in points) point.toJson()],
    'style': style.toJson(),
    'text': text,
    'locked': locked,
    'hidden': hidden,
  };

  @override
  bool operator ==(Object other) =>
      other is DrawingChange &&
      listEquals(other.points, points) &&
      other.style == style &&
      other.text == text &&
      other.locked == locked &&
      other.hidden == hidden;

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(points), style, text, locked, hidden);
}

/// A drawing not saved yet: what the chart page placed.
@immutable
class DrawingDraft {
  const DrawingDraft({required this.type, required this.change});

  factory DrawingDraft.fromJson(Object? body) {
    final json = asJsonObject(body, 'draft');
    return DrawingDraft(
      type: readString(json, 'type'),
      change: _changeFromJson(json),
    );
  }

  /// The backend's `DrawingType`, such as `TREND_LINE`.
  final String type;
  final DrawingChange change;

  DrawingDraft withText(String text) => DrawingDraft(
    type: type,
    change: change.copyWith(text: text),
  );
}

@immutable
class ChartDrawing {
  const ChartDrawing({
    required this.id,
    required this.layoutId,
    required this.type,
    required this.change,
    required this.version,
  });

  factory ChartDrawing.fromJson(Object? body) {
    final json = asJsonObject(body, 'drawing');
    return ChartDrawing(
      id: readString(json, 'id'),
      layoutId: readString(json, 'layoutId'),
      type: readString(json, 'type'),
      change: _changeFromJson(json),
      version: _int(json, 'version'),
    );
  }

  final String id;
  final String layoutId;
  final String type;
  final DrawingChange change;

  /// Sent back with the next write; a stale one answers 409.
  final int version;

  List<DrawingPoint> get points => change.points;
  DrawingStyle get style => change.style;
  bool get locked => change.locked;
  bool get hidden => change.hidden;

  ChartDrawing withChange(DrawingChange change) => ChartDrawing(
    id: id,
    layoutId: layoutId,
    type: type,
    change: change,
    version: version,
  );

  /// The shape the chart page reads (the web's `ChartDrawing`).
  Map<String, Object?> toJson() => {
    'id': id,
    'layoutId': layoutId,
    'type': type,
    ...change.toJson(),
    'version': version,
  };

  @override
  bool operator ==(Object other) =>
      other is ChartDrawing &&
      other.id == id &&
      other.layoutId == layoutId &&
      other.type == type &&
      other.change == change &&
      other.version == version;

  @override
  int get hashCode => Object.hash(id, layoutId, type, change, version);
}

List<ChartDrawing> decodeChartDrawings(Object? body) => [
  for (final each in _list(body, 'drawings')) ChartDrawing.fromJson(each),
];

DrawingChange _changeFromJson(Map<String, Object?> json) => DrawingChange(
  points: [
    for (final point in _list(json['points'], 'points'))
      DrawingPoint.fromJson(point),
  ],
  style: DrawingStyle.fromJson(json['style']),
  text: readOptionalString(json, 'text'),
  locked: json['locked'] == true,
  hidden: json['hidden'] == true,
);

/// A named copy of the drawings on a pair (D-149 (5)); Spot and Futures of
/// the pair share it.
@immutable
class ChartLayout {
  const ChartLayout({
    required this.id,
    required this.pairId,
    required this.number,
    required this.drawings,
    this.name,
  });

  factory ChartLayout.fromJson(Object? body) {
    final json = asJsonObject(body, 'layout');
    return ChartLayout(
      id: readString(json, 'id'),
      pairId: readString(json, 'pairId'),
      number: _int(json, 'number'),
      name: readOptionalString(json, 'name'),
      drawings: _int(json, 'drawings'),
    );
  }

  static const maxPerPair = 10;
  static const maxDrawings = 200;

  final String id;
  final String pairId;

  /// The smallest number free when it was opened: "Copy n" until renamed.
  final int number;
  final String? name;
  final int drawings;

  ChartLayout copyWith({String? name, bool clearName = false, int? drawings}) =>
      ChartLayout(
        id: id,
        pairId: pairId,
        number: number,
        name: clearName ? null : name ?? this.name,
        drawings: drawings ?? this.drawings,
      );

  @override
  bool operator ==(Object other) =>
      other is ChartLayout &&
      other.id == id &&
      other.pairId == pairId &&
      other.number == number &&
      other.name == name &&
      other.drawings == drawings;

  @override
  int get hashCode => Object.hash(id, pairId, number, name, drawings);
}

List<ChartLayout> decodeChartLayouts(Object? body) =>
    [for (final each in _list(body, 'layouts')) ChartLayout.fromJson(each)]
      ..sort((a, b) => a.number.compareTo(b.number));

int _int(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is int) return value;
  throw DecodeException('$key is not an integer');
}

List<Object?> _list(Object? value, String what) {
  if (value is List) return value;
  throw DecodeException('$what is not a list');
}

final _decimalPattern = RegExp(r'^-?\d+(\.\d+)?$');

/// A decimal as text, whether the body wrote it as a string or a number.
String _decimalValue(Object? value, String what) {
  final text = value is String ? value : (value is num ? '$value' : null);
  if (text == null || !_decimalPattern.hasMatch(text)) {
    throw DecodeException('$what is not a decimal');
  }
  return text;
}

String _decimal(Map<String, Object?> json, String key) =>
    _decimalValue(json[key], key);
