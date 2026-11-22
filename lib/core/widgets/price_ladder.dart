import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/cp_colors.dart';

/// The plan's prices on one line (D-163, as the web `PriceLadder`): the
/// stop-to-entry part red, the entry-to-target part green, a tick at the
/// entry and a "Now" mark at the last price when it is known. The figures
/// only place marks; the prices shown are the decimal strings.
class PriceLadder extends StatelessWidget {
  const PriceLadder({
    required this.stop,
    required this.entry,
    required this.target,
    required this.now,
    required this.nowLabel,
    required this.semantics,
    super.key,
  });

  final String? stop;
  final String? entry;
  final String? target;
  final String? now;
  final String nowLabel;
  final String semantics;

  @override
  Widget build(BuildContext context) {
    final s = double.tryParse(stop ?? '');
    final e = double.tryParse(entry ?? '');
    final t = double.tryParse(target ?? '');
    if (s == null || e == null || t == null) return const SizedBox.shrink();
    final n = double.tryParse(now ?? '');
    final values = [s, e, t, ?n];
    final low = values.reduce(min);
    final high = values.reduce(max);
    final span = high - low;
    if (span <= 0) return const SizedBox.shrink();
    double at(double v) => (v - low) / span;
    final cp = context.cp;
    final label = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: cp.primary,
      fontWeight: FontWeight.w700,
    );
    return Semantics(
      key: const Key('plan-ladder'),
      label: semantics,
      excludeSemantics: true,
      child: SizedBox(
        height: 40,
        child: LayoutBuilder(
          builder: (context, box) {
            final w = box.maxWidth;
            double x(double v) => at(v) * w;
            final lossFrom = min(x(s), x(e));
            final lossTo = max(x(s), x(e));
            final winFrom = min(x(e), x(t));
            final winTo = max(x(e), x(t));
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: 24,
                  height: 6,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: cp.raised,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                Positioned(
                  left: lossFrom,
                  width: lossTo - lossFrom,
                  top: 24,
                  height: 6,
                  child: ColoredBox(color: cp.negative.withValues(alpha: 0.4)),
                ),
                Positioned(
                  left: winFrom,
                  width: winTo - winFrom,
                  top: 24,
                  height: 6,
                  child: ColoredBox(color: cp.positive.withValues(alpha: 0.4)),
                ),
                Positioned(
                  left: x(e) - 1,
                  top: 18,
                  width: 2,
                  height: 18,
                  child: ColoredBox(color: cp.text),
                ),
                if (n != null) ...[
                  Positioned(
                    left: (x(n) - 20).clamp(0, w - 40),
                    width: 40,
                    top: 0,
                    child: Text(
                      nowLabel,
                      key: const Key('plan-ladder-now'),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      style: label,
                    ),
                  ),
                  Positioned(
                    left: x(n) - 5,
                    top: 30,
                    child: Icon(
                      Icons.arrow_drop_up,
                      size: 10,
                      color: cp.primary,
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
