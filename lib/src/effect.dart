import 'dart:async';

import 'event.dart';
import 'kernel.dart';
import 'scope.dart';
import 'store.dart';
import 'unit.dart';

/// Done payload: `{ params, result }` like Effector.
final class EffectDone<P, D> {
  const EffectDone({required this.params, required this.result});
  final P params;
  final D result;
}

/// Fail payload: `{ params, error }`.
final class EffectFail<P> {
  const EffectFail({required this.params, required this.error});
  final P params;
  final Object error;
}

typedef EffectHandler<P, D> = FutureOr<D> Function(P params);

/// Async effect with race-safe generations — stale results never commit.
///
/// Generations / inflight counts are **per [Scope]** (and a separate global
/// lane) so overlapping `allSettled` on the same effect in two forks cannot
/// cancel each other — required for ecommerce parallel fetches.
final class Effect<P, D> extends Unit with Subscribable<P> {
  Effect(this._handler, {super.name}) {
    done = createEventTyped<EffectDone<P, D>>(
      name: name == null ? null : '$name.done',
    );
    fail = createEventTyped<EffectFail<P>>(
      name: name == null ? null : '$name.fail',
    );
    finally_ = createEventTyped<P>(
      name: name == null ? null : '$name.finally',
    );
    $pending = createStore<bool>(
      false,
      name: name == null ? null : '$name.pending',
    );
  }

  final EffectHandler<P, D> _handler;

  late final Event<EffectDone<P, D>> done;
  late final Event<EffectFail<P>> fail;
  late final Event<P> finally_;
  late final Store<bool> $pending;

  int _generation = 0;
  int _inflight = 0;
  bool _aborted = false;

  void abort() {
    final active = Kernel.instance.currentScope;
    if (active is Scope) {
      active.abortEffect(this);
      Kernel.instance.batch(() => $pending.write(false));
      return;
    }
    _aborted = true;
    _generation++;
    _inflight = 0;
    Kernel.instance.batch(() => $pending.write(false));
  }

  Future<D> call(P params) {
    if (isDisposed) {
      return Future.error(StateError('Effect disposed'));
    }

    final active = Kernel.instance.currentScope;
    final EffectHandler<P, D> handler = active is Scope
        ? (active.handlerFor<P, D>(this) ?? _handler)
        : _handler;

    late final int gen;
    if (active is Scope) {
      gen = active.beginEffect(this);
    } else {
      _aborted = false;
      gen = ++_generation;
      _inflight++;
    }

    Kernel.instance.batch(() {
      $pending.write(true);
      notify(params);
    });

    return Future.sync(() => handler(params)).then((result) {
      if (active is Scope) {
        final still = active.endEffect(this, gen);
        if (!still || isDisposed) {
          if (!isDisposed) {
            Kernel.instance.batch(
              () => $pending.write(active.effectInflight(this) > 0),
            );
          }
          return result;
        }
      } else {
        _inflight = (_inflight - 1).clamp(0, 1 << 30);
        if (gen != _generation || _aborted || isDisposed) {
          if (!isDisposed) {
            Kernel.instance.batch(() => $pending.write(_inflight > 0));
          }
          return result;
        }
      }
      Kernel.instance.batch(() {
        done(EffectDone(params: params, result: result));
        finally_(params);
        if (active is Scope) {
          $pending.write(active.effectInflight(this) > 0);
        } else {
          $pending.write(_inflight > 0);
        }
      });
      return result;
    }, onError: (Object e, StackTrace st) {
      if (active is Scope) {
        final still = active.endEffect(this, gen);
        if (!still || isDisposed) {
          if (!isDisposed) {
            Kernel.instance.batch(
              () => $pending.write(active.effectInflight(this) > 0),
            );
          }
          return Future<D>.error(e, st);
        }
      } else {
        _inflight = (_inflight - 1).clamp(0, 1 << 30);
        if (gen != _generation || _aborted || isDisposed) {
          if (!isDisposed) {
            Kernel.instance.batch(() => $pending.write(_inflight > 0));
          }
          return Future<D>.error(e, st);
        }
      }
      Kernel.instance.batch(() {
        fail(EffectFail(params: params, error: e));
        finally_(params);
        if (active is Scope) {
          $pending.write(active.effectInflight(this) > 0);
        } else {
          $pending.write(_inflight > 0);
        }
      });
      return Future<D>.error(e, st);
    });
  }

  @override
  void onDispose() {
    abort();
    done.dispose();
    fail.dispose();
    finally_.dispose();
    $pending.dispose();
    super.onDispose();
  }
}

Effect<P, D> createEffect<P, D>(EffectHandler<P, D> handler, {String? name}) =>
    Effect<P, D>(handler, name: name);

bool isEffect(Object? u) => u is Effect;
