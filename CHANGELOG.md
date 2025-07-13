# Changelog

All notable changes to this project will be documented in this file.

## [0.1.0] – 2025-07-11

Initial release of **Loe**, a tiny Elixir library for chaining and transforming raw, `{:ok, _}`, and `{:error, _}` values.

### Added

- `lift/2` — Applies a function to raw or success values.
- `tfil/2` — Applies a function to error values only.
- `unwrap!/1` — Extracts the `{:ok, value}` or raises on error.
- `~>>` — Infix macro for chaining with `lift/2`.
- `<~>` — Infix macro for chaining with `tfil/2`.
