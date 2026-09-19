# vorzela_effector

Effector-style reactive state for **Dart** and **Flutter** — stores, events, effects, `sample`, `combine`, scopes, and gates.

MIT licensed. Fine-grained subscriptions, sync graph flushes (no UI `getState()` races), effect generation so stale async results never commit, and Flutter widgets that **auto-unsubscribe on dispose**.

## Install

```yaml
dependencies:
  vorzela_effector:
    git:
      url: https://github.com/vorzela/vorzela_effector.git
    # or path: ../vorzela_effector
```

```dart
import 'package:vorzela_effector/vorzela_effector.dart'; // core
import 'package:vorzela_effector/flutter.dart';         // UnitBuilder, GateScope
```

## Quick start (StatelessWidget)

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
          TextButton(onPressed: () => decremented(), child: const Text('-')),
        ],
      ),
    );
  }
}
```

`UnitBuilder` registers a watcher in `initState` and **unsubscribes in `dispose`** — same role as disposing a controller in a `StatefulWidget`.

## Effector API map

| Effector | vorzela_effector |
|----------|------------------|
| `createStore(0)` | `createStore(0)` → `Store` (`$name` convention) |
| `createEvent()` | `createEvent()` / `createEventTyped<T>()` |
| `createEffect(handler)` | `createEffect<P,D>(handler)` → `.done` `.fail` `.\$pending` `.abort()` |
| `$store.on(event, fn)` | `$store.on(event, fn)` |
| `sample({ clock, source, fn, target })` | `sample(...)` |
| `combine` / `$store.map` | `combine` / `combine2` / `$store.map` |
| `fork` / `allSettled` | `fork()` / `allSettled(...)` |
| Gate | `createGate()` + `GateScope` |

## Async effects (race-safe)

```dart
final fetchUserFx = createEffect<String, Map>((id) async {
  final res = await http.get(Uri.parse('https://api.example.com/users/$id'));
  return jsonDecode(res.body) as Map;
});

final $user = createStore<Map?>(null);
$user.on(fetchUserFx.done, (_, d) => d.result);

// Rapid calls: only the latest generation updates stores.
fetchUserFx('1');
fetchUserFx('2');
```

Call `fetchUserFx.abort()` to drop in-flight results (e.g. on route leave).

## sample (no getState races)

```dart
final $form = createStore(FormData());
final submitted = createEvent();

sample(
  clock: submitted,
  source: $form,
  fn: (form, _) => form,
  target: saveFx,
);
```

When `submitted` fires, `$form` is read **inside the same sync flush** as the clock — safer than reading stores ad hoc in button handlers for multi-step graphs.

## Gate (feature auto lifecycle)

```dart
final pageGate = createGate<String>(name: 'profile');

sample(clock: pageGate.open, target: loadProfileFx);

// In UI:
GateScope<String>(
  gate: pageGate,
  props: userId,
  child: ProfileView(),
);
```

Opens on mount, closes on dispose.

## Scope dispose

```dart
final scope = fork();
scope.own($local);
scope.own(localEvent);
// …
scope.dispose(); // disposes owned units, cancels effect generations owned via abort patterns
```

## Performance

- Per-store subscriber lists (widgets rebuild only for watched stores)
- Nested updates batch into one notification flush
- Derived stores (`map` / `combine`) are read-only
- Effects never block the UI isolate; commits go through the graph queue

## Never do this in UI

```dart
// Bad — racey / bypasses the graph
onPressed: () => save(formStore.getState());
```

Prefer `sample` or pass payloads through events.

## License

MIT — see [LICENSE](LICENSE).
