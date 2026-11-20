import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/ai/application/ai_chat_controller.dart';
import '../../features/ai/application/ai_context.dart';
import '../../features/ai/domain/ai.dart';
import '../../features/ai/presentation/ai_chat_screen.dart';
import '../../features/ai/presentation/ai_conversations_screen.dart';
import '../../features/journal/presentation/journal_entry_screen.dart';
import '../../features/journal/presentation/journal_view.dart';
import '../../features/journal/presentation/plan_journal_link.dart';
import '../../features/plans/presentation/plan_detail_screen.dart';
import '../../features/plans/presentation/plans_screen.dart';
import '../../features/academy/presentation/academy_screen.dart';
import '../../features/academy/presentation/glossary_screen.dart';
import '../../features/academy/presentation/lesson_screen.dart';
import '../../features/account/presentation/account_screen.dart';
import '../../features/alerts/presentation/alerts_screen.dart';
import '../../features/analysis/presentation/analysis_screen.dart';
import '../../features/auth/presentation/admin_notice_screen.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/reset_password_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/market/domain/market.dart';
import '../../features/market/presentation/markets_screen.dart';
import '../../features/notifications/presentation/notification_bell.dart';
import '../../features/paper/presentation/assets_screen.dart';
import '../../features/paper/presentation/history_screen.dart';
import '../../features/paper/presentation/trade_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/shell/presentation/home_shell.dart';
import '../../features/watchlist/presentation/watchlist_view.dart';
import '../auth/session.dart';
import '../auth/session_controller.dart';
import 'splash_screen.dart';

abstract final class Routes {
  static const splash = '/splash';
  static const login = '/login';
  static const forgotPassword = '/forgot-password';
  static const resetPassword = '/reset-password';
  static const adminNotice = '/admin-notice';
  static const home = '/home';
  static const markets = '/markets';
  static const alerts = '/alerts';
  static const trade = '/trade';
  static const plans = '/plans';
  static const assets = '/assets';
  static const assetsHistory = '/assets/history';
  static const account = '/account';
  static const notifications = '/notifications';

  /// The Academy (D-155), pushed from Home and the account screen.
  static const academy = '/academy';
  static const academyGlossary = '/academy/glossary';
  static const academyLesson = '/academy/lesson/:slug';

  /// SCR-29 (T-126), pushed from Home and from Ask AI on SCR-10/11.
  static const ai = '/ai';
  static const aiNew = '/ai/new';
  static const aiChat = '/ai/c/:id';

  /// SCR-18 and SCR-21 (T-091), pushed over the tabs.
  static const plan = '/plan/:id';
  static const journalEntry = '/journal/:id';

  /// SCR-10 (spot) and SCR-11 (futures).
  static const analysis = '/analysis/:market/:symbol';
}

const _publicRoutes = {
  Routes.login,
  Routes.forgotPassword,
  Routes.resetPassword,
};

/// Where the session state sends [location], or `null` to stay.
@visibleForTesting
String? redirectFor(SessionState session, String location) {
  switch (session) {
    case SessionRestoring() || SessionUnavailable():
      return location == Routes.splash ? null : Routes.splash;
    case SignedOut():
      return _publicRoutes.contains(location) ? null : Routes.login;
    case SignedIn(role: UserRole.admin):
      return location == Routes.adminNotice ? null : Routes.adminNotice;
    case SignedIn(role: UserRole.trader):
      if (location == Routes.resetPassword) return null;
      final outside =
          location == Routes.splash ||
          location == Routes.adminNotice ||
          _publicRoutes.contains(location);
      return outside ? Routes.home : null;
  }
}

Market? _marketOf(GoRouterState state) => Market.values
    .where((market) => market.path == state.pathParameters['market'])
    .firstOrNull;

final appRouterProvider = Provider<GoRouter>((ref) {
  final session = ValueNotifier<SessionState>(
    ref.read(sessionControllerProvider),
  );
  ref
    ..listen(sessionControllerProvider, (_, next) => session.value = next)
    ..onDispose(session.dispose);

  final router = GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: session,
    redirect: (_, state) => redirectFor(session.value, state.matchedLocation),
    routes: [
      GoRoute(path: Routes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(path: Routes.login, builder: (_, _) => const LoginScreen()),
      GoRoute(
        path: Routes.forgotPassword,
        builder: (_, _) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: Routes.resetPassword,
        builder: (_, state) =>
            ResetPasswordScreen(token: state.uri.queryParameters['token']),
      ),
      GoRoute(
        path: Routes.adminNotice,
        builder: (_, _) => const AdminNoticeScreen(),
      ),
      GoRoute(path: Routes.account, builder: (_, _) => const AccountScreen()),
      // SCR-13 is pushed from Markets and Home, not a tab (D-142).
      GoRoute(path: Routes.alerts, builder: (_, _) => const AlertsScreen()),
      GoRoute(
        path: Routes.notifications,
        builder: (_, _) => const NotificationsScreen(),
      ),
      GoRoute(
        path: Routes.assetsHistory,
        builder: (_, _) => const HistoryScreen(),
      ),
      GoRoute(path: Routes.academy, builder: (_, _) => const AcademyScreen()),
      GoRoute(
        path: Routes.academyGlossary,
        builder: (_, _) => const GlossaryScreen(),
      ),
      GoRoute(
        path: Routes.academyLesson,
        builder: (_, state) =>
            LessonScreen(slug: state.pathParameters['slug']!),
      ),
      GoRoute(
        path: Routes.plan,
        builder: (_, state) => PlanDetailScreen(
          id: state.pathParameters['id']!,
          // Features meet here: Ask AI (SCR-29) and the journal entry
          // (SCR-21) of the plan.
          extraActions: (plan) => [AskAiOnPlanButton(plan: plan.summary)],
          journalLink: (plan) => PlanJournalLink(
            journalKey: (
              planId: plan.id,
              pairId: plan.pairId,
              market: plan.market,
            ),
          ),
        ),
      ),
      GoRoute(
        path: Routes.journalEntry,
        builder: (_, state) =>
            JournalEntryScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: Routes.ai,
        builder: (_, _) => const AiConversationsScreen(),
      ),
      GoRoute(
        path: Routes.aiNew,
        builder: (_, state) => AiChatScreen(
          args: AiChatArgs.fresh(switch (state.extra) {
            // Ask AI on SCR-18 carries the plan itself.
            final AiContext seed => seed,
            _ => AiContext.fromQuery(state.uri.queryParameters),
          }),
        ),
      ),
      GoRoute(
        path: Routes.aiChat,
        builder: (_, state) => switch (state.extra) {
          final AiConversation conversation => AiChatScreen(
            args: AiChatArgs.existing(conversation),
          ),
          _ => AiChatLookup(id: state.pathParameters['id']!),
        },
      ),
      // Pushed over the tabs from a row of Markets, Watchlist or Home.
      GoRoute(
        path: Routes.analysis,
        redirect: (_, state) =>
            _marketOf(state) == null ? Routes.markets : null,
        builder: (_, state) => AnalysisScreen(
          market: _marketOf(state)!,
          symbol: state.pathParameters['symbol']!,
        ),
      ),
      StatefulShellRoute.indexedStack(
        // A notification pushed while a tab is shown appears as a banner.
        builder: (_, _, shell) =>
            NotificationBanner(child: HomeShell(navigationShell: shell)),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: Routes.home, builder: (_, _) => const HomeScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.markets,
                builder: (_, _) => const MarketsScreen(
                  watchlist: WatchlistView(),
                  actions: [NotificationBell()],
                ),
              ),
            ],
          ),
          // The paper exchange (D-154).
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.trade,
                builder: (_, _) => const TradeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.plans,
                // The journal (SCR-20) is the Plans tab's fourth part
                // (D-154), composed here so the features stay apart.
                builder: (_, state) {
                  final tab = state.uri.queryParameters['tab'];
                  return PlansScreen(
                    // A new tab request builds the tabs again on it.
                    key: ValueKey(tab),
                    initialTab: tab,
                    journal: const JournalView(),
                  );
                },
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.assets,
                builder: (_, _) => const AssetsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
