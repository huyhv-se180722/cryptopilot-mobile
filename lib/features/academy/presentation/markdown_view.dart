import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/cp_colors.dart';
import '../domain/markdown.dart';

/// A lesson body as widgets. Links call [onLink] with their app path or web
/// address; the recognizers they need are released with each build.
class MarkdownView extends StatefulWidget {
  const MarkdownView({required this.blocks, required this.onLink, super.key});

  final List<Block> blocks;
  final void Function(String href) onLink;

  @override
  State<MarkdownView> createState() => _MarkdownViewState();
}

class _MarkdownViewState extends State<MarkdownView> {
  final List<TapGestureRecognizer> _recognizers = [];

  void _release() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  @override
  void dispose() {
    _release();
    super.dispose();
  }

  TapGestureRecognizer _tap(String href) {
    final recognizer = TapGestureRecognizer()
      ..onTap = () => widget.onLink(href);
    _recognizers.add(recognizer);
    return recognizer;
  }

  /// A recognizer applies only to the span that holds it, not to its
  /// children, so a link hands its own down to every piece of its text.
  List<InlineSpan> _spans(
    List<Inline> inlines,
    TextStyle style, [
    TapGestureRecognizer? link,
  ]) => [
    for (final inline in inlines)
      switch (inline) {
        TextInline(:final text) => TextSpan(
          text: text,
          style: style,
          recognizer: link,
        ),
        StrongInline(:final children) => TextSpan(
          children: _spans(
            children,
            style.copyWith(fontWeight: FontWeight.w700),
            link,
          ),
        ),
        EmInline(:final children) => TextSpan(
          children: _spans(
            children,
            style.copyWith(fontStyle: FontStyle.italic),
            link,
          ),
        ),
        CodeInline(:final text) => TextSpan(
          text: text,
          style: style.copyWith(
            fontFamily: 'monospace',
            backgroundColor: context.cp.raised,
          ),
          recognizer: link,
        ),
        LinkInline(:final href, :final children) => TextSpan(
          children: _spans(
            children,
            style.copyWith(
              color: context.cp.primary,
              decoration: TextDecoration.underline,
            ),
            _tap(href),
          ),
        ),
      },
  ];

  Widget _rich(List<Inline> inlines, TextStyle style) =>
      Text.rich(TextSpan(children: _spans(inlines, style)));

  @override
  Widget build(BuildContext context) {
    _release();
    final theme = Theme.of(context).textTheme;
    final body = (theme.bodyMedium ?? const TextStyle()).copyWith(
      height: 1.5,
      color: context.cp.text,
    );
    return Column(
      key: const Key('lesson-body'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final block in widget.blocks)
          switch (block) {
            HeadingBlock(:final level, :final text) => Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 6),
              child: Text(
                text,
                style: switch (level) {
                  2 => theme.titleLarge,
                  3 => theme.titleMedium,
                  _ => theme.titleSmall,
                },
              ),
            ),
            ParagraphBlock(:final content) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _rich(content, body),
            ),
            ListBlock(:final ordered, :final items) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < items.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 24,
                            child: Text(
                              ordered ? '${i + 1}.' : '•',
                              style: body,
                            ),
                          ),
                          Expanded(child: _rich(items[i], body)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            TableBlock(:final header, :final rows) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              // Wider than the phone: the table scrolls, the page does not.
              child: SingleChildScrollView(
                key: const Key('lesson-table'),
                scrollDirection: Axis.horizontal,
                child: Table(
                  defaultColumnWidth: const IntrinsicColumnWidth(),
                  border: TableBorder.all(color: context.cp.border),
                  children: [
                    TableRow(
                      decoration: BoxDecoration(color: context.cp.raised),
                      children: [
                        for (final cell in header)
                          _cell(
                            _rich(
                              cell,
                              body.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                      ],
                    ),
                    for (final row in rows)
                      TableRow(
                        children: [
                          for (var i = 0; i < header.length; i++)
                            _cell(
                              _rich(i < row.length ? row[i] : const [], body),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            QuoteBlock(:final paragraphs) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              decoration: BoxDecoration(
                color: context.cp.raised,
                border: Border(
                  left: BorderSide(color: context.cp.primary, width: 3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final paragraph in paragraphs)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _rich(paragraph, body),
                    ),
                ],
              ),
            ),
            RuleBlock() => const Divider(height: 24),
          },
      ],
    );
  }

  Widget _cell(Widget child) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 240),
    child: Padding(padding: const EdgeInsets.all(8), child: child),
  );
}
