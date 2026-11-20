import 'dart:async';

import 'package:cryptopilot_mobile/core/state/load_after_build.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _source = Provider<int>((_) => 1);

/// The old pattern: the first load scheduled without a check.
final _raw = NotifierProvider.autoDispose<_Raw, int>(_Raw.new);

class _Raw extends Notifier<int> {
  @override
  int build() {
    unawaited(Future.microtask(load));
    return 0;
  }

  void load() => state = ref.read(_source);
}

final _guarded = NotifierProvider.autoDispose<_Guarded, int>(_Guarded.new);

class _Guarded extends Notifier<int> {
  int loads = 0;

  @override
  int build() {
    ref.loadAfterBuild(load);
    return 0;
  }

  void load() {
    loads++;
    state = ref.read(_source);
  }
}

Future<List<Object>> _errorsOf(void Function(ProviderContainer) act) async {
  final errors = <Object>[];
  final done = Completer<void>();
  unawaited(
    runZonedGuarded(() async {
      // The container goes, and its providers with it, before the
      // microtask of their first load runs.
      act(ProviderContainer());
      for (var i = 0; i < 5; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      done.complete();
    }, (error, _) => errors.add(error)),
  );
  await done.future;
  return errors;
}

void main() {
  test('the old pattern uses a disposed Ref when the provider goes before '
      'its first load', () async {
    final errors = await _errorsOf((c) {
      c.read(_raw);
      c.dispose();
    });
    expect(errors, isNotEmpty);
  });

  test('loadAfterBuild skips the load of a provider already gone', () async {
    final errors = await _errorsOf((c) {
      c.read(_guarded);
      c.dispose();
    });
    expect(errors, isEmpty);
  });

  test('loadAfterBuild loads a provider that stays', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.listen(_guarded, (_, _) {});
    await Future<void>.delayed(Duration.zero);
    expect(container.read(_guarded), 1);
    expect(container.read(_guarded.notifier).loads, 1);
  });
}
