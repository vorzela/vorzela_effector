# vorzela_effector

Effector-style reactive state for **Dart** and **Flutter**.

Stores, events, effects, `sample`, `combine`, scopes, and gates — with fine-grained rebuilds, sync graph flushes (no UI `getState()` races), race-safe effects, and Flutter helpers that **auto-dispose** subscriptions and `TextEditingController`s.

**License:** MIT  
**Repo:** https://github.com/vorzela/vorzela_effector

---

## Install

```yaml
dependencies:
  vorzela_effector:
    git:
      url: https://github.com/vorzela/vorzela_effector.git
```

```dart
import 'package:vorzela_effector/vorzela_effector.dart'; // core (Dart)
import 'package:vorzela_effector/flutter.dart';         // UnitBuilder, AutoDispose, …
```

---

## Quick start

```dart
final $count = createStore(0);
final incremented = createEvent();
final decremented = createEvent();

$count
  ..on(incremented, (s, _) => s + 1)
  ..on(decremented, (s, _) => s - 1);

class CounterPage extends StatelessWidget {
  const CounterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return UnitBuilder<int>(
      unit: $count,
      builder: (context, count) => Column(
        children: [
          Text('$count'),
          TextButton(onPressed: () => incremented(), child: const Text('+')),
        ],
      ),
    );
  }
}
```

---

## Text fields — auto-disposed controllers

### `AutoDispose` (own any `TextEditingController`)

```dart
final nameChanged = createEventTyped<String>();
final $name = createStore('');
$name.on(nameChanged, (_, v) => v);

class NameForm extends StatelessWidget {
  const NameForm({super.key});

  @override
  Widget build(BuildContext context) {
    return AutoDispose(
      builder: (context, d) {
        // Disposed automatically when NameForm leaves the tree —
        // no State.dispose() boilerplate.
        final name = d.textEditingController();
        final focus = d.focusNode();

        return TextField(
          controller: name,
          focusNode: focus,
          onChanged: (v) => nameChanged(v),
          decoration: const InputDecoration(labelText: 'Name'),
        );
      },
    );
  }
}
```

`AutoDisposeHandle` also provides:

- `textEditingController({text})`
- `focusNode({debugLabel})`
- `scrollController({initialScrollOffset})`
- `manage(value, dispose)` / `own(Disposable)`
- `watchStore(store, onChange)`

### `StoreTextField` (two-way bind to `Store<String>`)

```dart
final $email = createStore('');
final setEmail = createEventTyped<String>();
$email.on(setEmail, (_, v) => v);

StoreTextField(
  store: $email,
  onChanged: setEmail.call,
  decoration: const InputDecoration(labelText: 'Email'),
  keyboardType: TextInputType.emailAddress,
);
```

Typing updates the store via `onChanged`. Resetting the store (e.g. `setEmail('')`) rewrites the field. The internal `TextEditingController` is disposed with the widget.

---

## Effector API map

| Effector | vorzela_effector |
|----------|------------------|
| `createStore(0)` | `createStore(0)` |
| `createEvent()` | `createEvent()` / `createEventTyped<T>()` |
| `createEffect(fn)` | `createEffect<P,D>(fn)` |
| `$store.on(event, fn)` | `$store.on(event, fn)` |
| `sample({…})` | `sample({…})` |
| `combine` / `.map` | `combine` / `combine2` / `combine3` / `$store.map` |
| `fork` / `allSettled` | `fork()` / `allSettled(…)` |
| Gate | `createGate()` + `GateScope` |

---

## Full API reference

### Factories (core)

| API | Returns | Description |
|-----|---------|-------------|
| `createStore<T>(initial, {name, updateFilter})` | `Store<T>` | Writable atom |
| `createEvent({name})` | `Event<void>` | Void event |
| `createEventTyped<T>({name})` | `Event<T>` | Typed event |
| `createEffect<P,D>(handler, {name})` | `Effect<P,D>` | Async effect |
| `createGate<T>({name})` | `Gate<T>` | Mount lifecycle gate |
| `sample({clock, source, filter, fn, target, name})` | `Object` | Connect units; returns `target` or new `Event` |
| `combine(stores, fn, {name})` | `Store<R>` | Derived from list of stores |
| `combine2(a, b, fn, {name})` | `Store<R>` | Two-store combine |
| `combine3(a, b, c, fn, {name})` | `Store<R>` | Three-store combine |
| `fork()` | `Scope` | Isolated scope |
| `allSettled(unit, {scope, params})` | `Future<void>` | Run event/effect and flush |
| `scopeBind(unit, {scope})` | `Function` | Bind call to a scope |
| `isStore` / `isEvent` / `isEffect` | `bool` | Type guards |
| `Kernel.instance.batch(fn)` | — | Coalesce nested updates |

### `Store<T>`

| Member | Description |
|--------|-------------|
| `getState()` / `value` | Current value (avoid in UI graphs; prefer `sample` / `UnitBuilder`) |
| `on<P>(Event<P>, reducer)` | Update from event |
| `reset(Event<void>, [to])` | Reset on clock |
| `map<R>(fn, {name, updateFilter})` | Derived store |
| `watch(listener)` → `Subscription` | Subscribe |
| `write(value)` | Internal / sample target write |
| `attachLinks(subs)` | Keep child subscriptions alive |
| `dispose()` | Clear listeners + links |
| `isDerived` / `isDisposed` / `subscriberCount` / `name` | Introspection |

### `Event<T>`

| Member | Description |
|--------|-------------|
| `call([payload])` | Fire event |
| `to(handler)` → `Subscription` | Side-effect handler |
| `watch(listener)` → `Subscription` | Observe fires |
| `dispose()` | Tear down |

### `Effect<P, D>`

| Member | Description |
|--------|-------------|
| `call(params)` → `Future<D>` | Run handler (generation-tracked) |
| `abort()` | Bump generation; ignore in-flight results |
| `done` | `Event<EffectDone<P,D>>` (`params`, `result`) |
| `fail` | `Event<EffectFail<P>>` (`params`, `error`) |
| `finally_` | `Event<P>` after done/fail |
| `$pending` | `Store<bool>` |
| `dispose()` | Abort + dispose child units |

### `Gate<T>`

| Member | Description |
|--------|-------------|
| `open` | `Event<T>` — fire with props |
| `close` | `Event<void>` |
| `$status` | `Store<bool>` open/closed |
| `$state` | `Store<T?>` last props |
| `isOpen` | Convenience |
| `dispose()` | Dispose child units |

### `Scope`

| Member | Description |
|--------|-------------|
| `own(unit)` | Dispose unit with scope |
| `getState` / `setState` | Scoped store access |
| `dispose()` | Dispose owned units |
| `isDisposed` | |

### `Subscription`

| Member | Description |
|--------|-------------|
| `unsubscribe()` / `dispose()` | Detach listener |
| `isActive` | |

### Flutter (`package:vorzela_effector/flutter.dart`)

| API | Description |
|-----|-------------|
| `UnitBuilder<T>(unit, builder)` | Rebuild on store change; unsub on dispose |
| `MultiUnitBuilder(units, builder)` | Rebuild when any store changes |
| `GateScope<T>(gate, props, child)` | `open` on mount, `close` on dispose |
| `AutoDispose(builder)` | Builder with `AutoDisposeHandle` |
| `AutoDisposeHandle.textEditingController` | Auto-disposed `TextEditingController` |
| `AutoDisposeHandle.focusNode` | Auto-disposed `FocusNode` |
| `AutoDisposeHandle.scrollController` | Auto-disposed `ScrollController` |
| `AutoDisposeHandle.manage` / `own` | Register custom disposables |
| `AutoDisposeHandle.watchStore` | Subscription cleared on dispose |
| `StoreTextField` | Two-way `Store<String>` ↔ field |
| `UnitHook` | Manual sub list for custom `State` |
| `Disposable` / `DisposableRef` | Dispose protocol |

---

## Async effects (race-safe)

```dart
final fetchUserFx = createEffect<String, Map>((id) async { /* … */ });
final $user = createStore<Map?>(null);
$user.on(fetchUserFx.done, (_, d) => d.result);

fetchUserFx('1');
fetchUserFx('2'); // only this generation may commit
fetchUserFx.abort(); // on route leave
```

---

## `sample` (no getState races)

```dart
sample(
  clock: submitted,
  source: $form,
  fn: (form, _) => form,
  target: saveFx,
);
```

---

## Performance

- Per-store subscriber lists
- Nested updates batch into one flush
- Derived stores are read-only
- Effects never block the UI isolate

## Never do this in UI

```dart
onPressed: () => save($form.getState()); // racey
```

Prefer `sample` or event payloads.

---

## Tests

```bash
flutter test
```

---

## License

MIT — see [LICENSE](LICENSE).
