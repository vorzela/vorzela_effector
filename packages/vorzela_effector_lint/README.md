# vorzela_effector_lint

[`custom_lint`](https://pub.dev/packages/custom_lint) rules for
[vorzela_effector](https://github.com/vorzela/vorzela_effector) best practices
(mirrors Effector’s ESLint plugin ideas for Flutter/Dart).

## Install

In your app `pubspec.yaml`:

```yaml
dev_dependencies:
  custom_lint: ^0.8.1
  vorzela_effector_lint:
    git:
      url: https://github.com/vorzela/vorzela_effector.git
      path: packages/vorzela_effector_lint
```

In `analysis_options.yaml`:

```yaml
analyzer:
  plugins:
    - custom_lint

custom_lint:
  rules:
    - prefer_dollar_store_name
    - prefer_fx_effect_name
    - avoid_get_state_in_widget
    - avoid_watch_in_widget
    - avoid_create_unit_in_widget
    - prefer_bind_in_widget
    - avoid_create_event_typed
```

Run:

```bash
dart run custom_lint
```

## Rules

| Rule | What it catches |
|------|-----------------|
| `prefer_dollar_store_name` | Stores not named `$cart` / `$user` |
| `prefer_fx_effect_name` | Effects not ending in `Fx` |
| `avoid_get_state_in_widget` | `getState()` / `.value` inside `build` |
| `avoid_watch_in_widget` | `.watch()` inside `build` (listener leak) |
| `avoid_create_unit_in_widget` | `createStore` / `createEvent` / `fork` in `build` |
| `prefer_bind_in_widget` | Bare `event()` under files that use `ScopeProvider` — prefer `bind` / `UnitAction` |
| `avoid_create_event_typed` | Deprecated `createEventTyped` |

Disable a rule:

```yaml
custom_lint:
  rules:
    - prefer_fx_effect_name: false
```

## License

MIT
