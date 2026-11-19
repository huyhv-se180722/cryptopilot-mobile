import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_failure.dart';
import '../data/academy_api.dart';
import '../domain/academy.dart';

/// Search sends nothing below this many characters (the API needs 2–100).
const academySearchMin = 2;

/// Typing pauses this long before a search goes out, as on the web.
const academySearchDelay = Duration(milliseconds: 350);

/// Lessons read per page.
const academyPageSize = 20;

/// The text to send for what the Trader typed, or null below
/// [academySearchMin] characters; at most 100 characters.
String? academyQuery(String text) {
  final trimmed = text.trim();
  if (trimmed.length < academySearchMin) return null;
  return trimmed.length > 100 ? trimmed.substring(0, 100) : trimmed;
}

@immutable
class AcademyState {
  const AcademyState({
    this.topics,
    this.path,
    this.lessons,
    this.total = 0,
    this.page = 0,
    this.topic,
    this.level,
    this.query,
    this.loadingMore = false,
    this.failure,
  });

  final List<AcademyTopic>? topics;

  /// The beginner path; empty when it cannot be read.
  final List<LessonSummary>? path;

  /// The lessons of the filters, page after page; null while the first page
  /// loads.
  final List<LessonSummary>? lessons;
  final int total;
  final int page;
  final String? topic;
  final LessonLevel? level;
  final String? query;
  final bool loadingMore;

  /// The first page of the filters could not be read.
  final ApiFailure? failure;

  bool get hasMore => lessons != null && lessons!.length < total;

  bool get filtered => topic != null || level != null || query != null;
}

final academyControllerProvider =
    NotifierProvider.autoDispose<AcademyController, AcademyState>(
      AcademyController.new,
    );

/// The Academy screen (D-155): topics, the beginner path and the lessons of
/// the chosen topic, level and search, read page after page as the list
/// scrolls. An answer to older filters is dropped.
class AcademyController extends Notifier<AcademyState> {
  Timer? _typing;

  /// Raised by every new set of filters; an answer carries the one it was
  /// asked with.
  int _request = 0;

  AcademyApi get _api => ref.read(academyApiProvider);

  @override
  AcademyState build() {
    ref.onDispose(() => _typing?.cancel());
    unawaited(Future.microtask(load));
    return const AcademyState();
  }

  /// Topics, path and the first page, all again.
  Future<void> load() async {
    await Future.wait([_readTopics(), _readPath(), _firstPage()]);
  }

  Future<void> _readTopics() async {
    try {
      final topics = await _api.topics();
      if (ref.mounted) state = _with(topics: topics);
    } on ApiFailure {
      // The chips are left out; the lessons still list.
      if (ref.mounted && state.topics == null) state = _with(topics: const []);
    }
  }

  Future<void> _readPath() async {
    try {
      final path = await _api.path();
      if (ref.mounted) state = _with(path: path);
    } on ApiFailure {
      if (ref.mounted && state.path == null) state = _with(path: const []);
    }
  }

  Future<void> _firstPage() async {
    final request = ++_request;
    state = _with(clearLessons: true, clearFailure: true, loadingMore: false);
    try {
      final page = await _api.lessons(
        topic: state.topic,
        level: state.level,
        query: state.query,
        pageSize: academyPageSize,
      );
      if (!ref.mounted || request != _request) return;
      state = _with(lessons: page.items, total: page.total, page: page.page);
    } on ApiFailure catch (failure) {
      if (ref.mounted && request == _request) state = _with(failure: failure);
    }
  }

  /// The next page, when the list reaches its end.
  Future<void> loadMore() async {
    if (!state.hasMore || state.loadingMore) return;
    final request = _request;
    state = _with(loadingMore: true);
    try {
      final page = await _api.lessons(
        topic: state.topic,
        level: state.level,
        query: state.query,
        page: state.page + 1,
        pageSize: academyPageSize,
      );
      if (!ref.mounted || request != _request) return;
      state = _with(
        lessons: [...?state.lessons, ...page.items],
        total: page.total,
        page: page.page,
        loadingMore: false,
      );
    } on ApiFailure {
      // The end of the list offers the next page again.
      if (ref.mounted && request == _request) state = _with(loadingMore: false);
    }
  }

  void selectTopic(String? slug) {
    if (slug == state.topic) return;
    state = _with(topic: slug, clearTopic: slug == null);
    unawaited(_firstPage());
  }

  void selectLevel(LessonLevel? level) {
    if (level == state.level) return;
    state = _with(level: level, clearLevel: level == null);
    unawaited(_firstPage());
  }

  /// What the Trader typed; the search goes out after a pause.
  void search(String text) {
    _typing?.cancel();
    final query = academyQuery(text);
    if (query == state.query) return;
    _typing = Timer(academySearchDelay, () {
      state = _with(query: query, clearQuery: query == null);
      unawaited(_firstPage());
    });
  }

  AcademyState _with({
    List<AcademyTopic>? topics,
    List<LessonSummary>? path,
    List<LessonSummary>? lessons,
    bool clearLessons = false,
    int? total,
    int? page,
    String? topic,
    bool clearTopic = false,
    LessonLevel? level,
    bool clearLevel = false,
    String? query,
    bool clearQuery = false,
    bool? loadingMore,
    ApiFailure? failure,
    bool clearFailure = false,
  }) => AcademyState(
    topics: topics ?? state.topics,
    path: path ?? state.path,
    lessons: clearLessons ? null : lessons ?? state.lessons,
    total: clearLessons ? 0 : total ?? state.total,
    page: clearLessons ? 0 : page ?? state.page,
    topic: clearTopic ? null : topic ?? state.topic,
    level: clearLevel ? null : level ?? state.level,
    query: clearQuery ? null : query ?? state.query,
    loadingMore: loadingMore ?? state.loadingMore,
    failure: clearFailure ? null : failure ?? state.failure,
  );
}
