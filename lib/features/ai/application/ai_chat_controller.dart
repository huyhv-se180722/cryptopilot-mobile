import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_failure.dart';
import '../../../core/realtime/realtime_hub.dart';
import '../../../core/realtime/reload_on_reconnect.dart';
import '../../../core/state/load_after_build.dart';
import '../../../core/state/poll_gate.dart';
import '../data/ai_api.dart';
import '../domain/ai.dart';
import 'ai_context.dart';
import 'ai_conversations_controller.dart';
import 'ai_quota.dart';

/// Which chat the screen shows: a conversation of the list, or a new one
/// that is created with its first question, starting from [seed].
@immutable
class AiChatArgs {
  const AiChatArgs.existing(AiConversation this.conversation) : seed = null;

  const AiChatArgs.fresh(AiContext this.seed) : conversation = null;

  final AiConversation? conversation;
  final AiContext? seed;

  @override
  bool operator ==(Object other) =>
      other is AiChatArgs &&
      other.conversation?.id == conversation?.id &&
      other.seed == seed;

  @override
  int get hashCode => Object.hash(conversation?.id, seed);
}

@immutable
class AiChatState {
  const AiChatState({
    required this.context,
    this.conversation,
    this.messages,
    this.page = 0,
    this.total = 0,
    this.failure,
    this.loadingOlder = false,
    this.sending = false,
    this.sendFailure,
  });

  /// Null until the first question creates it.
  final AiConversation? conversation;
  final AiContext context;

  /// Oldest first; null while the first page loads.
  final List<AiMessage>? messages;
  final int page;
  final int total;

  /// Reading the messages failed.
  final ApiFailure? failure;
  final bool loadingOlder;
  final bool sending;

  /// The last question was refused (MSG01, MSG29, MSG30, MSG41 …).
  final ApiFailure? sendFailure;

  bool get hasOlder => messages != null && messages!.length < total;

  /// A question waits for its answer (the typing indicator).
  bool get waiting =>
      messages?.any(
        (m) =>
            m.role == AiSenderRole.user && m.status == AiMessageStatus.pending,
      ) ??
      false;

  AiChatState copyWith({
    AiConversation? conversation,
    AiContext? context,
    List<AiMessage>? messages,
    int? page,
    int? total,
    ApiFailure? failure,
    bool clearFailure = false,
    bool? loadingOlder,
    bool? sending,
    ApiFailure? sendFailure,
    bool clearSendFailure = false,
  }) => AiChatState(
    conversation: conversation ?? this.conversation,
    context: context ?? this.context,
    messages: messages ?? this.messages,
    page: page ?? this.page,
    total: total ?? this.total,
    failure: clearFailure ? null : failure ?? this.failure,
    loadingOlder: loadingOlder ?? this.loadingOlder,
    sending: sending ?? this.sending,
    sendFailure: clearSendFailure ? null : sendFailure ?? this.sendFailure,
  );
}

final aiChatControllerProvider = NotifierProvider.autoDispose
    .family<AiChatController, AiChatState, AiChatArgs>(AiChatController.new);

/// One chat of SCR-29 (UC-30). A question is stored PENDING and its answer,
/// or FAILED (MSG31, after an error or 60 s), is pushed on [aiQueue]; while a
/// question waits the newest page is also read every [pollEvery], as the web
/// does, and again after a reconnection or when the app comes back.
class AiChatController extends Notifier<AiChatState> {
  AiChatController(this.args);

  static const pageSize = 50;
  static const pollEvery = Duration(seconds: 3);

  final AiChatArgs args;
  Timer? _poll;
  int _generation = 0;

  @override
  AiChatState build() {
    final pushes = ref
        .read(realtimeHubProvider.notifier)
        .watch(aiQueue)
        .listen(_onPush);
    ref
      ..onDispose(() {
        _poll?.cancel();
        _poll = null;
        // Not awaited: a broadcast cancel only detaches the listener.
        unawaited(pushes.cancel());
      })
      ..reloadOnReconnect(() => unawaited(refresh()));
    listenSelf((_, next) => _pollWhile(waiting: next.waiting));

    final conversation = args.conversation;
    if (conversation == null) {
      return AiChatState(context: args.seed!, messages: const []);
    }
    ref.loadAfterBuild(load);
    return AiChatState(
      conversation: conversation,
      context: AiContext.of(conversation),
    );
  }

  AiApi get _api => ref.read(aiApiProvider);

  /// The newest page, replacing what is shown.
  Future<void> load() async {
    final conversation = state.conversation;
    if (conversation == null) return;
    final generation = ++_generation;
    try {
      final page = await _api.messages(conversation.id, pageSize: pageSize);
      if (!ref.mounted || generation != _generation) return;
      state = state.copyWith(
        messages: page.items.reversed.toList(),
        page: 1,
        total: page.total,
        clearFailure: true,
      );
    } on ApiFailure catch (failure) {
      if (!ref.mounted || generation != _generation) return;
      state = state.copyWith(failure: failure);
    }
  }

  /// The newest page again, keeping the older pages already read.
  Future<void> refresh() async {
    final conversation = state.conversation;
    final shown = state.messages;
    if (conversation == null || shown == null) return;
    final generation = ++_generation;
    try {
      final page = await _api.messages(conversation.id, pageSize: pageSize);
      if (!ref.mounted || generation != _generation) return;
      final newest = page.items.reversed.toList();
      final ids = {for (final m in newest) m.id};
      final from = newest.isEmpty ? null : newest.first.createdAt;
      state = state.copyWith(
        messages: [
          for (final m in state.messages ?? shown)
            if (!ids.contains(m.id) &&
                (from == null || !m.createdAt.isAfter(from)))
              m,
          ...newest,
        ],
        total: page.total,
        clearFailure: true,
      );
    } on ApiFailure {
      // The next round, push or reconnection catches up.
    }
  }

  /// The page before the oldest one shown.
  Future<void> loadOlder() async {
    final conversation = state.conversation;
    if (conversation == null || !state.hasOlder || state.loadingOlder) return;
    state = state.copyWith(loadingOlder: true);
    try {
      final page = await _api.messages(
        conversation.id,
        page: state.page + 1,
        pageSize: pageSize,
      );
      if (!ref.mounted) return;
      final known = {for (final m in state.messages!) m.id};
      state = state.copyWith(
        messages: [
          for (final m in page.items.reversed)
            if (!known.contains(m.id)) m,
          ...state.messages!,
        ],
        page: page.page,
        total: page.total,
        loadingOlder: false,
      );
    } on ApiFailure catch (failure) {
      if (ref.mounted) {
        state = state.copyWith(failure: failure, loadingOlder: false);
      }
    }
  }

  void setContext(AiContext context) {
    if (context.topic != state.context.topic) return;
    state = state.copyWith(context: context, clearSendFailure: true);
  }

  /// Sends [text] with the data of the chosen context; a new chat is created
  /// first. False when it was refused: [AiChatState.sendFailure] says why
  /// (MSG29 and MSG30 also read the quota again).
  Future<bool> send(String text) async {
    final question = text.trim();
    if (question.isEmpty ||
        question.length > aiQuestionMaxLength ||
        state.sending ||
        !state.context.ready) {
      return false;
    }
    state = state.copyWith(sending: true, clearSendFailure: true);
    try {
      final conversation =
          state.conversation ??
          await _api.start(
            topic: state.context.topic,
            pairId: state.context.topic == ConversationTopic.market
                ? state.context.pairId
                : null,
          );
      if (!ref.mounted) return false;
      if (state.conversation == null) {
        state = state.copyWith(conversation: conversation);
      }
      final result = await _api.ask(
        conversation.id,
        state.context.question(question),
      );
      if (!ref.mounted) return true;
      ref.read(aiQuotaProvider.notifier).set(result.quota);
      state = state.copyWith(
        messages: [...?state.messages, result.question],
        total: state.total + 1,
        sending: false,
      );
      _conversationsChanged();
      return true;
    } on ApiFailure catch (failure) {
      if (!ref.mounted) return false;
      state = state.copyWith(sending: false, sendFailure: failure);
      if (failure is ProblemFailure &&
          (failure.code == 'PLAN_FEATURE_NOT_INCLUDED' ||
              failure.code == 'AI_DAILY_QUOTA_EXHAUSTED')) {
        unawaited(ref.read(aiQuotaProvider.notifier).load());
      }
      return false;
    }
  }

  /// Asks a FAILED question again (it used no quota).
  Future<bool> retry(AiMessage failed) => send(failed.content);

  /// Throws [ApiFailure] (MSG01, MSG41) for the dialog to show.
  Future<void> rename(String title) async {
    final conversation = state.conversation;
    if (conversation == null) return;
    final renamed = await _api.rename(conversation.id, title);
    if (!ref.mounted) return;
    state = state.copyWith(conversation: renamed);
    if (ref.exists(aiConversationsControllerProvider)) {
      ref.read(aiConversationsControllerProvider.notifier).replace(renamed);
    }
  }

  /// Throws [ApiFailure] (MSG41) for the screen to show.
  Future<void> delete() async {
    final conversation = state.conversation;
    if (conversation == null) return;
    if (ref.exists(aiConversationsControllerProvider)) {
      await ref
          .read(aiConversationsControllerProvider.notifier)
          .delete(conversation.id);
    } else {
      await _api.delete(conversation.id);
    }
  }

  void _conversationsChanged() {
    if (ref.exists(aiConversationsControllerProvider)) {
      unawaited(ref.read(aiConversationsControllerProvider.notifier).load());
    }
  }

  void _onPush(Object? body) {
    final AiAnswerPush push;
    try {
      push = decodeAnswerPush(body);
    } on Exception {
      unawaited(refresh());
      return;
    }
    if (push.conversationId != state.conversation?.id) return;
    final messages = state.messages;
    if (messages == null) return;
    final answer = push.answer;
    state = state.copyWith(
      messages: [
        for (final m in messages)
          if (m.id == push.questionId) m.withStatus(push.status) else m,
        if (answer != null && messages.every((m) => m.id != answer.id)) answer,
      ],
      total: answer == null ? state.total : state.total + 1,
    );
    unawaited(ref.read(aiQuotaProvider.notifier).load());
  }

  void _pollWhile({required bool waiting}) {
    if (!waiting) {
      _poll?.cancel();
      _poll = null;
    } else {
      _poll ??= ref.pollEvery(pollEvery, () => unawaited(refresh()));
    }
  }
}
