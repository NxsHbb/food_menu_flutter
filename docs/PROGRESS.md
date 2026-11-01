# Progress

Newest first. One entry per completed task.

## Task 1.1 — Flutter foundations: architecture, routing, folder layout
Branch `feat/app-foundations`

- **Riverpod** (`flutter_riverpod` 3.3.2) for state and DI, no code generation.
  Chosen because provider overrides are the cheapest way to inject fakes in
  widget tests, and because it covers DI and state in one tool.
- **`go_router`** 17.5.0 with `StatefulShellRoute.indexedStack`, so each
  top-level tab keeps its own stack and scroll position. The router is a
  provider, not a global, so Phase 3 can add an auth redirect without
  restructuring.
- **`dio`** 5.11.1, picked for its interceptor model — task 1.2 needs to
  capture and replay the Store API's `Nonce` and `Cart-Token` headers.
- Feature-first layout under `lib/src/{core,features}`; four placeholder
  screens (Menu, Cart, Orders, Account) so routing is wired and testable
  before their phases land.
- `AppConfig` reads the backend from `--dart-define=FOOD_MENU_BASE_URL`, with
  derived `wc/store/v1` and `fmp/v1` bases. Never defaults to `localhost`,
  which no emulator or device can reach.
- Interim Material 3 theme with a single seed colour, deliberately *not* brand
  values — task 1.3 replaces it from the supplied design.
- Replaced the stock counter `main.dart` and its widget test. 6 tests pass,
  `flutter analyze` clean.
- Navigation destinations are provisional pending the design.

## Task 0.2 — Display name, attribution guard, process docs
Branch `chore/project-setup`

- App display name set to **Food Menu** on both platforms
  (`android:label`, `CFBundleDisplayName`, `CFBundleName`).
- Added `.githooks/commit-msg`: rejects AI/assistant attribution in commit
  messages. Activated with `tool/setup_hooks.sh` (sets `core.hooksPath`).
- Stripped the attribution trailer that was in the initial commit (amended).
- Added `CLAUDE.md` with project facts and the standing working rules.
- Added this docs set: `PLAN.md`, `PROGRESS.md`, `FINDINGS.md`, `CONTEXT.md`.

## Task 0.1 — Flutter scaffold
Branch `main` (initial commit)

- `flutter create` with project name `food_menu`, platforms Android + iOS.
- Bundle ID / applicationId set to `com.foodmenu` on both platforms;
  Kotlin package moved to `com.foodmenu`.
- Folder renamed `food-menu` → `food_menu` to match the package name.
- Git initialised on `main`, remote `NxsHbb/food_menu_flutter`.
