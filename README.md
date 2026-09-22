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

## Scopes — when you need isolation

For Alibaba / YouTube-class apps you often need **more than one live state
tree**: a checkout sheet next to a catalog, SSR per request, or tests that
must not touch global stores.

1. Give durable stores a stable `sid` if you serialize them.
2. `final scope = fork(…)` per request / screen / test.
3. Wrap UI in `ScopeProvider(scope: scope, child: …)`.
4. Trigger updates with `bindOf(context, event)` or `allSettled(…, scope:)`.
5. Never call `event()` bare under a Provider if you meant the fork.

See **Scope (ecommerce / SSR)** in the API reference below.

---

## Controllers & dispose (why this exists)

Flutter objects like `TextEditingController`, `FocusNode`, `ScrollController`,
`PageController`, `AnimationController`, and `TabController` **must** be
`dispose()`d or they leak memory and keep listeners alive (jank over time).

Normally that means a `StatefulWidget` + fields + `dispose()`.  
**vorzela_effector** gives you a `Life` bag that creates each resource **once**
and disposes it when the widget leaves the tree — Stateless or Stateful.

### Which API should I use?

| What you need | Use this |
|---------------|----------|
| One text field ↔ `Store<String>` | **`StoreTextField`** (zero layout boilerplate) |
| Custom form layout, StatelessWidget | **`AutoDispose`** + `life.bindText` / controllers |
| Animations / `TabController` (`vsync`) | **`StatefulWidget` + `AutoDisposeMixin`** |
| Rebuild UI from a store only | **`UnitBuilder`** (no controllers) |

---

### 1) Easiest — `StoreTextField`

Wire the store + event once; the widget owns the controller.

```dart
final $email = createStore('');
final setEmail = createEventTyped<String>();
$email.on(setEmail, (_, v) => v);

// Pass the event directly (no .call needed):
StoreTextField(
  store: $email,
  event: setEmail,
  decoration: const InputDecoration(labelText: 'Email'),
);
```

Typing updates `$email`. `setEmail('')` clears the field. Controller is disposed automatically.

---

### 2) Stateless form — `AutoDispose` + `Life`

`Life` is the bag of resources. Factories are **stable across rebuilds**
(same call order → same instance). No junk controllers on every frame.

```dart
final $name = createStore('');
final setName = createEventTyped<String>();
$name.on(setName, (_, v) => v);

class NameForm extends StatelessWidget {
  const NameForm({super.key});

  @override
  Widget build(BuildContext context) {
    return AutoDispose(
      builder: (context, life) {
        // Two-way bind in one line (controller + store sync + dispose).
        final name = life.bindText($name, setName.call);
        final focus = life.focusNode();

        return TextField(
          controller: name,
          focusNode: focus,
          decoration: const InputDecoration(labelText: 'Name'),
        );
      },
    );
  }
}
```

**`Life` factories (all auto-disposed):**

| Method | Creates |
|--------|---------|
| `bindText(store, onChanged)` | `TextEditingController` synced to store |
| `textEditingController({text})` | plain `TextEditingController` |
| `focusNode({debugLabel})` | `FocusNode` |
| `scrollController(…)` | `ScrollController` |
| `pageController(…)` | `PageController` |
| `animationController(vsync: …)` | `AnimationController` (needs mixin/`vsync`) |
| `tabController(vsync:, length:)` | `TabController` |
| `valueNotifier(initial)` | `ValueNotifier` |
| `use(create, dispose)` | any custom resource (once) |
| `watch(store, onChange)` | one subscription (safe in `build`) |

---

### 3) Stateful + animations — `AutoDisposeMixin`

Keep `StatefulWidget` when you need `vsync` (or other State APIs).  
Mixin still kills controllers / store watches for you.

```dart
class FadeCounter extends StatefulWidget {
  const FadeCounter({super.key});
  @override
  State<FadeCounter> createState() => _FadeCounterState();
}

class _FadeCounterState extends State<FadeCounter>
    with SingleTickerProviderStateMixin, AutoDisposeMixin {
  @override
  Widget build(BuildContext context) {
    // buildWithLife resets call-order every frame (no stacked listeners).
    return buildWithLife((life) {
      final anim = life.animationController(
        vsync: this,
        duration: const Duration(milliseconds: 300),
      );
      final count = life.watch($count, (_) => setState(() {}));

      return FadeTransition(
        opacity: anim.drive(Tween(begin: 0.5, end: 1.0)),
        child: Text('$count'),
      );
    });
  }
}
```

You can still mix: `UnitBuilder` for store UI + normal `State` for animation only.

---

### Performance rules (avoid junk)

1. **Controllers are created once** — `Life` memoizes by call order; rebuilds reuse them.
2. **`life.watch` / `bindText` subscribe once** — safe in `build`; will not stack listeners.
3. **Keep `UnitBuilder` / `AutoDispose` small** — rebuild only the subtree that needs the value, not the whole page.
4. **Prefer one store per `UnitBuilder`** over a giant `MultiUnitBuilder` when fields update independently.
5. **Dispose on route leave** — `AutoDispose` / mixin do this; never keep a `Life` in a global singleton.
6. **Animations stay on StatefulWidget** — `vsync` requires a `TickerProvider`; that is intentional and cheap.

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
| `createStore<T>(initial, {name, sid, updateFilter})` | `Store<T>` | Writable atom (`sid` for SSR) |
| `createEvent({name})` | `Event<void>` | Void event |
| `createEventTyped<T>({name})` | `Event<T>` | Typed event |
| `createEffect<P,D>(handler, {name})` | `Effect<P,D>` | Async effect |
| `createGate<T>({name})` | `Gate<T>` | Mount lifecycle gate |
| `sample({clock, source, filter, fn, target, name})` | `Object` | Connect units; returns `target` or new `Event` |
| `combine(stores, fn, {name, sid})` | `Store<R>` | Derived from list of stores |
| `combine2` / `combine3` | `Store<R>` | Typed combines (`sid` optional) |
| `fork({values, valuesMap, handlers})` | `Scope` | Isolated scope (seeds + effect mocks) |
| `allSettled(unit, {scope, params})` | `Future<void>` | Run event/effect in optional scope |
| `scopeBind(unit, {scope})` | `Function` | Bind call to a Zone scope |
| `serialize(scope, {onlyChanges})` | `Map` | SSR payload by `sid` |
| `hydrate(scope, values)` | — | Apply sid→value map into scope |
| `isStore` / `isEvent` / `isEffect` | `bool` | Type guards |
| `Kernel.instance.batch(fn)` | — | Coalesce nested updates |

### `Store<T>`

| Member | Description |
|--------|-------------|
| `getState()` / `value` | Current value (avoid in UI graphs; prefer `sample` / `UnitBuilder`) |
| `on<P>(Event<P>, reducer)` | Update from event |
| `reset(Event<void>, [to])` | Reset to `defaultState` (or `to`) on clock |
| `map<R>(fn, {name, sid, updateFilter})` | Derived store (scoped recompute) |
| `defaultState` / `globalState` / `sid` | Initial / unscoped / SSR id |
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

### `Scope` (ecommerce / SSR)

Zone-isolated fork of store values — safe for parallel catalog/cart work,
Provider UI trees, and SSR handoff.

| Member | Description |
|--------|-------------|
| `fork({values, valuesMap, handlers})` | Create scope; seed stores / mock effects |
| `getState` / `setState` | Scoped access (never mutates global) |
| `watchStore(store, fn)` | Scope-local subscription (drives `UnitBuilder`) |
| `own(unit)` / `dispose()` | Lifecycle bag |
| `serialize` / `hydrate` | SSR transfer by `Store.sid` |

**When to use a scope**

| Use case | Pattern |
|----------|---------|
| Unit / widget tests | `fork()` + `allSettled(…, scope:)` |
| Parallel page fetches | Concurrent `allSettled` on different scopes (Zone-safe) |
| Checkout vs catalog UI | Sibling `ScopeProvider`s |
| SSR / state transfer | `sid` on stores → `serialize` → `hydrate` / `fork(valuesMap:)` |
| Mock API in one tree | `fork(handlers: [(fetchFx, mock)])` |

**When not to use a scope**

- Simple single-user SPA with one global graph — plain `createStore` is enough.
- Firing `event()` from a button **without** `bindOf` / `scopeBind` under a
  `ScopeProvider` — that writes the **global** store (same rule as Effector).

#### Provider UI

```dart
final scope = fork(values: [($session, session)]);

runApp(ScopeProvider(
  scope: scope,
  child: MaterialApp(
    home: Builder(
      builder: (context) => UnitBuilder<Cart>(
        unit: $cart,
        builder: (context, cart) => TextButton(
          onPressed: bindOf(context, checkout), // must bind!
          child: Text('Pay ${cart.total}'),
        ),
      ),
    ),
  ),
));
```

#### SSR sketch

```dart
final $cartCount = createStore(0, sid: 'cart.count');

// server
final server = fork();
await allSettled(loadCartFx, scope: server);
final payload = serialize(server); // {'cart.count': 3}

// client
final client = fork(valuesMap: payload);
// or: hydrate(client, payload);
runApp(ScopeProvider(scope: client, child: App()));
```

Derived `.map` / `combine` recompute inside the fork when sources change.
Overlapping `allSettled` on different scopes on one isolate is safe (Zone).

### `Subscription`

| Member | Description |
|--------|-------------|
| `unsubscribe()` / `dispose()` | Detach listener |
| `isActive` | |

### Flutter (`package:vorzela_effector/flutter.dart`)

| API | Description |
|-----|-------------|
| `ScopeProvider(scope, child)` | Inherited scope for the subtree |
| `bindOf(context, unit)` | `scopeBind` to nearest `ScopeProvider` |
| `UnitBuilder<T>(unit, builder)` | Rebuild on store change (scoped if Provider) |
| `MultiUnitBuilder(units, builder)` | Rebuild when any store changes |
| `GateScope<T>(gate, props, child)` | `open` on mount, `close` on dispose |
| `Life` | Resource bag (controllers + watches); alias `AutoDisposeHandle` |
| `AutoDispose(builder)` | Stateless wrapper that owns a `Life` |
| `AutoDisposeMixin` | Stateful mixin; use `buildWithLife` |
| `Life.bindText` / controllers / `watch` / `use` | See “Controllers & dispose” above |
| `StoreTextField` | Ready-made field; `event:` or `onChanged:` |
| `UnitHook` | Manual subs — `initState` only |
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

## Performance (core graph)

- Per-store subscriber lists
- Nested updates batch into one flush
- Derived stores are read-only
- Effects never block the UI isolate

## Never do this in UI

```dart
onPressed: () => save($form.getState()); // racey
```

Prefer `sample` or event payloads.

```dart
// Never subscribe in build without Life memoization:
store.watch((_) => setState(() {})); // stacks a listener every frame → jank
```

---

## Tests

```bash
flutter test
```

---

## License

MIT — see [LICENSE](LICENSE).
