import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/web/web_links.dart';
import '../../paper/application/trade_controller.dart';

/// Where a lesson link leads on the phone (D-155 (4)). Lessons link web
/// paths; those the app has open its screen, the others open the web.
sealed class AcademyLinkTarget {
  const AcademyLinkTarget();
}

/// A tab or screen of the app, opened with [push] or as a tab.
class AppScreen extends AcademyLinkTarget {
  const AppScreen(this.location, {required this.tab});
  final String location;

  /// A bottom bar tab is gone to; any other screen is pushed.
  final bool tab;
}

/// The Trade tab in Spot or Futures, on a pair when the path names one
/// (`/trade/spot`, `/trade/futures/BTCUSDT`).
class TradeTab extends AcademyLinkTarget {
  const TradeTab({required this.futures, this.symbol});
  final bool futures;
  final String? symbol;
}

/// A web path, opened in the browser on the web app.
class WebPath extends AcademyLinkTarget {
  const WebPath(this.path);
  final String path;
}

/// A full web address (`https://…`).
class WebAddress extends AcademyLinkTarget {
  const WebAddress(this.address);
  final String address;
}

/// The app screens a lesson path maps to today. `/trade/spot` and
/// `/trade/futures` open the Trade tab (T-131), `/journal` the journal of
/// the Plans tab (T-091), `/community` the community (T-133); `/plans/new`
/// and any unknown path open the web.
AcademyLinkTarget academyLinkTarget(String href) {
  if (!href.startsWith('/')) return WebAddress(href);
  final path = Uri.parse(href).path;
  final segments = path.split('/').where((s) => s.isNotEmpty).toList();
  if (segments.length <= 3 &&
      segments.length >= 2 &&
      segments[0] == 'trade' &&
      (segments[1] == 'spot' || segments[1] == 'futures')) {
    return TradeTab(
      futures: segments[1] == 'futures',
      symbol: segments.length == 3 ? segments[2].toUpperCase() : null,
    );
  }
  return switch (path) {
    '/markets' => const AppScreen('/markets', tab: true),
    '/alerts' => const AppScreen('/alerts', tab: false),
    '/journal' => const AppScreen('/plans?tab=journal', tab: true),
    '/community' => const AppScreen('/community', tab: false),
    _ => WebPath(href),
  };
}

void openAcademyLink(BuildContext context, WidgetRef ref, String href) {
  final web = ref.read(webLinksProvider);
  switch (academyLinkTarget(href)) {
    case AppScreen(:final location, tab: true):
      context.go(location);
    case AppScreen(:final location, tab: false):
      context.push(location);
    case TradeTab(:final futures, :final symbol):
      if (symbol != null) {
        if (futures) {
          ref.read(futuresPairProvider.notifier).select(symbol);
        } else {
          ref.read(tradePairProvider.notifier).select(symbol);
        }
      }
      ref.read(tradeFuturesProvider.notifier).show(futures: futures);
      context.go('/trade');
    case WebPath(:final path):
      web.open(path);
    case WebAddress(:final address):
      web.openAddress(address);
  }
}
