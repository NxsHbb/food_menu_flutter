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

There is **no CLI screenshot or input API** for a physical iPhone, so visual
checks there are either the simulator or a person looking at the screen.

## Live reference site
`https://radiustheme.net/demos/food-menu/` — useful for comparing intended
behaviour. Treat it as read-only; do not seed or reconfigure it.
