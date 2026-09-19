import 'kernel.dart';
import 'store.dart';
import 'unit.dart';

/// Combine stores into a derived store (Effector `combine`).
///
/// If several source stores change inside the same [Kernel.batch] (the
/// common case — e.g. resetting a form updates many fields at once), the
/// derived value is recomputed exactly **once**, using the final settled
/// values of all sources, instead of once per changed source. Kernel's dirty
/// set already dedupes by identity, so registering one [Notifiable] per
/// `combine()` call — rather than writing eagerly from every source's watch
/// callback — is enough to get that for free.
Store<R> combine<R>(
  List<Store> stores,
  R Function(List<dynamic> values) fn, {
  String? name,
}) {
  List<dynamic> snapshot() => [for (final s in stores) s.getState()];
  final derived = Store<R>(
    fn(snapshot()),
    name: name,
    derived: true,
  );
  final recomputer = _CombineRecomputer(() => derived.writeDerived(fn(snapshot())));
  final links = <Subscription>[
    for (final s in stores) s.watch((_) => Kernel.instance.markDirty(recomputer)),
  ];
  derived.attachLinks(links);
  return derived;
}

final class _CombineRecomputer implements Notifiable {
  _CombineRecomputer(this._recompute);
  final void Function() _recompute;

  @override
  void notifySubscribers() => _recompute();
}

Store<R> combine2<A, B, R>(
  Store<A> a,
  Store<B> b,
  R Function(A a, B b) fn, {
  String? name,
}) =>
    combine<R>([a, b], (vals) => fn(vals[0] as A, vals[1] as B), name: name);

Store<R> combine3<A, B, C, R>(
  Store<A> a,
  Store<B> b,
  Store<C> c,
  R Function(A a, B b, C c) fn, {
  String? name,
}) =>
    combine<R>(
      [a, b, c],
      (vals) => fn(vals[0] as A, vals[1] as B, vals[2] as C),
      name: name,
    );
