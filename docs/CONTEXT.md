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
| `fmp/v1/app/*` | add-ons, order types, slots, branches, accounts, wishlist — **built by this project** | bearer token |
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

### The address book
`features/address/` (task 3.9), over the `addresses` half of `/me` and the
field metadata below.

- **`PUT /me` replaces the whole book**, so an omitted address is deleted.
  Never build that list in a screen — `AddressController` holds the book,
  applies one change to a copy and sends the result. Add, edit, delete and
  set-default are all that one operation underneath.
- **It also decides the single default.** The server promotes the first entry
  when nothing is marked, so sending two defaults silently picks one.
- **Writes are not optimistic**, unlike the wishlist: the server resolves a
  state code from a name, formats the postcode and builds `locality`, so the
  saved answer is not what was sent.
- A rejection names the field **and its index in the submitted book**, which
  may be a different address than the one being edited. The controller
  resolves that into `AddressSaveException.isThisAddress`; the form only
  blames its own input when that is true.
- `SavedAddress.locality` is **read-only and never rebuilt in Dart** — only
  the server can turn `DE` into `Delaware`.
- The form is generated from the field metadata; see below. `AddressRepository`
  also calls `/me`, as `ProfileRepository` does, each parsing its own half.

### Address fields
`GET fmp/v1/app/address-fields[?country=XX]` (task 3.8). **How to draw the
address form** — do not hard-code any of it.

- Returns `default_country`, a `countries` map for the picker, and `fields`
  for one country.
- **`fields` is an ordered list.** Render it in order: WooCommerce orders
  address fields differently per country and that order is the point. Each
  entry is `{key, label, required, priority, type}`, with `options` on `state`
  where the country has a state list.
- **Pick the widget from `type` and `options`**: `country` uses the
  `countries` map, `state` with `options` is a picker and without them a text
  field, `tel` is a phone keyboard, everything else is text.
- **A field that is absent is the answer** — `company` is omitted in most
  locales, and the form should not show it there.
- Use `label` as given. It is WooCommerce's own wording in the store's
  language: "ZIP Code" in the US, "District" in Bangladesh.
- One country per request, so refetch when the customer changes country.
- **Hold it for the session.** It is static per country, but WordPress forces
  `no-store` on authenticated REST responses, so HTTP caching cannot help.
- `required` still is not the last word: the server revalidates and returns
  `fmp_app_invalid_address` with `data.field` and `data.index`. This route
  saves the round trip; it is not the gate.

### Account and profile
`features/account/` holds the design's account screen (task 3.7) and the form
behind its Edit button, over `GET|PUT fmp/v1/app/me`.

- **`PUT` is partial, and the repository keeps it that way** — only the fields
  the form owns are sent. The endpoint treats an absent key as "leave alone"
  and a present one as "replace", so sending a whole object would let the
  profile form wipe the address book it does not show.
- **A successful save is written back into the session** via
  `AuthController.updateSession`, which also persists it. The header reads the
  session, not a provider over `/me`, so without that write-back it would show
  the old name until the next sign-in.
- **Only rows that lead somewhere are rendered.** The design lists six; Payment
  methods, Notifications and Help & support have no backend in v1 and would
  need invented values, so they are absent. Saved addresses arrives with task
  3.8. `AccountRow` and `AccountRowCard` exist for it to drop into.
- **My orders carries no count** until task 7.1 — a `0` would say "you have
  never ordered" rather than "we have not asked".
- The email is shown on the edit form but **not editable**: no endpoint exists
  for it. See task 3.9.

### Wishlist
`GET|POST fmp/v1/app/wishlist` and `DELETE fmp/v1/app/wishlist/{product_id}`
(task 3.5), with the screen, the hearts and the controller in
`features/wishlist/` (task 3.6). Server-backed, so favourites follow the
customer between devices.

- `GET` returns `{ items, product_ids }`. **`items` are full Store API product
  payloads**, so `WishlistRepository` maps `Product.fromJson` over them and no
  second fetch is needed. Newest favourite first.
- **`WishlistController` holds the list for the whole session**, loaded once
  per sign-in. `wishlistIdsProvider` derives the id set from it and every heart
  watches that — with a grid of dishes on screen, asking per card would be a
  request per card for something one request already carries.
- The id set is derived from `items` rather than read from `product_ids`,
  because they are the same thing and deriving it cannot drift. A favourite
  whose dish is off the menu is in neither.
- `build()` watches `isSignedInProvider`, so signing in loads the wishlist and
  signing out drops it with **no explicit invalidation anywhere**. Signed out
  is an empty list, not an error.
- **Writes are optimistic.** `toggle()` updates the list, then calls the
  server, and puts the whole previous list back on failure. It `await`s the
  first load before touching state, so a heart tapped during the opening
  request still applies rather than doing nothing.
- A 404 from a write also **invalidates the controller**: the dish has left the
  menu, so the held list is stale in more ways than that one heart.
- **Riverpod's automatic retry is switched off** on this provider. The screen
  offers "Try again", and the default backoff otherwise keeps a timer firing
  while the customer sits on the error — and stops `.future` ever completing
  with the error.
- **The heart is shown to everyone**, signed in or not. Tapping it while signed
  out pushes the sign-in screen rather than calling the API, which is the
  journey the router was already built for. Hiding it would leave a signed-out
  customer no way to discover that dishes can be saved.
- `WishlistHeart` takes a `HeartStyle` — `onImage` (card and detail), `bare`
  (menu row) and `tinted` (the wishlist screen's own filled button) — because
  the design dresses it differently in each place.
- The wishlist screen uses its own compact **`WishlistRow`**, not `DishRow`:
  the design drops the description, rating and add button here, since the list
  is decisions already made rather than a menu to browse.
- It is **nested under the Account tab**, so the tab bar stays and Account
  stays highlighted, matching the design.
- Error codes worth handling are already handled in `WishlistHeart._message`:
  409 is the cap and its wording is passed straight through, 401 is reworded
  because the server's "you must be signed in" reads as a bug on a signed-in
  screen, and 404 means the dish is gone.

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

The card's geometry lives in `_BannerMetrics`, which holds the design's
measurements as **ratios of its 330x160 card** and derives them from the real
card size. The copy column is derived from the artwork's left edge rather than
stated separately, so the two cannot drift apart. Do not reintroduce fixed
pixel widths here — a card narrower than the design's own put the title under
the artwork on a real phone. See `FINDINGS.md`.

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
