# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this project is

A Flutter desktop app for inspecting and managing UEFI boot entries (the "startup disk" picker). The Dart side is the UI; the Rust side talks to EFI variables via the `efivar` crate. Linux is the realistic target — `efivar` only works on systems with EFI variables exposed (i.e. not macOS/Windows in practice, despite the platform folders being scaffolded).

Note: `lib/main.dart` is still the default Flutter counter scaffold — the UI has not been wired to the Rust signals yet. When building UI, replace the counter rather than extending it.

## Architecture

Three-layer split, glued together by [Rinf](https://rinf.cunarist.org):

1. **`native/efixs/`** — pure Rust library wrapping `efivar`. Exposes `boot_entries()`, `set_default(id)`, `set_next(id)`. Has a standalone `main.rs` so you can run it as a CLI to sanity-check EFI access without launching Flutter.
2. **`native/hub/`** — Rinf entry crate (the name `hub` is required by Rinf, do not rename). Defines DartSignal/RustSignal types in `src/signals/mod.rs`, spawns actors in `src/actors/` from `lib.rs`. Each actor is an async task that loops on `Signal::get_dart_signal_receiver()` and replies with `.send_signal_to_dart()`.
3. **`lib/src/bindings/`** — **generated** Dart code. Don't hand-edit. Re-run `rinf gen` after changing any `#[derive(DartSignal)]` / `#[derive(RustSignal)]` / `#[derive(SignalPiece)]` struct in Rust. Signals are exported via `lib/src/bindings/bindings.dart`.

Signal flow today: Dart sends `GetBootEntries` → `actors::efi::start` loop receives it → calls `efixs::boot_entries()` → maps each `efixs::BootEntry` into the signal-layer `BootEntry` (renaming `default` → `selected`) → sends `GetBootEntriesResult { entries }` back. To add a new operation (e.g. wire up `set_default` / `set_next`), add a signal struct in `hub/src/signals/mod.rs`, handle it in an actor, and run `rinf gen`.

## Commands

```shell
# One-time setup
cargo install rinf_cli

# Regenerate Dart bindings after editing any Rinf signal struct
rinf gen

# Run the Flutter app (Linux desktop)
flutter run -d linux

# Run the Rust EFI library as a CLI (prints all boot entries; useful for verifying efivar works on this machine without Flutter)
cargo run -p efixs

# Lint / analyze
flutter analyze
cargo clippy --workspace

# Tests
flutter test                          # all Dart/widget tests
flutter test test/widget_test.dart    # single file
cargo test --workspace
```

## Rust lint policy (hub crate)

`native/hub/Cargo.toml` denies `clippy::unwrap_used`, `clippy::expect_used`, and `clippy::wildcard_imports`. When handling EFI errors in actors, use `.unwrap_or_default()` / `if let Ok(...)` patterns (see `actors/efi.rs` for the established style) rather than `unwrap()`/`expect()`.

## EFI access requires root

Writing to EFI variables (`set_default`, `set_next`) needs root privileges on Linux. Reading usually doesn't, but some variables may. If a feature works under `sudo cargo run -p efixs` but fails inside `flutter run`, that's why.
