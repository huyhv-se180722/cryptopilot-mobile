import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session_controller.dart';
import '../errors/message_text.dart';
import '../i18n/app_localizations.dart';
import '../widgets/brand_logo.dart';

/// Shown while the stored session resumes, and when the server cannot be
/// reached to resume it (the token is kept; "Try again" resumes).
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final session = ref.watch(sessionControllerProvider);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const BrandLogo(height: 40),
                const SizedBox(height: 32),
                if (session is SessionUnavailable) ...[
                  Text(
                    l.splashUnavailableTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    failureText(l, session.failure),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () =>
                        ref.read(sessionControllerProvider.notifier).restore(),
                    child: Text(l.commonRetry),
                  ),
                ] else
                  Semantics(
                    label: l.commonLoading,
                    child: const CircularProgressIndicator(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
