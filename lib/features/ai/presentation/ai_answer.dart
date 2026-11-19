import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/cp_colors.dart';
import '../../../core/web/web_links.dart';
import '../domain/ai.dart';

/// A block of an answer: a paragraph, or the items of one list.
sealed class AnswerBlock {
  const AnswerBlock();
}

class AnswerParagraph extends AnswerBlock {
  const AnswerParagraph(this.text);

  final String text;
}

class AnswerList extends AnswerBlock {
  const AnswerList(this.items);

  final List<String> items;
}

final _listItem = RegExp(r'^\s*(?:[-*•]|\d{1,2}[.)])\s+(.*)$');

/// An answer as the web shows it (`AnswerText`): blank lines end a
/// paragraph, bullet or numbered lines make a list; lines of one paragraph
/// are joined.
List<AnswerBlock> answerBlocks(String content) {
  final blocks = <AnswerBlock>[];
  final paragraph = <String>[];
  final items = <String>[];
  void flush() {
    if (paragraph.isNotEmpty) {
      blocks.add(AnswerParagraph(paragraph.join(' ')));
      paragraph.clear();
    }
    if (items.isNotEmpty) {
      blocks.add(AnswerList(List.of(items)));
      items.clear();
    }
  }

  for (final raw in content.split('\n')) {
    final line = raw.trimRight();
    final item = _listItem.firstMatch(line);
    if (line.trim().isEmpty) {
      flush();
    } else if (item != null) {
      if (paragraph.isNotEmpty) flush();
      items.add(item.group(1)!.trim());
    } else {
      if (items.isNotEmpty) flush();
      paragraph.add(line.trim());
    }
  }
  flush();
  return blocks;
}

/// A piece of one line: plain, bold, or a citation of stored sources.
sealed class AnswerSpan {
  const AnswerSpan();
}

class PlainSpan extends AnswerSpan {
  const PlainSpan(this.text, {this.bold = false});

  final String text;
  final bool bold;
}

class CitationSpan extends AnswerSpan {
  const CitationSpan(this.sources);

  final List<AiSource> sources;
}

final _inline = RegExp(r'(\*\*[^*]+\*\*|\[\d{1,2}(?:\s*,\s*\d{1,2})*\])');

/// `**bold**` and `[1]`, `[1, 2]`: a number becomes a citation only when
/// every number of it is a stored source (BR-51), otherwise it stays text.
List<AnswerSpan> answerSpans(String text, Map<int, AiSource> byRef) {
  final spans = <AnswerSpan>[];
  var at = 0;
  for (final match in _inline.allMatches(text)) {
    if (match.start > at) spans.add(PlainSpan(text.substring(at, match.start)));
    final part = match.group(0)!;
    if (part.startsWith('**')) {
      spans.add(PlainSpan(part.substring(2, part.length - 2), bold: true));
    } else {
      final refs = [
        for (final n in part.substring(1, part.length - 1).split(','))
          int.parse(n.trim()),
      ];
      spans.add(
        refs.every(byRef.containsKey)
            ? CitationSpan([for (final ref in refs) byRef[ref]!])
            : PlainSpan(part),
      );
    }
    at = match.end;
  }
  if (at < text.length) spans.add(PlainSpan(text.substring(at)));
  return spans;
}

/// An assistant answer: its text, the articles it cites, Copy, and the
/// short disclaimer under every answer (BR-51; the server already ends the
/// text with the full one).
class AiAnswer extends ConsumerStatefulWidget {
  const AiAnswer({required this.message, super.key});

  final AiMessage message;

  @override
  ConsumerState<AiAnswer> createState() => _AiAnswerState();
}

class _AiAnswerState extends ConsumerState<AiAnswer> {
  final List<TapGestureRecognizer> _taps = [];

  @override
  void dispose() {
    for (final tap in _taps) {
      tap.dispose();
    }
    super.dispose();
  }

  void _open(AiSource source) =>
      unawaited(ref.read(webLinksProvider).openAddress(source.url));

  /// Disposed with the next build or the widget.
  TapGestureRecognizer _tapFor(AiSource source) {
    final tap = TapGestureRecognizer()..onTap = () => _open(source);
    _taps.add(tap);
    return tap;
  }

  List<InlineSpan> _spans(String text, Map<int, AiSource> byRef, Color link) {
    return [
      for (final span in answerSpans(text, byRef))
        switch (span) {
          PlainSpan(:final text, :final bold) => TextSpan(
            text: text,
            style: bold ? const TextStyle(fontWeight: FontWeight.w700) : null,
          ),
          CitationSpan(:final sources) => TextSpan(
            children: [
              for (final source in sources)
                TextSpan(
                  text: ' ${source.ref}',
                  style: TextStyle(
                    color: link,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                  recognizer: _tapFor(source),
                ),
            ],
          ),
        },
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cp = context.cp;
    final text = Theme.of(context).textTheme;
    final message = widget.message;
    final byRef = {for (final s in message.sources) s.ref: s};
    for (final tap in _taps) {
      tap.dispose();
    }
    _taps.clear();
    final body = text.bodyMedium?.copyWith(color: cp.text, height: 1.4);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final block in answerBlocks(message.content))
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: switch (block) {
              AnswerParagraph(:final text) => Text.rich(
                TextSpan(
                  style: body,
                  children: _spans(text, byRef, cp.primary),
                ),
              ),
              AnswerList(:final items) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final item in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('•  ', style: body),
                          Expanded(
                            child: Text.rich(
                              TextSpan(
                                style: body,
                                children: _spans(item, byRef, cp.primary),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            },
          ),
        if (message.sources.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(l.aiSources, style: text.labelMedium?.copyWith(color: cp.muted)),
          for (final source in message.sources)
            InkWell(
              key: Key('ai-source-${message.id}-${source.ref}'),
              onTap: () => _open(source),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  [
                    '[${source.ref}] ${source.headline ?? source.url}',
                    ?source.outlet,
                    if (source.publishedAt case final at?)
                      DateFormat('d MMM yyyy', 'en').format(at.toLocal()),
                  ].join(' · '),
                  style: text.bodySmall?.copyWith(color: cp.primary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
        ],
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(Icons.info_outline, size: 14, color: cp.muted),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                l.aiDisclaimer,
                key: Key('ai-disclaimer-${message.id}'),
                style: text.bodySmall?.copyWith(color: cp.muted),
              ),
            ),
            IconButton(
              key: Key('ai-copy-${message.id}'),
              tooltip: l.aiCopy,
              icon: Icon(Icons.copy, size: 18, color: cp.muted),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                await Clipboard.setData(ClipboardData(text: message.content));
                messenger
                  ..hideCurrentSnackBar()
                  ..showSnackBar(SnackBar(content: Text(l.aiCopied)));
              },
            ),
          ],
        ),
      ],
    );
  }
}
