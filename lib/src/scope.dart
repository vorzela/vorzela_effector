import 'effect.dart';
import 'event.dart';
import 'store.dart';
import 'unit.dart';

/// Isolated Effector-style scope: forked state values + dispose tears everything down.
final class Scope {
  Scope._();

  final Map<Store, dynamic> _values = {};
  final List<Unit> _owned = [];
  bool _disposed = false;

  bool get isDisposed => _disposed;

  T getState<T>(Store<T> store) {
    if (_disposed) throw StateError('Scope disposed');
    if (_values.containsKey(store)) return _values[store] as T;
    return store.getState();
  }

  /// Write into this scope's own snapshot **only**. The whole point of
  /// [fork] is an isolated copy of state; previously this also called
  /// `store.write(value)`, which mutated the real global store, so every
  /// fork silently leaked into (and stomped on) global state and every
  /// other scope. Note this means values set here are only visible via
  /// this scope's [getState] / [scopeBind] — not through `store.getState()`
  /// or `UnitBuilder`, which read the global store directly.
  void setState<T>(Store<T> store, T value) {
    if (_disposed) throw StateError('Scope disposed');
    _values[store] = value;
  }

  void own(Unit unit) => _owned.add(unit);

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final u in _owned) {
      u.dispose();
    }
    _owned.clear();
    _values.clear();
  }
}

/// Create an isolated scope (Effector `fork`).
Scope fork() => Scope._();

/// Run [unit] and wait for async chains (effects) to settle.
Future<void> allSettled(
  Object unit, {
  Scope? scope,
  dynamic params,
}) async {
  if (unit is Event) {
    unit.call(params);
  } else if (unit is Effect) {
    await unit.call(params);
  } else {
    throw ArgumentError('allSettled expects Event or Effect');
  }
  await Future<void>.delayed(Duration.zero);
}

/// Bind a callable to always run in [scope] context (placeholder for multi-scope UI).
void Function([dynamic params]) scopeBind(
  Object unit, {
  required Scope scope,
}) {
  if (scope.isDisposed) {
    throw StateError('Cannot bind to disposed scope');
  }
  return ([params]) {
    if (unit is Event) {
      unit.call(params);
    } else if (unit is Effect) {
      unit.call(params);
    }
  };
}
