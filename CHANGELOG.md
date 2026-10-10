# Change Log

All notable changes to this project will be documented in this file.
This project adheres to the [Semantic Version](https://semver.org/) guideline.

## [Version] - yyyy-mm-dd

Here we write upgrading notes and make them as straightforward as possible.

### Added
- A short description for added item 1
- A short description for added item 2
- A short description for added item n

### Changed
- A short description for changed item 1
- A short description for changed item 2
- A short description for changed item n

### Fixed
- A short description for fixed item 1
- A short description for fixed item 2
- A short description for fixed item n


## [v1.3.0] - 2026-10-10

Bug fixes, performance improvements and a bulk insert API with Internal code refactoring, better documentation, and Zig-0.17.0 version support.

### Added
- `Redox.Sync.setMany()` — pipelined bulk insert of multiple records in a single network round-trip.

### Changed
- `scan()` now scales its per-batch `COUNT` hint with the requested count (up to 1024), reducing network round-trips for large scans.
- `scan()` pre-allocates the result list and copies keys binary-safely (embedded NUL bytes are no longer truncated).
- Reduced code duplication in `set()`/`setWith()` command construction and reply validation.
- Optimized `Sync` struct memory layout and host copy.

### Fixed
- `scan()` always terminated after the first `SCAN` batch, silently returning incomplete results; the new cursor is now followed until completion.
- Potential use-after-free in `scan()` — the cursor is now copied out of the reply before it is freed.
- Reply memory leaks on error replies in `set()`, `setWith()`, `get()` and `remove()`.
- Null pointer dereference in `errMsg()` when the HiRedis context allocation failed, and a leaked context on failed `connect()`.

## [v1.2.0] - 2026-03-29

Miscellaneous Improvements.

### Added
- Clearer error message propagation.
- Reconnect and retry once for command execution.

## [v1.1.0] - 2025-09-13

Minor code changes required for Zig v0.15.1 breaking changes.

## [v1.0.0] - 2025-07-29

Initial bare minimum implementation (Sync Interface only).
