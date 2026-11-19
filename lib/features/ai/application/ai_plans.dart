import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../plans/data/plan_api.dart';
import '../../plans/domain/plan.dart';

/// The Trader's plans for the MY_TRADING picker, every status, newest
/// first, read when the picker opens.
final aiPlansProvider = FutureProvider.autoDispose<List<PlanSummary>>((
  ref,
) async {
  final page = await ref.read(planApiProvider).list(pageSize: 50);
  return page.items;
});
