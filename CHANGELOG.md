# Changelog

## 0.1.0

### Added — full Scope isolation (ecommerce / SSR)
- **Zone-backed scopes** — overlapping `allSettled` on different scopes on one
  isolate no longer clobber each other.
- **Scope-local watchers** — `scope.watchStore` / scoped `Store.watch`; drives
  `UnitBuilder` under `ScopeProvider` without leaking into global UI.
- **Derived recompute in forks** — `.map` / `combine` track sources and
  recompute inside the active scope.
- **`fork(handlers:)`** — per-scope effect mocks.
- **`sid` + `serialize` / `hydrate` / `fork(valuesMap:)`** — SSR handoff.
- **`ScopeProvider` + `bindOf`** — Provider-style Flutter trees.
- Per-scope effect generation lanes so the same effect can run in parallel forks.

### Docs
- README: when to use / not use scopes, Provider + SSR recipes, API updates.

## 0.0.7

### Fixed (Scope / fork audit)
- `allSettled` / `scopeBind` honor `scope` for leaf store updates.
- `Store.on` reducers use `getState()` under a scope.

## 0.0.6

### Fixed
- `Store.reset()` restores constructor `defaultState` when `to` is omitted.

## 0.0.5

### Fixed
- `Event.to()` lazy compaction (match `watch()`).

## 0.0.4

### Fixed
- Derived `write()` guard, `Event.to()` identity, sample list links, `readSource` null.

## 0.0.3 and earlier

See git history.
