import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../journal/data/performance_api.dart';
import '../../journal/domain/performance.dart';
import '../../news/data/news_api.dart';
import '../../news/domain/news.dart';
import '../../notifications/application/notifications_controller.dart';
import '../../notifications/data/notification_api.dart';
import '../../notifications/domain/notification.dart';
import '../../plans/data/plan_api.dart';
import '../../plans/domain/plan.dart';

/// The blocks of SCR-08 (SRS: watchlist snapshot, active plans and open
/// positions, recent notifications, performance summary, latest news). Each
/// reads on its own, so one failure leaves the others shown; pull to refresh
/// reads them all again ([refreshHome]).

/// How many rows a block lists.
const homeRows = 5;

/// The first plans of a tab of SCR-16 and the tab's total.
final homePlansProvider = FutureProvider.autoDispose.family<PlanPage, PlanTab>(
  (ref, tab) => ref.read(planApiProvider).list(tab: tab, pageSize: homeRows),
);

/// Executed plans whose position is still open, counted from the first 100
/// as the web counts them; [more] when there are more executed plans.
final openPositionsProvider =
    FutureProvider.autoDispose<({int open, bool more})>((ref) async {
      final page = await ref
          .read(planApiProvider)
          .list(tab: PlanTab.executed, pageSize: 100);
      return (
        open: page.items
            .where((plan) => plan.positionState == PositionState.open)
            .length,
        more: page.total > page.items.length,
      );
    });

/// The three newest notifications; read again when the bell's count changes.
final homeNotificationsProvider =
    FutureProvider.autoDispose<List<AppNotification>>((ref) async {
      ref.watch(unreadCountProvider);
      final page = await ref.read(notificationApiProvider).list(pageSize: 3);
      return page.items;
    });

final homePerformanceProvider = FutureProvider.autoDispose<PerformanceSummary>(
  (ref) => ref.read(performanceApiProvider).summary(),
);

final homeNewsProvider = FutureProvider.autoDispose<List<NewsArticle>>(
  (ref) => ref.read(newsApiProvider).latest(),
);

/// Reads every block again; done when they are.
Future<void> refreshHome(WidgetRef ref) async {
  for (final tab in [PlanTab.active, PlanTab.executed]) {
    ref.invalidate(homePlansProvider(tab));
  }
  ref
    ..invalidate(openPositionsProvider)
    ..invalidate(homeNotificationsProvider)
    ..invalidate(homePerformanceProvider)
    ..invalidate(homeNewsProvider);
  await Future.wait(
    [
      ref.read(homePlansProvider(PlanTab.active).future),
      ref.read(homeNotificationsProvider.future),
      ref.read(homePerformanceProvider.future),
      ref.read(homeNewsProvider.future),
    ].map((f) => f.then<void>((_) {}, onError: (_) {})),
  );
  unawaited(ref.read(unreadCountProvider.notifier).load());
}
