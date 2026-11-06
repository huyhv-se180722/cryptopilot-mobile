import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/session_controller.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/web/web_links.dart';
import 'auth_scaffold.dart';

/// An Admin signed in: SCR-33…44 exist only on the web (SRS 3.1.1). The
/// notice and sign-out follow the proposal of Q-90.
class AdminNoticeScreen extends ConsumerWidget {
  const AdminNoticeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return AuthScaffold(
      title: l.adminTitle,
      subtitle: l.adminBody,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            onPressed: () => ref.read(webLinksProvider).open('/admin'),
            iconAlignment: IconAlignment.end,
            icon: const Icon(Icons.open_in_new, size: 18),
            label: Text(l.adminOpenConsole),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () =>
                ref.read(sessionControllerProvider.notifier).signOut(),
            child: Text(l.accountSignOut),
          ),
        ],
      ),
    );
  }
}
