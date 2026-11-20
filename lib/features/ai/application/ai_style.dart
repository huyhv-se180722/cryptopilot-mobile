import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../account/data/profile_api.dart';
import '../../account/domain/profile.dart';

/// The profile whose trading style and risk profile the assistant answers
/// for (T-074), read once while SCR-29 is open. The questions work without
/// it: a profile still loading or not read shows no style.
final aiStyleProvider = FutureProvider.autoDispose<Profile>(
  (ref) => ref.watch(profileApiProvider).profile(),
);
