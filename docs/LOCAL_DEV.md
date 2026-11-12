# Local development environment

The WordPress backend the app talks to. It lives **outside** this repo so
nothing WordPress-related enters the Flutter git tree.

| Item | Value |
|---|---|
| Site root | `~/dev/wp/foodmenu-dev` |
| URL | `http://192.168.0.171:8080` (LAN IP, not `localhost` — see below) |
| WordPress | 7.1.4 |
| WooCommerce | 11.2.1 |
| Admin | `admin` / `Admin@2020##` |
| DB | MySQL 8.2 (Homebrew), database `foodmenu_dev`, user `root`, no password |
| PHP | 8.3.1, built-in server |
| wp-cli | `~/.local/bin/wp` (wrapper raising `memory_limit` to 1G) |

## Why the LAN IP and not localhost
An Android emulator reaches the host at `10.0.2.2`; a physical device needs the
machine's LAN address. `siteurl`/`home` are set to the LAN IP so REST responses
contain URLs a device can actually fetch. If the IP changes, update both:

```sh
wp option update siteurl 'http://<new-ip>:8080'
wp option update home    'http://<new-ip>:8080'
```

## Starting it
```sh
brew services start mysql
cd ~/dev/wp/foodmenu-dev
php -d memory_limit=512M -S 0.0.0.0:8080 -t . ~/.local/bin/router.php
```
`router.php` is a two-line shim so PHP's built-in server honours WordPress
pretty permalinks; static files are served directly, everything else goes to
`index.php`.

## Plugins
Both are git clones in `wp-content/plugins/`, each on a **`mobile-app`** branch
cut from `main`:

| Plugin | Version | Repo |
|---|---|---|
| `tlp-food-menu` (free) | 6.0.7 | `radiustheme/tlp-food-menu` |
| `food-menu-pro` | 6.0.6.1 | `radiustheme/food-menu-pro` |

`vendor/` is committed in both, so no `composer install` is needed. Neither has
`node_modules`; run `npm install && npm run dev` in a plugin only when JS/CSS
source needs rebuilding. No license key is required — activation unlocks the
Pro features.

## Configuration applied
- `fm_food_menu_type = online_ordering` (WooCommerce products as the data
  source, which is the mode online ordering requires).
- Enabled: product add-ons, kitchen monitor, custom order statuses, QR table
  ordering, timed products, order timeline, pickup, delivery, dine-in.
- Currency USD, taxes off.
- **Cash on delivery enabled** (task 6.2). The Store API refuses an order when
  the store has no gateway at all, so the app cannot check out without it:
  `wp wc payment_gateway update cod --enabled=true --user=1`.
- A handful of app-placed orders for `customer@foodmenu.test` are left in the
  store (delivery and pickup, all cash on delivery) as real data for Phase 7's
  order history, and two of them are captured as `order_*.json` fixtures.
- Only `cod` is enabled. Turning `bacs` on is how task 6.3's "enabled but the
  app cannot finish it" row was checked; it was turned back off afterwards.
- **Add-on test data** (tasks 4.1 and 4.2): three groups on *Fresh Lemonade* — a
  required radio with price deltas, a checkbox with `max_selection` 3 and a
  deliberately non-numeric price, and a textarea with a placeholder and char
  limit — plus two entries in `global_addon_settings`, one targeted at *Iced
  Latte* and one applying to every dish. The lemonade also has
  `_fmp_pa_global_override` set, so it uses its own groups and ignores the
  globals; that is the either/or the endpoint reproduces. **On a simple
  product deliberately** — the website never renders add-ons on a variable
  one, so *Build Your Pizza* was the wrong home for them.
- **Task 5.2 seeded and then restored** a pickup/delivery schedule, a branch
  term with its own hours, a timed-product rule, a per-product order limit and
  four test orders. The settings option was backed up to JSON first and diffed
  against it afterwards; `fmp_food_location_popup` was switched back off, which
  also unregisters the `tpl-food-location` taxonomy. Nothing from it remains.
- **Order statuses, for task 7.1's Active/Past tabs.** The six test orders on
  `customer@foodmenu.test` were all `processing`, which left the Past tab
  empty and task 7.2 unverifiable. Orders **59 → `completed`** and
  **60 → `cancelled`**; both were `processing` before. Kept rather than
  restored, because the history screen needs both tabs populated.
- **Task 6.6 seeded and then restored** two branch terms (Downtown, Uptown)
  with `fmp_food_location_popup` on, Garlic Bread filed to Downtown only,
  Margherita to both and Build Your Pizza to Uptown. The settings option was
  backed up to JSON and diffed clean afterwards, the terms deleted and all 18
  products are visible again. Nothing from it remains.
- **Five Order Extra Fields seeded for task 8.2**, in
  `fmp_order_custom_fields`: a required text ("Apartment / buzzer"), a single
  select ("How did you hear about us?"), a multi-select ("Allergies"), and
  **two deliberately unusable** — one with no label and one select with no
  options — so the route's dropping of them is exercised against real data.
  Kept: without them the app's Additional information section has nothing to
  draw. They render on the site's own checkout too, which is what a store
  with extra fields looks like.
- **Build Your Pizza's variations were repaired for task 8.1.** All three
  sizes had **empty** attribute values, which WooCommerce reads as "any" —
  three variations matching every size at three different prices — and the
  attribute was named `pa_size` as if it were a taxonomy. Now: a custom
  attribute called `Size`, with 28/29/30 carrying `Small`, `Medium`, `Large`.
  Kept, not restored: the old state was broken rather than deliberate, and
  the live demo site is likely seeded the same way — worth checking before
  the iPhone is pointed at it.
- **Order 70, kept for task 7.4.** Placed through the app's own flow with a
  radio, two checkboxes and a textarea on *Fresh Lemonade*, so it carries a
  recorded `_fmp_addon_selection` and reorders cleanly. Its other line, an
  *Iced Latte* added to the cart before 7.4 existed, has none — which makes
  the order the **mixed case** the reorder screen has to draw: `any` true,
  `all` false. Every other order on the store predates 7.4 and refuses
  entirely, because the dev site has a global add-on group matching every
  dish.
- **A shipping zone, kept, for tasks 8.5 and 8.6.** "Delaware" (US:DE, which
  is where the demo addresses are) with **two flat rates**: *Standard
  delivery* $4.95 and *Express delivery* $9.95. Before it the store had no
  zone and no method at all, so every cart answered `shipping_rates: []` and
  nothing about delivery pricing could be exercised. **It changes delivery
  totals** — a delivery order now costs $4.95 more than the dishes — which is
  what a real store looks like. `cart_with_shipping.json` is captured from it.
- **A dish image on every product, and a wider catalogue.** Seeded so UI work
  can be reviewed from a screenshot instead of a payload. The store went from
  18 products to **28**.

  The images are **real food photographs**, one per dish, from
  [TheMealDB](https://www.themealdb.com) and, for the drinks,
  [TheCocktailDB](https://www.thecocktaildb.com) — both free, no key, and both
  serving photos of the dish they name. 45–180 KB JPEGs at photographic
  aspect ratios, which is what a real store's media library looks like.

  They replaced a first pass of **generated gradient tiles**, which were
  legible but read as coloured blocks rather than food and so were no use for
  judging a card. The tiles are gone from the media library, not merely
  unlinked.

  Matching is by search term per dish, picking the first result not already
  used, so no two dishes share a photo. A few are approximate rather than
  literal — *Pepperoni* is a cassava pizza, *Espresso* is an espresso martini,
  *Tiramisu* is a trifle — which is fine for judging layout and would not be
  for judging copy. If a photo ever needs replacing, the dish's own file in
  `wp-content/uploads/2026/11/` is named after it.

  **`Garlic Bread` is deliberately left with no image**, so the placeholder
  path stays exercised.

  The ten new dishes were each chosen for a case the UI has to handle:

  | Dish | What it is there for |
  |---|---|
  | Chef's Slow-Braised Short Rib with Truffle Mash and Winter Greens | A name long enough to wrap and truncate. **It also carries an apostrophe**, which is how the entity bug in `FINDINGS.md` was found |
  | Loaded Fries | A WooCommerce sale *inside* the 15% discounted category: 8.50 to 7.00 to **5.95**, the two mechanisms stacking |
  | Sunrise Breakfast Platter | Timed, served 00:00–11:00, so it is **available** at the dev site's clock |
  | Midnight Ramen | Timed, served 22:00–23:59, so it is **unavailable** and draws the note |
  | Seasonal Soup | A second out-of-stock dish, in a different category |
  | Espresso | The cheapest thing on the menu, $1.95 |
  | Wagyu Tasting Menu | $125.00 — four figures in minor units, for the thousand separator |
  | Mango Lassi | The third stock state, on backorder |
  | Tiramisu | Carries three reviews, so a card shows a rating rather than "No reviews yet" |
  | Family Feast Box | A second variable dish — *Feeds* Two/Four/Six at 24/42/58, with **explicit** attribute values, per task 8.1 |

  Reviews were also added to *Double Smash* (4.5), *Margherita* (4.0) and
  *Crispy Chicken Burger* (4.0), so ratings and the empty state both appear in
  one screenful.

- **Two timed rules added, and a thing worth knowing about `action`.** A
  rule's `action` is only ever `show` or `hide`:
  `TimedProducts::is_rule_unavailable()` tests for exactly those two strings
  and **anything else silently never matches**. A rule written with
  `action: disable` — which looks plausible, because `disable` is a valid
  value of the *global* `fmp_timed_products_behavior` — is a rule that does
  nothing at all, with no warning anywhere. `show` means the window is when
  the dish **is** served; `hide` means the window is when it is not.

- **An automatic discount, kept, for Phase 9.** 15% off the **Burgers**
  category (`fmp_include_cat: [18]`, `fmp_discount_percentage: 15`,
  `fmp_applicable_discount: product_total`, `fmp_discount_badge_display:
  everywhere`). **Corrected during task 9.2** from `all`, which is not one
  of the two values the plugin tests for and so showed no badge at all —
  see `FINDINGS.md`. Before it the store had no discount configured at all, so the whole
  of Phase 9 was unexercisable — the same hole task 8.5 found with shipping.
  **It changes menu prices**: the three burgers now read $8.29/$9.75,
  $11.82/$13.90 and $8.93/$10.50, charged over struck. *Crispy Chicken
  Burger* is the useful one, because it is **also** on a WooCommerce sale
  ($11.25 down to $9.75), so it is the case where the two discount mechanisms
  stack and only the inner pair should be shown.

- **One timed-product rule kept for task 8.3**, in `fmp_timed_products`:
  "Off the menu late", hiding *Mushroom Risotto* between 11:00 pm and
  11:59 pm site time. Chosen because it blocks nothing during working hours
  and still gives the app a dish whose payload carries a schedule note. The
  second rule the task used — Margherita servable only 2–4 am — was deleted
  after the device pass, along with the `disappear` behaviour it was tested
  under; `fmp_timed_products_behavior` is unset again, which reads as
  `disable`. **The site's timezone is UTC**, so a rule's hours are UTC and
  not the phone's.
- `woocommerce_enable_myaccount_registration = yes`. **Off by default**, and
  task 3.1's register endpoint follows this setting rather than overriding it,
  so registration returns 403 without it.

## Demo data
Seeded via wp-cli, idempotent on title, so re-running a seed script is safe.

| What | Count | Notes |
|---|---|---|
| Products | 18 | incl. **1 variable** (Build Your Pizza, 3 sizes) and **1 out of stock** (Sold Out Special) |
| Product categories | 7 | Starters, Pizza, Burgers, Main Course, Desserts, Drinks |
| Product tags | 7 | Vegetarian, Vegan, Spicy, Gluten Free, Healthy, Popular, Shareable |
| Banner posts | 2 | in the `app-banners` category, with featured images from `designs/img/` |
| Ingredient / nutrition / unit terms | 4 each | attached to **Margherita** (product 14) as sample food data |
| Customer account | 1 | `customer@foodmenu.test` / `Customer@2020##`, created through the app's own register endpoint |
| Saved addresses | 2 | `Home` (default, Celina DE) and `Work` (Dover DE) on that customer, matching the design's data |

The awkward cases are deliberate: a variable product exercises price ranges
and "Choose options", the out-of-stock one exercises `is_purchasable: true`
alongside `is_in_stock: false`, and Margherita is the only dish carrying
ingredients and nutrition.

## Dev-only mu-plugin
`wp-content/mu-plugins/00-dev-app-passwords.php` forces
`wp_is_application_passwords_available` to true, because core gates Application
Passwords behind HTTPS and this site is plain HTTP. **Local only — never ship
this.**

## Running the app against this site
```sh
xcrun simctl list devices available | grep iPhone     # pick one
xcrun simctl boot <id> && open -a Simulator
flutter run -d <id> --dart-define=FOOD_MENU_BASE_URL=http://192.168.0.171:8080
xcrun simctl io booted screenshot /tmp/shot.png
```

iOS needs `NSAllowsLocalNetworking`, already set in `ios/Runner/Info.plist`,
or App Transport Security blocks the HTTP site outright. **Android has no
equivalent yet** and cannot reach this site.

`simctl` cannot tap, so to reach a screen behind navigation, temporarily set
the router's `initialLocation` to that route, restart, screenshot, and revert.
The sign-in and register screens are *pushed*, so this is the only way to see
them. Dark mode is `xcrun simctl ui booted appearance dark`.

A state that needs typed input — a validation error, a rejected sign-in — cannot
be reached this way at all. Those are covered by widget tests instead.

## Exercising the auth endpoints
The four routes from task 3.1 need no nonce and no cookie:

```sh
B='http://192.168.0.171:8080/?rest_route='

# Sign in and keep the tokens.
curl -s -X POST "$B/fmp/v1/app/auth/login" -H 'Content-Type: application/json' \
  -d '{"username":"customer@foodmenu.test","password":"Customer@2020##"}'

# Use the access token anywhere the current user matters.
curl -s "$B/wp/v2/users/me" -H "Authorization: Bearer <access_token>"
```

Read and edit the profile and address book:

```sh
curl -s "$B/fmp/v1/app/me" -H "Authorization: Bearer <access_token>"

# PUT is partial, but `addresses` replaces the whole book.
curl -s -X PUT "$B/fmp/v1/app/me" -H "Authorization: Bearer <access_token>" \
  -H 'Content-Type: application/json' -d '{"phone":"+8801700000000"}'
```

Read and edit the wishlist:

```sh
curl -s "$B/fmp/v1/app/wishlist" -H "Authorization: Bearer <access_token>"

curl -s -X POST "$B/fmp/v1/app/wishlist" -H "Authorization: Bearer <access_token>" \
  -H 'Content-Type: application/json' -d '{"product_id":26}'

# The ID goes in the path, not the body.
curl -s -X DELETE "$B/fmp/v1/app/wishlist/26" -H "Authorization: Bearer <access_token>"
```

Three things to know while testing:

- **Rate limits are real and keyed on your IP.** Repeated failed logins will
  start returning 429. Clear them with `wp transient delete --all`.
- **Do not replay a refresh token.** Rotation is one-shot; sending a spent
  refresh token revokes the whole session on purpose. Mint a new session with
  `/login` rather than reusing an old response.
- **A `PUT` with an `addresses` key replaces the book**, so a careless test
  payload wipes the seeded Home/Work pair. Re-seed with the two addresses in
  the demo data table above.

## Running on physical devices
Both are more informative than a simulator, and Android is the only target that
can be driven end to end from a terminal.

```sh
flutter devices                      # find the ids
flutter run -d <id> --dart-define=FOOD_MENU_BASE_URL=http://192.168.0.171:8080
```

The device reaches this Mac over the LAN, so `FOOD_MENU_BASE_URL` must be the
LAN IP — the same reason `siteurl` is set to it.

### Android
Debug builds permit cleartext HTTP via
`android/app/src/debug/res/xml/network_security_config.xml`. Release builds do
not, by design.

Driving the UI:
```sh
adb exec-out screencap -p > /tmp/shot.png
adb shell input tap <x> <y>
adb shell input keyevent 67            # backspace
adb shell "input text 'A@2020##'"      # single-quote, or the device shell eats #
```
**`input text` silently drops and duplicates characters** in longer strings.
Type character by character with a short sleep when the value matters, and read
the field back before believing a login failure.

### iOS
Device builds need `DEVELOPMENT_TEAM = M34L8S85ZF` in the Xcode project —
already set. `com.foodmenu` cannot be registered under any other team, so a
different account means a different bundle ID. See `FINDINGS.md`.

**Always use `--profile` on a physical iPhone.** A debug build cannot be
launched from the home screen on iOS 14+; tapping the icon shows a black
placeholder and the Dart code never runs, which looks exactly like a broken
app.

**Point the iPhone at the live site, not the LAN.** Reaching a LAN address from
a handset needs the Local Network privacy permission on top of ATS, and it
fails silently when denied:

```sh
flutter run --profile -d <iphone-id> \
  --dart-define=FOOD_MENU_BASE_URL=https://radiustheme.net/demos/food-menu
```

There is **no CLI screenshot or input API** for a physical iPhone, so visual
checks there are either the simulator or a person looking at the screen.

## Live site — the iOS testing target
`https://radiustheme.net/demos/food-menu/`. **No longer read-only**: it runs the
merged Pro plugin over HTTPS, which makes it the only practical backend for a
physical iPhone, and it has been seeded to mirror the local demo data.

| What | Count |
|---|---|
| Products | 16, incl. **Build Your Pizza** (variable, 3 sizes) and **Sold Out Special** (out of stock) |
| On sale | 3 — Biryani, Pepperoni Feast, Chicken Wings |
| Categories / tags | 6 / 7 |
| Banner posts | 2, in `app-banners` (category 29) |
| Test customer | `claude.devicetest@foodmenu.test` / `DeviceTest@2026##` |

Currency is **BDT** and the store country **BD**, so prices there read
differently from the local site's USD.

Seeding was done over the REST API with a `wp-login.php` cookie plus a
`rest-nonce`, since the site has no Application Password set up. The scripts
are idempotent on name, so re-running them is safe.
