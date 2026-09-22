import 'effect.dart';
import 'event.dart';
import 'kernel.dart';
import 'store.dart';
import 'unit.dart';

/// Isolated Effector-style scope: forked store values + dispose bag.
///
/// **What works (Effector-compatible subset):**
/// - [fork] / [fork] `values:` seed overrides
/// - [allSettled] / [scopeBind] run units inside the scope via
///   [Kernel.runInScope] / [runInScopeAsync]
/// - Leaf [Store] reads/writes during that window hit this scope's bag —
///   global `store.getState()` stays unchanged
///
/// **Not yet Effector-complete:**
/// - No `serialize` / `hydrate` / effect `handlers:` overrides
/// - Derived stores (`.map` / `combine`) are not graph-cloned — scoped
///   updates to sources do not recompute derived values inside the scope
/// - Scoped writes do not notify global `watch` / `UnitBuilder` listeners
///   (by design — isolation); UI must read via [getState] on the scope or
///   run under a bound callback
/// - Overlapping concurrent [allSettled] on different scopes on one isolate
///   can clobber [Kernel.currentScope] — run them sequentially
final class Scope {
  Scope._();

  final Map<Store, dynamic> _values = {};
  final List<Unit> _owned = [];
  bool _disposed = false;

  bool get isDisposed => _disposed;

  bool contains(Store store) => _values.containsKey(store);

  T read<T>(Store<T> store) => _values[store] as T;

  void writeValue(Store store, Object? value) => _values[store] = value;

  T getState<T>(Store<T> store) {
    if (_disposed) throw StateError('Scope disposed');
    if (_values.containsKey(store)) return _values[store] as T;
    return store.getState();
  }

  /// Write into this scope's own snapshot **only** (does not mutate the
  /// global store, and does not require being inside [Kernel.runInScope]).
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
///
/// [values] seeds per-store overrides, Effector-style:
/// `fork(values: [($user, 'alice'), ($count, 1)])`.
Scope fork({List<(Store, Object?)>? values}) {
  final scope = Scope._();
  if (values != null) {
    for (final (store, value) in values) {
      scope.writeValue(store, value);
    }
  }
  return scope;
}

/// Run [unit] (and wait for an [Effect] to settle) optionally inside [scope].
Future<void> allSettled(
  Object unit, {
  Scope? scope,
  dynamic params,
}) async {
  Future<void> run() async {
    if (unit is Event) {
      unit.call(params);
    } else if (unit is Effect) {
      await unit.call(params);
    } else {
      throw ArgumentError('allSettled expects Event or Effect');
    }
  }

  if (scope != null) {
    if (scope.isDisposed) {
      throw StateError('Cannot allSettled in a disposed scope');
    }
    await Kernel.instance.runInScopeAsync(scope, run);
  } else {
    await run();
  }
  // Let microtasks from effect completions flush.
  await Future<void>.delayed(Duration.zero);
}

/// Bind a callable so it always runs inside [scope].
///
/// Events run synchronously in-scope. Effects keep the scope across their
/// async handler via [Kernel.runInScopeAsync] (fire-and-forget Future).
void Function([dynamic params]) scopeBind(
  Object unit, {
  required Scope scope,
}) {
  if (scope.isDisposed) {
    throw StateError('Cannot bind to disposed scope');
  }
  return ([params]) {
    if (scope.isDisposed) {
      throw StateError('Cannot call bound unit: scope disposed');
    }
    if (unit is Event) {
      Kernel.instance.runInScope(scope, () => unit.call(params));
    } else if (unit is Effect) {
      Kernel.instance.runInScopeAsync(scope, () => unit.call(params));
    } else {
      throw ArgumentError('scopeBind expects Event or Effect');
    }
  };
}
