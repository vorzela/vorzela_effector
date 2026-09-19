import 'package:flutter/material.dart';
import 'package:vorzela_effector/vorzela_effector.dart';

/// Anything that can be released when a route / feature widget unmounts.
abstract class Disposable {
  void dispose();
}

/// Wraps an object that needs an explicit [dispose] callback.
final class DisposableRef<T extends Object> implements Disposable {
  DisposableRef(this.value, this._dispose);
  final T value;
  final void Function(T value) _dispose;

  @override
  void dispose() => _dispose(value);
}

class _Slot {
  _Slot(this.value, this.dispose);
  final Object value;
  final void Function() dispose;
}

/// Lifecycle bag: create controllers / subscriptions **once**, dispose **once**.
///
/// Used by:
/// - [AutoDispose] — for StatelessWidget trees
/// - [AutoDisposeMixin] — for StatefulWidget (animations, TabController, …)
///
/// Call factories in the **same order** every build (like hooks). Rebuilds
/// return the **same** instance — no duplicate controllers, no listener junk.
final class Life {
  Life();

  final List<_Slot> _slots = [];
  int _cursor = 0;
  bool _sealed = false;

  /// Reset call-order cursor. Called automatically before each build.
  void beginBuild() => _cursor = 0;

  void _ensureOpen() {
    if (_sealed) {
      throw StateError('Life used after dispose');
    }
  }

  /// Create-once helper. Same call order → same instance across rebuilds.
  T use<T extends Object>(T Function() create, void Function(T value) dispose) {
    _ensureOpen();
    if (_cursor < _slots.length) {
      return _slots[_cursor++].value as T;
    }
    final value = create();
    _slots.add(_Slot(value, () => dispose(value)));
    _cursor++;
    return value;
  }

  // —— Common Flutter controllers (all auto-disposed) ——

  TextEditingController textEditingController({String text = ''}) {
    return use(() => TextEditingController(text: text), (c) => c.dispose());
  }

  FocusNode focusNode({String? debugLabel}) {
    return use(
      () => FocusNode(debugLabel: debugLabel),
      (n) => n.dispose(),
    );
  }

  ScrollController scrollController({double initialScrollOffset = 0}) {
    return use(
      () => ScrollController(initialScrollOffset: initialScrollOffset),
      (c) => c.dispose(),
    );
  }

  PageController pageController({
    int initialPage = 0,
    bool keepPage = true,
    double viewportFraction = 1.0,
  }) {
    return use(
      () => PageController(
        initialPage: initialPage,
        keepPage: keepPage,
        viewportFraction: viewportFraction,
      ),
      (c) => c.dispose(),
    );
  }

  /// Needs a [TickerProvider] — use from a [State] with
  /// [TickerProviderStateMixin] / [SingleTickerProviderStateMixin] +
  /// [AutoDisposeMixin].
  AnimationController animationController({
    required TickerProvider vsync,
    Duration? duration,
    Duration? reverseDuration,
    String? debugLabel,
    double lowerBound = 0.0,
    double upperBound = 1.0,
    double? value,
    AnimationBehavior animationBehavior = AnimationBehavior.normal,
  }) {
    return use(
      () => AnimationController(
        vsync: vsync,
        duration: duration,
        reverseDuration: reverseDuration,
        debugLabel: debugLabel,
        lowerBound: lowerBound,
        upperBound: upperBound,
        value: value,
        animationBehavior: animationBehavior,
      ),
      (c) => c.dispose(),
    );
  }

  /// Needs [TickerProvider] + [length] (TabBar / TabBarView).
  TabController tabController({
    required TickerProvider vsync,
    required int length,
    int initialIndex = 0,
    Duration? animationDuration,
  }) {
    return use(
      () => TabController(
        vsync: vsync,
        length: length,
        initialIndex: initialIndex,
        animationDuration: animationDuration,
      ),
      (c) => c.dispose(),
    );
  }

  ValueNotifier<T> valueNotifier<T>(T initial) {
    return use(() => ValueNotifier<T>(initial), (n) => n.dispose());
  }

  // —— Store ↔ text (cuts form boilerplate) ——

  /// Two-way bind: typing → [onChanged]; store updates → rewrite field.
  /// One controller + one store subscription; disposed with this [Life].
  TextEditingController bindText(
    Store<String> store,
    void Function(String value) onChanged,
  ) {
    return use(
      () => _BoundText.create(store, onChanged),
      (b) => b.dispose(),
    ).controller;
  }

  /// Subscribe once (memoized). Safe to call from `build` every frame —
  /// does **not** stack listeners.
  T watch<T>(Store<T> store, void Function(T value) onChange) {
    final slot = use(
      () => _WatchSlot<T>(store, onChange),
      (s) => s.dispose(),
    );
    return slot.latest;
  }

  void dispose() {
    if (_sealed) return;
    _sealed = true;
    for (final slot in _slots.reversed) {
      slot.dispose();
    }
    _slots.clear();
  }
}

/// Alias kept so older docs / code still type-check.
typedef AutoDisposeHandle = Life;

final class _WatchSlot<T> {
  _WatchSlot(this.store, this.onChange) {
    latest = store.getState();
    _sub = store.watch((v) {
      latest = v;
      onChange(v);
    });
  }

  final Store<T> store;
  final void Function(T value) onChange;
  late T latest;
  late final Subscription _sub;

  void dispose() => _sub.unsubscribe();
}

final class _BoundText {
  _BoundText({
    required this.controller,
    required Subscription sub,
    required VoidCallback onUser,
  })  : _sub = sub,
        _onUser = onUser;

  factory _BoundText.create(
    Store<String> store,
    void Function(String value) onChanged,
  ) {
    final controller = TextEditingController(text: store.getState());
    var writingFromStore = false;

    void onUser() {
      if (writingFromStore) return;
      onChanged(controller.text);
    }

    controller.addListener(onUser);

    final sub = store.watch((v) {
      if (controller.text == v) return;
      writingFromStore = true;
      controller.value = TextEditingValue(
        text: v,
        selection: TextSelection.collapsed(offset: v.length),
      );
      writingFromStore = false;
    });

    return _BoundText(controller: controller, sub: sub, onUser: onUser);
  }

  final TextEditingController controller;
  final Subscription _sub;
  final VoidCallback _onUser;

  void dispose() {
    _sub.unsubscribe();
    controller.removeListener(_onUser);
    controller.dispose();
  }
}

/// Stateless-friendly: [Life] lives as long as this widget.
///
/// ```dart
/// AutoDispose(
///   builder: (context, life) {
///     final name = life.bindText($name, setName.call);
///     return TextField(controller: name);
///   },
/// )
/// ```
class AutoDispose extends StatefulWidget {
  const AutoDispose({super.key, required this.builder});

  final Widget Function(BuildContext context, Life life) builder;

  @override
  State<AutoDispose> createState() => _AutoDisposeState();
}

class _AutoDisposeState extends State<AutoDispose> {
  final Life life = Life();

  @override
  void dispose() {
    life.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    life.beginBuild();
    return widget.builder(context, life);
  }
}

/// Drop into any [State] (including animation / tab states).
///
/// ```dart
/// class _PageState extends State<Page>
///     with SingleTickerProviderStateMixin, AutoDisposeMixin {
///   @override
///   Widget build(BuildContext context) {
///     return buildWithLife((life) {
///       final anim = life.animationController(
///         vsync: this,
///         duration: const Duration(milliseconds: 300),
///       );
///       final count = life.watch($count, (_) => setState(() {}));
///       return FadeTransition(opacity: anim, child: Text('$count'));
///     });
///   }
/// }
/// ```
mixin AutoDisposeMixin<T extends StatefulWidget> on State<T> {
  final Life life = Life();

  @override
  void dispose() {
    life.dispose();
    super.dispose();
  }

  /// Call at the top of `build` if you use [life] directly (not [buildWithLife]).
  void lifeBeginBuild() => life.beginBuild();

  /// Preferred: resets call-order then runs [builder].
  Widget buildWithLife(Widget Function(Life life) builder) {
    life.beginBuild();
    return builder(life);
  }
}

/// Ready-made [TextField] bound to a [Store]<[String]>; controller auto-disposed.
///
/// Use when the field **is** the UI. For custom layouts use [Life.bindText].
class StoreTextField extends StatefulWidget {
  const StoreTextField({
    super.key,
    required this.store,
    this.onChanged,
    this.event,
    this.decoration,
    this.obscureText = false,
    this.keyboardType,
    this.maxLines = 1,
    this.enabled = true,
  }) : assert(
          onChanged != null || event != null,
          'Provide onChanged or event',
        );

  final Store<String> store;

  /// Called on each keystroke (e.g. `setEmail.call`).
  final void Function(String value)? onChanged;

  /// Shorthand: pass the event itself instead of `.call`.
  final Event<String>? event;

  final InputDecoration? decoration;
  final bool obscureText;
  final TextInputType? keyboardType;
  final int? maxLines;
  final bool enabled;

  @override
  State<StoreTextField> createState() => _StoreTextFieldState();
}

class _StoreTextFieldState extends State<StoreTextField> {
  late final _BoundText _bound;

  void Function(String) get _emit =>
      widget.onChanged ?? (v) => widget.event!(v);

  @override
  void initState() {
    super.initState();
    _bound = _BoundText.create(widget.store, _emit);
  }

  @override
  void dispose() {
    _bound.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _bound.controller,
      decoration: widget.decoration,
      obscureText: widget.obscureText,
      keyboardType: widget.keyboardType,
      maxLines: widget.maxLines,
      enabled: widget.enabled,
    );
  }
}
