import 'package:flutter/material.dart';

import '../theme/cp_colors.dart';

/// A short status or market word on a tinted ground, coloured text, sentence
/// case: one look for plan, position, alert and journal states (D-163). The
/// word carries the meaning, never the colour alone.
class CpTag extends StatelessWidget {
  const CpTag(this.text, {this.color, super.key});

  final String text;

  /// The tint and text colour; muted when null.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? context.cp.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        maxLines: 1,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: tint,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
