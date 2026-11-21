import 'package:flutter/material.dart';

import '../theme/cp_colors.dart';

/// Nothing to show: an icon above one sentence, centred (D-163). [inline]
/// is the smaller form for a section inside a screen.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.inline = false,
    super.key,
  });

  final String message;
  final IconData icon;
  final bool inline;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: inline ? 16 : 32, horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: inline ? 28 : 40,
            color: cp.muted.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: (inline ? text.bodySmall : text.bodyMedium)?.copyWith(
              color: cp.muted,
            ),
          ),
        ],
      ),
    );
  }
}
