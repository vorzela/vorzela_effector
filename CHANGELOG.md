# Changelog

## 0.1.2

### Added
- **`packages/vorzela_effector_lint`** — `custom_lint` rules for best practices
  (naming, no getState/watch/create in build, prefer bind under ScopeProvider).

## 0.1.1

### Simplified mental model
- **One `createEvent<T>()`** — `createEventTyped` deprecated.
- **One `fork(values:)`** — accepts `List<(Store,v)>` or sid `Map` (`valuesMap` deprecated).
- **`Scope.serialize()`** — prefer over top-level helper.
- **`sid` defaults to `name`** — one knob for SSR stores.
- **`ScopeProvider` auto-forks** when `scope:` is omitted.
- **`bind` + `UnitAction`** — `bindOf` deprecated.
- README rewritten as **3 layers** (app → Provider → SSR/tests) with clear
  guidance on when Flutter needs `ScopeProvider` (Effector’s Provider is not
  automatic in Flutter).

### Tests
- Large-state / concurrent-fork performance smoke tests.

## 0.1.0

Zone-isolated Scopes, derived recompute, serialize/hydrate, ScopeProvider.

## 0.0.7 and earlier

See git history.
