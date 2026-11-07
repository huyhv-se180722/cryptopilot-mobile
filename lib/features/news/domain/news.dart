import '../../../core/json/json_read.dart';

enum NewsSentiment {
  bullish('BULLISH'),
  neutral('NEUTRAL'),
  bearish('BEARISH');

  const NewsSentiment(this.wire);

  final String wire;

  static NewsSentiment decode(String value) => values.firstWhere(
    (sentiment) => sentiment.wire == value,
    orElse: () => throw DecodeException('sentiment $value is unknown'),
  );
}

/// One article of `GET /news` (`NewsArticleResponse`). SCR-28 is on the web;
/// the app lists the latest on Home and opens the web page.
class NewsArticle {
  const NewsArticle({
    required this.id,
    required this.title,
    required this.source,
    required this.publishedAt,
    required this.coins,
    this.sentiment,
  });

  final String id;
  final String title;
  final String source;
  final DateTime publishedAt;
  final NewsSentiment? sentiment;

  /// Coin symbols, the primary one first.
  final List<String> coins;
}

NewsArticle decodeNewsArticle(Object? body) {
  final json = asJsonObject(body, 'news article');
  final sentiment = readOptionalString(json, 'sentiment');
  final coins = json['coins'];
  return NewsArticle(
    id: readString(json, 'articleId'),
    title: readString(json, 'title'),
    source: readString(json, 'source'),
    publishedAt: readInstant(json, 'publishedAt'),
    sentiment: sentiment == null ? null : NewsSentiment.decode(sentiment),
    coins: coins is List
        ? [
            for (final coin in coins)
              readString(asJsonObject(coin, 'coin'), 'symbol'),
          ]
        : const [],
  );
}

List<NewsArticle> decodeNewsPage(Object? body) {
  final json = asJsonObject(body, 'news page');
  final items = json['items'];
  if (items is! List) throw const DecodeException('items is not a list');
  return [for (final item in items) decodeNewsArticle(item)];
}
