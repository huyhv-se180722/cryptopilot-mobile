import 'package:flutter/material.dart';

import '../theme/cp_colors.dart';
import 'cp_tag.dart';

/// The quote assets a bare symbol can end with, longest first.
const _quotes = ['FDUSD', 'USDT', 'USDC', 'BUSD'];

/// `BTCUSDT` → (`BTC`, `USDT`); a symbol with no known quote stays whole.
(String, String) splitSymbol(String symbol) {
  for (final quote in _quotes) {
    if (symbol.length > quote.length && symbol.endsWith(quote)) {
      return (symbol.substring(0, symbol.length - quote.length), quote);
    }
  }
  return (symbol, '');
}

/// The base in bold and `/quote` muted: the one way a pair is named on every
/// screen (D-163). For a [Text.rich] that carries more after the pair.
List<InlineSpan> pairSpans(
  BuildContext context, {
  required String base,
  required String quote,
  TextStyle? style,
}) {
  final strong = (style ?? Theme.of(context).textTheme.titleSmall)?.copyWith(
    fontWeight: FontWeight.w700,
  );
  return [
    TextSpan(text: base, style: strong),
    if (quote.isNotEmpty)
      TextSpan(
        text: '/$quote',
        style: strong?.copyWith(
          fontWeight: FontWeight.w400,
          fontSize: strong.fontSize == null ? null : strong.fontSize! * 0.85,
          color: context.cp.muted,
        ),
      ),
  ];
}

/// A pair as `BTC/USDT`, with an optional market tag such as "Perp".
class PairLabel extends StatelessWidget {
  const PairLabel({
    required this.base,
    required this.quote,
    this.tag,
    this.style,
    super.key,
  });

  /// From a bare symbol such as `BTCUSDT` (see [splitSymbol]).
  factory PairLabel.symbol(
    String symbol, {
    String? tag,
    TextStyle? style,
    Key? key,
  }) {
    final (base, quote) = splitSymbol(symbol);
    return PairLabel(
      base: base,
      quote: quote,
      tag: tag,
      style: style,
      key: key,
    );
  }

  final String base;
  final String quote;
  final String? tag;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final name = Text.rich(
      TextSpan(
        children: pairSpans(context, base: base, quote: quote, style: style),
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    if (tag == null) return name;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: name),
        const SizedBox(width: 6),
        CpTag(tag!),
      ],
    );
  }
}
