import 'package:flutter/foundation.dart';

import '../../../core/json/json_read.dart';

/// How much a reader should already know (`ArticleLevel`).
enum LessonLevel {
  beginner('BEGINNER'),
  intermediate('INTERMEDIATE'),
  advanced('ADVANCED');

  const LessonLevel(this.wire);

  final String wire;

  static LessonLevel decode(String value) => values.firstWhere(
    (level) => level.wire == value,
    orElse: () => throw DecodeException('level $value is unknown'),
  );
}

/// A topic of the Academy home (`TopicResponse`).
@immutable
class AcademyTopic {
  const AcademyTopic({
    required this.slug,
    required this.name,
    required this.description,
    required this.lessons,
  });

  final String slug;
  final String name;
  final String description;

  /// Published lessons of the topic.
  final int lessons;
}

/// A lesson as a card shows it (`ArticleSummaryResponse`).
@immutable
class LessonSummary {
  const LessonSummary({
    required this.slug,
    required this.title,
    required this.summary,
    required this.level,
    required this.readingMinutes,
    required this.topicSlug,
    required this.topicName,
    this.pathOrder,
    this.coverImageUrl,
  });

  final String slug;
  final String title;
  final String summary;
  final LessonLevel level;
  final int readingMinutes;
  final String topicSlug;
  final String topicName;

  /// Place on the beginner path; null when the lesson is not on it.
  final int? pathOrder;
  final String? coverImageUrl;
}

/// Another lesson named from a lesson page (`ArticleLinkResponse`).
@immutable
class LessonLink {
  const LessonLink({required this.slug, required this.title});

  final String slug;
  final String title;
}

/// A lesson page (`ArticleDetailResponse`).
@immutable
class Lesson {
  const Lesson({
    required this.summary,
    required this.body,
    required this.updatedAt,
    required this.related,
    this.appLink,
    this.previous,
    this.next,
    this.coverCredit,
  });

  /// The card fields of the lesson.
  final LessonSummary summary;

  /// Markdown (the subset of `markdown.dart`).
  final String body;
  final DateTime updatedAt;

  /// The web path of the screen the lesson teaches, such as `/markets`.
  final String? appLink;
  final LessonLink? previous;
  final LessonLink? next;

  /// Up to three lessons of the same topic.
  final List<LessonSummary> related;
  final String? coverCredit;
}

/// A glossary entry (`TermResponse`).
@immutable
class GlossaryTerm {
  const GlossaryTerm({
    required this.slug,
    required this.term,
    required this.definition,
    this.lessonSlug,
    this.lessonTitle,
  });

  final String slug;
  final String term;
  final String definition;

  /// The lesson that explains the term at length.
  final String? lessonSlug;
  final String? lessonTitle;
}

/// One page of lessons (`PageResponse<ArticleSummaryResponse>`).
@immutable
class LessonPage {
  const LessonPage({
    required this.items,
    required this.page,
    required this.total,
  });

  final List<LessonSummary> items;
  final int page;
  final int total;
}

/// The Trader's progress (`AcademyProgressResponse`).
@immutable
class AcademyProgress {
  const AcademyProgress({
    required this.completed,
    required this.publishedTotal,
    required this.pathCompleted,
    required this.pathTotal,
  });

  /// Slugs of the lessons marked as learned.
  final Set<String> completed;
  final int publishedTotal;
  final int pathCompleted;
  final int pathTotal;
}

int _readInt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is int) return value;
  throw DecodeException('$key is not a whole number');
}

int? _readOptionalInt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is int) return value;
  throw DecodeException('$key is not a whole number');
}

List<Object?> _readList(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is List) return value;
  throw DecodeException('$key is not a list');
}

List<Object?> _asList(Object? body, String what) {
  if (body is List) return body;
  throw DecodeException('$what is not a list');
}

AcademyTopic decodeTopic(Object? body) {
  final json = asJsonObject(body, 'topic');
  return AcademyTopic(
    slug: readString(json, 'slug'),
    name: readString(json, 'name'),
    description: readString(json, 'description'),
    lessons: _readInt(json, 'articles'),
  );
}

List<AcademyTopic> decodeTopics(Object? body) => [
  for (final item in _asList(body, 'topics')) decodeTopic(item),
];

LessonSummary decodeLessonSummary(Object? body) {
  final json = asJsonObject(body, 'lesson');
  return LessonSummary(
    slug: readString(json, 'slug'),
    title: readString(json, 'title'),
    summary: readString(json, 'summary'),
    level: LessonLevel.decode(readString(json, 'level')),
    readingMinutes: _readInt(json, 'readingMinutes'),
    topicSlug: readString(json, 'topicSlug'),
    topicName: readString(json, 'topicName'),
    pathOrder: _readOptionalInt(json, 'pathOrder'),
    coverImageUrl: readOptionalString(json, 'coverImageUrl'),
  );
}

List<LessonSummary> decodeLessonList(Object? body) => [
  for (final item in _asList(body, 'lessons')) decodeLessonSummary(item),
];

LessonPage decodeLessonPage(Object? body) {
  final json = asJsonObject(body, 'lesson page');
  return LessonPage(
    items: [
      for (final item in _readList(json, 'items')) decodeLessonSummary(item),
    ],
    page: _readInt(json, 'page'),
    total: _readInt(json, 'total'),
  );
}

LessonLink? _decodeLink(Object? body) {
  if (body == null) return null;
  final json = asJsonObject(body, 'lesson link');
  return LessonLink(
    slug: readString(json, 'slug'),
    title: readString(json, 'title'),
  );
}

Lesson decodeLesson(Object? body) {
  final json = asJsonObject(body, 'lesson page');
  return Lesson(
    summary: decodeLessonSummary(json),
    body: readString(json, 'body'),
    updatedAt: readInstant(json, 'updatedAt'),
    appLink: readOptionalString(json, 'appLink'),
    previous: _decodeLink(json['previous']),
    next: _decodeLink(json['next']),
    related: [
      for (final item in _readList(json, 'related')) decodeLessonSummary(item),
    ],
    coverCredit: readOptionalString(json, 'coverCredit'),
  );
}

GlossaryTerm decodeTerm(Object? body) {
  final json = asJsonObject(body, 'term');
  return GlossaryTerm(
    slug: readString(json, 'slug'),
    term: readString(json, 'term'),
    definition: readString(json, 'definition'),
    lessonSlug: readOptionalString(json, 'articleSlug'),
    lessonTitle: readOptionalString(json, 'articleTitle'),
  );
}

List<GlossaryTerm> decodeTerms(Object? body) => [
  for (final item in _asList(body, 'terms')) decodeTerm(item),
];

AcademyProgress decodeProgress(Object? body) {
  final json = asJsonObject(body, 'progress');
  return AcademyProgress(
    completed: {
      for (final item in _readList(json, 'completed'))
        readString(asJsonObject(item, 'completed lesson'), 'slug'),
    },
    publishedTotal: _readInt(json, 'publishedTotal'),
    pathCompleted: _readInt(json, 'pathCompleted'),
    pathTotal: _readInt(json, 'pathTotal'),
  );
}
