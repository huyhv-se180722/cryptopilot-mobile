import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../chart/presentation/chart_surface.dart';

/// The five tabs of D-154: Home, Markets, Trade, Plans, Assets. Alerts open
/// from Markets and Home; the journal joins Plans (T-091). Each tab keeps
/// its own navigation stack.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  @override
  void initState() {
    super.initState();
    // Every tab can open a pair's analysis: start the chart page now so it
    // is ready by then (ADR-012 item 2).
    unawaited(ref.read(chartSurfaceProvider).warm());
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final navigationShell = widget.navigationShell;
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
            icon: const Icon(Icons.swap_horiz),
            selectedIcon: const Icon(Icons.swap_horizontal_circle),
            label: l.navTrade,
          ),
          NavigationDestination(
            icon: const Icon(Icons.assignment_outlined),
            selectedIcon: const Icon(Icons.assignment),
            label: l.navPlans,
          ),
          NavigationDestination(
            icon: const Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: const Icon(Icons.account_balance_wallet),
            label: l.navAssets,
          ),
        ],
      ),
    );
  }
}

/// A tab whose screens arrive with T-089…T-091. It says so and shows no data.
class PendingTab extends StatelessWidget {
  const PendingTab({required this.title, this.actions = const [], super.key});

  final String title;

  /// Header actions other features add (the bell), composed by the router.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          ...actions,
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
