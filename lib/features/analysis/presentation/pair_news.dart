import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/session_controller.dart';
import '../../../core/format/age_format.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/cp_colors.dart';
import '../../../core/web/web_links.dart';
import '../../news/domain/news.dart';
import '../application/pair_news.dart';
import 'analysis_card.dart';

/// The latest news tagged with the pair's base coin (SRS 3.3.2). SCR-28 is
/// on the web only (SRS 3.1.1): an article and "See all" open it there.
class PairNews extends ConsumerWidget {
  const PairNews({required this.coin, super.key});

  final String coin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final web = ref.read(webLinksProvider);
    final news = ref.watch(pairNewsProvider(coin));
    return AnalysisCard(
      key: const Key('pair-news'),
      title: l.analysisNewsTitle(coin),
      trailing: TextButton(
        key: const Key('pair-news-all'),
        onPressed: () =>
            web.open('/news?coin=${Uri.encodeQueryComponent(coin)}'),
        child: Text(l.homeSeeAll),
      ),
      child: switch (news) {
        AsyncValue(:final value?) when value.isEmpty => Text(
          l.analysisNewsEmpty(coin),
          key: const Key('pair-news-empty'),
          style: TextStyle(color: context.cp.muted),
        ),
        AsyncValue(:final value?) => Column(
          children: [for (final article in value) _NewsRow(article: article)],
        ),
        AsyncValue(:final error?) => BlockFailure(
          error: error,
          onRetry: () => ref.invalidate(pairNewsProvider(coin)),
        ),
        _ => const BlockSkeleton(key: Key('pair-news-loading')),
      },
    );
  }
}

class _NewsRow extends ConsumerWidget {
  const _NewsRow({required this.article});

  final NewsArticle article;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final now = ref.read(clockProvider)();
    final sentiment = switch (article.sentiment) {
      NewsSentiment.bullish => l.newsBullish,
      NewsSentiment.neutral => l.newsNeutral,
      NewsSentiment.bearish => l.newsBearish,
      null => null,
    };
    return InkWell(
      key: Key('pair-news-${article.id}'),
      onTap: () => ref.read(webLinksProvider).open('/news/${article.id}'),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                article.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: text.titleSmall,
              ),
              const SizedBox(height: 2),
              Text(
                [
                  article.source,
                  formatAge(l, article.publishedAt, now),
                  ?sentiment,
                ].join(' · '),
                style: text.bodySmall?.copyWith(color: context.cp.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
