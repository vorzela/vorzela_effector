/// Synchronous Effector-style kernel: one flush queue, atomic source reads.
library;

typedef VoidCallback = void Function();

abstract class Notifiable {
  void notifySubscribers();
}

final class Kernel {
  Kernel._();

  static final Kernel instance = Kernel._();

  bool _flushing = false;
  final List<VoidCallback> _queue = [];
  final Set<Object> _dirtyStores = {};

  /// Run [fn] inside a single graph flush (nested calls coalesce).
  void batch(VoidCallback fn) {
    if (_flushing) {
      fn();
      return;
    }
    _flushing = true;
    try {
      fn();
      while (_queue.isNotEmpty) {
        final job = _queue.removeAt(0);
        job();
      }
      final dirty = List<Object>.from(_dirtyStores);
      _dirtyStores.clear();
      for (final s in dirty) {
        if (s is Notifiable) s.notifySubscribers();
      }
    } finally {
      _flushing = false;
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
