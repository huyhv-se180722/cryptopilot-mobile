import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/format/decimal_format.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/cp_colors.dart';

/// "● Live" / "● Delayed" (CR-09).
class LiveBadge extends StatelessWidget {
  const LiveBadge({required this.delayed, super.key});

  final bool delayed;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final color = delayed ? context.cp.warning : context.cp.positive;
    return Semantics(
      liveRegion: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: color),
          const SizedBox(width: 4),
          Text(
            delayed ? l.marketDelayed : l.marketLive,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

/// The 24 h change on a filled pill, sign always shown (up green, down red).
class ChangePill extends StatelessWidget {
  const ChangePill({required this.percent, this.width = 84, super.key});

  final String? percent;
  final double width;

  @override
  Widget build(BuildContext context) {
    final direction = directionOf(percent);
    final background = switch (direction) {
      Direction.up => context.cp.positive,
      Direction.down => context.cp.negative,
      Direction.flat => context.cp.raised,
    };
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      alignment: Alignment.center,
      child: Text(
        formatSignedPercent(percent),
        style: TextStyle(
          color: direction == Direction.flat ? context.cp.text : Colors.white,
          fontWeight: FontWeight.w600,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

/// Text coloured by the sign of [percent], with the sign written.
class SignedPercentText extends StatelessWidget {
  const SignedPercentText(this.percent, {this.style, super.key});

  final String? percent;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final color = switch (directionOf(percent)) {
      Direction.up => context.cp.positive,
      Direction.down => context.cp.negative,
      Direction.flat => context.cp.muted,
    };
    return Text(
      formatSignedPercent(percent),
      style: (style ?? const TextStyle()).copyWith(color: color),
    );
  }
}

/// hh:mm:ss until [until], ticking every second (funding countdown, BR-11).
class Countdown extends StatefulWidget {
  const Countdown({
    required this.until,
    required this.now,
    this.style,
    super.key,
  });

  final DateTime until;
  final DateTime Function() now;
  final TextStyle? style;

  @override
  State<Countdown> createState() => _CountdownState();
}

class _CountdownState extends State<Countdown> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var left = widget.until.difference(widget.now());
    if (left.isNegative) left = Duration.zero;
    String two(int n) => n.toString().padLeft(2, '0');
    return Text(
      '${two(left.inHours)}:${two(left.inMinutes % 60)}:${two(left.inSeconds % 60)}',
      style: widget.style,
    );
  }
}
