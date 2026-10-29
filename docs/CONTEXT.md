# Context

Architecture and conventions. Kept current as the app grows.

## Current state
Stock `flutter create` scaffold — [lib/main.dart](../lib/main.dart) still holds
the counter demo. No app architecture, state management, routing, theming or
dependencies chosen yet; those follow from the design and feature set.

## Layout
```
lib/            Dart source (only main.dart so far)
test/           widget tests
android/ ios/   platform projects — mobile only, no web/desktop
docs/           plan, progress, findings, this file
.githooks/      versioned git hooks (commit-msg attribution guard)
tool/           dev scripts (setup_hooks.sh)
```

## Conventions
- Analyzer: `package:flutter_lints` via `analysis_options.yaml`.
  `flutter analyze` must be clean before any commit.
- Branches: `feat/…`, `fix/…`, `chore/…`. Never commit to `main`; it only
  advances through merged PRs.
- Commit messages: imperative subject, no AI attribution (enforced by hook).
