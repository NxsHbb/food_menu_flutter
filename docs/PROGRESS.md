# Progress

Newest first. One entry per completed task.

## Task 1.3 — Design system: tokens, typography, light and dark themes
Branch `feat/design-system`

- `AppTokens` holds every raw value from the design — brand `#F20800`, the
  neutral ramp, the 12/14/16/18/20 radius scale and the 2→24 spacing run.
  Nothing outside that file hard-codes a hex or a radius.
- `AppPalette` is a `ThemeExtension`, so a widget calls
  `AppPalette.of(context)` and gets the right values in either mode without
  asking which one is active.
- **Plus Jakarta Sans is bundled, not fetched.** Only a *variable* font is
  published upstream, so weights are driven with
  `fontVariations: [FontVariation('wght', …)]` **as well as** `fontWeight`.
  Setting `fontWeight` alone renders the whole scale at one weight — it looks
  like the theme ignoring the design, and a test guards against it.
- Theme styles buttons, inputs, chips, cards, nav bar and sheets from the
  tokens, so most screens need no local styling. The primary CTA matches the
  design exactly: 48px tall, 14px radius, 14/700 label.
- `DishImagePlaceholder` draws the design's 135° stripe fill for dishes with
  no photo. It is in `core/widgets` because home, menu, cart, upsells and
  order thumbnails all use it.
- **Dark mode is derived, not designed.** The design is light-only, so the
  dark surfaces are warm neutrals matching the warm light canvas, and the
  brand red is lifted to `#FF5436` because `#F20800` reads muddy on dark and
  its contrast with white text is already marginal. Worth a designer's review.
- Verified the font actually ships: it appears in `FontManifest.json` and
  `build/flutter_assets`. 34 tests pass, `flutter analyze` clean.

## Task 1.2 — HTTP client, error mapping, Store API session
Branch `feat/http-client`

- `ApiClient` wraps dio and speaks only in `ApiException`, so no feature layer
  ever imports dio's error types. URLs are built from `AppConfig`, so a feature
  never concatenates a base URL itself.
- `ApiException` classifies failures as network / timeout / http /
  malformedResponse / cancelled / unknown, and lifts `code` and `message` out
  of the WordPress REST error body (`{code, message, data:{status}}`), which
  both the Store API and the plugin use. Exposes `isRetryable` and
  `isAuthFailure` so screens decide what to do without inspecting statuses.
- `StoreSessionInterceptor` carries the Store API's `Nonce` and `Cart-Token`
  between requests. **It harvests them from error responses too** — a 401 for
  a missing nonce still returns a usable `Nonce`, so reading only successful
  responses would leave a client that can never make its first write. Verified
  against the running site before writing the code.
- A response carrying only one of the two headers no longer erases the other,
  and a header set deliberately by a caller is never overwritten.
- `StoreSession` is in-memory behind a notifier; task 4.6 adds persistence
  without touching anything else.
- Tests use a fake dio adapter, so the suite needs no network and no new
  dependency. 22 tests pass, `flutter analyze` clean.

## Revised the plan after reading the design
- Payment is **native**, per the design: cash on delivery in v1, card and
  PayPal deferred. The webview handoff and its cart-adoption problem are gone,
  and Phase 6 is rewritten around a native checkout screen.
- **Dine-in dropped** — the design has a pickup/delivery toggle only, which
  also makes QR table ordering moot.
- Coupons, upsells, card and PayPal payment moved to **v2**.
- Wishlist (design screen 10) is **undecided** and not costed in any phase.
- `designs/` is gitignored, along with `.DS_Store`.

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
