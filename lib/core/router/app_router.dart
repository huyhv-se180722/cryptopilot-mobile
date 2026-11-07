import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/account/presentation/account_screen.dart';
import '../../features/alerts/presentation/alerts_screen.dart';
import '../../features/auth/presentation/admin_notice_screen.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/reset_password_screen.dart';
import '../../features/market/presentation/markets_screen.dart';
import '../../features/shell/presentation/home_shell.dart';
import '../../features/watchlist/presentation/watchlist_view.dart';
import '../auth/session.dart';
import '../auth/session_controller.dart';
import '../i18n/app_localizations.dart';
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
  static const plans = '/plans';
  static const journal = '/journal';
  static const account = '/account';
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

final appRouterProvider = Provider<GoRouter>((ref) {
  final session = ValueNotifier<SessionState>(
    ref.read(sessionControllerProvider),
  );
  ref
    ..listen(sessionControllerProvider, (_, next) => session.value = next)
    ..onDispose(session.dispose);

  StatefulShellBranch branch(
    String path,
    String Function(AppLocalizations) title,
  ) => StatefulShellBranch(
    routes: [
      GoRoute(
        path: path,
        builder: (context, _) =>
            PendingTab(title: title(AppLocalizations.of(context))),
      ),
    ],
  );

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
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => HomeShell(navigationShell: shell),
        branches: [
          branch(Routes.home, (l) => l.navHome),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.markets,
                builder: (_, _) =>
                    const MarketsScreen(watchlist: WatchlistView()),
              ),
            ],
          ),
          branch(Routes.plans, (l) => l.navPlans),
          branch(Routes.journal, (l) => l.navJournal),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
