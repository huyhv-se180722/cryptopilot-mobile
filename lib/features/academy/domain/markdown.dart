import 'package:flutter/foundation.dart';

/// The Markdown of the Academy lessons (T-114), parsed into plain data that
/// the lesson view draws as widgets: nothing in a lesson can become markup.
/// Only the subset the lessons use is understood, as on the web
/// (`markdown.ts`, D-155): headings (##, ###, ####), paragraphs, bullet and
/// numbered lists, tables, block quotes, rules, and inline bold, italic,
/// code and links; anything else stays visible as text. No heading anchors:
/// the app shows no table of contents.
sealed class Inline {
  const Inline();
}

@immutable
class TextInline extends Inline {
  const TextInline(this.text);
  final String text;

  @override
  bool operator ==(Object other) => other is TextInline && other.text == text;

  @override
  int get hashCode => text.hashCode;

  @override
  String toString() => 'text($text)';
}

@immutable
class StrongInline extends Inline {
  const StrongInline(this.children);
  final List<Inline> children;

  @override
  bool operator ==(Object other) =>
      other is StrongInline && listEquals(other.children, children);

  @override
  int get hashCode => Object.hashAll(children);

  @override
  String toString() => 'strong($children)';
}

@immutable
class EmInline extends Inline {
  const EmInline(this.children);
  final List<Inline> children;

  @override
  bool operator ==(Object other) =>
      other is EmInline && listEquals(other.children, children);

  @override
  int get hashCode => Object.hashAll(children);

  @override
  String toString() => 'em($children)';
}

@immutable
class CodeInline extends Inline {
  const CodeInline(this.text);
  final String text;

  @override
  bool operator ==(Object other) => other is CodeInline && other.text == text;

  @override
  int get hashCode => text.hashCode;

  @override
  String toString() => 'code($text)';
}

@immutable
class LinkInline extends Inline {
  const LinkInline(this.href, this.children);

  /// An app path (`/markets`) or a web address (`https://…`), see [safeHref].
  final String href;
  final List<Inline> children;

  @override
  bool operator ==(Object other) =>
      other is LinkInline &&
      other.href == href &&
      listEquals(other.children, children);

  @override
  int get hashCode => Object.hash(href, Object.hashAll(children));

  @override
  String toString() => 'link($href, $children)';
}

sealed class Block {
  const Block();
}

class HeadingBlock extends Block {
  const HeadingBlock(this.level, this.text);

  /// 2, 3 or 4.
  final int level;
  final String text;
}

class ParagraphBlock extends Block {
  const ParagraphBlock(this.content);
  final List<Inline> content;
}

class ListBlock extends Block {
  const ListBlock({required this.ordered, required this.items});
  final bool ordered;
  final List<List<Inline>> items;
}

class TableBlock extends Block {
  const TableBlock({required this.header, required this.rows});
  final List<List<Inline>> header;
  final List<List<List<Inline>>> rows;
}

class QuoteBlock extends Block {
  const QuoteBlock(this.paragraphs);
  final List<List<Inline>> paragraphs;
}

class RuleBlock extends Block {
  const RuleBlock();
}

final _heading = RegExp(r'^(#{2,4})\s+(.+?)\s*#*\s*$');
final _bullet = RegExp(r'^\s*[-*]\s+(.*)$');
final _numbered = RegExp(r'^\s*\d+[.)]\s+(.*)$');
final _rule = RegExp(r'^\s*(-{3,}|\*{3,})\s*$');
final _tableSeparator = RegExp(
  r'^\s*\|?\s*:?-{2,}:?\s*(\|\s*:?-{2,}:?\s*)*\|?\s*$',
);
final _inline = RegExp(
  r'(`[^`]+`)|(\*\*(?=\S)[\s\S]*?\S\*\*)|(\*(?=\S)[^*]*?\S\*|\*\S\*)|(\[[^\]]+\]\([^)\s]+\))',
);
final _webAddress = RegExp(r'^https?://', caseSensitive: false);

/// Only app paths and web addresses are links; anything else stays text.
String? safeHref(String href) {
  if (href.startsWith('/') && !href.startsWith('//')) return href;
  return _webAddress.hasMatch(href) ? href : null;
}

List<Inline> parseInline(String source) {
  final result = <Inline>[];
  var last = 0;
  for (final match in _inline.allMatches(source)) {
    if (match.start > last) {
      result.add(TextInline(source.substring(last, match.start)));
    }
    final token = match[0]!;
    if (match[1] != null) {
      result.add(CodeInline(token.substring(1, token.length - 1)));
    } else if (match[2] != null) {
      result.add(
        StrongInline(parseInline(token.substring(2, token.length - 2))),
      );
    } else if (match[3] != null) {
      result.add(EmInline(parseInline(token.substring(1, token.length - 1))));
    } else {
      final split = token.indexOf('](');
      final label = parseInline(token.substring(1, split));
      final href = safeHref(token.substring(split + 2, token.length - 1));
      if (href != null) {
        result.add(LinkInline(href, label));
      } else {
        result.addAll(label);
      }
    }
    last = match.end;
  }
  if (last < source.length) result.add(TextInline(source.substring(last)));
  return result;
}

List<String> _cells(String line) {
  var row = line.trim();
  if (row.startsWith('|')) row = row.substring(1);
  if (row.endsWith('|')) row = row.substring(0, row.length - 1);
  return [for (final cell in row.split('|')) cell.trim()];
}

bool _isBlank(String? line) => line == null || line.trim().isEmpty;

List<Block> parseMarkdown(String source) {
  final lines = source.replaceAll(RegExp(r'\r\n?'), '\n').split('\n');
  final blocks = <Block>[];
  String? at(int index) => index < lines.length ? lines[index] : null;
  var i = 0;

  while (i < lines.length) {
    final line = lines[i];
    if (_isBlank(line)) {
      i++;
      continue;
    }
    final heading = _heading.firstMatch(line);
    if (heading != null) {
      blocks.add(HeadingBlock(heading[1]!.length, heading[2]!));
      i++;
      continue;
    }
    if (_rule.hasMatch(line)) {
      blocks.add(const RuleBlock());
      i++;
      continue;
    }
    if (line.trim().startsWith('|') &&
        _tableSeparator.hasMatch(at(i + 1) ?? '')) {
      final header = [for (final cell in _cells(line)) parseInline(cell)];
      final rows = <List<List<Inline>>>[];
      i += 2;
      while (i < lines.length && lines[i].trim().startsWith('|')) {
        rows.add([for (final cell in _cells(lines[i])) parseInline(cell)]);
        i++;
      }
      blocks.add(TableBlock(header: header, rows: rows));
      continue;
    }
    if (line.trim().startsWith('>')) {
      final paragraphs = <List<Inline>>[];
      var current = <String>[];
      while (i < lines.length && lines[i].trim().startsWith('>')) {
        final text = lines[i].trim().replaceFirst(RegExp(r'^>\s?'), '');
        if (text.trim().isEmpty) {
          if (current.isNotEmpty) {
            paragraphs.add(parseInline(current.join(' ')));
          }
          current = [];
        } else {
          current.add(text.trim());
        }
        i++;
      }
      if (current.isNotEmpty) paragraphs.add(parseInline(current.join(' ')));
      blocks.add(QuoteBlock(paragraphs));
      continue;
    }
    final ordered = _numbered.hasMatch(line);
    if (ordered || _bullet.hasMatch(line)) {
      final pattern = ordered ? _numbered : _bullet;
      final items = <List<Inline>>[];
      while (i < lines.length) {
        final item = pattern.firstMatch(lines[i]);
        if (item == null) break;
        items.add(parseInline(item[1] ?? ''));
        i++;
      }
      blocks.add(ListBlock(ordered: ordered, items: items));
      continue;
    }
    // The first line always belongs to the paragraph, so a stray "|" line
    // that starts no table still moves the parser on.
    final paragraph = [line.trim()];
    i++;
    while (i < lines.length) {
      final next = lines[i];
      if (_isBlank(next) ||
          _heading.hasMatch(next) ||
          _rule.hasMatch(next) ||
          next.trim().startsWith('|') ||
          next.trim().startsWith('>') ||
          _bullet.hasMatch(next) ||
          _numbered.hasMatch(next)) {
        break;
      }
      paragraph.add(next.trim());
      i++;
    }
    blocks.add(ParagraphBlock(parseInline(paragraph.join(' '))));
  }
  return blocks;
}
