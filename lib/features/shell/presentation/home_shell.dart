import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/app_localizations.dart';

/// The five tabs of the mobile plan (Home, Markets, Alerts, Plans, Journal);
/// each keeps its own navigation stack.
class HomeShell extends StatelessWidget {
  const HomeShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: l.navHome,
          ),
          NavigationDestination(
            icon: const Icon(Icons.candlestick_chart_outlined),
            selectedIcon: const Icon(Icons.candlestick_chart),
            label: l.navMarkets,
          ),
          NavigationDestination(
            icon: const Icon(Icons.notifications_active_outlined),
            selectedIcon: const Icon(Icons.notifications_active),
            label: l.navAlerts,
          ),
          NavigationDestination(
            icon: const Icon(Icons.assignment_outlined),
            selectedIcon: const Icon(Icons.assignment),
            label: l.navPlans,
          ),
          NavigationDestination(
            icon: const Icon(Icons.menu_book_outlined),
            selectedIcon: const Icon(Icons.menu_book),
            label: l.navJournal,
          ),
        ],
      ),
    );
  }
}

/// A tab whose screens arrive with T-089…T-091. It says so and shows no data.
class PendingTab extends StatelessWidget {
  const PendingTab({required this.title, super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            key: const Key('open-account'),
            tooltip: l.navAccount,
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () => context.push('/account'),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.construction_outlined,
                size: 40,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 12),
              Text(l.tabComingTitle, style: text.titleMedium),
              const SizedBox(height: 4),
              Text(l.tabComingBody, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
