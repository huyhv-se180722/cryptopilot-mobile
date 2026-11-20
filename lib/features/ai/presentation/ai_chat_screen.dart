import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/api_failure.dart';
import '../../../core/errors/message_text.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/cp_colors.dart';
import '../../../core/web/web_links.dart';
import '../application/ai_chat_controller.dart';
import '../application/ai_context.dart';
import '../application/ai_conversations_controller.dart';
import '../application/ai_quota.dart';
import '../domain/ai.dart';
import 'ai_answer.dart';
import 'ai_context_bar.dart';
import 'ai_conversations_screen.dart';
import 'ai_style_chip.dart';

/// `/ai/c/{id}` opened without its conversation (a restored route): found in
/// the list, page by page; MSG41 when the Trader has no such conversation.
class AiChatLookup extends ConsumerWidget {
  const AiChatLookup({required this.id, super.key});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final state = ref.watch(aiConversationsControllerProvider);
    final found = state.items?.where((c) => c.id == id).firstOrNull;
    if (found != null) return AiChatScreen(args: AiChatArgs.existing(found));
    if (state.items != null && state.hasMore && state.failure == null) {
      unawaited(
        Future.microtask(() {
          // The lookup may be gone by then (its chat opened).
          if (context.mounted) {
            return ref
                .read(aiConversationsControllerProvider.notifier)
                .loadMore();
          }
        }),
      );
    }
    final settled =
        state.items != null && (!state.hasMore || state.failure != null);
    return Scaffold(
      appBar: AppBar(title: Text(l.aiTitle)),
      body: Center(
        child: settled
            ? Text(
                state.failure == null
                    ? l.msg41
                    : failureText(l, state.failure!),
                key: const Key('ai-chat-missing'),
              )
            : const CircularProgressIndicator(),
      ),
    );
  }
}

/// A chat of SCR-29 (SRS 3.9.1): the messages, the typing indicator while a
/// question waits, MSG31 with Try again on a failed one, the context
/// selector and the input; on a plan without the assistant the input gives
/// way to the upgrade card (BR-52), and a used-up quota shows MSG30.
class AiChatScreen extends ConsumerStatefulWidget {
  const AiChatScreen({required this.args, super.key});

  final AiChatArgs args;

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> {
  final _input = TextEditingController();

  @override
  void initState() {
    super.initState();
    _input.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  NotifierProvider<AiChatController, AiChatState> get _provider =>
      aiChatControllerProvider(widget.args);

  Future<void> _send() async {
    final sent = await ref.read(_provider.notifier).send(_input.text);
    if (!mounted) return;
    if (sent) {
      _input.clear();
      return;
    }
    // MSG29 is a dialog (SRS 5.3); the other refusals stay in line.
    final refused = ref.read(_provider).sendFailure;
    if (refused is ProblemFailure && refused.problem.messageCode == 'MSG29') {
      await _upgradeDialog(refused);
    }
  }

  Future<void> _upgradeDialog(ProblemFailure failure) async {
    final l = AppLocalizations.of(context);
    final open = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('ai-msg29'),
        content: Text(failureText(l, failure)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.commonCancel),
          ),
          FilledButton(
            key: const Key('ai-msg29-open'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.upgradeOnWeb),
          ),
        ],
      ),
    );
    if (open ?? false) {
      await ref.read(webLinksProvider).open('/subscription');
    }
  }

  Future<void> _rename(AiConversation conversation) async {
    final l = AppLocalizations.of(context);
    final title = await showDialog<String>(
      context: context,
      builder: (_) => _RenameDialog(initial: conversation.title ?? ''),
    );
    if (title == null || title.isEmpty || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(_provider.notifier).rename(title);
    } on ApiFailure catch (failure) {
      messenger.showSnackBar(SnackBar(content: Text(failureText(l, failure))));
    }
  }

  Future<void> _delete() async {
    final l = AppLocalizations.of(context);
    if (!await confirmDelete(context) || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(_provider.notifier).delete();
      messenger.showSnackBar(SnackBar(content: Text(l.aiDeleted)));
      if (mounted) context.pop();
    } on ApiFailure catch (failure) {
      messenger.showSnackBar(SnackBar(content: Text(failureText(l, failure))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cp = context.cp;
    final state = ref.watch(_provider);
    final controller = ref.read(_provider.notifier);
    final conversation = state.conversation;
    final messages = state.messages;

    Widget body;
    if (messages == null && state.failure != null) {
      body = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(failureText(l, state.failure!), textAlign: TextAlign.center),
            TextButton(onPressed: controller.load, child: Text(l.commonRetry)),
          ],
        ),
      );
    } else if (messages == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (messages.isEmpty) {
      body = Center(
        key: const Key('ai-chat-empty'),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            l.aiEmptyChat,
            textAlign: TextAlign.center,
            style: TextStyle(color: cp.muted),
          ),
        ),
      );
    } else {
      final newestFirst = messages.reversed.toList();
      final extra = (state.waiting ? 1 : 0);
      body = ListView.builder(
        key: const Key('ai-messages'),
        reverse: true,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        itemCount: newestFirst.length + extra + (state.hasOlder ? 1 : 0),
        itemBuilder: (context, index) {
          if (state.waiting && index == 0) return const _Typing();
          final i = index - extra;
          if (i == newestFirst.length) {
            return Center(
              child: state.loadingOlder
                  ? const Padding(
                      padding: EdgeInsets.all(8),
                      child: CircularProgressIndicator(),
                    )
                  : TextButton(
                      key: const Key('ai-load-older'),
                      onPressed: controller.loadOlder,
                      child: Text(l.aiLoadOlder),
                    ),
            );
          }
          final message = newestFirst[i];
          return message.role == AiSenderRole.user
              ? _Question(
                  message: message,
                  onRetry: state.waiting || state.sending
                      ? null
                      : () => unawaited(controller.retry(message)),
                )
              : _AnswerBubble(message: message);
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              conversation?.title ?? l.aiUntitled,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              topicLabel(l, state.context.topic),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: cp.muted),
            ),
          ],
        ),
        actions: [
          const AiQuotaChip(),
          if (conversation != null)
            PopupMenuButton<String>(
              key: const Key('ai-chat-menu'),
              onSelected: (action) =>
                  action == 'rename' ? _rename(conversation) : _delete(),
              itemBuilder: (_) => [
                PopupMenuItem(
                  key: const Key('ai-chat-rename'),
                  value: 'rename',
                  child: Text(l.aiRename),
                ),
                PopupMenuItem(
                  key: const Key('ai-chat-delete'),
                  value: 'delete',
                  child: Text(l.aiDelete),
                ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: body),
          _Composer(
            state: state,
            input: _input,
            onSend: _send,
            onContext: controller.setContext,
          ),
        ],
      ),
    );
  }
}

/// Owns its field, so it outlives the closing animation of the dialog.
class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.initial});

  final String initial;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final _field = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.aiRenameTitle),
      content: TextField(
        key: const Key('ai-rename-field'),
        controller: _field,
        autofocus: true,
        maxLength: aiTitleMaxLength,
        decoration: InputDecoration(labelText: l.aiRenameLabel),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.commonCancel),
        ),
        FilledButton(
          key: const Key('ai-rename-save'),
          onPressed: () => Navigator.pop(context, _field.text.trim()),
          child: Text(l.aiSave),
        ),
      ],
    );
  }
}

class _Question extends StatelessWidget {
  const _Question({required this.message, required this.onRetry});

  final AiMessage message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cp = context.cp;
    final failed = message.status == AiMessageStatus.failed;
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.85,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              key: Key('ai-question-${message.id}'),
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: cp.primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: SelectableText(
                message.content,
                style: TextStyle(color: cp.text),
              ),
            ),
            if (failed)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      l.msg31,
                      key: Key('ai-failed-${message.id}'),
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: cp.negative),
                    ),
                    TextButton(
                      key: Key('ai-retry-${message.id}'),
                      onPressed: onRetry,
                      child: Text(l.aiTryAgain),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AnswerBubble extends StatelessWidget {
  const _AnswerBubble({required this.message});

  final AiMessage message;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.85,
        ),
        child: Container(
          key: Key('ai-answer-${message.id}'),
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 0),
          decoration: BoxDecoration(
            color: cp.surface,
            border: Border.all(color: cp.border),
            borderRadius: BorderRadius.circular(14),
          ),
          child: AiAnswer(message: message),
        ),
      ),
    );
  }
}

class _Typing extends StatelessWidget {
  const _Typing();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cp = context.cp;
    return Align(
      key: const Key('ai-typing'),
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: cp.muted),
            ),
            const SizedBox(width: 8),
            Text(l.aiThinking, style: TextStyle(color: cp.muted)),
          ],
        ),
      ),
    );
  }
}

/// The bottom of the chat: the upgrade card on a plan without the assistant
/// (BR-52), or the context selector, the refusal line and the input.
class _Composer extends ConsumerWidget {
  const _Composer({
    required this.state,
    required this.input,
    required this.onSend,
    required this.onContext,
  });

  final AiChatState state;
  final TextEditingController input;
  final VoidCallback onSend;
  final ValueChanged<AiContext> onContext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final cp = context.cp;
    final small = Theme.of(context).textTheme.bodySmall;
    final quota = ref.watch(aiQuotaProvider).quota;
    final refused = state.sendFailure;
    final notIncluded =
        (quota?.notIncluded ?? false) ||
        (refused is ProblemFailure &&
            refused.code == 'PLAN_FEATURE_NOT_INCLUDED' &&
            (quota?.canAsk ?? false) == false);

    if (notIncluded) {
      return SafeArea(
        top: false,
        child: Container(
          key: const Key('ai-upgrade'),
          width: double.infinity,
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cp.raised,
            border: Border.all(color: cp.border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.aiUpgradeTitle,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              Text(l.aiUpgradeBody, style: small?.copyWith(color: cp.muted)),
              const SizedBox(height: 8),
              FilledButton(
                key: const Key('ai-upgrade-open'),
                onPressed: () =>
                    unawaited(ref.read(webLinksProvider).open('/subscription')),
                child: Text(l.upgradeOnWeb),
              ),
            ],
          ),
        ),
      );
    }

    final context0 = state.context;
    final exhausted = quota?.exhausted ?? false;
    final text = input.text.trim();
    final tooLong = text.length > aiQuestionMaxLength;
    final canSend =
        text.isNotEmpty &&
        !tooLong &&
        context0.ready &&
        !exhausted &&
        !state.sending &&
        !state.waiting;
    final symbol = contextSymbol(ref, context0);
    final hint = switch (context0.topic) {
      ConversationTopic.market =>
        symbol == null ? l.aiPlaceholderNoPair : l.aiPlaceholderPair(symbol),
      ConversationTopic.myTrading => l.aiPlaceholderMine,
      ConversationTopic.general => l.aiPlaceholderGeneral,
    };
    String? notice;
    if (exhausted) {
      notice = l.msg30('${quota?.limit ?? ''}');
    } else if (refused != null) {
      notice = failureText(l, refused);
    } else if (!context0.ready) {
      notice = context0.topic == ConversationTopic.market
          ? l.aiPairNeedsChoice
          : l.aiMineNeedsChoice;
    }

    return Material(
      color: cp.surface,
      child: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: cp.border)),
          ),
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Only on a plan with the assistant (the upgrade card above
              // otherwise), as the web shows it.
              if (quota != null)
                const Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: AiStyleChip(),
                ),
              AiContextBar(value: context0, onChanged: onContext, quota: quota),
              if (context0.topic == ConversationTopic.myTrading)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    l.aiPrivacy,
                    style: small?.copyWith(color: cp.muted),
                  ),
                ),
              if (notice != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    notice,
                    key: const Key('ai-notice'),
                    style: small?.copyWith(
                      color: exhausted || refused != null
                          ? cp.negative
                          : cp.muted,
                    ),
                  ),
                ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('ai-input'),
                      controller: input,
                      enabled: !exhausted,
                      minLines: 1,
                      maxLines: 5,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        hintText: hint,
                        isDense: true,
                        counterText: '',
                        helperText: text.isEmpty
                            ? null
                            : l.aiCounter(text.length),
                        helperStyle: TextStyle(
                          color: tooLong ? cp.negative : cp.muted,
                        ),
                      ),
                    ),
                  ),
                  IconButton.filled(
                    key: const Key('ai-send'),
                    tooltip: l.aiSend,
                    onPressed: canSend ? onSend : null,
                    icon: state.sending
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
