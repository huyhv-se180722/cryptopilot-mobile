import 'package:cryptopilot_mobile/core/json/json_read.dart';
import 'package:cryptopilot_mobile/features/academy/domain/academy.dart';
import 'package:flutter_test/flutter_test.dart';

/// Shapes of backend develop 5c2398cb (`academy/dto/response`).
Map<String, Object?> summaryJson({
  String slug = 'bitcoin-la-gi',
  Object? level = 'BEGINNER',
  Object? pathOrder = 1,
}) => {
  'slug': slug,
  'title': 'Bitcoin là gì?',
  'summary': 'Đồng tiền mã hóa đầu tiên.',
  'level': level,
  'readingMinutes': 6,
  'topicSlug': 'nhap-mon',
  'topicName': 'Nhập môn',
  'pathOrder': pathOrder,
  'coverImageUrl': null,
};

void main() {
  group('Academy decoders (backend develop 5c2398cb)', () {
    test('topics carry the number of their lessons', () {
      final topics = decodeTopics([
        {
          'slug': 'nhap-mon',
          'name': 'Nhập môn',
          'description': 'Những bước đầu tiên.',
          'articles': 8,
        },
      ]);
      expect(topics.single.lessons, 8);
    });

    test('a page of lessons; pathOrder and cover may be null', () {
      final page = decodeLessonPage({
        'items': [summaryJson(), summaryJson(slug: 'vi', pathOrder: null)],
        'page': 1,
        'pageSize': 20,
        'total': 41,
      });
      expect(page.total, 41);
      expect(page.items.first.level, LessonLevel.beginner);
      expect(page.items.first.pathOrder, 1);
      expect(page.items.last.pathOrder, isNull);
      expect(page.items.last.coverImageUrl, isNull);
    });

    test('a lesson page with its neighbours, related lessons and app link', () {
      final lesson = decodeLesson({
        ...summaryJson(),
        'body': '## Mở đầu\n\nNội dung.',
        'appLink': '/markets',
        'publishedAt': '2026-10-25T03:00:00Z',
        'updatedAt': '2026-10-26T04:00:00Z',
        'previous': null,
        'next': {'slug': 'vi-crypto', 'title': 'Ví crypto'},
        'related': [summaryJson(slug: 'blockchain', pathOrder: null)],
        'coverImageUrl': 'https://res.cloudinary.com/x/cover.jpg',
        'coverCredit': 'Unsplash',
      });
      expect(lesson.summary.slug, 'bitcoin-la-gi');
      expect(lesson.previous, isNull);
      expect(lesson.next!.title, 'Ví crypto');
      expect(lesson.related.single.slug, 'blockchain');
      expect(lesson.updatedAt, DateTime.utc(2026, 10, 26, 4));
      expect(lesson.appLink, '/markets');
    });

    test('terms may name no lesson', () {
      final terms = decodeTerms([
        {
          'slug': 'ath',
          'term': 'ATH (All-Time High)',
          'definition': 'Mức giá cao nhất.',
          'articleSlug': null,
          'articleTitle': null,
        },
      ]);
      expect(terms.single.lessonSlug, isNull);
    });

    test('progress keeps the marked slugs and the totals', () {
      final progress = decodeProgress({
        'completed': [
          {'slug': 'bitcoin-la-gi', 'completedAt': '2026-11-01T00:00:00Z'},
        ],
        'publishedTotal': 41,
        'pathCompleted': 1,
        'pathTotal': 8,
      });
      expect(progress.completed, {'bitcoin-la-gi'});
      expect(progress.pathTotal, 8);
    });

    test('an unknown level, a decimal count or a missing list is refused', () {
      expect(
        () => decodeLessonSummary(summaryJson(level: 'EXPERT')),
        throwsA(isA<DecodeException>()),
      );
      expect(
        () => decodeLessonSummary(summaryJson(pathOrder: 1.5)),
        throwsA(isA<DecodeException>()),
      );
      expect(
        () => decodeLessonPage({'page': 1, 'total': 0}),
        throwsA(isA<DecodeException>()),
      );
      expect(() => decodeTopics({'x': 1}), throwsA(isA<DecodeException>()));
    });
  });
}
