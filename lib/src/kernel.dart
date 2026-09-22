/// Synchronous Effector-style kernel: one flush queue, atomic source reads.
library;

import 'dart:async';
import 'dart:collection';

typedef VoidCallback = void Function();

abstract class Notifiable {
  void notifySubscribers();
}

/// Zone key for the active [Scope]. Typed as [Object] so kernel never imports
/// scope.dart (avoids cycles). [Store] / [Effect] cast with `is Scope`.
const Symbol kVorzelaScope = #vorzelaEffectorScope;

final class Kernel {
  Kernel._();

  static final Kernel instance = Kernel._();

  /// Max queue↔dirty cycles per [batch]. Catches accidental self-update loops
  /// (a watcher writing the store it watches) without changing normal graphs.
  static const int maxFlushPasses = 1000;

  bool _flushing = false;
  final Queue<VoidCallback> _queue = Queue<VoidCallback>();
  final Set<Object> _dirtyStores = {};

  /// Active scope from the current [Zone] (safe under overlapping async work).
  Object? get currentScope => Zone.current[kVorzelaScope];

  /// Run [fn] with [scope] bound in a child [Zone] (nested sync calls stack).
  R runInScope<R>(Object scope, R Function() fn) {
    return runZoned(fn, zoneValues: {kVorzelaScope: scope});
  }

  /// Like [runInScope] but keeps the scope across `await`s inside [fn].
  /// Concurrent [allSettled] on different scopes on one isolate are safe.
  Future<R> runInScopeAsync<R>(
    Object scope,
    Future<R> Function() fn,
  ) {
    return runZoned(fn, zoneValues: {kVorzelaScope: scope});
  }

  /// Run [fn] inside a single graph flush (nested calls coalesce).
  void batch(VoidCallback fn) {
    if (_flushing) {
      fn();
      return;
    }
    _flushing = true;
    var failed = true;
    try {
      fn();
      _drain();
      failed = false;
    } finally {
      _flushing = false;
      if (failed) {
        _queue.clear();
        _dirtyStores.clear();
      }
    }
  }

  void _drain() {
    var passes = 0;
    while (true) {
      if (++passes > maxFlushPasses) {
        throw StateError(
          'Kernel flush exceeded $maxFlushPasses passes — likely a '
          'self-referential store update loop (a watcher writing the same '
          'store, or an unbounded cascade). Fix the graph; do not raise the '
          'limit.',
        );
      }
      while (_queue.isNotEmpty) {
        final job = _queue.removeFirst();
        job();
      }
      if (_dirtyStores.isEmpty) return;
      final dirty = _dirtyStores.toList(growable: false);
      _dirtyStores.clear();
      for (final s in dirty) {
        if (s is Notifiable) s.notifySubscribers();
      }
    }
  }

  void enqueue(VoidCallback fn) {
    if (_flushing) {
      _queue.add(fn);
    } else {
      batch(fn);
    }
  }

  void markDirty(Object store) {
    _dirtyStores.add(store);
  }
}
