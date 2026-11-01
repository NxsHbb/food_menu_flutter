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

## Demo data
16 products across 6 categories (Starters, Pizza, Burgers, Main Course,
Desserts, Drinks), four of them on sale. Seeded with
`WC_Product_Simple` via wp-cli; the script is idempotent on product title.

## Dev-only mu-plugin
`wp-content/mu-plugins/00-dev-app-passwords.php` forces
`wp_is_application_passwords_available` to true, because core gates Application
Passwords behind HTTPS and this site is plain HTTP. **Local only — never ship
this.**

## Live reference site
`https://radiustheme.net/demos/food-menu/` — useful for comparing intended
behaviour. Treat it as read-only; do not seed or reconfigure it.
