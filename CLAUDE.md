# Food Menu — Flutter

## Project facts

| Field | Value |
|---|---|
| Package / project name | `food_menu` |
| Display name | Food Menu |
| Slug | `foodmenu` |
| Bundle ID / applicationId | `com.foodmenu` |
| Platforms | Android, iOS only (no web/desktop) |
| Flutter | 3.41.6 stable (Dart 3.11.4) |
| Remote | `NxsHbb/food_menu_flutter`, default branch `main` |

## Working rules

These are standing instructions. Follow them without being re-asked.

### 1. Commit authorship — hard rule
Never put AI/assistant attribution in a commit message, PR body, or code
comment. No `Co-Authored-By: Claude`, no "Generated with Claude Code", no 🤖.
Commits carry human authorship only.

Enforced by `.githooks/commit-msg`. After cloning, run `tool/setup_hooks.sh`
once to activate it. Do not bypass it with `--no-verify`.

### 2. Plan before building
When design or features are supplied, first write the work into
`docs/PLAN.md` as **phases**, each broken into numbered **tasks**. Get the plan
agreed before starting task 1.

### 3. One task at a time
For each task, in order:
1. Implement it fully — no partial handoffs.
2. Update `docs/PROGRESS.md`, `docs/FINDINGS.md`, `docs/CONTEXT.md`, and any
   affected docs.
3. Run `flutter analyze` and `flutter test`; both must pass.
4. Commit on a new branch (`feat/…`, `fix/…`, `chore/…`), never on `main`.
5. Push and open a PR against `main`.
6. Report (see rule 4), then **stop and wait** for the merge to be confirmed.
7. Only after confirmation, sync `main` and start the next task.

### 4. Reporting after every PR push
Post two short sections:
- **What this PR does** — a few bullets.
- **Next up** — a short description of the next task.

Keep both brief; detail belongs in the docs.

## Doc map
- `docs/PLAN.md` — phases and tasks, with status.
- `docs/PROGRESS.md` — what is done, per task, newest first.
- `docs/FINDINGS.md` — decisions, gotchas, things learned the hard way.
- `docs/CONTEXT.md` — architecture and conventions a newcomer needs.
