import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/web/web_links.dart';

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

/// The app screens a lesson path maps to today. `/trade/*` waits for the
/// Trade tab (T-128) and `/journal` for the Journal screens (T-091): until
/// then they open the web, as `/plans/new`, `/community` and any unknown
/// path do.
AcademyLinkTarget academyLinkTarget(String href) {
  if (!href.startsWith('/')) return WebAddress(href);
  final path = Uri.parse(href).path;
  return switch (path) {
    '/markets' => const AppScreen('/markets', tab: true),
    '/alerts' => const AppScreen('/alerts', tab: false),
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
    case WebPath(:final path):
      web.open(path);
    case WebAddress(:final address):
      web.openAddress(address);
  }
}
