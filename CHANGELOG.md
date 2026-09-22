# Changelog

## 0.1.4

### Changed
- **`UnitBuilder` / `MultiUnitBuilder`** — documented rebuild locality (each
  builder only `setState`s for its own unit). Added `UnitBuilder.withChild` /
  `MultiUnitBuilder.withChild` so nested / static subtrees stay in the
  `child:` slot and are not rebuilt when the parent store updates.

## 0.1.3

### Fixed
- **Scoped derived stores** — `Store._set` no longer calls
  `recomputeDependents` synchronously on every write. Scoped updates now
  queue through Kernel `_dirtyStores` (same dedup as global `combine`), so a
  multi-source combine inside a fork recomputes **once per batch**, nested
  maps settle in one flush, and diamond graphs do not double-fire.

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
