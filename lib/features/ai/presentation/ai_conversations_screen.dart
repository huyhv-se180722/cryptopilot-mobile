import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/auth/session_controller.dart';
import '../../../core/errors/api_failure.dart';
import '../../../core/errors/message_text.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/cp_colors.dart';
import '../../market/domain/candle.dart';
import '../../market/domain/market.dart';
import '../../market/presentation/market_widgets.dart';
import '../application/ai_context.dart';
import '../application/ai_conversations_controller.dart';
import '../application/ai_quota.dart';
import '../domain/ai.dart';

String topicLabel(AppLocalizations l, ConversationTopic topic) =>
    switch (topic) {
      ConversationTopic.market => l.aiTopicMarket,
      ConversationTopic.myTrading => l.aiTopicMine,
      ConversationTopic.general => l.aiTopicGeneral,
    };

IconData topicIcon(ConversationTopic topic) => switch (topic) {
  ConversationTopic.market => Icons.candlestick_chart_outlined,
  ConversationTopic.myTrading => Icons.assignment_outlined,
  ConversationTopic.general => Icons.chat_bubble_outline,
};

/// `/ai/new?…` for a new chat starting from [seed].
String aiNewLocation(AiContext seed) =>
    Uri(path: '/ai/new', queryParameters: seed.toQuery()).toString();

/// Ask AI from SCR-10/11: a new MARKET chat on [pair] at [timeframe]
/// (composed in `main.dart` as `askAiOnPairProvider`).
void askAiOnPair(BuildContext context, MarketPair pair, Timeframe timeframe) =>
    unawaited(
      context.push(
        aiNewLocation(
          AiContext(
            topic: ConversationTopic.market,
            pairId: pair.pairId,
            symbol: pair.symbol,
            market: pair.market,
            timeframe: timeframe,
          ),
        ),
      ),
    );

/// `/ai/c/{id}`; the conversation rides along as `extra`.
String aiChatLocation(String id) => '/ai/c/${Uri.encodeComponent(id)}';

/// Today's questions beside the title (BR-50); nothing on a plan without
/// the assistant or before the first read.
class AiQuotaChip extends ConsumerWidget {
  const AiQuotaChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final quota = ref.watch(aiQuotaProvider).quota;
    if (quota == null || quota.notIncluded) return const SizedBox.shrink();
    final text = quota.unlimited
        ? l.aiQuotaUnlimited
        : l.aiQuota(quota.remaining ?? 0, quota.limit ?? 0);
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Center(
        child: Text(
          text,
          key: const Key('ai-quota'),
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: quota.exhausted ? context.cp.negative : context.cp.muted,
          ),
        ),
      ),
    );
  }
}

/// SCR-29 conversation list (SRS 3.9.1): every topic or one, grouped by day,
/// last asked first; New opens a chat in the mode the Trader picks.
class AiConversationsScreen extends ConsumerWidget {
  const AiConversationsScreen({super.key});

  Future<void> _new(BuildContext context) async {
    final topic = await showModalBottomSheet<ConversationTopic>(
      context: context,
      showDragHandle: true,
      builder: (_) => const AiModeSheet(),
    );
    if (topic != null && context.mounted) {
      unawaited(context.push(aiNewLocation(AiContext(topic: topic))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final cp = context.cp;
    final state = ref.watch(aiConversationsControllerProvider);
    final controller = ref.read(aiConversationsControllerProvider.notifier);
    final items = state.items;
    final now = ref.read(clockProvider)();

    Widget body;
    if (items == null && state.failure != null) {
      body = _Centered(
        icon: Icons.cloud_off,
        title: failureText(l, state.failure!),
        action: TextButton(
          onPressed: controller.load,
          child: Text(l.commonRetry),
        ),
      );
    } else if (items == null) {
      body = const ListSkeleton();
    } else if (items.isEmpty) {
      body = _Centered(
        key: const Key('ai-empty'),
        icon: Icons.forum_outlined,
        title: l.aiNoConversations,
        subtitle: l.aiNoConversationsHint,
      );
    } else {
      final rows = <Widget>[];
      String? group;
      for (final conversation in items) {
        final label = _group(l, conversation.updatedAt, now);
        if (label != group) {
          group = label;
          rows.add(
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(color: cp.muted),
              ),
            ),
          );
        }
        rows.add(_ConversationRow(conversation: conversation, now: now));
      }
      if (state.hasMore) {
        rows.add(
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
        );
      }
      body = NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.extentAfter < 400) {
            unawaited(controller.loadMore());
          }
          return false;
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 88),
          children: rows,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l.aiTitle), actions: const [AiQuotaChip()]),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('ai-new'),
        onPressed: () => _new(context),
        icon: const Icon(Icons.add),
        label: Text(l.aiNewConversation),
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                for (final topic in <ConversationTopic?>[
                  null,
                  ...ConversationTopic.values,
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      key: Key('ai-filter-${topic?.wire ?? 'ALL'}'),
                      label: Text(
                        topic == null ? l.aiFilterAll : topicLabel(l, topic),
                      ),
                      selected: state.topic == topic,
                      onSelected: (_) => unawaited(controller.show(topic)),
                    ),
                  ),
              ],
            ),
          ),
          if (items != null && state.failure != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Text(
                failureText(l, state.failure!),
                style: TextStyle(color: cp.negative),
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await Future.wait([
                  controller.load(),
                  ref.read(aiQuotaProvider.notifier).load(),
                ]);
              },
              child: body,
            ),
          ),
        ],
      ),
    );
  }
}

String _group(AppLocalizations l, DateTime at, DateTime now) {
  final local = at.toLocal();
  final today = DateUtils.dateOnly(now.toLocal());
  final days = today.difference(DateUtils.dateOnly(local)).inDays;
  if (days <= 0) return l.aiGroupToday;
  if (days == 1) return l.aiGroupYesterday;
  if (days < 7) return l.aiGroupWeek;
  return l.aiGroupOlder;
}

/// Time today, else the date, in the app's locale (A-43).
String conversationTime(DateTime at, DateTime now) {
  final local = at.toLocal();
  final sameDay = DateUtils.isSameDay(local, now.toLocal());
  return DateFormat(sameDay ? 'HH:mm' : 'd MMM', 'en').format(local);
}

Future<bool> confirmDelete(BuildContext context) async {
  final l = AppLocalizations.of(context);
  final yes = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l.aiDeleteTitle),
      content: Text(l.aiDeleteBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l.commonCancel),
        ),
        FilledButton(
          key: const Key('ai-delete-confirm'),
          onPressed: () => Navigator.pop(context, true),
          child: Text(l.aiDelete),
        ),
      ],
    ),
  );
  return yes ?? false;
}

class _ConversationRow extends ConsumerWidget {
  const _ConversationRow({required this.conversation, required this.now});

  final AiConversation conversation;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final cp = context.cp;
    final text = Theme.of(context).textTheme;
    return Dismissible(
      key: Key('ai-conversation-${conversation.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: cp.negative,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        if (!await confirmDelete(context)) return false;
        if (!context.mounted) return false;
        final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
        try {
          await ref
              .read(aiConversationsControllerProvider.notifier)
              .delete(conversation.id);
          messenger.showSnackBar(SnackBar(content: Text(l.aiDeleted)));
          return true;
        } on ApiFailure catch (failure) {
          messenger.showSnackBar(
            SnackBar(content: Text(failureText(l, failure))),
          );
          return false;
        }
      },
      child: ListTile(
        leading: Icon(topicIcon(conversation.topic), color: cp.muted),
        title: Text(
          conversation.title ?? l.aiUntitled,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: text.titleSmall,
        ),
        subtitle: Text(
          '${topicLabel(l, conversation.topic)} · '
          '${conversationTime(conversation.updatedAt, now)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: text.bodySmall?.copyWith(color: cp.muted),
        ),
        onTap: () =>
            context.push(aiChatLocation(conversation.id), extra: conversation),
      ),
    );
  }
}

/// The three ways to ask (web T-076 modes, and the floating chat's general
/// question).
class AiModeSheet extends StatelessWidget {
  const AiModeSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cp = context.cp;
    String hint(ConversationTopic topic) => switch (topic) {
      ConversationTopic.market => l.aiTopicMarketHint,
      ConversationTopic.myTrading => l.aiTopicMineHint,
      ConversationTopic.general => l.aiTopicGeneralHint,
    };
    // Scrolls on a short screen or with large text.
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                l.aiChooseMode,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            for (final topic in ConversationTopic.values)
              ListTile(
                key: Key('ai-mode-${topic.wire}'),
                leading: Icon(topicIcon(topic), color: cp.primary),
                title: Text(topicLabel(l, topic)),
                subtitle: Text(hint(topic)),
                onTap: () => Navigator.pop(context, topic),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _Centered extends StatelessWidget {
  const _Centered({
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 96),
        Icon(icon, size: 48, color: cp.muted),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(title, textAlign: TextAlign.center),
        ),
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 4, 32, 0),
            child: Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: TextStyle(color: cp.muted),
            ),
          ),
        if (action != null) Center(child: action),
      ],
    );
  }
}
