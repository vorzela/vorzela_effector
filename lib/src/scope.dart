import 'effect.dart';
import 'event.dart';
import 'kernel.dart';
import 'store.dart';
import 'unit.dart';

final class _ScopeSlot {
  _ScopeSlot(this.listener);
  final void Function(dynamic value) listener;
  bool removed = false;
}

/// Isolated Effector-style scope for tests, SSR, and Provider UI trees.
///
/// Zone-backed ([Kernel.runInScopeAsync]) so overlapping [allSettled] calls
/// on one isolate stay isolated. Leaf + derived stores recompute inside the
/// fork; [watchStore] drives [ScopeProvider] / [UnitBuilder] without touching
/// global watchers.
final class Scope {
  Scope._();

  final Map<Store, dynamic> _values = {};
  final Map<Store, List<_ScopeSlot>> _watchers = {};
  final Map<Effect, Function> _handlers = {};
  final Map<Effect, int> _effectGen = {};
  final Map<Effect, int> _effectInflight = {};
  final Set<Store> _changed = {};
  final List<Unit> _owned = [];

  /// Derived stores waiting for a Kernel-deduped recompute (mirrors
  /// global `combine` → `markDirty(recomputer)`).
  final Set<Store> _pendingRecompute = {};

  /// Latest value to push to [watchStore] listeners after the graph settles.
  final Map<Store, Object?> _pendingNotify = {};

  _ScopeDrain? _drain;
  bool _draining = false;
  bool _disposed = false;

  bool get isDisposed => _disposed;

  bool contains(Store store) => _values.containsKey(store);

  T read<T>(Store<T> store) => _values[store] as T;

  void writeValue(Store store, Object? value) {
    _values[store] = value;
    _changed.add(store);
  }

  /// Effect handler override for this scope (from [fork] `handlers:`).
  EffectHandler<P, D>? handlerFor<P, D>(Effect<P, D> effect) {
    final h = _handlers[effect];
    if (h == null) return null;
    return h as EffectHandler<P, D>;
  }

  void _setHandler(Effect effect, Function handler) {
    _handlers[effect] = handler;
  }

  T getState<T>(Store<T> store) {
    if (_disposed) throw StateError('Scope disposed');
    if (_values.containsKey(store)) return _values[store] as T;
    if (store.isDerived && store.hasCompute) {
      return Kernel.instance.runInScope(this, () {
        final v = store.computeValue() as T;
        writeValue(store, v);
        return v;
      });
    }
    return store.globalState;
  }

  void setState<T>(Store<T> store, T value) {
    if (_disposed) throw StateError('Scope disposed');
    final prev = contains(store) ? read<T>(store) : store.globalState;
    if (identical(prev, value) || prev == value) return;
    writeValue(store, value);
    queueNotify(store, value);
    queueDependentRecompute(store);
    Kernel.instance.flush();
  }

  /// Defer [watchStore] notification until Kernel flush (like
  /// [DeferredNotify.scheduleNotify] on the global graph).
  void queueNotify(Store store, Object? value) {
    _pendingNotify[store] = value;
    _ensureDrainScheduled();
  }

  /// Mark derived dependents of [source] dirty — Kernel dedups via
  /// [_ScopeDrain], so a multi-source [combine] recomputes once per batch.
  void queueDependentRecompute(Store source) {
    var added = false;
    for (final derived in source.dependents) {
      if (!derived.hasCompute) continue;
      if (_pendingRecompute.add(derived)) added = true;
    }
    if (added) _ensureDrainScheduled();
  }

  void _ensureDrainScheduled() {
    if (_draining) return;
    _drain ??= _ScopeDrain(this);
    Kernel.instance.markDirty(_drain!);
  }

  /// Kernel-driven flush: recompute dirty derived stores (with pass cap),
  /// then fire deferred [watchStore] notifications.
  void _drainPending() {
    if (_disposed) {
      _pendingRecompute.clear();
      _pendingNotify.clear();
      return;
    }
    _draining = true;
    try {
      Kernel.instance.runInScope(this, () {
        var passes = 0;
        while (_pendingRecompute.isNotEmpty) {
          if (++passes > Kernel.maxFlushPasses) {
            throw StateError(
              'Scope derived flush exceeded ${Kernel.maxFlushPasses} passes — '
              'likely a self-referential scoped update loop. Fix the graph.',
            );
          }
          final batch = _pendingRecompute.toList(growable: false);
          _pendingRecompute.clear();
          for (final derived in batch) {
            if (!derived.hasCompute) continue;
            final next = derived.computeValue();
            final prev = contains(derived)
                ? _values[derived]
                : derived.globalState;
            if (identical(prev, next) || prev == next) continue;
            // writeDerived → Store._set (scoped) → queueNotify + queue
            // dependents; `_draining` keeps us from re-markDirty mid-loop.
            derived.writeDerived(next);
          }
        }
        if (_pendingNotify.isEmpty) return;
        final notifies = Map<Store, Object?>.of(_pendingNotify);
        _pendingNotify.clear();
        for (final e in notifies.entries) {
          notifyStore(e.key, e.value);
        }
      });
    } finally {
      _draining = false;
    }
  }

  /// Subscribe to [store] updates **in this scope only**.
  Subscription watchStore<T>(Store<T> store, void Function(T value) listener) {
    if (_disposed) throw StateError('Cannot watch on a disposed scope');
    final slot = _ScopeSlot((v) => listener(v as T));
    (_watchers[store] ??= []).add(slot);
    return Subscription(() {
      if (slot.removed) return;
      slot.removed = true;
    });
  }

  void notifyStore(Store store, Object? value) {
    final slots = _watchers[store];
    if (slots == null || slots.isEmpty) return;
    final len = slots.length;
    for (var i = 0; i < len; i++) {
      final slot = slots[i];
      if (!slot.removed) slot.listener(value);
    }
    if (slots.length > 16) {
      final live = slots.where((s) => !s.removed).length;
      if (live * 2 < slots.length) {
        slots.removeWhere((s) => s.removed);
      }
    }
  }

  int beginEffect(Effect effect) {
    final gen = (_effectGen[effect] ?? 0) + 1;
    _effectGen[effect] = gen;
    _effectInflight[effect] = (_effectInflight[effect] ?? 0) + 1;
    return gen;
  }

  /// Returns true if this generation is still current (not aborted / superseded).
  bool endEffect(Effect effect, int gen) {
    final inflight = ((_effectInflight[effect] ?? 1) - 1).clamp(0, 1 << 30);
    _effectInflight[effect] = inflight;
    return gen == (_effectGen[effect] ?? 0);
  }

  int effectInflight(Effect effect) => _effectInflight[effect] ?? 0;

  void abortEffect(Effect effect) {
    _effectGen[effect] = (_effectGen[effect] ?? 0) + 1;
    _effectInflight[effect] = 0;
  }

  /// Serialize this scope's store values keyed by [Store.sid].
  Map<String, dynamic> serialize({bool onlyChanges = true}) =>
      serializeScope(this, onlyChanges: onlyChanges);

  void own(Unit unit) => _owned.add(unit);

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final u in _owned) {
      u.dispose();
    }
    _owned.clear();
    _values.clear();
    _watchers.clear();
    _handlers.clear();
    _effectGen.clear();
    _effectInflight.clear();
    _changed.clear();
    _pendingRecompute.clear();
    _pendingNotify.clear();
    _drain = null;
  }
}

/// One Notifiable per [Scope] so Kernel `_dirtyStores` dedups scoped work
/// the same way it dedups global `combine` recomputers.
final class _ScopeDrain implements Notifiable {
  _ScopeDrain(this._scope);
  final Scope _scope;

  @override
  void notifySubscribers() => _scope._drainPending();
}

void _seedValues(Scope scope, Object? values) {
  if (values == null) return;
  if (values is Map) {
    for (final e in values.entries) {
      final store = Store.bySid(e.key.toString());
      if (store != null) scope.writeValue(store, e.value);
    }
    return;
  }
  if (values is List) {
    for (final item in values) {
      if (item case (Store store, Object? value)) {
        scope.writeValue(store, value);
      } else {
        throw ArgumentError(
          'fork values list entries must be (Store, value) records',
        );
      }
    }
    return;
  }
  throw ArgumentError(
    'fork values: must be List<(Store, value)> or Map<String, dynamic>',
  );
}

/// Create an isolated scope (Effector `fork`).
///
/// [values] — either `List<(Store, value)>` or `Map<String, dynamic>` (by sid).
/// [handlers] — `(effect, mockHandler)` overrides for this scope only.
Scope fork({
  Object? values,
  List<(Effect, Function)>? handlers,
  @Deprecated('Pass a Map to values:') Map<String, dynamic>? valuesMap,
}) {
  final scope = Scope._();
  _seedValues(scope, values);
  if (valuesMap != null) _seedValues(scope, valuesMap);
  if (handlers != null) {
    for (final (effect, handler) in handlers) {
      scope._setHandler(effect, handler);
    }
  }
  return scope;
}

/// Serialize scoped store values keyed by [Store.sid].
Map<String, dynamic> serializeScope(
  Scope scope, {
  bool onlyChanges = true,
}) {
  if (scope.isDisposed) throw StateError('Cannot serialize a disposed scope');
  final out = <String, dynamic>{};
  final entries = onlyChanges
      ? [
          for (final s in scope._changed)
            if (scope.contains(s)) MapEntry(s, scope._values[s]),
        ]
      : scope._values.entries.toList();
  for (final e in entries) {
    final sid = e.key.sid;
    if (sid == null) continue;
    out[sid] = e.value;
  }
  return out;
}

/// Compatibility — prefer [Scope.serialize].
Map<String, dynamic> serialize(
  Scope scope, {
  bool onlyChanges = true,
}) =>
    serializeScope(scope, onlyChanges: onlyChanges);

/// Seed an existing scope from a sid→value map. Prefer `fork(values: map)`.
void hydrate(Scope scope, Map<String, dynamic> values) {
  if (scope.isDisposed) throw StateError('Cannot hydrate a disposed scope');
  Kernel.instance.batch(() {
    for (final e in values.entries) {
      final store = Store.bySid(e.key);
      if (store == null) continue;
      final prev = scope.contains(store)
          ? scope._values[store]
          : store.globalState;
      if (identical(prev, e.value) || prev == e.value) continue;
      scope.writeValue(store, e.value);
      scope.queueNotify(store, e.value);
      scope.queueDependentRecompute(store);
    }
  });
}

/// Run [unit] optionally inside [scope], waiting for effects to settle.
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
  await Future<void>.delayed(Duration.zero);
}

/// Bind a callable so it always runs inside [scope] (Zone-safe across await).
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
