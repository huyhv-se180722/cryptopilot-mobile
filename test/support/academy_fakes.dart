import 'dart:async';

import 'package:cryptopilot_mobile/features/academy/data/academy_api.dart';
import 'package:cryptopilot_mobile/features/academy/domain/academy.dart';

LessonSummary lessonOf(
  String slug, {
  String topic = 'basics',
  LessonLevel level = LessonLevel.beginner,
  int? pathOrder,
  String? cover,
}) => LessonSummary(
  slug: slug,
  title: 'Title $slug',
  summary: 'Summary $slug',
  level: level,
  readingMinutes: 5,
  topicSlug: topic,
  topicName: 'Topic $topic',
  pathOrder: pathOrder,
  coverImageUrl: cover,
);

/// The Academy as the seed of backend develop 5c2398cb shapes it, in memory.
class FakeAcademyApi implements AcademyApi {
  List<AcademyTopic> topicList = const [
    AcademyTopic(
      slug: 'basics',
      name: 'Topic basics',
      description: 'First steps',
      lessons: 30,
    ),
    AcademyTopic(
      slug: 'risk',
      name: 'Topic risk',
      description: 'Managing risk',
      lessons: 5,
    ),
  ];

  /// Every published lesson, in reading order.
  List<LessonSummary> all = [
    for (var i = 1; i <= 30; i++)
      lessonOf('lesson-$i', pathOrder: i <= 3 ? i : null),
    for (var i = 1; i <= 5; i++)
      lessonOf('risk-$i', topic: 'risk', level: LessonLevel.intermediate),
  ];

  /// Lesson bodies by slug; others get a short default.
  final Map<String, String> bodies = {};
  final Map<String, String?> appLinks = {};

  List<GlossaryTerm> glossary = const [
    GlossaryTerm(
      slug: 'altcoin',
      term: 'Altcoin',
      definition: 'Any coin other than Bitcoin.',
      lessonSlug: 'lesson-2',
      lessonTitle: 'Title lesson-2',
    ),
    GlossaryTerm(slug: 'ath', term: 'ATH', definition: 'All-time high.'),
    GlossaryTerm(
      slug: 'bitcoin',
      term: 'Bitcoin (BTC)',
      definition: 'The first cryptocurrency.',
    ),
  ];

  Set<String> completed = {'lesson-1'};

  /// Calls in order, e.g. `lessons page=1 topic=risk q=btc`, `mark lesson-2`.
  final List<String> calls = [];

  Object? topicsError;
  Object? lessonsError;
  Object? lessonError;
  Object? termsError;
  Object? progressError;
  Object? markError;

  /// While set, `lessons()` waits for it.
  Completer<void>? lessonsHold;

  /// While set, `mark()` and `unmark()` wait for it.
  Completer<void>? markHold;

  @override
  Future<List<AcademyTopic>> topics() async {
    calls.add('topics');
    if (topicsError case final error?) throw error;
    return topicList;
  }

  @override
  Future<LessonPage> lessons({
    String? topic,
    LessonLevel? level,
    String? query,
    int page = 1,
    int pageSize = 20,
  }) async {
    calls.add(
      [
        'lessons page=$page',
        if (topic != null) 'topic=$topic',
        if (level != null) 'level=${level.wire}',
        if (query != null) 'q=$query',
      ].join(' '),
    );
    if (lessonsHold case final hold?) await hold.future;
    if (lessonsError case final error?) throw error;
    final found = [
      for (final lesson in all)
        if ((topic == null || lesson.topicSlug == topic) &&
            (level == null || lesson.level == level) &&
            (query == null ||
                lesson.title.toLowerCase().contains(query.toLowerCase())))
          lesson,
    ];
    final start = (page - 1) * pageSize;
    return LessonPage(
      items: found.skip(start).take(pageSize).toList(),
      page: page,
      total: found.length,
    );
  }

  @override
  Future<Lesson> lesson(String slug) async {
    calls.add('lesson $slug');
    if (lessonError case final error?) throw error;
    final index = all.indexWhere((lesson) => lesson.slug == slug);
    final summary = all[index];
    LessonLink? link(int at) => at < 0 || at >= all.length
        ? null
        : LessonLink(slug: all[at].slug, title: all[at].title);
    return Lesson(
      summary: summary,
      body: bodies[slug] ?? '## Intro\n\nText of **$slug**.',
      updatedAt: DateTime.utc(2026, 10, 25, 3),
      appLink: appLinks.containsKey(slug) ? appLinks[slug] : '/markets',
      previous: link(index - 1),
      next: link(index + 1),
      related: [
        for (final lesson in all)
          if (lesson.topicSlug == summary.topicSlug && lesson.slug != slug)
            lesson,
      ].take(3).toList(),
      coverCredit: summary.coverImageUrl == null ? null : 'Unsplash',
    );
  }

  @override
  Future<List<LessonSummary>> path() async {
    calls.add('path');
    return [
      for (final lesson in all)
        if (lesson.pathOrder != null) lesson,
    ];
  }

  @override
  Future<List<GlossaryTerm>> terms({String? query, String? letter}) async {
    calls.add(
      [
        'terms',
        if (query != null) 'q=$query',
        if (letter != null) 'letter=$letter',
      ].join(' '),
    );
    if (termsError case final error?) throw error;
    return [
      for (final term in glossary)
        if ((letter == null || term.term.toUpperCase().startsWith(letter)) &&
            (query == null ||
                term.term.toLowerCase().contains(query.toLowerCase())))
          term,
    ];
  }

  @override
  Future<AcademyProgress> progress() async {
    calls.add('progress');
    if (progressError case final error?) throw error;
    final path = {
      for (final lesson in all)
        if (lesson.pathOrder != null) lesson.slug,
    };
    return AcademyProgress(
      completed: {...completed},
      publishedTotal: all.length,
      pathCompleted: completed.where(path.contains).length,
      pathTotal: path.length,
    );
  }

  @override
  Future<void> mark(String slug) async {
    calls.add('mark $slug');
    if (markHold case final hold?) await hold.future;
    if (markError case final error?) throw error;
    completed.add(slug);
  }

  @override
  Future<void> unmark(String slug) async {
    calls.add('unmark $slug');
    if (markHold case final hold?) await hold.future;
    if (markError case final error?) throw error;
    completed.remove(slug);
  }
}
