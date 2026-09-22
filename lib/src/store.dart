import 'event.dart';
import 'kernel.dart';
import 'scope.dart';
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
        _initial = initial,
        _derived = derived;

  T _state;
  /// Value passed to the constructor — what [reset] restores when [to] is omitted.
  final T _initial;
  final bool _derived;
  final UpdateFilter<T>? updateFilter;

  /// Current value — respects [Kernel.currentScope] when inside
  /// [allSettled] / [scopeBind] / [Kernel.runInScope].
  T getState() {
    final scope = Kernel.instance.currentScope;
    if (scope is Scope && scope.contains(this)) {
      return scope.read<T>(this);
    }
    return _state;
  }

  /// Current value (alias of [getState] for Effector familiarity).
  T get value => getState();

  /// Constructor default — Effector-style reset target when [reset]'s [to] is omitted.
  T get defaultState => _initial;

  /// Global (unscoped) value — for rare introspection; prefer [getState].
  T get globalState => _state;

  bool get isDerived => _derived;

  /// `$store.on(event, (state, payload) => next)`
  Store<T> on<P>(Event<P> event, Reducer<T, P> reducer) {
    if (_derived) {
      throw StateError('Cannot .on() a derived store');
    }
    final sub = event.to((payload) {
      // Must use getState() so reducers see forked values under a Scope.
      final next = reducer(getState(), payload);
      _set(next);
    });
    attachLinks([sub]);
    return this;
  }

  /// Reset store when [clock] fires.
  ///
  /// When [to] is omitted, restores the constructor [defaultState] — not
  /// whatever value happened to be current when [reset] was wired. Capturing
  /// `_state` at call time meant `$s.on(...); $s.write(x); $s.reset(e)` would
  /// permanently "reset" to `x` instead of the real initial.
  Store<T> reset(Event<void> clock, [T? to]) {
    if (_derived) throw StateError('Cannot reset a derived store');
    final target = to ?? _initial;
    final sub = clock.to((_) => _set(target));
    attachLinks([sub]);
    return this;
  }

  void _set(T next) {
    if (isDisposed) return;
    final active = Kernel.instance.currentScope;
    if (active is Scope) {
      final prev =
          active.contains(this) ? active.read<T>(this) : _state;
      if (updateFilter != null) {
        if (!updateFilter!(prev, next)) return;
      } else if (identical(prev, next) || prev == next) {
        return;
      }
      // Forked write: bag only — do not mutate global `_state` or notify
      // global watchers (that would leak the fork into the live UI tree).
      active.writeValue(this, next);
      return;
    }
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
