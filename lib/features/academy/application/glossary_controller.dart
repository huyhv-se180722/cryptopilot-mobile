import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_failure.dart';
import '../data/academy_api.dart';
import '../domain/academy.dart';
import 'academy_controller.dart';

/// The first letters a term may start with: the Latin letters and Đ, as on
/// the web.
const glossaryLetters = [
  'A', 'B', 'C', 'D', 'Đ', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', //
  'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
];

@immutable
class GlossaryState {
  const GlossaryState({this.terms, this.failure, this.letter, this.query});

  final List<GlossaryTerm>? terms;
  final ApiFailure? failure;
  final String? letter;
  final String? query;

  /// The terms under their first letter, in the order they came.
  Map<String, List<GlossaryTerm>> get groups {
    final groups = <String, List<GlossaryTerm>>{};
    for (final term in terms ?? const <GlossaryTerm>[]) {
      final key = term.term.isEmpty ? '' : term.term[0].toUpperCase();
      (groups[key] ??= []).add(term);
    }
    return groups;
  }
}

final glossaryControllerProvider =
    NotifierProvider.autoDispose<GlossaryController, GlossaryState>(
      GlossaryController.new,
    );

/// The glossary: every term, or those of a first letter and a search, both
/// filtered by the server. An answer to an older filter is dropped.
class GlossaryController extends Notifier<GlossaryState> {
  Timer? _typing;
  int _request = 0;

  @override
  GlossaryState build() {
    ref.onDispose(() => _typing?.cancel());
    unawaited(Future.microtask(load));
    return const GlossaryState();
  }

  Future<void> load() async {
    final request = ++_request;
    final letter = state.letter;
    final query = state.query;
    state = GlossaryState(letter: letter, query: query);
    try {
      final terms = await ref
          .read(academyApiProvider)
          .terms(query: query, letter: letter);
      if (ref.mounted && request == _request) {
        state = GlossaryState(terms: terms, letter: letter, query: query);
      }
    } on ApiFailure catch (failure) {
      if (ref.mounted && request == _request) {
        state = GlossaryState(failure: failure, letter: letter, query: query);
      }
    }
  }

  /// Null shows every letter.
  void selectLetter(String? letter) {
    if (letter == state.letter) return;
    state = GlossaryState(
      terms: state.terms,
      letter: letter,
      query: state.query,
    );
    unawaited(load());
  }

  void search(String text) {
    _typing?.cancel();
    final query = academyQuery(text);
    if (query == state.query) return;
    _typing = Timer(academySearchDelay, () {
      state = GlossaryState(
        terms: state.terms,
        letter: state.letter,
        query: query,
      );
      unawaited(load());
    });
  }
}
