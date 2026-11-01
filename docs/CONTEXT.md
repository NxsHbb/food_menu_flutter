# Context

Architecture and conventions. Kept current as the app grows.

## What this app is
A customer-facing mobile client for the Food Menu WordPress plugin
(`radiustheme/tlp-food-menu` + `food-menu-pro`). It is a **thin client**:
pricing, slot limits, discount maths and order-status transitions all stay
server-side. The app renders and calls. Staff and kitchen operations are not in
v1 — see `PLAN.md`.

## Backends it talks to
| Namespace | Used for | Auth |
|---|---|---|
| `wc/store/v1` | menu reads, cart writes | public for reads; `Nonce` + `Cart-Token` headers for cart |
| `fmp/v1` | the one public route, `GET /track/{token}` | none |
| `fmp/v1/app/*` | add-ons, order types, slots, branches, accounts — **built by this project** | bearer token |

The existing `fmp/v1` routes are nonce-gated and unusable from a mobile client;
`FINDINGS.md` explains why and what that implies.

## Architecture
Feature-first, with a thin shared core.

```
lib/
  main.dart                     runApp + ProviderScope, nothing else
  src/
    app.dart                    MaterialApp.router: theme + router, no logic
    core/
      config/app_config.dart    base URL and derived API bases
      router/app_router.dart    GoRouter + bottom-nav shell
      theme/app_tokens.dart     raw design values — the only place hexes live
      theme/app_palette.dart    semantic roles as a ThemeExtension
      theme/app_typography.dart type scale (variable-font weights)
      theme/app_theme.dart      ThemeData for light and dark
      store_api/models/         Store API DTOs: money, product, cart
      widgets/                  widgets shared across features
    features/
      <feature>/
        presentation/           screens and widgets
        domain/                 models (added per feature)
        data/                   repositories and API clients (added per feature)
```

**State management and DI: Riverpod** (`flutter_riverpod` 3.x). Chosen over
alternatives because it gives dependency injection and state in one tool with
no code generation required, and because overriding a provider is the cheapest
way to inject a fake API client in a widget test. Nothing is a global; the
router itself is a provider so Phase 3 can hang an auth redirect off it without
restructuring.

**Routing: `go_router`** with `StatefulShellRoute.indexedStack`, so each
top-level tab keeps its own navigation stack and scroll position. The four
destinations (Menu, Cart, Orders, Account) are **provisional** — the supplied
design decides the final navigation.

**HTTP: `dio`**, chosen for its interceptor model, which the Store API's
session headers need.

### The network layer
`core/network/` holds four pieces:

- `api_client.dart` — `ApiClient`, the only thing features talk to. It builds
  URLs from `AppConfig` and throws `ApiException`, never `DioException`, so
  dio's types stop at this boundary.
- `api_exception.dart` — failure classification plus `isRetryable` /
  `isAuthFailure`. WordPress REST errors all share the shape
  `{code, message, data:{status}}`, so the server's own `code` and `message`
  are lifted out of it.
- `store_session.dart` — holds the Store API's `Nonce` and `Cart-Token`.
  In-memory until task 4.6 adds persistence.
- `store_session_interceptor.dart` — carries those two headers between
  requests.

**The interceptor harvests headers from error responses, not just successful
ones.** This is deliberate: the Store API answers a nonce-less write with 401
*and a fresh `Nonce`*, so a client that only read successful responses could
never make its first cart write. Do not "tidy" that into an `onResponse`-only
interceptor.

### Money
**Never parse a Store API price as a decimal.** Prices arrive as strings in
minor units with a `currency_minor_unit` exponent, so `"395"` means `$3.95`.
Use `Money.tryParse` / `Money.parseOrZero`, keep amounts in `minorUnits`, and
format with `Money.format()`, which applies the site's own separators and
affixes. Doubles are never used for money.

`Currency` is read from whichever price block is in hand — products, cart
totals and line totals each repeat it.

### Theming
Colours, radii and spacing come from `AppTokens`; **no hex, radius or spacing
literal belongs anywhere else.** Widgets read semantic roles with
`AppPalette.of(context)` rather than branching on brightness.

The bundled Plus Jakarta Sans is a **variable** font, because that is the only
form published upstream. Every text style therefore sets the weight twice — in
`fontWeight` for layout and in `fontVariations` to move the `wght` axis. A
style with no `fontVariations` silently renders at the default weight, so build
styles through `AppTypography.style()` rather than constructing `TextStyle`
directly.

Both light and dark come from the design's own `THEME` map in
`designs/Food Ordering App.html`, and the role names in `AppTokens` and
`AppPalette` mirror that map one-to-one — check a value against the design
without translating vocabulary.

**The brand red is the same in both modes.** The design declares it as a
constant outside the theme map. Do not adjust it for dark-mode contrast; a
test pins it.

The only invented token is light-mode `ring`, because the design's value for it
is self-referential. It is flagged in `AppTokens`.

## Configuration
The backend URL is a compile-time define, never hard-coded to a machine:

```sh
flutter run --dart-define=FOOD_MENU_BASE_URL=http://192.168.0.171:8080
```

Omitting it falls back to the local dev site in `LOCAL_DEV.md`. `localhost` is
never the default: an Android emulator reaches the host at `10.0.2.2` and a
physical device needs the LAN address.

## Layout
```
lib/            Dart source (see Architecture above)
test/           unit and widget tests, mirroring lib/src
android/ ios/   platform projects — mobile only, no web/desktop
docs/           plan, progress, findings, local dev, this file
.githooks/      versioned git hooks (commit-msg attribution guard)
tool/           dev scripts (setup_hooks.sh)
```

## Conventions
- Analyzer: `package:flutter_lints` via `analysis_options.yaml`.
  `flutter analyze` and `flutter test` must both be clean before any commit.
- Screens are `StatelessWidget` or `ConsumerWidget`; no logic in `build`
  beyond reading providers.
- Branches: `feat/…`, `fix/…`, `chore/…`. Never commit to `main`; it only
  advances through merged PRs.
- Commit messages: imperative subject, no AI attribution (enforced by hook).
