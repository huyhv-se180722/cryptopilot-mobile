import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_failure.dart';
import '../data/paper_api.dart';
import '../data/paper_repository.dart';
import '../domain/paper.dart';

/// The Home "Demo account" block (plan 9.1): the account's worth and
/// today's PnL, or null before the Trader opened it. Reading never opens
/// the account: only entering Trade or Assets does (D-154).
final homeDemoProvider = FutureProvider.autoDispose<PaperEquity?>((ref) async {
  // Read again once Trade or Assets opened the account.
  ref.watch(paperOpenedProvider);
  try {
    return await ref.watch(paperApiProvider).equity();
  } on ProblemFailure catch (failure) {
    if (failure.problem.messageCode == 'MSG41') return null;
    rethrow;
  }
});
