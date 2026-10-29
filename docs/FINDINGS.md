# Findings

Decisions, gotchas and anything learned that is not obvious from the code.

## Bundle ID is two-segment
`com.foodmenu` has no third segment, so `flutter create --org` could not
produce it (it always appends the project name). The IDs were set by hand in
`android/app/build.gradle.kts` and `ios/Runner.xcodeproj/project.pbxproj`.
Any future `flutter create` re-run over this project will reintroduce
`com.example` — re-check both files if that happens.

## Hook activation is per-clone
`core.hooksPath` lives in `.git/config`, which is not versioned. A fresh clone
has **no** attribution guard until `tool/setup_hooks.sh` is run. Worth a CI
check later if commits start arriving from other machines.

## The guard allows human co-authors
`.githooks/commit-msg` only blocks trailers naming AI tools
(claude/anthropic/copilot/gpt/openai/gemini/cursor/codex), bot addresses and
the 🤖 emoji. A normal `Co-authored-by: Name <email>` still passes, which is
intentional. Commented (`#`) lines are ignored.
