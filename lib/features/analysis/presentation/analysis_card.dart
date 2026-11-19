import 'package:flutter/material.dart';

import '../../../core/errors/api_failure.dart';
import '../../../core/errors/message_text.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/cp_colors.dart';

/// A titled block of the analysis screen; each one loads, fails and empties
/// on its own.
class AnalysisCard extends StatelessWidget {
  const AnalysisCard({
    required this.title,
    required this.child,
    this.trailing,
    super.key,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 40),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
          child,
        ],
      ),
    ),
  );
}

/// What went wrong in a block, with Try again.
class BlockFailure extends StatelessWidget {
  const BlockFailure({required this.error, required this.onRetry, super.key});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = switch (error) {
      final ApiFailure failure => failureText(l, failure),
      _ => l.msg43(l.errorUnknownReference),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(text, style: TextStyle(color: context.cp.muted)),
        TextButton(onPressed: onRetry, child: Text(l.commonRetry)),
      ],
    );
  }
}

/// Grey bars with the height of the content that is still being read.
class BlockSkeleton extends StatelessWidget {
  const BlockSkeleton({this.lines = 3, super.key});

  final int lines;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (var i = 0; i < lines; i++)
        Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          width: i.isEven ? double.infinity : 180,
          height: 14,
          decoration: BoxDecoration(
            color: context.cp.raised,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
    ],
  );
}
