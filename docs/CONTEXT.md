# Context

Architecture and conventions. Kept current as the app grows.

## What this app is
A customer-facing mobile client for the Food Menu WordPress plugin
(`radiustheme/tlp-food-menu` + `food-menu-pro`). It is a **thin client**:
pricing, slot limits, discount maths and order-status transitions all stay
server-side. The app renders and calls. Staff and kitchen operations are not in
v1 — see `PLAN.md`.

**Both plugins, not either.** The whole `fmp/v1/app/*` namespace lives in
`food-menu-pro`, so the app needs Pro active — the free plugin alone has no
accounts, add-ons, order types, slots or orders endpoint for it to call.

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

### Account security
`POST fmp/v1/app/auth/{forgot-password,reset-password,change-password,change-email}`
(task 3.10). The Flutter side is task 3.11.

- Reset is a **6-digit code emailed to the customer**, not a link to a web
  page: `forgot-password` sends it, `reset-password` takes
  `{email, code, password}`. It lasts 15 minutes and allows 5 guesses.
- **`forgot-password` always answers the same way**, account or not, so the
  screen must not say "we sent it to you" in a way that implies the address is
  registered. `reset-password` returns one `fmp_app_invalid_reset_code` for an
  unknown address, a wrong code and an expired one.
- **All four routes return a fresh session and revoke the old one.** Treat the
  response exactly like a login: hand it to `AuthController.updateSession` (or
  adopt it) rather than ignoring the body. **The token in hand is dead
  afterwards** — a success that is not adopted signs the customer out on their
  next request.
- A successful `reset-password` signs the customer straight in.
- `change-password` and `change-email` need the **current password** as well
  as the token, and answer `fmp_app_incorrect_password` (403) without it.
- Errors worth wording: `fmp_app_weak_password`,
  `fmp_app_password_unchanged`, `fmp_app_email_unchanged`,
  `fmp_app_email_exists` (409), and a 429 whose `retry_after` the client
  already understands.
- **Changing the email sends no confirmation to the new address**, so the form
  asks for it twice (task 3.11).

The Flutter side is `auth/presentation/{forgot,reset}_password_screen.dart`
and `account/presentation/change_{password,email}_screen.dart`, reached from a
**Forgot your password?** link on sign-in and a Security card on the account
screen. `AuthController.{forgotPassword,resetPassword,changePassword,changeEmail}`
adopt the replacement session; no screen should call the repository directly.

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

### Timed dishes
The plugin's own rules — "breakfast until eleven", "off the menu on Mondays"
— reach the app as a `timed` block on the Store API product payload's
`food-menu-pro` extension (task 8.3):

```json
"timed": {
  "available": false,
  "behavior": "disable",
  "note": "Will be Available: 8:00 am – 11:00 am"
}
```

- **`available` is the same answer the storefront enforces.** It comes from
  the resolver `woocommerce_is_purchasable` uses, so a dish the app offers is
  a dish the server will accept.
- **`behavior` is the store's choice, reported not applied.** `disable` means
  draw it unorderable; `disappear` means take it off the menu. The app does
  the hiding, in `MenuRepository`, because the rules are not a taxonomy the
  Store API can filter on — so **a page of twenty can arrive as nineteen**.
- **`note` is the store's own words**, already translated and in its own date
  and time formats, and **empty when there is nothing to say** — which covers
  every dish no rule touches. Never compose this text in Dart.
- A variation carries its parent's block: rules are written against products
  and categories, never variations.
- `Product.isOrderable` folds it in beside stock, so every screen that already
  respected a sold-out dish respects the clock for free.
  `Product.unavailableReason` picks the words, stock first.
- Absent on an older plugin, which reads as always available rather than as an
  empty menu.

### Product add-ons
`GET fmp/v1/app/products/{id}/addons` (task 4.1). The Flutter side is task 4.4.

- **Public**, unlike the rest of `fmp/v1/app/*`, because the dish screen is
  reachable before sign-in.
- Returns `{ product_id, currency, groups }`. **Prices are minor-unit strings
  with the Store API's `currency_*` keys**, so `Money.fromJson` and
  `Currency.fromJson` read them unchanged — do not add a second way to parse
  an add-on price.
- A group is `{ id, title, description, type, required, position,
  min_selection, max_selection, option_quantity, placeholder, char_limit,
  free_label, options }`. Types: `dropdown`, `checkbox`, `radio`, `text`,
  `textarea`.
- **`min_selection` and `max_selection` of 0 mean no limit.** Groups arrive in
  `position` order; render them as given.
- `option_quantity` means each option carries its own stepper.
  `placeholder` and `char_limit` are for `text` and `textarea`, which keep
  their price on `options[0]`.
- `free_label` is **already resolved to a boolean** — show a "Free" badge on
  zero-priced options when it is true. Do not re-derive it.
- Whether a dish uses its own add-ons or the store's global ones is settled
  server-side; the app just renders what comes back.
- **A variable dish always answers `groups: []`**, whatever is stored against
  it (task 8.8). The website never renders add-ons on one and the cart never
  applies them, so publishing them put a question on the dish screen whose
  answer was dropped. A variable dish's only choice is its attributes.
- **Selections go back under the extension key** (task 4.2):

  ```json
  "extensions": { "food-menu-pro": { "addons": [
      { "group_id": "0", "option_ids": ["1"] },
      { "group_id": "1", "option_ids": ["0"], "quantities": { "0": 2 } },
      { "group_id": "2", "text": "No ice please" }
  ] } }
  ```

  **Send ids, never labels.** The ids are the ones this endpoint returned.
  `quantities` is keyed by option id and only applies where
  `option_quantity` is true; `text` is for `text` and `textarea` groups.
- **The server validates and prices.** Do not compute a line total locally
  beyond a preview — the cart response carries the real one. Refusals come
  back as `fmp_app_addon_required`, `fmp_app_addon_too_few`,
  `fmp_app_addon_too_many`, `fmp_app_addon_too_long` and
  `fmp_app_addon_unknown_option`, each naming the group in its message.
- An **unknown option id is refused**, so a stale menu produces an error
  rather than a wrong charge — reload the add-ons and ask again.
- Two different selections on the same dish are **two cart lines**, which is
  what the cart screen should expect.

#### The selection UI (task 4.4)
`domain/product_addons.dart` models the groups, `domain/addon_selection.dart`
holds what the customer has chosen, and
`presentation/widgets/addon_group_card.dart` draws one group.

- **`AddonSelection` is immutable**; every tap returns a new one. It enforces
  the same rules the server does — one-of replaces, a tick past
  `max_selection` is refused, a quantity is clamped to **10** because
  `AddonFields` clamps there — so the customer is not told "no" after the
  fact. The server still validates everything again.
- **`is_default` is honoured.** The store pre-answering its own required
  group is why a dish can open with Done rather than Required.
- A **dropdown is drawn as a one-of list**, not a picker: the design has no
  dropdown anywhere, and on a phone a list of three beats a menu that hides
  two of them.
- A **`text`/`textarea` group reuses the design's "Special instructions" card
  shape** with the group's own title. That card itself — the cart line note —
  is still task 4.5; these are priced add-ons that happen to be typed.
- **`option_quantity` gets a small stepper** on the chosen row. The design
  has none, but the plugin prices it and the cart records it, so leaving it
  out would make real options unreachable.
- The group's **description and its rule line are both shown**. Collapsing
  them would mean choosing between the store's words and "Select up to 3".
- **The total on the add button is a preview.** It is the dish price plus the
  deltas; the plugin can discount a line server-side, so the cart response is
  the only charged figure.
- The add button stays **enabled** with a group unanswered and names what is
  missing when pressed, which is what the design does. Pressing it turns the
  open groups red; answering clears them again.
- `productAddonsProvider` **never surfaces an error** — a store whose plugin
  predates the route 404s, and a dish that cannot be customised is still a
  dish. Widget tests override `addonsRepositoryProvider`.

### The cart
`features/cart/data/cart_repository.dart` wraps the Store API's four cart
routes; `cart_controller.dart` holds the cart for the session.

- **Every route answers with the whole cart**, so a mutation is one round trip
  and its response *is* the new state. Never read after a write.
- **Mutations are not optimistic**, unlike the wishlist's hearts. A cart line
  carries money, and only the server knows what a change costs once the
  plugin's discounts and the add-on pricing have had their say. The line being
  changed is marked busy instead — `controller.isPending(key)`.
- **Lines are addressed by `key`, never by product id.** The same dish ordered
  two ways is two lines sharing one id.
- A failed change **rethrows but leaves the cart intact**: the screen shows
  the server's own message, and a cart the customer is reading never blanks
  out over one refused tap.
- `clear()` is the odd one: `DELETE cart/items` answers with the items list
  (`[]`), not the cart, so the totals are read back.
- `cartCountProvider` is the unit count for badges, zero while the first read
  is in flight.

The screen reads a line's add-ons from `item.addons` — the extension block —
and falls back to `item_data` only for a store too old to send it. The coupon
field and the "Complete your meal" carousel the design draws are **v2**; the
discount row still appears when the server applies one of its own.

Adding happens from the dish screen: `AddonSelection.toPayload()` goes
straight into `cart/add-item` under the extension key, the dish closes, and
the server's wording is what a refusal shows — it names the group.

#### The floating bar and the badge (task 4.6)
`CartBar` is the design's floating bar — count, "View cart", subtotal — shown
by `HomeShell` over the **menu branch only**, because that is where a customer
is while they fill a cart. The cart screen is what it leads to and a dish has
its own bottom bar, so neither gets one.

It floats rather than pushing content up, so the screens underneath add
`cartBarInsetProvider` to their bottom padding. That provider is zero when
there is no bar, so nothing is reserved for a bar that is not there.

The tab badge counts **units**, the same number the bar shows. `HomeShell`
watching `cartCountProvider` is also what loads the cart at launch.

#### A cart survives the app closing
`StoreSessionNotifier` is an `AsyncNotifier`: its `build()` restores the
`Cart-Token` from secure storage, and `StoreSessionInterceptor` **awaits**
that before the first Store API request — otherwise the server would hand out
a new cart and orphan the saved one.

- **Only the cart token is stored.** The nonce comes back on every response
  and is short-lived, so keeping it buys nothing.
- Secure storage, reusing the auth session's dependency: not a login, but
  anyone holding it can read and change that cart.
- A token whose own `exp` has passed is dropped before it is sent. One that
  cannot be decoded is **kept** — the server is entitled to judge a shape
  this build has never seen.
- `clear()` wipes the stored copy too, so a paid-for cart cannot come back.

### Order types
`GET fmp/v1/app/order-types[?branch=<term_id>]` (task 5.1). The Flutter side
is task 5.4.

- **Public**, like the add-ons route: the design puts the delivery/pickup
  choice in the header of the first screen, before sign-in.
- Returns `{ branch, timezone, today, preorder_max_days, slot_limits_enabled,
  types }`. Only **pickup and delivery** ever appear — the plugin has dine-in
  and the app has no screen for it.
- `enabled` is the store's own switch. `time_required` is separate: when
  false the customer picks **no date or time at all** and the order is as soon
  as possible, so skip the slot list rather than showing an empty one.
- `first_date` already has `lead_days` applied. `last_date` is **null for no
  bound**, not "today".
- **An open day with no `windows` is a day with no stated hours**, not a
  closed one. Only `open: false` means closed.
- `max_orders_per_slot` is 0 for no cap, and only means anything when
  `slot_limits_enabled` is true.
- Pass `branch` once branches exist (5.3). A branch overrides the store **per
  type**: one with its own pickup hours but no delivery hours falls back to
  the store's for delivery. An **unknown branch is a 404**; a store not
  running branches answers store-wide with `branch: 0`, so check what came
  back rather than assuming the parameter was honoured.

#### Reading them back off a cart item
Task 4.3 put them on every Store API cart item, under the same extension key:

```json
"extensions": { "food-menu-pro": {
  "addons": [
    { "group_id": "0", "group_title": "Choose your size", "field_type": "radio",
      "option_id": "1", "value": "Medium 12\"", "quantity": 1,
      "price_type": "quantity_based", "price": "250", "price_single": "250" }
  ],
  "addons_total": "400",
  "addons_total_charged": "400",
  "base_price": "325",
  "currency_code": "USD", "currency_minor_unit": 2
} }
```

- Read the add-ons from **here**, not from `item_data`. That array is the
  website's own display copy, with the quantity baked into the string as
  `x2` and no ids or prices at all.
- `group_id` and `option_id` are the same ids `GET …/addons` publishes, so
  the add-on sheet can be reopened on a cart line with its selections
  already ticked.
- Both can be **null**: `option_id` always is for `text` and `textarea`, and
  either is when the group or label was reworded after the line went into the
  cart. `value`, `price` and the totals are still right, so render the line
  and just don't offer "edit".
- **`base_price + addons_total_charged == prices.price`**, always — that is
  how to draw the "dish + extras" breakdown. Use `addons_total` only to
  label what the add-ons cost before any discount; it is not necessarily
  what was charged.
- `price` includes the option's quantity; `price_single` is one of them.
- An item with no add-ons still has the keys, with `addons: []` and
  `base_price` equal to the line price. No null-checking the block itself.

### Branches
`GET fmp/v1/app/branches` (task 5.3, food-menu-pro#16). The Flutter side is
task 5.5. This says *which* branch to pass to `/order-types` and `/slots`.

- **Public**, no parameters.
- **The list is never empty.** A store with no branches comes back as a single
  entry with `id: 0`, `is_store: true` and WooCommerce's own store address —
  and `branch=0` is already what the other two routes mean by "store-wide". So
  render `branches[0]` and send its id; there is no empty case to handle.
- `multi_location` is whether the customer gets a choice. When false, show the
  one entry as "Pick up from …" rather than a picker.
- Per branch: `id`, `name`, `slug`, `parent`, `description`, `product_count`,
  `address`, `coordinates`, `is_store`, `types`. **`parent` matters** — the
  taxonomy is hierarchical, so a store can file branches under a city, and a
  flat list would show the city as if it were a branch.
- `address` is **one free-text field with its line breaks intact**, not
  WooCommerce's structured parts — that is all the location screen has ever
  stored. Render it as one line or several as the layout needs.
- **`coordinates` is null unless the branch really has them**, and is never
  `0, 0`. Distance ("0.8 mi away" in the design) is computed in Dart from the
  device's location; with null coordinates, omit the distance rather than
  showing zero.
- Per type: `enabled`, `time_required`, `has_custom_schedule`, `time_interval`,
  `max_orders_per_slot`, `lead_days`, `open_today`, `open_now`, and `today`
  with that day's windows. Enough to draw a picker without a second call.
- **The week is not here on purpose** — ask `/order-types?branch=<id>` for it.
  Inlining it would make this response grow with the number of branches.
- **`open_now` is true on a day with no windows**, because no stated hours
  means no restriction. Same rule as everywhere else.

#### Branch selection does not yet filter the menu
The website scopes products to a branch with `woocommerce_product_query` and a
`fmp_location_id` cookie. **The Store API runs neither**, so passing a branch
to the API changes slots and hours but **not** which dishes come back. Task 5.5
cannot be done in Dart alone; it needs a plugin change first. `FINDINGS.md` has
the detail.

### Slots
`GET fmp/v1/app/slots?type=pickup|delivery[&date=Y-m-d][&branch=<id>][&items=42:2,17:1]`
(task 5.2, food-menu-pro#15). The Flutter side is task 5.4. `/order-types`
answers the week; this answers one day of it, already judged.

- **Public**, like `/order-types`. `type` is required; omitting `date` gives
  the earliest date the type can be fulfilled on.
- **Never format a date or a time for submission.** Send back `date_value` as
  `fmp_{type}_date` and the chosen slot's `value` as `fmp_{type}_time`,
  verbatim. Those are the **site's own display formats** (`F j, Y` and
  `g:i a` on the dev store), because that is what the web checkout submits and
  the Store API extension stores what it is given. Slot limits then count by
  matching those strings, so an ISO time would place an order no limit counted
  and that the admin order screen rendered unlike every web order. `date`,
  `start` and `end` are the machine-readable copies, for display and sorting
  only.
- Each slot: `{ asap, label, value, start, end, start_minutes, available,
  remaining, reason, message, products }`. `label` is ready to draw — a point
  time for pickup, a `12:00 pm – 1:00 pm` window for delivery, which is what
  the design shows.
- **`message` is the server's own copy, in the store's language.** Show it;
  do not compose a reason from `reason`. `reason` is for branching only:
  `full`, `not_served`, `sold_out`.
- **Unavailable slots are still in the list** and should be drawn disabled —
  a full slot is information. **Past times are already gone**, so no filtering
  by clock in Dart.
- **The ASAP row has an empty `value`.** Send no `fmp_{type}_time` at all for
  it. It is only present when it genuinely applies, so render whatever comes
  back rather than synthesising one: it is absent for a future date, and
  withheld when the next real slot is full or a cart dish is not served now.
  Its label carries the store's estimate — `ASAP (15 min)`,
  `ASAP (20–35 min)` — or plain `ASAP` when the store has set none.
- **`time_required: false` returns exactly one slot, the ASAP row.** Hide the
  date picker, draw the single row. The list is never empty in that mode.
- **`items` is how per-product limits and timed dishes get considered**, as
  `product_id:qty` pairs — parent product ids, quantities summed across
  variations. Without it the answer covers only the store-wide slot caps. The
  route cannot read the cart itself: it is public, and the cart lives behind a
  Store API `Cart-Token` that only Store API routes resolve. When a dish is in
  the way, `products` names it with its own `message`.
- **An empty `slots` always comes with a `closed_reason` and a `message`** —
  `type_disabled`, `before_first_date`, `after_last_date`, `weekly_closed`,
  `no_times_left`. Show the message; there is nothing to pick.
- A malformed `date` is the only refusal: 400 `fmp_app_invalid_date`. An
  unknown `branch` is a 404, as on `/order-types`.
- **Re-fetch after the cart changes.** Availability is a function of the cart,
  so adding a dish can take slots away.

### Choosing a branch (task 5.5)
`features/branch/`, plus `core/network/branch_interceptor.dart`.

- **The branch travels as a header, `X-FMP-Branch`**, set once by an
  interceptor, so the menu, search, collection counts and the cart all agree
  about it. Pro scopes Store API product queries by it; see its `CLAUDE.md`.
- **The restore is awaited**, like the cart token. A request that went out
  before the branch was read would be answered with every branch's dishes and
  the list would then visibly swap. `selectedBranchProvider` therefore has
  `retry: null` and **never enters an error state** — an unreadable keystore
  means "no branch chosen", because the interceptor waits on this before
  every request.
- **Zero is a real branch id**, meaning store-wide, and is not the same as
  null. The header is only sent above zero, since the server already assumes
  store-wide.
- **Everything scoped by the branch watches `activeBranchIdProvider`** purely
  as a cache key — the branch rides on a header, so two branches produce
  identical-looking requests with different answers, and without the watch the
  menu would keep showing the branch the customer just left.
- **The branch in force is resolved, not stored.** A remembered branch that no
  longer exists, or a store that turns multi-location off, falls back to the
  first rather than leaving the app pointed at nothing.
- A store with no branches answers with **one entry, `id: 0`, `is_store`**, so
  the picker says "This store has one location" and the header's chevron is
  dropped rather than opening a list of one.
- **A closed branch can still be chosen.** The design lets a customer browse
  and order for later; the slot list is what refuses a time.
- The picker is shown with **`useRootNavigator: true`** — the shell paints the
  floating cart bar in a Stack above its own navigator, so a sheet from the
  inner one comes up underneath the bar.

#### What a branch switch does not do
**The cart is left alone.** The website removes lines the new branch does not
serve (`FoodLocation::validateCartLocation()`), and the app cannot — so a
customer can carry a dish across. Task 6.6 decides whether to warn, drop or
let the checkout refuse. Until then, assume a cart may contain something the
chosen branch will not make.

### Choosing how and when (task 5.4)
`features/fulfilment/` — the type switch and the time list, which the checkout
screen renders as its first section. The screen itself is
`features/checkout/`, below.

- **`CheckoutScreen` sits outside the tab shell**, like a dish, because the
  design shows no tab bar on it. Reached from the cart's "Go to checkout".
- **Nothing about availability is decided in Dart.** The server generates and
  judges the list; this feature renders it and remembers which chip was
  tapped. `FulfilmentChoice` holds only a type, a date and a slot identity.
- **`slotsProvider` is keyed by `SlotRequest`**, a value object of type, date
  and the encoded cart. Everything the fetch depends on is in that one
  comparable key, so one cart means one request.
- **Watch what it depends on *before* any `await`.** A `ref.watch` after an
  asynchronous gap registers late and rebuilds the provider when that
  dependency settles, which fetched the same slots twice.
- `cartItemsProvider` publishes the cart as the **encoded string**, not a map:
  two equal maps are never `==`, so a map re-triggered the fetch on every cart
  emission.
- **The selected slot is resolved, never stored as an object.** A choice is
  kept as minutes-since-midnight and looked up in the current list, so adding
  a dish or letting a time pass falls back to the earliest open slot instead
  of submitting one the server has stopped offering. ASAP is -1.
- **The type is resolved too**, against `enabled`, so a type the store
  switches off mid-session is dropped rather than drawn.
- `retry: (_, _) => null` on both providers. The section offers "Try again",
  and a background retry would keep firing while the customer reads the error.
- **The slot row scrolls horizontally**, as the design draws it. Wrapping was
  tried: a store open all day at a half-hour interval offers nearly forty
  slots, which ran down the screen and buried everything below.
- Unavailable chips are drawn struck through and **explain themselves on tap**
  with the server's own sentence. A chip that ignores taps reads as broken.
- **The date strip** (task 8.4) is drawn from `first_date` and `last_date`,
  one chip per date, labelled against the **store's** today — "Today",
  "Tomorrow", then "Thu 13 Nov". It appears only when there is more than one
  date to pick; the lone-date case keeps the old line under the title, which
  a kitchen's lead time can make necessary.
  - **A null `last_date` means today only**, not "no limit": the store sends
    one only when `fmp_preorder_max_days` is above zero. The route itself is
    laxer — see `FINDINGS.md`.
  - A day the store is closed is **still offered**, and answers with the
    store's own "closed" message. The app cannot know a store's weekly
    closures without asking for that date.
  - Changing the date **clears the chosen slot**, because slot identity is
    minutes within a day and the same number means a different time of a
    different day.
  - The date is submitted as the server's own `date_value` for the date in
    force, never a string the app formats.
- **A scheduled order says which day it is for.** `CustomerOrder.scheduledDate`
  is the order's stored date, and empty for an ASAP order, which has no time
  and so no day to be wrong about. Drawn on the order-received tile and beside
  the estimate. Before the date strip every order was for the earliest date and
  a bare time was unambiguous; now it is not.

### The checkout screen (task 6.1)
`features/checkout/` — the screen the design draws, around
`FulfilmentSection`: the address block, contact details, the order summary and
the sticky total bar. **Payment is task 6.3 and placing the order is 6.2**;
until then "Place order" validates and stops.

- **The screen lives here, not in `fulfilment`.** Fulfilment is the order type
  and the time; the checkout is the page and, from 6.2, the order. The rest of
  Phase 6 drops in beside it.
- **The address block is one row over two sources.** Delivery reads the
  address book, pickup reads the branch list and reuses `BranchPickerSheet`,
  and the arm is chosen by `resolvedOrderTypeProvider`. "Change" is hidden on
  pickup when the store runs no branches, because the picker would open on a
  single row.
- **The address is held as an id and resolved on every read**, like the order
  type and the slot: a deleted address, or a different customer signing in,
  falls back to the book's default instead of pointing at something the server
  has never heard of.
- **Name, phone and notes live in `CheckoutController`, not in the form.** The
  address sheet and the address book both rebuild the screen beneath them, and
  task 6.5 must return to a checkout that kept its input. Null name or phone
  means *not edited*, which is what lets `checkoutContactProvider` prefill from
  the account and then from the address; an empty string is a cleared field and
  stays cleared.
- **Prefill through `ref.listen`, never `ref.watch`.** Writing
  `controller.text` during `build` is a `setState` during build — see
  `FINDINGS.md` — and the flag that says "already prefilled" is **per field**,
  because the name and the phone arrive at different times.
- **Never recompute money.** The summary's rows are `CartTotalsRows`, shared
  with the cart screen, and the bar shows the cart's own `total_price`. Tax,
  fees and automatic discounts are server-side arithmetic.
- `_blocker` on the screen is the single list of what stops an order — empty
  cart, signed out, no type, no slot, no delivery address — read fresh on every
  tap, because any of them can change while the screen is open. Task 6.2 posts
  the order from the same place.
- Validation is `CheckoutValidation`, which mirrors the server as
  `AuthValidation` does. Phone is **required here** and optional on the
  profile, and it borrows the profile's digit rule rather than restating it.

### When an order is refused (task 6.5)
`CheckoutFailure` classifies whatever the checkout route threw, and the screen
shows it in `CheckoutErrorBanner` until it is dealt with.

- **A banner, not a snackbar.** A refusal has to be read, acted on, and still
  be there afterwards — a missing postcode is fixed three fields away, and a
  snackbar is gone before the keyboard has opened.
- **The kind decides the offer**, not the message: a dropped connection gets
  "Try again" because the identical order could work; a rejected address does
  not, because it would be refused identically. A 429 is excluded on purpose —
  it will work later, but not now, and a button spends another attempt.
- **The server's own sentences are shown**, including the per-field ones under
  `data.errors` and `data.params`. They name the field, the dish or the
  gateway, which nothing composed here could.
- **Through `plainText()`.** WooCommerce entity-escapes its messages, so a
  total-mismatch sentence arrives with `&#036;` in it. See `FINDINGS.md`.
- **Nothing is cleared.** Every field, the address, the slot and the payment
  method stay where the customer left them — which is the whole point of
  keeping the input in `CheckoutController` since 6.1. The contact section is
  **keyed** so the banner's insertion cannot reset it; see `FINDINGS.md`.
- **`expected_total` is sent** so a price that moved is refused rather than
  charged unseen, and the refusal's own `data.cart` is adopted rather than
  re-fetched.
- The failure lives in the screen's `State`, not a provider: it belongs to
  this attempt, and coming back later should not re-raise an order refused ten
  minutes ago.

### Reading an order back (task 6.4)
`features/orders/`, over `GET fmp/v1/app/orders/{id}` (Pro). The screen the
customer lands on after paying, and the model Phase 7 builds on.

- **Nothing is carried over from the checkout.** The order-received screen is
  given an id and reads the order from the server. The checkout's response
  echoes the plugin's extension schema with its defaults rather than the saved
  order, and a store can renumber, reprice or re-status an order in between.
  It also makes the route survive being opened cold.
- **Why not `wc/store/v1/order/{id}`** — it works, and answers items, totals
  and addresses, but carries no order number, no date, no payment title and
  none of the plugin's fields, including the tracking token. See
  `FINDINGS.md`.
- **The route replaces the stack** rather than being pushed: the cart is gone
  and the checkout behind it is for an order already placed. A `PopScope`
  sends the hardware back button home instead of out of the app.
- **A failure here never says the order failed.** It was placed — the checkout
  answered with it — so the error state says so and offers a retry.
- `status` is WooCommerce's slug and `status_label` is the words; **branch on
  neither**. A store can add statuses of its own and this app has no name for
  them.
- An ASAP order stores **no time at all**, so `eta` carries the store's own
  estimate instead, composed server-side so it cannot disagree with the slot
  list.
- `tracking_token` is **empty until the first status change writes one**, so
  task 7.3's button has to check `canTrack` rather than assume.
- A line's `meta` is **WooCommerce's own formatted meta on its defaults**
  (task 8.8): no underscore-prefixed keys, and no attribute already spelled
  out in a variation's name. Entities are decoded, because the app draws the
  string as text. Do not widen it to "everything the line holds" — that is
  how `_fmp_addon_selection` reached a customer's screen.

### Delivery method (task 8.5)
The cart's own `shipping_rates`, rendered as a radio list on the checkout and
chosen with `POST cart/select-shipping-rate`. Before this the app drew
`total_shipping` once the server had decided for it, which is only correct for
a store running exactly one method.

- **`Cart.shippingPackages`** is WooCommerce's packages, each with its rates.
  A restaurant order is one package; the package name is drawn only when there
  is more than one.
- **The server marks the rate in force** (`selected`) and recomputes the cart
  when one is chosen. The response is the new truth — nothing is recomputed
  here, and the shipping total moves with it.
- **A price in minor units with the usual `currency_*` keys**, so `Money`
  reads a rate exactly as it reads a line total.
- **One rate is reported, not offered**: drawn with its price and no radio,
  because a control that cannot change reads as a broken one.
- **Pickup draws nothing**, and an address no zone covers draws nothing
  either — an empty list is not a choice withheld, it is a store that cannot
  deliver there, which belongs to the address block.
- `rate_id` and `package_id` go back as given. `method_id` is never branched
  on: a store can install a method this app has never heard of.

### Paying (task 6.3)
`GET fmp/v1/app/payment-methods` (Pro), rendered as the design's radio list.

- **The words are the merchant's.** WooCommerce gateway titles are translated
  and routinely renamed, so nothing about a gateway is composed in Dart — only
  its id, which is what goes on the order.
- **Two lists, intersected.** The endpoint says what the store has *enabled*
  (cart-independent, stable for the session); `Cart.paymentMethods` says what
  is *available for this cart*. `PaymentMethods.offered` takes a nullable
  list, because an unread cart and a cart nothing can pay for are different
  answers. See `FINDINGS.md`.
- **`supported` is the app's reach, not the store's.** A gateway needing a
  redirect or a native SDK is still listed, drawn dimmed and unselectable, so
  a store running only card gets an explanation instead of an empty section.
  The server decides which ids those are, filterable with
  `fmp_app_supported_gateways`.
- **The method is resolved, never stored** — like the order type, the slot and
  the address. A tap on an unsupported row can never reach an order.
- No client-side validation that a gateway is enabled: **the Store API already
  refuses one**, by name, and that message is what the customer is shown.

### Placing the order (task 6.2)
`POST wc/store/v1/checkout`, the Store API's own route — the order, its
totals, stock and the gateway are WooCommerce's business, and the plugin only
adds the pickup/delivery fields.

- **`checkoutReadinessProvider` is the single answer to "can this be
  ordered".** It returns either a `CheckoutReady` carrying the `OrderDraft` or
  a `CheckoutBlocked` carrying the sentence to show. The two questions are the
  same question: everything that blocks an order is a part the order is
  missing. Read at the moment of the tap, never watched.
- **The form is validated first**, because what it checks is on screen and a
  message beside the field beats the same complaint in a snackbar. When the
  form is not on screen at all — signed out, or an empty cart — it passes and
  the readiness says the useful thing.
- **`OrderDraft.toJson` is the payload**, built in the domain rather than the
  repository so it can be asserted on without a network layer and resubmitted
  unchanged by task 6.5.
- **Send every key of the `food-menu-pro` extension, every time**, including
  the dine-in ones this app never uses. An omitted key is null and the whole
  request is rejected. See `FINDINGS.md`.
- **The date and time are the server's own strings** — `date_value` from the
  slot list and `value` from the slot — never composed in Dart. ASAP's value
  is empty, which is what the plugin reads as "as soon as possible".
- **An address is required for pickup too.** WooCommerce validates a billing
  address on every order regardless of type.
- **The branch is not in the payload.** The plugin reads `X-FMP-Branch`, which
  the interceptor already sets, and resolves the name from the term itself
  (food-menu-pro#19).
- **The cart is emptied server-side** by a successful checkout, so the app
  re-reads it rather than assuming — the mini cart and the tab badge watch it.
- **The response cannot be trusted for the order's own fields**: its extension
  block is the schema's empty defaults, not what was saved. Task 6.4 reads the
  order back.
- A 200 with `order_id: 0` is treated as a refusal, not an order.
- Payment is **cash on delivery, hard-coded**, until task 6.3 reads the
  store's enabled gateways. A store with no gateway enabled has every order
  refused by the Store API.

### The plugin's block on a product
`AppProductStoreApi` in Pro adds one `food-menu-pro` extension to Store API
product responses, carrying everything about a dish WooCommerce does not
describe. Every level of the block is treated as optional on this side, so a
site running an older plugin loses the feature rather than erroring.

- **`ingredients` / `nutrition`** — the dish's food data, unreachable for
  products before food-menu-pro#5.
- **`requires_choices`** — true when an add-on group must be answered before
  the dish can be added at all. Read together with WooCommerce's own
  `has_options` as `Product.needsChoices`, because the two cover different
  things: `has_options` means a variation must be picked, and knows nothing
  about add-ons. See `FINDINGS.md`.

One class owns that endpoint and namespace on the plugin side, by necessity —
a second registration replaces the first without a word.

### The order screens
`OrdersScreen` is the design's two tabs over a paged list; `OrderDetailScreen`
is one order in full, pushed over it so the Orders tab keeps its place.

- **Signed out shows an invitation, not an error.** `OrderHistoryController`
  watches `isSignedInProvider` and returns an empty history rather than
  asking, exactly as the wishlist does — signing in loads it, signing out
  drops it, and nothing invalidates anything by hand.
- **The status pill takes its colour from the server.** The design hard-codes
  a pair per status for the five it knows; a store can invent more, so the
  plugin sends one colour and `OrderStatusPill` derives the pair. Six-digit
  hex only — see `FINDINGS.md`.
- **Paging belongs to the controller**, and so do its tests: a pending page
  keeps a spinner in the tree, which `pumpAndSettle` can never settle.
- **The order screen reads twice, on purpose.** The order itself is settled
  — items, totals, address — while its progress is the one part that moves,
  so `orderTrackingProvider` is separate from `orderProvider`. A tracking
  failure then costs the timeline and not the screen.
- **The estimate is in one place at a time.** While an order is active the
  tracking card at the top carries it, where the design puts it; once it is
  over the details list keeps it as a record of the slot that was chosen.
  Drawing both at once said the same thing twice.
- **Reorder is on a finished order only.** Reordering something still being
  cooked is how a customer ends up with two dinners. The button adds to the
  cart rather than replacing it, does not ask first — the cart is the
  confirmation step — and lands on the cart only when something actually went
  in.

Dates go through `core/util/relative_date.dart` — "Today, 2:02 PM" — which is
hand-rolled because `intl` is not a dependency. Always in the device's time
zone, since the server sends an offset.

**A stage time is the exception**: it arrives already formatted, and is drawn
as it arrived. "Ready at 9:33 pm" only means anything on the kitchen's clock,
so the server renders it in the site's own zone and format and the app does
not re-zone it onto the phone's. The payload carries a UTC instant alongside,
which nothing needs yet.

### Order tracking
`GET fmp/v1/app/orders/{id}/tracking` (task 7.3, food-menu-pro#26), and
**not** the public `fmp/v1/track/{token}` the website's own tracking page
reads, though an order payload carries the token for it.

- That route answers only what **happened** — every entry `completed` —
  because the website draws a history rather than a plan, and the design's
  progress strip needs the stages still to come as well.
- It also **expires**, by `fmp_tracking_link_expiry_days`, which is right for
  a link emailed to whoever placed the order and wrong for the customer's own
  order in their own signed-in app.

So the app route is bearer-authed against the order's customer, like the rest
of `/app`, and a stranger's order answers 404 exactly as a missing one does.

**The app never decides how far along an order is.** `step` and `stages` come
from the store's own declared pipeline — the Order Statuses screen drag-sorts
its custom statuses and saves them in that order — for the same reason the
status pill takes its colour from the server. `FINDINGS.md` records how the
sequence is built and why a store with no custom statuses gets two stages
rather than the design's four.

**A stage's time is drawn from `at_utc`, on the phone's clock** (task 8.8).
Each stage carries both a preformatted `at` on the store's clock and the
instant; the app re-zones the instant like every other date and falls back to
`at` only when there is no instant. 7.3 drew `at` and a device showed two
times for one order. See `FINDINGS.md`.

The history row carries `progress: { step, stage_count }` on the summary
instead, so a page of ten rows does not cost ten tracking requests. It is
**absent rather than zero** when there is nothing to measure — a bar stuck at
the left reads as an order nobody has started.

`trackingToken` stays on the order payload as the key to the website's public
page, which is the only way to hand someone else a link. No screen does yet.
The `canTrack` getter that gated tracking on it was **removed**: tracking no
longer needs the token, so a getter saying otherwise would have withheld the
button from orders that track perfectly well.

### Reorder
`GET fmp/v1/app/orders/{id}/reorder` (task 7.4, food-menu-pro#27).

**A read, not a write.** It answers what the lines would be; the app then adds
each through the Store API's own `cart/add-item` — the path where add-on
validation, branch scoping, timed products and stock already work. Rebuilding
the cart inside the plugin route would have meant reproducing all four.

**The server decides what is reproducible.** A line comes back `available`
with the add-on payload to re-submit, or unavailable with a reason: `gone`,
`unavailable`, `out_of_stock`, `choices_not_recorded`. The app never inspects
the payload — it is the plugin's own shape, and reading inside it here would
be a second place for the add-on contract to drift.

`ReorderController` runs the two steps and returns a `ReorderOutcome`. A failed
**read** throws, because nothing has changed and the screen can say so; a line
that fails to **add** is reported in the outcome instead, because by then part
of the order is already in the cart and pretending otherwise would be a lie.
The design shows a toast, so partial success says which part worked.

### Variable dishes
A parent product plus a variation per combination. The dish screen draws an
attribute picker above the add-on groups — the attributes decide the price,
the add-ons are priced on top of it — and nothing is pre-answered, because the
Store API sends no default attributes to seed from.

- **Matched on `name` and `slug`, never ids.** A custom attribute, the kind a
  restaurant types in rather than registering as a taxonomy, comes back with
  `id: 0` on the attribute and on every term.
- **An empty value on a variation is a wildcard**, not a literal — WooCommerce's
  "any size".
- **The chosen variation is read back as a product**, through
  `productProvider(variationId)`, for its price *and* its stock: a size can be
  sold out while the dish is not. Cached per id, so flipping between sizes
  costs one request each and no more.
- **Add-to-cart sends the parent's id** and `variation: [{attribute, value}]`;
  the line comes back under the variation's own id.
- **The cart line shows the size**, from the item's `variation` key —
  `item_data` is empty for a variable line, so without it two sizes read as
  one dish twice.

`FINDINGS.md` has the payload's shape and the demo-data trap behind it.

### The store's own checkout fields
`GET fmp/v1/app/checkout-fields` (task 8.2, food-menu-pro#28). A store defines
its own checkout questions — "Apartment / buzzer", "Allergies" — each a text
input or a select, optionally required, optionally multi-select.

- **The key is the field's position**, published rather than derived, because
  that is what the website writes and what the admin order screen and the
  slips read back. `FINDINGS.md` has what that costs when fields are
  reordered.
- **The section is absent, not empty**, when a store has defined none, has the
  section switched off, or the route fails. `checkoutFieldsProvider` resolves
  a failure to no fields, as the add-ons provider does — a checkout that will
  not draw because an optional section could not load is worse than one
  without it.
- **Required answers go through the screen's own `Form`**, so they error in
  the same pass as the name and the phone. A select joins it as a
  `FormField`, since it is not a text input.
- **The answers live in `CheckoutDetails`**, with everything else a refused
  order hands back untouched.
- **An unanswered field is left out of the payload**, not sent empty: the
  plugin stores only non-empty answers, and a blank would write meta the slips
  would then print.

### Order history
`GET fmp/v1/app/orders` (task 7.1, food-menu-pro#24). Paged as a **bare array
with `X-WP-Total` / `X-WP-TotalPages`**, which is what `ApiClient.getPaged`
already reads — the same contract as the menu list, not an envelope.

Each row is a **summary**, not the `/app/orders/{id}` payload: number, date,
type, status (+ label and the store's own `status_color`), `is_active`,
`eta`, `item_count`, up to four items for thumbnails, and the total. Opening
an order reads the single-order route for the address, the customer and every
line's add-ons.

`?group=active|past|any` drives the design's two tabs, and `X-WP-Total` on the
active request is the number for its "Active (N)" label — no extra field and
no extra request.

**Active is defined as "not finished"**, so a store's own custom statuses are
active without anyone configuring them. Only the plugin knows which statuses
end an order; the app must not infer it from the slug.

### Changing branch with a full cart
Branches do not all serve the same menu, so a cart filled at one can hold a
dish another will not make. `BranchSwitcher`
(`features/branch/data/branch_switch.dart`) is the whole of it:

- `check(branchId)` **awaits** the cart, then asks
  `GET /fmp/v1/app/branches/{id}/unserved?products=…` which of its lines that
  branch refuses. Awaiting matters — sampling the current value answers
  "nothing to lose" for a cart that has not loaded, which is exactly the cold
  start case. See `FINDINGS.md`.
- The picker names those dishes and asks. **Cancel leaves everything alone and
  keeps the sheet open**, since the customer came to change branch and may
  want a different one.
- `commit()` removes the lines **and then** switches, so nothing is asked of
  the server while the cart it holds is one that branch would refuse.

Both halves fail **open**: a failed check switches anyway, and a failed
removal switches anyway. Stranding a customer on a branch they are trying to
leave is worse than carrying a line, and nothing incorrect gets through
either way — the plugin refuses such a cart at checkout with
`fmp_cart_item_branch` (a 409, classified as a cart failure with no retry),
and flags it in the cart response's `errors` meanwhile.

**The website's own pass is no help here.** It hangs off the
`fmp_location_id` cookie, which the app never sends.

### Adding to the cart from a card or a row
The `+` on a dish card and a menu row is `QuickAddButton`, in
`features/cart/presentation/widgets/`. One widget for both, so the rule cannot
differ between the landing screen and the menu list:

- `product.canAddDirectly` — in stock, purchasable and `!needsChoices` — goes
  straight to `cart/add-item` with no add-on payload;
- anything else opens the dish screen, including a sold-out dish, which says
  so there. Disabling the button leaves the card looking broken instead.

`QuickAddController` holds the product ids with an add in flight: a second tap
is dropped rather than queued, and the button spins. The flag is state rather
than a field on the button because the list rebuilds on every cart change,
which is exactly while an add is running.

**A successful add says nothing.** The floating cart bar is the design's own
confirmation and appears on the same frame; a snackbar would cover it, since
both are pinned to the bottom of the shell's `Scaffold`. Refusals do get a
snackbar, and an add-on refusal — which only a store on an older plugin can
produce — opens the dish screen so the choices can actually be made.

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
