import '../../market/domain/candle.dart';
import 'indicators.dart';

/// The overlays and panels of SRS 3.3.2 / BR-12 the Trader can toggle.
enum ChartIndicator {
  sma20('sma20'),
  ema20('ema20'),
  ema50('ema50'),
  ema200('ema200'),
  bollinger('bb'),
  volume('volume'),
  rsi('rsi'),
  macd('macd');

  const ChartIndicator(this.key);

  /// Stored in the device settings (SRS 3.3.2: remembered on the device).
  final String key;

  static const overlays = {sma20, ema20, ema50, ema200, bollinger};

  /// SRS 3.3.2 lists them all; Volume is on by default as on the web.
  static const defaults = {ema20, ema50, volume};

  static Set<ChartIndicator> parse(String? stored) {
    if (stored == null) return defaults;
    final keys = stored.split(',');
    return {
      for (final i in values)
        if (keys.contains(i.key)) i,
    };
  }

  static String format(Set<ChartIndicator> set) => [
    for (final i in values)
      if (set.contains(i)) i.key,
  ].join(',');
}

/// Line colours of the indicators; the same in both themes so a line keeps
/// its meaning (the candle colours follow the theme tokens).
const _colors = {
  'sma20': '#F0B90B',
  'ema20': '#3B82F6',
  'ema50': '#A855F7',
  'ema200': '#F97316',
  'bb': '#64748B',
  'volumeSma': '#F0B90B',
  'rsi': '#A855F7',
  'macdLine': '#3B82F6',
  'macdSignal': '#F97316',
};

/// What the chart page draws for [enabled]: one value per candle (null while
/// the seed is incomplete), overlays on the price pane and panels below it in
/// the order Volume, RSI, MACD.
Map<String, Object?> indicatorPayload(
  List<Candle> candles,
  Set<ChartIndicator> enabled,
) {
  final closes = [for (final c in candles) double.parse(c.close)];
  final volumes = [for (final c in candles) double.parse(c.quoteVolume)];
  Map<String, Object?> line(String id, Series values) => {
    'id': id,
    'type': 'line',
    'color': _colors[id],
    'values': values,
  };

  final overlays = <Map<String, Object?>>[
    if (enabled.contains(ChartIndicator.sma20)) line('sma20', sma(closes, 20)),
    if (enabled.contains(ChartIndicator.ema20)) line('ema20', ema(closes, 20)),
    if (enabled.contains(ChartIndicator.ema50)) line('ema50', ema(closes, 50)),
    if (enabled.contains(ChartIndicator.ema200))
      line('ema200', ema(closes, 200)),
    if (enabled.contains(ChartIndicator.bollinger))
      ...() {
        final bands = bollinger(closes);
        return [
          line('bb', bands.upper),
          line('bb', bands.middle),
          line('bb', bands.lower),
        ];
      }(),
  ];
  final panels = <Map<String, Object?>>[
    if (enabled.contains(ChartIndicator.volume))
      {
        'id': 'volume',
        'series': [
          {
            'id': 'volume',
            'type': 'histogram',
            'volume': true,
            'values': volumes,
            'up': [
              for (final c in candles)
                double.parse(c.close) >= double.parse(c.open),
            ],
          },
          line('volumeSma', sma(volumes, 20)),
        ],
      },
    if (enabled.contains(ChartIndicator.rsi))
      {
        'id': 'rsi',
        'series': [
          {
            ...line('rsi', rsi(closes)),
            'levels': [30, 70],
          },
        ],
      },
    if (enabled.contains(ChartIndicator.macd))
      ...() {
        final m = macd(closes);
        return [
          {
            'id': 'macd',
            'series': [
              {
                'id': 'macdHistogram',
                'type': 'histogram',
                'values': m.histogram,
                'up': [for (final h in m.histogram) (h ?? 0) >= 0],
              },
              line('macdLine', m.line),
              line('macdSignal', m.signal),
            ],
          },
        ];
      }(),
  ];
  return {
    'times': [
      for (final c in candles) c.openTime.millisecondsSinceEpoch ~/ 1000,
    ],
    'overlays': overlays,
    'panels': panels,
  };
}
