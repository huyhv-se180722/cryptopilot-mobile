import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_failure.dart';
import '../../../core/errors/message_text.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/cp_colors.dart';
import '../../market/domain/market.dart';
import '../../market/presentation/market_widgets.dart';
import '../application/alerts_controller.dart';
import '../domain/alert.dart';
import 'alert_format.dart';
import 'alert_sheet.dart';

/// SCR-13 Alerts (SRS 3.4.3, UC-14), pushed from Markets (and Home): status
/// and type filters on the server, 20 a page loaded as the list scrolls,
/// tap to edit (SCR-14), Pause / Resume / Delete in the row menu, swipe left
/// to delete; every delete is confirmed.
class AlertsScreen extends ConsumerStatefulWidget {
  const AlertsScreen({super.key});

  @override
  ConsumerState<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends ConsumerState<AlertsScreen> {
  @override
  void initState() {
    super.initState();
    // The first read starts with the controller; a later visit reads again,
    // since the engine changes statuses meanwhile.
    if (ref.read(alertsControllerProvider).items != null) {
      Future.microtask(
        () => ref.read(alertsControllerProvider.notifier).load(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final state = ref.watch(alertsControllerProvider);
    final controller = ref.read(alertsControllerProvider.notifier);
    final items = state.items;

    Widget body;
    if (items == null && state.failure != null) {
      body = _Message(
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
      body = state.filtered
          ? _Message(icon: Icons.filter_alt_off, title: l.alertsEmptyFiltered)
          : _Message(
              icon: Icons.alarm_add,
              title: l.alertsEmpty,
              body: l.alertsEmptyBody,
              action: FilledButton.icon(
                onPressed: () => showAlertSheet(context),
                icon: const Icon(Icons.add),
                label: Text(l.alertsNew),
              ),
            );
    } else {
      body = NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.extentAfter < 400) controller.loadMore();
          return false;
        },
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 88),
          itemCount: items.length + (state.hasMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == items.length) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            return AlertRow(alert: items[index]);
          },
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l.alertsTitle)),
      body: Column(
        children: [
          _Filters(state: state),
          if (items != null && state.failure != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Text(
                failureText(l, state.failure!),
                style: TextStyle(color: context.cp.negative),
              ),
            ),
          Expanded(
            child: RefreshIndicator(onRefresh: controller.load, child: body),
          ),
        ],
      ),
      floatingActionButton: items != null && items.isNotEmpty
          ? FloatingActionButton.extended(
              key: const Key('new-alert'),
              onPressed: () => showAlertSheet(context),
              icon: const Icon(Icons.add),
              label: Text(l.alertsNew),
            )
          : null,
    );
  }
}

class _Filters extends ConsumerWidget {
  const _Filters({required this.state});

  final AlertsState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final controller = ref.read(alertsControllerProvider.notifier);
    // The type filter (SRS 3.4.3) leads the row so a 360 dp screen shows it
    // without scrolling. Its entries are records: a popup treats a null value
    // as "dismissed", so "All types" must not be a bare null.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: PopupMenuButton<({AlertType? type})>(
              key: const Key('alert-filter-type'),
              tooltip: l.alertTypeAll,
              initialValue: (type: state.type),
              onSelected: (choice) =>
                  controller.setFilter(status: state.status, type: choice.type),
              itemBuilder: (_) => [
                PopupMenuItem(value: (type: null), child: Text(l.alertTypeAll)),
                for (final type in AlertType.values)
                  PopupMenuItem(
                    value: (type: type),
                    child: Text(typeLabel(l, type)),
                  ),
              ],
              child: Chip(
                avatar: const Icon(Icons.tune, size: 16),
                label: Text(
                  state.type == null
                      ? l.alertTypeAll
                      : typeLabel(l, state.type!),
                ),
              ),
            ),
          ),
          for (final status in <AlertStatus?>[null, ...AlertStatus.values])
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                key: Key('alert-filter-${status?.wire ?? 'ALL'}'),
                label: Text(
                  status == null ? l.alertsAll : statusLabel(l, status),
                ),
                selected: state.status == status,
                onSelected: (_) =>
                    controller.setFilter(status: status, type: state.type),
              ),
            ),
        ],
      ),
    );
  }
}

class AlertRow extends ConsumerWidget {
  const AlertRow({required this.alert, super.key});

  final Alert alert;

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function() action,
    String done,
  ) async {
    final l = AppLocalizations.of(context);
    // A newer outcome replaces the shown one instead of queueing behind it.
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    try {
      await action();
      messenger.showSnackBar(SnackBar(content: Text(done)));
    } on ProblemFailure catch (failure) {
      final expired =
          failure.problem.fieldErrors['expiresAt'] != null &&
          alert.status == AlertStatus.paused;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            expired ? l.alertResumeExpired : failureText(l, failure),
          ),
        ),
      );
      if (failure.problem.messageCode == 'MSG29' && context.mounted) {
        await showUpgradeDialog(context, ref, failure);
      }
    } on ApiFailure catch (failure) {
      messenger.showSnackBar(SnackBar(content: Text(failureText(l, failure))));
    }
  }

  /// Asks first; true when deleted. The list reload drops the row, so a
  /// Dismissible never removes it itself.
  Future<bool> _delete(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.alertDeleteTitle),
        content: Text(
          l.alertDeleteConfirm(conditionText(l, alert.rule), alert.symbol),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.commonCancel),
          ),
          FilledButton(
            key: const Key('confirm-delete-alert'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.alertDelete),
          ),
        ],
      ),
    );
    if (!(confirmed ?? false) || !context.mounted) return false;
    await _run(
      context,
      ref,
      () => ref.read(alertsControllerProvider.notifier).delete(alert),
      l.alertDeleted,
    );
    return false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final controller = ref.read(alertsControllerProvider.notifier);
    final last = alert.lastTriggeredAt;
    final expires = alert.rule.expiresAt;
    final details = [
      l.alertTriggerCount(alert.triggerCount),
      if (last != null) l.alertLastTriggered(shortTime(last)),
      if (expires != null) l.alertExpires(shortDate(expires)),
    ].join(' · ');

    return Dismissible(
      key: ValueKey('alert-${alert.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _delete(context, ref),
      background: Container(
        color: context.cp.negative,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: InkWell(
        key: Key('alert-row-${alert.id}'),
        onTap: () => showAlertSheet(context, alert: alert),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 4, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            alert.symbol,
                            overflow: TextOverflow.ellipsis,
                            style: text.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        _Tag(
                          text: alert.market == Market.spot
                              ? l.marketSpot
                              : l.marketFutures,
                        ),
                        const SizedBox(width: 6),
                        StatusTag(status: alert.status),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(conditionText(l, alert.rule), style: text.bodyMedium),
                    const SizedBox(height: 2),
                    Text(
                      details,
                      style: text.bodySmall?.copyWith(color: context.cp.muted),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                key: Key('alert-menu-${alert.id}'),
                onSelected: (action) => switch (action) {
                  'pause' => _run(
                    context,
                    ref,
                    () => controller.pause(alert),
                    l.alertPaused,
                  ),
                  'resume' => _run(
                    context,
                    ref,
                    () => controller.resume(alert),
                    l.alertResumed,
                  ),
                  'edit' => showAlertSheet(context, alert: alert),
                  _ => _delete(context, ref),
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'edit', child: Text(l.alertEdit)),
                  if (alert.status == AlertStatus.active)
                    PopupMenuItem(value: 'pause', child: Text(l.alertPause)),
                  if (alert.status == AlertStatus.paused)
                    PopupMenuItem(value: 'resume', child: Text(l.alertResume)),
                  PopupMenuItem(value: 'delete', child: Text(l.alertDelete)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The status as a word on a tinted tag; the word carries it, not the colour.
class StatusTag extends StatelessWidget {
  const StatusTag({required this.status, super.key});

  final AlertStatus status;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    final color = switch (status) {
      AlertStatus.active => cp.positive,
      AlertStatus.paused => cp.muted,
      AlertStatus.triggered => Theme.of(context).colorScheme.primary,
      AlertStatus.expired => cp.muted,
    };
    return _Tag(
      text: statusLabel(AppLocalizations.of(context), status),
      color: color,
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? context.cp.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: tint,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    this.body,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? body;
  final Widget? action;

  @override
  Widget build(BuildContext context) => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(32, 64, 32, 32),
        child: Column(
          children: [
            Icon(icon, size: 36, color: context.cp.muted),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (body != null) ...[
              const SizedBox(height: 4),
              Text(body!, textAlign: TextAlign.center),
            ],
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    ],
  );
}
