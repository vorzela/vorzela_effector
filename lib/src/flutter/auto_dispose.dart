import 'package:flutter/material.dart';
import 'package:vorzela_effector/vorzela_effector.dart';

/// Anything that can be released when a route / feature widget unmounts.
abstract class Disposable {
  void dispose();
}

/// Wraps Flutter controllers that need [dispose] (TextEditingController, etc.).
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

/// Handle passed to [AutoDispose.builder] — register resources; they dispose
/// automatically when the widget leaves the tree (same idea as disposing a
/// [TextEditingController] in `State.dispose`).
///
/// Factory helpers ([textEditingController], [focusNode], [scrollController])
/// are **stable across rebuilds** (same call order → same instance), like hooks.
final class AutoDisposeHandle {
  AutoDisposeHandle();

  final List<_Slot> _slots = [];
  final List<Disposable> _extras = [];
  final List<Subscription> _subs = [];
  int _cursor = 0;
  bool _sealed = false;

  void _beginBuild() => _cursor = 0;

  void _ensureOpen() {
    if (_sealed) {
      throw StateError('AutoDisposeHandle used after dispose');
    }
  }

  T _use<T extends Object>(T Function() create, void Function(T value) dispose) {
    _ensureOpen();
    if (_cursor < _slots.length) {
      return _slots[_cursor++].value as T;
    }
    final value = create();
    _slots.add(_Slot(value, () => dispose(value)));
    _cursor++;
    return value;
  }

  /// Own an arbitrary disposable (added once; call only from init-like paths
  /// or guard with your own flag — not memoized across rebuilds).
  T own<T extends Disposable>(T resource) {
    _ensureOpen();
    _extras.add(resource);
    return resource;
  }

  /// Own a Flutter object with an explicit dispose callback (not memoized).
  T manage<T extends Object>(T value, void Function(T value) dispose) {
    _ensureOpen();
    _extras.add(DisposableRef(value, dispose));
    return value;
  }

  /// [TextEditingController] that is disposed with this handle.
  /// Same call order on rebuild returns the same instance.
  TextEditingController textEditingController({String text = ''}) {
    return _use(() => TextEditingController(text: text), (c) => c.dispose());
  }

  /// [FocusNode] that is disposed with this handle.
  FocusNode focusNode({String? debugLabel}) {
    return _use(
      () => FocusNode(debugLabel: debugLabel),
      (n) => n.dispose(),
    );
  }

  /// [ScrollController] that is disposed with this handle.
  ScrollController scrollController({double initialScrollOffset = 0}) {
    return _use(
      () => ScrollController(initialScrollOffset: initialScrollOffset),
      (c) => c.dispose(),
    );
  }

  /// Watch a store; subscription is cleared on dispose.
  /// Prefer calling once (e.g. first frame) — each call adds a subscription.
  T watchStore<T>(Store<T> store, void Function(T value) onChange) {
    _ensureOpen();
    _subs.add(store.watch(onChange));
    return store.getState();
  }

  void dispose() {
    if (_sealed) return;
    _sealed = true;
    for (final s in _subs) {
      s.unsubscribe();
    }
    _subs.clear();
    for (final e in List<Disposable>.from(_extras.reversed)) {
      e.dispose();
    }
    _extras.clear();
    for (final slot in _slots.reversed) {
      slot.dispose();
    }
    _slots.clear();
  }
}

/// Stateless-friendly builder: create [TextEditingController]s (and friends)
/// that are **always** disposed when this widget is removed.
///
/// ```dart
/// AutoDispose(
///   builder: (context, d) {
///     final name = d.textEditingController();
///     return TextField(
///       controller: name,
///       onChanged: (v) => nameChanged(v),
///     );
///   },
/// )
/// ```
class AutoDispose extends StatefulWidget {
  const AutoDispose({super.key, required this.builder});

  final Widget Function(BuildContext context, AutoDisposeHandle d) builder;

  @override
  State<AutoDispose> createState() => _AutoDisposeState();
}

class _AutoDisposeState extends State<AutoDispose> {
  late final AutoDisposeHandle _handle = AutoDisposeHandle();

  @override
  void dispose() {
    _handle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _handle._beginBuild();
    return widget.builder(context, _handle);
  }
}

/// Two-way text field bound to a [Store]<[String]> with auto-disposed controller.
///
/// - Typing fires [onChanged] (wire to an event that updates the store).
/// - Store updates (e.g. form reset) rewrite the controller when the value differs.
class StoreTextField extends StatefulWidget {
  const StoreTextField({
    super.key,
    required this.store,
    required this.onChanged,
    this.decoration,
    this.obscureText = false,
    this.keyboardType,
    this.maxLines = 1,
    this.enabled = true,
  });

  final Store<String> store;
  final void Function(String value) onChanged;
  final InputDecoration? decoration;
  final bool obscureText;
  final TextInputType? keyboardType;
  final int? maxLines;
  final bool enabled;

  @override
  State<StoreTextField> createState() => _StoreTextFieldState();
}

class _StoreTextFieldState extends State<StoreTextField> {
  late final TextEditingController _controller;
  Subscription? _sub;
  bool _writingFromStore = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.store.getState());
    _controller.addListener(_onUserEdit);
    _sub = widget.store.watch((v) {
      if (!mounted) return;
      if (_controller.text == v) return;
      _writingFromStore = true;
      _controller.value = TextEditingValue(
        text: v,
        selection: TextSelection.collapsed(offset: v.length),
      );
      _writingFromStore = false;
    });
  }

  void _onUserEdit() {
    if (_writingFromStore) return;
    widget.onChanged(_controller.text);
  }

  @override
  void dispose() {
    _sub?.unsubscribe();
    _controller.removeListener(_onUserEdit);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      decoration: widget.decoration,
      obscureText: widget.obscureText,
      keyboardType: widget.keyboardType,
      maxLines: widget.maxLines,
      enabled: widget.enabled,
    );
  }
}
