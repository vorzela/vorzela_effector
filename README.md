# vorzela_effector

Effector-style reactive state for **Dart** and **Flutter**.

**License:** MIT · **Repo:** https://github.com/vorzela/vorzela_effector

---

## Mental model (learn this, ignore the rest)

Most product code needs **six verbs**:

| Verb | Role |
|------|------|
| `createStore` | State |
| `createEvent` / `createEvent<T>` | Intent |
| `createEffect` | Async work |
| `.on` / `.map` / `sample` | Wire them |
| `UnitBuilder` | Rebuild UI |
| `ScopeProvider` | Only when you need isolation (see below) |

```text
Layer 1 — App state     createStore / createEvent / createEffect / on / map / sample / UnitBuilder
Layer 2 — Isolated UI   ScopeProvider (+ bind / UnitAction)   ← Flutter-only, optional
Layer 3 — SSR / tests   fork / allSettled / serialize         ← rare
```

Start on **layer 1**. Your counter, cart, and feed do not need `fork`.

---

## Install

```yaml
dependencies:
  vorzela_effector:
    git:
      url: https://github.com/vorzela/vorzela_effector.git
```

```dart
import 'package:vorzela_effector/vorzela_effector.dart'; // core
import 'package:vorzela_effector/flutter.dart';         // UnitBuilder, ScopeProvider, …
```

---

## Quick start (layer 1)

```dart
final $count = createStore(0);
final incremented = createEvent();
final decremented = createEvent();

$count
  ..on(incremented, (s, _) => s + 1)
  ..on(decremented, (s, _) => s - 1);

UnitBuilder<int>(
  unit: $count,
  builder: (context, count) => TextButton(
    onPressed: () => incremented(), // global graph — fine for a single tree
    child: Text('$count'),
  ),
);
```

Each `UnitBuilder` only `setState`s for **its** store. Sibling builders
watching other stores do not rebuild. For nested UI, use
`UnitBuilder.withChild` so nested builders are the `child:` slot (not
recreated inside the parent builder):

```dart
UnitBuilder.withChild(
  unit: $header,
  builder: (context, h, child) => Column(children: [Text('$h'), child!]),
  child: UnitBuilder(unit: $body, builder: (_, b) => Text('$b')),
);
```

Typed events: `createEvent<String>()`. Async: `createEffect<P, D>(...)`.

---

## When do you need `ScopeProvider`?

Effector (JS) assumes React’s `Provider` for SSR and multi-instance apps.
Flutter has **no built-in equivalent** — without `ScopeProvider`, every
`UnitBuilder` reads the **global** store. That is correct for a single-user
SPA. You add a Provider when you need a **separate live copy** of state.

| Situation | Need `ScopeProvider`? |
|-----------|------------------------|
| One app, one cart, one user | **No** — layer 1 only |
| Widget / unit tests that must not touch global stores | **Yes** (or `fork` + `allSettled`) |
| Two UIs at once with different state (catalog + checkout sheet) | **Yes** — sibling Providers |
| SSR / pass state across a network boundary | **Yes** + `name`/`sid` + `serialize` |
| Mock an API for one screen | **Yes** + `fork(handlers: …)` |

```dart
// Auto-forks — you usually don't call fork() yourself:
runApp(ScopeProvider(
  child: MaterialApp(
    home: Builder(
      builder: (context) => UnitBuilder<int>(
        unit: $count,
        builder: (context, n) => UnitAction(
          unit: incremented, // fires inside this Provider's scope
          child: Text('$n'),
        ),
      ),
    ),
  ),
));
```

Under a Provider, prefer `bind(context, event)` or `UnitAction` — bare
`event()` still writes the **global** store (same rule as Effector).

---

## Controllers & dispose

| Need | Use |
|------|-----|
| Text field ↔ store | `StoreTextField` |
| Custom form, Stateless | `AutoDispose` + `life.bindText` |
| `vsync` animations / tabs | `AutoDisposeMixin` |
| Store → UI only | `UnitBuilder` |

```dart
final $email = createStore('');
final setEmail = createEvent<String>();
$email.on(setEmail, (_, v) => v);

StoreTextField(store: $email, event: setEmail);
```

---

## Core API (day-to-day)

| API | Description |
|-----|-------------|
| `createStore(initial, {name, sid, updateFilter})` | Writable atom (`sid` defaults to `name`) |
| `createEvent()` / `createEvent<T>()` | Void or typed event |
| `createEffect<P,D>(handler)` | Async effect |
| `sample({clock, source, filter, fn, target})` | Connect units |
| `combine` / `$store.map` | Derived state |
| `UnitBuilder` / `MultiUnitBuilder` | Rebuild on change |
| `ScopeProvider` / `bind` / `UnitAction` | Isolated UI (layer 2) |

### Advanced (layer 3 — SSR / tests)

| API | Description |
|-----|-------------|
| `fork({values, handlers})` | Isolated scope (`values`: list of `(store, v)` **or** sid `Map`) |
| `allSettled(unit, {scope, params})` | Run event/effect in a scope |
| `scope.serialize()` | SSR payload by sid/name |
| `createGate` + `GateScope` | Mount lifecycle |

Aliases kept for compatibility: `combine2`/`combine3`, `hydrate`, `scopeBind`,
`createEventTyped`, `bindOf` — prefer the table above.

---

## Effects

```dart
final fetchUserFx = createEffect<String, Map>((id) async { /* … */ });
final $user = createStore<Map?>(null);
$user.on(fetchUserFx.done, (_, d) => d.result);

fetchUserFx('1');
fetchUserFx.abort(); // ignore in-flight on leave
```

---

## `sample` (avoid UI `getState` races)

```dart
sample(
  clock: submitted,
  source: $form,
  fn: (form, _) => form,
  target: saveFx,
);
```

---

## SSR sketch

```dart
final $cartCount = createStore(0, name: 'cart.count'); // name → sid

final server = fork();
await allSettled(loadCartFx, scope: server);
final payload = server.serialize();

final client = fork(values: payload);
runApp(ScopeProvider(scope: client, child: App()));
```

---

## Performance notes

- Skip-notify when `==` / `identical` (or custom `updateFilter`)
- Kernel batches nested writes; `combine` recomputes once per batch
- `JsonModel`-style huge catalogs: keep **lists in one store**, derive with
  `.map`, use `UnitBuilder` on the derived slice — don’t create a store per row
- Scoped writes don’t notify the global tree (isolation by design)

---

## Never do this in UI

```dart
onPressed: () => save($form.getState()); // racey — use sample
store.watch((_) => setState(() {}));     // in build → stacks listeners
```

---

## Linter (best practices)

Use [`vorzela_effector_lint`](packages/vorzela_effector_lint) with
`custom_lint` ^0.8.1 to catch Effector-style footguns in the IDE:

- `$` store / `Fx` effect naming
- no `getState` / `.watch` / `createStore` inside `build`
- prefer `bind` / `UnitAction` when the file uses `ScopeProvider`
- no deprecated `createEventTyped`

See [packages/vorzela_effector_lint/README.md](packages/vorzela_effector_lint/README.md).

## Tests

```bash
flutter test
```

---

## License

MIT — see [LICENSE](LICENSE).
