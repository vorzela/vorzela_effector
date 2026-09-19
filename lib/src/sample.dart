import 'effect.dart';
import 'event.dart';
import 'store.dart';
import 'unit.dart';

dynamic readSource(Object? source) {
  if (source == null) return null;
  if (source is Store) return source.getState();
  if (source is List) {
    return [for (final s in source) readSource(s as Object)];
  }
  if (source is Map) {
    return {for (final e in source.entries) e.key: readSource(e.value as Object)};
  }
  return source;
}

Subscription subscribeClock(Object clock, void Function(dynamic payload) onClock) {
  if (clock is Event) return clock.to(onClock);
  if (clock is Store) return clock.watch(onClock);
  if (clock is Effect) return clock.watch(onClock);
  if (clock is List) {
    final subs = <Subscription>[
      for (final c in clock) subscribeClock(c as Object, onClock),
    ];
    return Subscription(() {
      for (final s in subs) {
        s.unsubscribe();
      }
    });
  }
  throw ArgumentError('Unsupported clock: $clock');
}

void fireTarget(Object target, dynamic value) {
  if (target is Event) {
    target.call(value);
    return;
  }
  if (target is Store) {
    target.write(value);
    return;
  }
  if (target is Effect) {
    target.call(value);
    return;
  }
  if (target is List) {
    for (final t in target) {
      fireTarget(t as Object, value);
    }
    return;
  }
  throw ArgumentError('Unsupported target: $target');
}

/// Effector `sample` — clock fires → read source → optional filter/fn → target.
///
/// Returns [target] when provided, otherwise a new [Event].
Object sample({
  Object? clock,
  Object? source,
  bool Function(dynamic sourceValue, dynamic clockValue)? filter,
  dynamic Function(dynamic sourceValue, dynamic clockValue)? fn,
  Object? target,
  String? name,
}) {
  if (clock == null && source == null) {
    throw ArgumentError('sample requires clock or source');
  }

  final Object effectiveClock = clock ?? source!;
  final Object? effectiveSource = source;
  final Object sink;
  final Event? createdEvent;

  if (target != null) {
    sink = target;
    createdEvent = null;
  } else {
    createdEvent = createEventTyped(name: name);
    sink = createdEvent;
  }

  void run(dynamic clockPayload) {
    final srcVal =
        effectiveSource != null ? readSource(effectiveSource) : clockPayload;
    if (filter != null && !filter(srcVal, clockPayload)) return;
    final out = fn != null ? fn(srcVal, clockPayload) : srcVal;
    fireTarget(sink, out);
  }

  subscribeClock(effectiveClock, run);
  return target ?? createdEvent!;
}
