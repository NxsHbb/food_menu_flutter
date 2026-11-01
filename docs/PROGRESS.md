# Progress

Newest first. One entry per completed task.

## Decisions — wishlist, banners, search
Recorded in `PLAN.md`:
- **Wishlist is in v1, server-backed.** New endpoints on the `mobile-app`
  branch store favourites against the customer's WP user, so they follow the
  customer between devices. Added as tasks 3.5 (plugin) and 3.6 (app), placed
  in Phase 3 because the data is account-scoped and needs auth first. **The
  heart stays absent from cards and rows until 3.6.** Confirmed first that
  neither plugin has any wishlist code and no wishlist plugin is installed.
- **Banners come from WordPress posts** in a dedicated category, read through
  `wp/v2/posts`. No plugin code and no new admin UI — the team edits them in
  WordPress today. Added as task 2.5. Needs an agreed category slug. The
  design's second banner advertises a coupon code, a v2 feature, so that one
  cannot be reproduced as drawn.
- **Search suggests categories when a search returns nothing**, so "pizza"
  offers the Pizza category instead of an empty screen. Client-side against
  the already-loaded category list. Added as task 2.6.

## Task 2.5 — Banner carousel from WordPress posts
Branch `feat/banner-carousel`

- Reads posts in the **`app-banners`** category through `wp/v2/posts`: title,
  excerpt, featured image, and the first post tag as a badge. No plugin code
  and no custom fields — the team edits banners in WordPress today.
- **The category is resolved by slug, never by id.** Term ids differ between
  the dev site and production, so a hard-coded id would silently return
  nothing live. Costs one extra request, which is the right trade.
- One request fetches artwork and tags with the posts, via
  `_embed=wp:featuredmedia,wp:term`, rather than one request per banner.
- Prefers a sized rendition over `full`, which can be a multi-megabyte upload.
- **Banner failures resolve to an empty list, not an error.** A banner is
  decoration; a down posts endpoint must not take the menu with it. Nothing
  published means no carousel at all rather than an empty band.
- Set the category up on the dev site and seeded two banners using the
  design's own artwork, so this was built against real payloads. Saved as a
  fixture.

Extracted `plainText()` into `core/util/html_text.dart` and routed the two
existing copies through it. It now also decodes **numeric** entities, which
matters because `wp/v2` returns an ampersand as `&#038;` rather than `&amp;` —
the old copies would have rendered that literally.

Also tightened the screen tests: they now override the banner repository
instead of reaching the real posts endpoint and relying on the error fallback
to hide a live request.

**Still open:** a banner opens the full menu, because `wp/v2/posts` exposes
only registered meta and registering a field needs plugin code. Per-banner
targets are a small follow-up.

132 tests pass, `flutter analyze` clean.

## Task 2.4 — Food tags on the detail screen (ingredients and nutrition blocked)
Branch `feat/dish-details`

Delivered the part that is reachable and stopped short of the part that is not.

- **Food tags ship**, via WooCommerce's `product_tag` taxonomy, which the Store
  API returns as `tags` on every product. Seeded seven tags across nine dishes
  on the dev site so this was built and tested against real payloads.
- `FoodTags` renders tinted pills, with a leading icon for seven common
  dietary slugs. Matched on **slug, not label**, so renaming a tag in
  WordPress does not silently drop its icon. An unrecognised tag renders as a
  plain pill rather than getting a guessed icon.

- **Ingredients and nutrition are not buildable** and are now task 2.7,
  blocked pending a decision. The plugin stores them as `_ingredient` and
  `_nutrition` post meta on its own `food-menu` post type; the Food Data
  metabox and all four `food-menu-*` taxonomies are registered for that post
  type only, never for `product`. The app reads products, because online
  ordering requires it, so there is no path to the data — and no admin UI that
  could even enter it against a product. Full trace and three options in
  `FINDINGS.md`.

Note the tags shipped are *not* the plugin's `food-menu-tag` taxonomy, which is
equally unreachable; they are the WooCommerce equivalent.

115 tests pass, `flutter analyze` clean.

## Task 2.3 — Product detail screen
Branch `feat/product-detail`

- Hero image with scrim and close button, details card, sticky bottom bar with
  a quantity stepper and the add button carrying a live line total.
- Nested route `dish/:id` under the menu tab. A non-numeric id resolves to -1
  and lands on the screen's own not-found state rather than crashing.
- **Seeded a variable product and an out-of-stock product** on the dev site
  so this was built against real payloads instead of hand-written JSON. Both
  are saved as fixtures.

**Two API traps the real payloads exposed**, now encoded in the model:
- `low_stock_remaining` is **0** on an out-of-stock product, so rendering it
  unguarded gives "Only 0 left". `Product.lowStockWarning` returns null unless
  the dish is in stock and the count is above zero, and a test pins it.
- `is_purchasable` stays **true** when a dish is sold out, so it alone cannot
  gate the add button. `Product.isOrderable` requires stock as well.

Also: the API supplies its own `stock_availability.text` ("Out of stock"),
already translated by the site, so that wording is preferred over copy a store
owner cannot change.

A variable dish shows a **range** and asks to "Choose options" rather than
offering a line total, because no single price exists until a variation is
picked. A 404 reads "This dish is no longer on the menu." rather than a
generic network message.

Deliberately not built here, each belonging to a later task: add-on groups
(4.4), special instructions (4.5), the favourite heart (3.6), and
ingredients/nutrition/tags (2.4).

111 tests pass, `flutter analyze` clean.

## Task 2.2 — Menu list: search, category filter and pagination
Branch `feat/menu-search`

- New `/menu` screen, nested under the menu tab so the bottom bar stays and
  the tab keeps its own back stack. Reached from the landing header's search
  entry and from "See all".
- `ApiClient.getPaged` reads WordPress's `X-WP-Total` and `X-WP-TotalPages`
  headers, because the Store API reports totals as headers rather than in an
  envelope — the body alone cannot say whether another page exists. A missing
  header is treated as one page, not zero, so a header-stripping proxy does
  not make every list look empty.
- The dish count shows the **server's** total, not how many have loaded.
- Search is debounced at 350ms, but **clearing the box skips the debounce**,
  so wiping a query feels instant.
- Changing the query rebuilds the list from page 1 rather than appending, and
  a page that lands after the query changed is discarded.
- A failed later page keeps the loaded rows on screen and offers a retry,
  instead of blanking the list.
- `DishRow` strips HTML from `short_description` with a small tag/entity
  replacement rather than pulling in a parser for one line of text.

**A search finding worth a decision:** WooCommerce's `search` matches product
names, not categories. Searching **"pizza" returns nothing** on the seeded
menu, even though there is a Pizza category holding Margherita and Pepperoni.
A customer typing a cuisine rather than a dish name hits an empty screen.
Fixable by also matching category names and offering them as suggestions, but
that goes beyond the design, so it is flagged rather than built.

**Three test-writing traps worth recording**, all of which produced false
failures before the assertions were corrected:
- `ListView` builds lazily, so counting rendered `DishRow` widgets measures
  the viewport, not the page size.
- The count header is disposed once scrolled out, so it cannot be asserted
  after a fling.
- `find.text('Dish 7')` also matches the search field when the query is a
  dish name, so row assertions are scoped to `DishRow`.

96 tests pass, `flutter analyze` clean.

## Task 2.1 — Menu landing screen and categories
Branch `feat/menu-landing`

- `MenuRepository` reads `products` and `products/categories` from the Store
  API. Both are public, so the menu loads before anyone signs in. Verified the
  exact queries against the live site, including `hide_empty` and
  `catalog_visibility=catalog`, so the menu never lists a dish that fails at
  add-to-cart.
- Empty categories are filtered in the repository, not the UI: a chip leading
  to an empty list is never useful, and only this layer sees the count.
- Screen renders the design's red header (address, greeting, search entry),
  the category chip row with a leading **All** chip, a section title that
  follows the selection, and a responsive dish grid. Pull to refresh.
- `DishCard` shows image, name, rating, price and the add button. A dish
  needing choices routes to the detail screen rather than disabling its add
  button, which would read as out of stock.
- The rating row is replaced by "No reviews yet" at zero reviews, because
  "★ 0.0 (0)" reads as a bad score rather than no score.

**Two layout bugs the tests caught**, both fixed structurally rather than by
tuning numbers:
- The card overflowed 11px vertically with a fixed image aspect ratio. The
  image is now `Expanded`, so it absorbs whatever height the text block
  leaves — which changes with the platform text scale.
- The price row overflowed 24px horizontally on a discounted dish, where two
  prices sit side by side. It is a `Wrap` now, so the struck price drops
  below on a narrow card.

**Three things the design shows that are deliberately not built**, because no
data source exists:
- the **promotional banner carousel** — nothing in either plugin supplies
  banners, the design's content is hard-coded, and one banner advertises a
  coupon code, which is v2;
- the **favourite heart** on each card — needs the wishlist decision;
- the **per-dish prep time** — no Store API field supplies it.

Faking any of them would put a number on screen the backend cannot stand
behind. The header's address and greeting are placeholders for the same
reason, pending branches (5.5) and accounts (3.3), and are passed in from the
screen so the invented copy sits in one visible place.

84 tests pass, `flutter analyze` clean.

## Fix — rebuild dark mode from the design's own theme map
Branch `fix/dark-mode-from-design`

A second design export, `designs/Food Ordering App.html`, turned up carrying a
real `THEME` object with `light` and `dark` sets over the same role names,
applied as CSS custom properties. It supersedes the dark palette derived in
task 1.3, which was wrong in three ways:

- **The brand red does not change in dark mode.** The design declares
  `RED = '#F20800'` as a constant *outside* the theme map. Task 1.3 lifted it
  to `#FF5436` for contrast; the design does not. A test now pins it in both
  modes so the "improvement" cannot come back.
- **The dark ramp is cool, not warm.** Real values are `#0A0A0A` / `#111112` /
  `#1C1C1E` / `#2C2C2E`. Task 1.3 guessed warm browns to match the warm light
  canvas.
- **Nine roles were missing**: `muted2`, `chip`, `field`, `contrast`, `ring`,
  and the `okbg`/`okfg` and `warnbg`/`warnfg` semantic pairs.

Token and palette role names now mirror the design's map one-to-one, so a
value can be checked against the design without translating vocabulary. Two
light values also corrected: `muted` is `#6E6E6E` (not `#7A7A7A`, which came
from inline styles in the earlier export).

`AppPalette.lerp` and `copyWith` both drive off a single role list, so a role
added to the class cannot be silently forgotten by either.

**One invented value remains**: the design's light `ring` is
`var(--ring)`, self-referential and defined nowhere, so light mode has no ring
colour to copy. `#D8D8D8` is my choice and is flagged in `AppTokens` for the
designer to confirm. Dark mode uses the design's `#55555A`.

70 tests pass, `flutter analyze` clean.

## Task 1.4 — Store API models
Branch `feat/store-api-models`

- **`Money` holds amounts as integer minor units.** The Store API sends prices
  as *strings in minor units* beside a `currency_minor_unit` exponent, so
  `"395"` is **$3.95**, not $395. Parsing those as a decimal is the easiest
  way to ship a menu priced a hundred times too high. Amounts stay `int` end
  to end, so totals cannot drift by a cent — there is a test adding one cent a
  hundred times and landing on exactly $1.00.
- `Currency` is parsed from whichever price block is at hand, because the API
  repeats the metadata on every one. Formatting uses the site's own separators,
  prefix and suffix, so a store set to `1.234,56 kr` renders that way with no
  locale knowledge in the app. Covered for 0-, 2- and 3-decimal currencies.
- `Product.prices.isDiscounted` is derived from the prices rather than the
  `on_sale` flag, because the two disagree when a scheduled sale lapses but
  leaves `sale_price` populated.
- `CartItem` is keyed by the server's `key`, not the product `id`: the same
  dish added twice with different add-ons is two lines sharing one id, so
  updates and removals must address the key.
- `CartItemData` is where Phase 4's add-ons will surface — the Pro plugin
  writes them via `woocommerce_get_item_data` and the Store API returns them
  verbatim.
- `totals.totalShipping` is **nullable**, not zero: a pickup order never
  calculates shipping, and zero would read as free delivery.
- `QuantityLimits.clamp` steps **down** to the nearest allowed multiple, so a
  stepper never silently charges for more than was asked.
- Tests run against **fixtures captured from the running dev site**
  (`test/fixtures/`), so they fail if the Store API's shape changes rather
  than if invented JSON does. 66 tests pass, `flutter analyze` clean.

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
