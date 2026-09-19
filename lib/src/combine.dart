import 'store.dart';
import 'unit.dart';

/// Combine stores into a derived store (Effector `combine`).
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
  final links = <Subscription>[
    for (final s in stores) s.watch((_) => derived.writeDerived(fn(snapshot()))),
  ];
  derived.attachLinks(links);
  return derived;
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
