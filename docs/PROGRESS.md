# Progress

Newest first. One entry per completed task.

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
