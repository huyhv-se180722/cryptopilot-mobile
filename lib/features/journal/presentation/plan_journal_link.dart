import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../market/domain/market.dart';
import '../data/journal_api.dart';
import '../domain/journal.dart';
import 'journal_view.dart';

/// Which plan's journal entry to look for.
typedef PlanJournalKey = ({String planId, String pairId, Market market});

/// The journal entry of an executed plan. The plan does not carry its id and
/// `GET /journal` has no plan filter, so the simulated trades of the plan's
/// pair and market are read (newest 100, every period) and the one with the
/// plan's id is taken; null when none is found.
final planJournalEntryProvider = FutureProvider.autoDispose
    .family<String?, PlanJournalKey>((ref, key) async {
      final page = await ref
          .read(journalApiProvider)
          .list(
            filter: JournalFilter(
              days: null,
              market: key.market,
              source: TradeSource.simulated,
              pairId: key.pairId,
            ),
            pageSize: 100,
          );
      return page.items
          .where((entry) => entry.planId == key.planId)
          .firstOrNull
          ?.id;
    });

/// SCR-18 "Journal entry ›" (SRS 3.5.3), composed onto the plan detail by
/// the router; nothing until the entry is found.
class PlanJournalLink extends ConsumerWidget {
  const PlanJournalLink({required this.journalKey, super.key});

  final PlanJournalKey journalKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final id = ref.watch(planJournalEntryProvider(journalKey)).value;
    if (id == null) return const SizedBox.shrink();
    return ListTile(
      key: const Key('plan-journal-entry'),
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.menu_book_outlined),
      title: Text(l.planJournalEntry),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push(journalEntryLocation(id)),
    );
  }
}
