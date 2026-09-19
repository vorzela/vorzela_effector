/// Synchronous Effector-style kernel: one flush queue, atomic source reads.
library;

import 'dart:collection';

typedef VoidCallback = void Function();

abstract class Notifiable {
  void notifySubscribers();
}

final class Kernel {
  Kernel._();

  static final Kernel instance = Kernel._();

  bool _flushing = false;
  final Queue<VoidCallback> _queue = Queue<VoidCallback>();
  final Set<Object> _dirtyStores = {};

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
      // Leave the kernel consistent if `fn()` / a job throws — otherwise a
      // leftover queue/dirty set would leak into the next unrelated batch.
      _flushing = false;
      if (failed) {
        _queue.clear();
        _dirtyStores.clear();
      }
    }
  }

  /// Drain the job queue, then dirty notifiables, repeating until both are
  /// empty so stores marked dirty *during* a dirty pass (combine → combine)
  /// still settle in the same tick.
  void _drain() {
    while (true) {
      // removeFirst() is O(1); List.removeAt(0) was O(n) → O(n²) flushes.
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
