import 'kernel.dart';

/// Base reactive unit.
abstract class Unit {
  Unit({this.name});

  final String? name;

  bool get isDisposed => _disposed;
  bool _disposed = false;

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    onDispose();
  }

  void onDispose() {}
}

typedef Subscriber<T> = void Function(T value);

/// Subscription handle — call [unsubscribe] (or [dispose]) to detach.
final class Subscription {
  Subscription(this._cancel);

  final void Function() _cancel;
  bool _active = true;

  void unsubscribe() {
    if (!_active) return;
    _active = false;
    _cancel();
  }

  void dispose() => unsubscribe();

  bool get isActive => _active;
}

mixin Subscribable<T> on Unit {
  final List<Subscriber<T>> _subs = [];

  Subscription watch(Subscriber<T> listener) {
    if (isDisposed) {
      throw StateError('Cannot watch a disposed unit${name == null ? '' : ' ($name)'}');
    }
    _subs.add(listener);
    return Subscription(() => _subs.remove(listener));
  }

  void notify(T value) {
    if (isDisposed) return;
    // Copy to allow unsubscribe during notify.
    final snap = List<Subscriber<T>>.from(_subs);
    for (final s in snap) {
      s(value);
    }
  }

  int get subscriberCount => _subs.length;

  @override
  void onDispose() {
    _subs.clear();
    super.onDispose();
  }
}

/// Defer store subscriber notifications until end of kernel flush.
mixin DeferredNotify<T> on Subscribable<T> implements Notifiable {
  T? _pendingNotify;
  bool _hasPending = false;

  void scheduleNotify(T value) {
    _pendingNotify = value;
    _hasPending = true;
    Kernel.instance.markDirty(this);
  }

  @override
  void notifySubscribers() {
    if (!_hasPending) return;
    _hasPending = false;
    final v = _pendingNotify as T;
    notify(v);
  }
}
