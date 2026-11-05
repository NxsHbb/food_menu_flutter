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
| `wp/v2` | landing-screen banner posts | none |

The existing `fmp/v1` routes are nonce-gated and unusable from a mobile client;
`FINDINGS.md` explains why and what that implies. `fmp/v1/app/*` exists for
exactly that reason — it is a separate prefix with no nonce anywhere, and its
auth half now exists on the plugin's `mobile-app` branch (task 3.1).

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

### Accounts and the bearer token
The plugin side landed in task 3.1 (food-menu-pro#6); the Flutter half is tasks
3.3 and 3.4. What the client has to honour:

- `POST fmp/v1/app/auth/{register,login,refresh,logout}`. Register and login
  both return `{token_type, access_token, expires_in, refresh_token,
  refresh_expires_in, user}`. The access token lives an hour, the refresh token
  thirty days.
- Authenticate with `Authorization: Bearer <access_token>`. The server resolves
  it into the real WordPress current user, so the same token also authenticates
  Store API cart and checkout calls later — one credential for the whole app.
- **Refreshes must be serialised behind a single mutex.** Replaying a spent
  refresh token revokes the session server-side, so two concurrent 401s each
  kicking off their own refresh will sign the user out. A 401 from `/refresh`
  is a logout, not a retry.
- Failed sign-ins return one generic `fmp_app_invalid_credentials` by design;
  do not try to tell the user which field was wrong, because the server does
  not say.
- `429` responses carry `data.retry_after` in seconds.
- There is no password reset endpoint yet.

### The auth feature
`features/auth/` holds the whole of it, in the project's usual
domain/data/presentation split.

- **`AuthController` holds the session as an `AsyncValue`.** `AsyncLoading` is
  the keychain restore at launch, `AsyncData(null)` is signed out,
  `AsyncData(session)` is signed in. Watch `currentSessionProvider` when you
  only want the session, `isSignedInProvider` for the boolean, and the
  controller itself when you must distinguish *restoring* from *signed out* —
  showing a sign-in prompt during the restore flashes it at someone who is
  already signed in.
- **Nothing outside `AuthController` holds a token.** `TokenStore` persists it
  to the Keychain / EncryptedSharedPreferences, and only the controller talks
  to that.
- **Refresh is single-flight.** `AuthController.refresh()` returns one shared
  future to every caller. This is correctness, not efficiency: the server
  rotates refresh tokens and revokes the session when a spent one is replayed,
  so two concurrent refreshes sign the customer out. **Never call the
  repository's `refresh` directly** — go through the controller.
- **`AuthRefreshInterceptor` turns a 401 into one refresh and one replay.** It
  is a plain `Interceptor`, not a `QueuedInterceptor`: a queued one deadlocks,
  because the retry re-enters the chain and waits on the queue slot the error
  handler still holds. A failed refresh signs out; a network blip does not.
- **`AuthInterceptor` adds the bearer header to everything except
  `fmp/v1/app/auth/*`.** It is blanket rather than opt-in because the plugin
  resolves the token into the real WordPress current user, so the same token
  authenticates the Store API cart and checkout calls too. It only ever adds a
  header — refreshing and signing out on a 401 are task 3.4, kept out because a
  refresh has to be serialised across the whole app, which an interceptor
  cannot do alone.
- **`AuthValidation` mirrors the server, and is not the gate.** It exists to
  save a round trip and to put the message next to the field. Where the two
  could drift the server wins. It is pure Dart with no Flutter imports, so it
  is tested directly.
- The auth screens are **pushed**, not navigated to: the customer reaches them
  mid-task and pops back with a result.

### Profile and saved addresses
`GET|PUT fmp/v1/app/me` (task 3.2). The Flutter side is tasks 3.7 and 3.8.

- The response is `{ user, addresses }`. `user.phone` is the account's contact
  number; each address carries its own optional `phone` on top of that.
- **`PUT` is partial** — send only what changed. But `addresses`, when present,
  **replaces the whole book**, so send the full list, not a delta. Omitting an
  address deletes it.
- Address IDs are stable; keep them when editing. Send `is_default: true` on
  one entry, or the server promotes the first.
- `locality` arrives pre-rendered ("Celina, Delaware 10299") because resolving
  a state code to its display name is server-side knowledge. Use it for the
  card's second line rather than rebuilding it in Dart.
- Validation is per-country, so **do not hard-code required fields** in the
  form. A US address needs a state and a ZIP, a UAE address needs neither.
  Errors come back as `fmp_app_invalid_address` with `data.field` and
  `data.index`, which is what the form should highlight.
- The default address is mirrored into WooCommerce's billing and shipping
  fields server-side, so Phase 6 checkout does not need to send it again.

### Text from WordPress
Every text field from both APIs arrives as rendered HTML, and `wp/v2` fields
are entity-escaped on top — an ampersand reaches the app as `&#038;`. Pass
anything displayed through `plainText()` in `core/util/html_text.dart`; never
render an API string directly.

### Ingredients and nutrition
Supplied by the plugin's `food-menu-pro` **Store API extension** on the
product response, not by WooCommerce. Added in food-menu-pro#5; before that
they were unreachable for products. Every level of the extension block is
treated as optional, so a site running an older plugin shows no sections
rather than erroring.

### Banners
The landing carousel reads WordPress posts in the **`app-banners`** category:
post title, excerpt, featured image, and the first post tag as a badge. The
category is resolved **by slug, never by id**, because term ids differ between
sites. Nothing published there means no carousel at all, not an empty band.

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

## Transport security
iOS blocks cleartext HTTP, so `Info.plist` sets `NSAllowsLocalNetworking`,
permitting HTTP to **local-network addresses only** — a dev or staging
WordPress site on the LAN. Production hosts still require HTTPS. Android has
no equivalent configured yet and cannot reach an HTTP dev site.

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
