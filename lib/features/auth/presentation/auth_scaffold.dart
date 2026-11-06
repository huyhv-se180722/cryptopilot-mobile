import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/cp_colors.dart';
import '../../../core/widgets/brand_logo.dart';

/// The frame of SCR-04…06: logo, title, subtitle, form, disclaimer (BR-60).
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    required this.title,
    required this.child,
    this.subtitle,
    this.showBack = false,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: showBack ? AppBar() : null,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!showBack) ...[
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: BrandLogo(height: 36),
                    ),
                    const SizedBox(height: 32),
                  ],
                  Text(title, style: text.headlineSmall),
                  if (subtitle != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      subtitle!,
                      style: text.bodyMedium?.copyWith(color: context.cp.muted),
                    ),
                  ],
                  const SizedBox(height: 24),
                  child,
                  const SizedBox(height: 32),
                  Text(
                    l.msg42,
                    style: text.bodySmall?.copyWith(color: context.cp.muted),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// An inline message above a form (MSG08, MSG44 …).
class FormBanner extends StatelessWidget {
  const FormBanner({
    required this.message,
    this.positive = false,
    this.action,
    super.key,
  });

  final String message;
  final bool positive;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final color = positive ? context.cp.positive : context.cp.negative;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            liveRegion: true,
            child: Text(message, style: TextStyle(color: context.cp.text)),
          ),
          ?action,
        ],
      ),
    );
  }
}
