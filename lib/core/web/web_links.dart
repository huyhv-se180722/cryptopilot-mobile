import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/config_provider.dart';

/// Screens that exist only on the web (SRS 3.1.1) open in the browser.
abstract interface class WebLinks {
  Future<bool> open(String path);
}

class BrowserWebLinks implements WebLinks {
  const BrowserWebLinks(this.webBaseUrl);

  final String webBaseUrl;

  @override
  Future<bool> open(String path) => launchUrl(
    Uri.parse('$webBaseUrl$path'),
    mode: LaunchMode.externalApplication,
  );
}

final webLinksProvider = Provider<WebLinks>(
  (ref) => BrowserWebLinks(ref.watch(appConfigProvider).webBaseUrl),
);
