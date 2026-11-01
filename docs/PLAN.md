# Plan

Phases and tasks. Status: `todo` / `in-progress` / `done`.

**Product:** customer-facing mobile app for the Food Menu WordPress plugin.
Staff/kitchen operations are explicitly out of scope for v1.

**Repo column:** `app` = this repo. `free` = `radiustheme/tlp-food-menu`,
`pro` = `radiustheme/food-menu-pro` — both on their `mobile-app` branch.

## Agreed decisions
| Decision | Choice |
|---|---|
| Audience | Customer app (v1) |
| Plugin-side endpoints | Written here, on the `mobile-app` branches |
| Payment | Hand off to the site's WooCommerce checkout in a webview |
| Accounts | Required — register/login before ordering |
| v1 features | Menu browse + detail, cart + add-ons, pickup/delivery/dine-in with slots, order tracking |

## Architecture in one paragraph
The app is a thin client. Menu reads go to WooCommerce's Store API
(`wc/store/v1`), which is public and needs no plugin changes. Cart writes go to
the Store API too, carrying the `Nonce` and `Cart-Token` headers it returns.
Anything Food Menu layers on the cart — add-on groups, order types, time slots,
branches — is not in the Store API, so Phase 3/4/5 add REST endpoints under a
new `fmp/v1/app/*` namespace on the plugin branches. Checkout is **not**
reimplemented: the app mints a one-time handoff URL and opens the site's own
checkout in a webview, so every existing gateway keeps working. Business rules
(pricing, slot caps, discount math, status transitions) stay server-side
throughout; the app renders and calls.

## Phase 0 — Project setup
| # | Task | Repo | Status |
|---|---|---|---|
| 0.1 | Flutter scaffold, mobile-only, bundle ID `com.foodmenu` | app | done |
| 0.2 | Display name, attribution guard, process docs | app | done |
| 0.3 | Local WordPress site, both plugins cloned on `mobile-app` branches, demo data, API survey | app | done |

## Phase 1 — Flutter foundations
| # | Task | Repo | Status |
|---|---|---|---|
| 1.1 | Choose and wire architecture: state management, DI, routing, folder layout; record the choice in `CONTEXT.md` | app | done |
| 1.2 | HTTP client with env-based base URL, error mapping, and a `Nonce`/`Cart-Token` interceptor that captures and replays Store API session headers | app | todo |
| 1.3 | Theme and design system: colors, typography, spacing, light/dark, shared widgets | app | todo |
| 1.4 | Store API models for product, category, cart, cart item, totals, with serialization tests | app | todo |

## Phase 2 — Menu browsing
Runs entirely against today's Store API. No plugin changes.

| # | Task | Repo | Status |
|---|---|---|---|
| 2.1 | Category list and menu landing screen | app | todo |
| 2.2 | Product list with pagination, category filter and search | app | todo |
| 2.3 | Product detail: images, description, variable and sale pricing, stock state | app | todo |
| 2.4 | Ingredients, nutrition and food tags on the detail screen | app | todo |

## Phase 3 — Customer accounts
`fmp/v1` is nonce-gated and unusable from a mobile client (see `FINDINGS.md`),
so customer auth is new work. No nonce gate on these routes — token only.

| # | Task | Repo | Status |
|---|---|---|---|
| 3.1 | `POST /fmp/v1/app/auth/register`, `/login`, `/refresh`, `/logout` — token issue and rotation, rate limited | pro | todo |
| 3.2 | `GET/PUT /fmp/v1/app/me` — profile and saved addresses | pro | todo |
| 3.3 | Flutter auth flow: register, login, validation, error states | app | todo |
| 3.4 | Secure token storage, auto-refresh, and logout-on-401 across the client | app | todo |

## Phase 4 — Cart and add-ons
Store API `cart/add-item` accepts only `id`, `quantity`, `variation`, so add-on
selections cannot be submitted as-is. Add-on definitions live in the
`fmp_product_addons` option and are not exposed anywhere.

| # | Task | Repo | Status |
|---|---|---|---|
| 4.1 | `GET /fmp/v1/app/products/{id}/addons` — add-on groups, field types, required flags, price deltas | pro | todo |
| 4.2 | Accept add-on selections on Store API add-to-cart via `woocommerce_store_api_add_to_cart_data`, validating required groups server-side | pro | todo |
| 4.3 | Surface chosen add-ons and their price effect in Store API cart item responses | pro | todo |
| 4.4 | Flutter add-on selection UI on the product detail screen, with live price preview | app | todo |
| 4.5 | Flutter cart: add, update quantity, remove, totals, empty state | app | todo |
| 4.6 | Floating mini cart, persisted across app restarts via the `Cart-Token` | app | todo |

## Phase 5 — Order type and time slots
The **write** path already exists: Pro registers a `food-menu-pro` Store API
checkout extension with `fmp_order_time_type`, pickup/delivery/dine-in dates and
times, table and custom fields. Only the **read** path is missing.

| # | Task | Repo | Status |
|---|---|---|---|
| 5.1 | `GET /fmp/v1/app/order-types` — which of pickup/delivery/dine-in are enabled, with their weekly schedules | pro | todo |
| 5.2 | `GET /fmp/v1/app/slots` — selectable dates and times for a type and branch, respecting slot limits and timed products | pro | todo |
| 5.3 | `GET /fmp/v1/app/branches` — branch list with per-branch rules | free | todo |
| 5.4 | Flutter order type selector with date and time slot pickers, driven by server availability | app | todo |
| 5.5 | Flutter branch selection, persisted and applied to menu and cart requests | app | todo |

## Phase 6 — Checkout handoff
Accounts are required and payment is a webview, so the webview must open
already authenticated **and** carrying the cart the app built as a guest. That
is the crux of this phase.

| # | Task | Repo | Status |
|---|---|---|---|
| 6.1 | `POST /fmp/v1/app/checkout/handoff` — exchange an app token + `Cart-Token` for a single-use, short-lived URL that logs the webview in and adopts the cart into that session | pro | todo |
| 6.2 | Flutter checkout webview: open the handoff URL, detect success and failure, block navigation outside the site | app | todo |
| 6.3 | Order confirmation screen read back from the API after the webview reports success | app | todo |
| 6.4 | Cancel, back and payment-failure paths return to a cart that still has its contents | app | todo |

## Phase 7 — Orders and tracking
| # | Task | Repo | Status |
|---|---|---|---|
| 7.1 | `GET /fmp/v1/app/orders` — order history for the signed-in customer | pro | todo |
| 7.2 | Flutter order history and order detail screens | app | todo |
| 7.3 | Live order tracking against the existing public `GET /fmp/v1/track/{token}`, with the status timeline | app | todo |

## Phase 8 — Hardening and release
| # | Task | Repo | Status |
|---|---|---|---|
| 8.1 | Offline and error handling pass: retries, empty states, connectivity loss | app | todo |
| 8.2 | Widget and integration test coverage for cart, add-ons, slots and checkout handoff | app | todo |
| 8.3 | App icon, splash, display name, permissions audit on both platforms | app | todo |
| 8.4 | Release builds, signing, and store metadata | app | todo |

## Deliberately out of scope for v1
Staff dashboard, kitchen monitor, inventory, POS printing, role manager,
reservations and the visual floor plan, QR table ordering, order bumps, tips,
and automatic discounts. Tips and discounts are server-side cart behaviour, so
they will appear in the webview checkout totals even though the app does not
drive them.

## Open dependencies
- **Design** has not been supplied. Phase 1.3 and every Flutter screen task
  needs it; without it those tasks will produce a plain, functional UI that
  then needs rework.
- **Payment gateway** on the live site determines how reliably 6.2 can detect
  success. To be confirmed against `radiustheme.net`.
