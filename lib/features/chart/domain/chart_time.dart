import '../../market/domain/candle.dart';

/// The chart library draws every time as UTC and has no time zones, so a
/// chart in the Trader's local time is fed times moved by the device's
/// offset (BR-08: stored in UTC, displayed in UTC+7 for a device in Viet
/// Nam), as the web does. One fixed offset serves the whole chart: an offset
/// that followed daylight saving would give two candles the same time.
///
/// Daily candles stay in UTC: a Binance day runs from 00:00 UTC, so moving
/// them would only move the date labels away from the day they hold.
Duration chartOffset(Timeframe timeframe, Duration zone) =>
    timeframe == Timeframe.d1 ? Duration.zero : zone;

/// "UTC", "UTC+7", "UTC+5:30", "UTC-3:30": the zone the axis shows.
String zoneLabel(Duration offset) {
  if (offset == Duration.zero) return 'UTC';
  final minutes = offset.inMinutes.abs();
  final rest = minutes % 60;
  return 'UTC${offset.isNegative ? '-' : '+'}${minutes ~/ 60}'
      '${rest == 0 ? '' : ':${rest.toString().padLeft(2, '0')}'}';
}
