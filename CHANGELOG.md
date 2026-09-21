# Changelog

## 0.0.4

### Fixed
- **`Store.write()`** — derived stores (`.map` / `combine`) now throw
  `StateError` instead of silently accepting writes. Matches the README
  “read-only” contract and blocks `sample(target: $derived)`.
- **`Event.to()`** — unsubscribe is identity-safe via slots (same pattern as
  `watch()`). Duplicate handler registrations no longer detach the wrong
  subscription; disposed events clear `.to()` handler closures.
- **`sample(target: [a, b])`** — each target gets a reference-counted link.
  Disposing one target no longer tears down clock delivery to the others.
- **`readSource`** — list/map sources may contain literal `null` without a
  cast `TypeError`.

## 0.0.3 and earlier

See git history.
