import 'event.dart';
import 'unit.dart';

typedef Reducer<T, P> = T Function(T state, P payload);
typedef UpdateFilter<T> = bool Function(T previous, T next);

/// Writable or derived store (atom). Prefer `$name` naming like Effector.
final class Store<T> extends Unit with Subscribable<T>, DeferredNotify<T> {
  Store(
    T initial, {
    super.name,
    this.updateFilter,
    bool derived = false,
  })  : _state = initial,
        _derived = derived;

  T _state;
  final bool _derived;
  final UpdateFilter<T>? updateFilter;

  T getState() => _state;

  /// Current value (alias of [getState] for Effector familiarity).
  T get value => _state;

  bool get isDerived => _derived;

  /// `$store.on(event, (state, payload) => next)`
  Store<T> on<P>(Event<P> event, Reducer<T, P> reducer) {
    if (_derived) {
      throw StateError('Cannot .on() a derived store');
    }
    final sub = event.to((payload) {
      final next = reducer(_state, payload);
      _set(next);
    });
    attachLinks([sub]);
    return this;
  }

  /// Reset store when [clock] fires.
  Store<T> reset(Event<void> clock, [T? to]) {
    if (_derived) throw StateError('Cannot reset a derived store');
    final target = to ?? _state;
    final sub = clock.to((_) => _set(target));
    attachLinks([sub]);
    return this;
  }

  void _set(T next) {
    if (isDisposed) return;
    if (updateFilter != null) {
      if (!updateFilter!(_state, next)) return;
    } else if (identical(_state, next) || _state == next) {
      return;
    }
    _state = next;
    scheduleNotify(next);
  }

  /// Internal write used by sample/effects.
  ///
  /// Derived stores (`.map`/`combine`) are read-only from the outside — only
  /// their own derivation pipeline may write to them (via [writeDerived]).
  /// Without this guard, `sample(target: $derivedStore)` or any other code
  /// holding a reference could silently stomp the derived value until the
  /// next source update overwrote it again.
  void write(T next) {
    if (_derived) {
      throw StateError(
        'Cannot write to a derived store'
        '${name == null ? '' : ' ($name)'} — it is computed from .map()/'
        'combine() and updates only when its source(s) change.',
      );
    }
    _set(next);
  }

  /// Force write even for derived (used by combine/map internals).
  void writeDerived(T next) => _set(next);

  /// `$store.map((s) => …)` — derived read-only store.
  Store<R> map<R>(R Function(T state) fn, {String? name, UpdateFilter<R>? updateFilter}) {
    final derived = Store<R>(
      fn(_state),
      name: name ?? (this.name == null ? null : '${this.name}.map'),
      updateFilter: updateFilter,
      derived: true,
    );
    derived.attachLinks([watch((v) => derived.writeDerived(fn(v)))]);
    return derived;
  }
}

Store<T> createStore<T>(
  T initial, {
  String? name,
  UpdateFilter<T>? updateFilter,
}) =>
    Store<T>(initial, name: name, updateFilter: updateFilter);

bool isStore(Object? u) => u is Store;
