import 'package:cryptopilot_mobile/features/academy/domain/markdown.dart';
import 'package:flutter_test/flutter_test.dart';

/// The cases of the web's `markdown.test.ts`, the anchors left out (the app
/// shows no table of contents).
void main() {
  group('Academy Markdown (as the web parses it)', () {
    test('headings of three levels; a single # stays a paragraph', () {
      final blocks = parseMarkdown(
        '## Ví & bảo mật\n\ntext\n\n### Chi tiết\n\n#### Nhỏ\n\n# Một',
      );
      expect(blocks.map((b) => b.runtimeType), [
        HeadingBlock,
        ParagraphBlock,
        HeadingBlock,
        HeadingBlock,
        ParagraphBlock,
      ]);
      expect((blocks.first as HeadingBlock).text, 'Ví & bảo mật');
      expect((blocks[3] as HeadingBlock).level, 4);
    });

    test('joins the lines of a paragraph and reads bullet and numbered '
        'lists', () {
      final blocks = parseMarkdown(
        'one\ntwo\n\n- a\n- **b**\n\n1. first\n2. second',
      );
      expect((blocks[0] as ParagraphBlock).content, [
        const TextInline('one two'),
      ]);
      final bullets = blocks[1] as ListBlock;
      expect(bullets.ordered, isFalse);
      expect(bullets.items[1], [
        const StrongInline([TextInline('b')]),
      ]);
      expect((blocks[2] as ListBlock).ordered, isTrue);
      expect((blocks[2] as ListBlock).items, hasLength(2));
    });

    test('reads a table with its header row and a quote', () {
      final blocks = parseMarkdown(
        '| A | B |\n|---|---|\n| 1 | *2* |\n\n> Lãi = Giá × Đòn bẩy\n>\n> *note*',
      );
      final table = blocks[0] as TableBlock;
      expect(table.header, [
        [const TextInline('A')],
        [const TextInline('B')],
      ]);
      expect(table.rows[0][1], [
        const EmInline([TextInline('2')]),
      ]);
      expect((blocks[1] as QuoteBlock).paragraphs, hasLength(2));
    });

    test('a rule, inline code and text around marks', () {
      final blocks = parseMarkdown('a `x` b\n\n---\n\n***');
      expect((blocks[0] as ParagraphBlock).content, [
        const TextInline('a '),
        const CodeInline('x'),
        const TextInline(' b'),
      ]);
      expect(blocks[1], isA<RuleBlock>());
      expect(blocks[2], isA<RuleBlock>());
    });

    test('links only app paths and web addresses', () {
      expect(parseInline('[a](/plans/new) [b](javascript:alert(1))'), [
        const LinkInline('/plans/new', [TextInline('a')]),
        const TextInline(' '),
        const TextInline('b'),
        const TextInline(')'),
      ]);
      expect(safeHref('//evil.test'), isNull);
      expect(safeHref('https://example.test'), 'https://example.test');
    });

    test('keeps going past a line that looks like a table but is not one', () {
      final blocks = parseMarkdown('| lonely\nnext');
      expect(blocks, hasLength(1));
      expect((blocks.single as ParagraphBlock).content, [
        const TextInline('| lonely next'),
      ]);
    });

    test('Windows line ends read as the others', () {
      expect(parseMarkdown('## A\r\n\r\nb'), hasLength(2));
    });
  });
}
