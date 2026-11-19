import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_failure.dart';
import '../data/ai_api.dart';
import '../domain/ai.dart';

@immutable
class AiConversationsState {
  const AiConversationsState({
    this.items,
    this.topic,
    this.page = 0,
    this.total = 0,
    this.failure,
    this.loadingMore = false,
  });

  /// Null until the first page arrives; last asked first.
  final List<AiConversation>? items;

  /// The topic filter; every topic when null.
  final ConversationTopic? topic;
  final int page;
  final int total;
  final ApiFailure? failure;
  final bool loadingMore;

  bool get hasMore => items != null && items!.length < total;

  AiConversationsState copyWith({
    List<AiConversation>? items,
    int? page,
    int? total,
    ApiFailure? failure,
    bool clearFailure = false,
    bool? loadingMore,
  }) => AiConversationsState(
    items: items ?? this.items,
    topic: topic,
    page: page ?? this.page,
    total: total ?? this.total,
    failure: clearFailure ? null : failure ?? this.failure,
    loadingMore: loadingMore ?? this.loadingMore,
  );
}

final aiConversationsControllerProvider =
    NotifierProvider.autoDispose<
      AiConversationsController,
      AiConversationsState
    >(AiConversationsController.new);

/// The conversation list of SCR-29, readable on every plan (BR-52): 20 a
/// page, filtered by topic, renamed and deleted in place.
class AiConversationsController extends Notifier<AiConversationsState> {
  static const pageSize = 20;

  int _generation = 0;

  @override
  AiConversationsState build() {
    unawaited(Future.microtask(load));
    return const AiConversationsState();
  }

  AiApi get _api => ref.read(aiApiProvider);

  Future<void> load() => _loadFirst(state.topic);

  Future<void> show(ConversationTopic? topic) {
    if (topic == state.topic && state.items != null) return load();
    state = AiConversationsState(topic: topic);
    return _loadFirst(topic);
  }

  Future<void> _loadFirst(ConversationTopic? topic) async {
    final generation = ++_generation;
    try {
      final page = await _api.conversations(topic: topic, pageSize: pageSize);
      if (!ref.mounted || generation != _generation) return;
      state = AiConversationsState(
        items: page.items,
        topic: topic,
        page: 1,
        total: page.total,
      );
    } on ApiFailure catch (failure) {
      if (!ref.mounted || generation != _generation) return;
      state = state.copyWith(failure: failure);
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.loadingMore) return;
    final generation = _generation;
    state = state.copyWith(loadingMore: true);
    try {
      final page = await _api.conversations(
        topic: state.topic,
        page: state.page + 1,
        pageSize: pageSize,
      );
      if (!ref.mounted || generation != _generation) return;
      final known = {for (final c in state.items!) c.id};
      state = state.copyWith(
        items: [
          ...state.items!,
          for (final c in page.items)
            if (!known.contains(c.id)) c,
        ],
        page: page.page,
        total: page.total,
        loadingMore: false,
        clearFailure: true,
      );
    } on ApiFailure catch (failure) {
      if (!ref.mounted || generation != _generation) return;
      state = state.copyWith(failure: failure, loadingMore: false);
    }
  }

  /// Throws [ApiFailure] (MSG01, MSG41) for the dialog to show.
  Future<AiConversation> rename(String id, String title) async {
    final renamed = await _api.rename(id, title);
    if (ref.mounted) replace(renamed);
    return renamed;
  }

  /// Throws [ApiFailure] (MSG41) for the screen to show.
  Future<void> delete(String id) async {
    await _api.delete(id);
    if (!ref.mounted || state.items == null) return;
    state = state.copyWith(
      items: [
        for (final c in state.items!)
          if (c.id != id) c,
      ],
      total: state.total > 0 ? state.total - 1 : 0,
    );
  }

  /// A conversation changed elsewhere (renamed in the chat).
  void replace(AiConversation conversation) {
    final items = state.items;
    if (items == null) return;
    state = state.copyWith(
      items: [
        for (final c in items) c.id == conversation.id ? conversation : c,
      ],
    );
  }
}
