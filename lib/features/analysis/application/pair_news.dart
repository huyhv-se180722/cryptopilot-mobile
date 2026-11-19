import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../news/data/news_api.dart';
import '../../news/domain/news.dart';

/// How many articles the analysis screen lists.
const pairNewsRows = 3;

/// The latest news tagged with a base coin (SRS 3.3.2), by coin symbol.
final pairNewsProvider = FutureProvider.autoDispose
    .family<List<NewsArticle>, String>(
      (ref, coin) =>
          ref.read(newsApiProvider).latest(pageSize: pairNewsRows, coin: coin),
    );
