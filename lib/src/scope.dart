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

  void setState<T>(Store<T> store, T value) {
    if (_disposed) throw StateError('Scope disposed');
    _values[store] = value;
    store.write(value);
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
