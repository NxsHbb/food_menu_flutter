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
| Design | `designs/All Screens.dc.html` — 10 screens, untracked and local only |
| Plugin-side endpoints | Written here, on the `mobile-app` branches |
| Payment | **Native checkout in the app.** Cash on delivery in v1; card (Stripe) and PayPal are their own phase |
| Accounts | Required — register/login before ordering |
| v1 features | Menu browse + detail, cart + add-ons, **pickup/delivery** with slots, order tracking |

## Architecture in one paragraph
The app is a thin client. Menu reads go to WooCommerce's Store API
(`wc/store/v1`), which is public and needs no plugin changes. Cart writes go to
the Store API too, carrying the `Nonce` and `Cart-Token` headers it returns.
Anything Food Menu layers on the cart — add-on groups, order types, time slots,
branches — is not in the Store API, so Phase 3/4/5 add REST endpoints under a
new `fmp/v1/app/*` namespace on the plugin branches. Checkout is native, per
the design: the app posts the order through the Store API's checkout route,
carrying the `food-menu-pro` extension fields that Pro already registers.
Business rules
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
| 1.2 | HTTP client with env-based base URL, error mapping, and a `Nonce`/`Cart-Token` interceptor that captures and replays Store API session headers | app | done |
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
Pickup and delivery only — the design has no dine-in, which also makes QR
table ordering moot. The **write** path already exists: Pro registers a
`food-menu-pro` Store API checkout extension with `fmp_order_time_type` and the
pickup/delivery dates and times. Only the **read** path is missing.

| # | Task | Repo | Status |
|---|---|---|---|
| 5.1 | `GET /fmp/v1/app/order-types` — whether pickup and delivery are enabled, with their weekly schedules | pro | todo |
| 5.2 | `GET /fmp/v1/app/slots` — selectable slots for a type and branch, respecting slot limits and timed products. Returns the design's flat list (`ASAP (15 min)`, `12:45`, …) rather than a date+time matrix | pro | todo |
| 5.3 | `GET /fmp/v1/app/branches` — branch list with per-branch rules | free | todo |
| 5.4 | Flutter pickup/delivery toggle and slot list, driven by server availability | app | todo |
| 5.5 | Flutter branch selection, persisted and applied to menu and cart requests | app | todo |

## Phase 6 — Native checkout
The design's checkout is a single native screen: a pickup/delivery toggle, the
address block, contact details, a payment method list and an order summary.
No webview, so the earlier cart-handoff problem disappears.

| # | Task | Repo | Status |
|---|---|---|---|
| 6.1 | Flutter checkout screen: contact details, address block, order summary, per the design | app | todo |
| 6.2 | Place the order via `POST /wc/store/v1/checkout`, sending the `food-menu-pro` extension fields for order type, date and time | app | todo |
| 6.3 | Cash on delivery as the v1 payment method, with server-side validation that it is an enabled gateway | pro + app | todo |
| 6.4 | Order received screen, read back from the API after the order is placed | app | todo |
| 6.5 | Failure paths — declined order, validation errors, connectivity loss — return to a checkout that keeps its input | app | todo |

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
reservations and the visual floor plan, dine-in and QR table ordering, tips.

Deferred to **v2**, all three present in the design but each needing backend
work this phase plan does not cost:
- **Coupons** — the cart's code field and the discount line in totals.
- **Upsells** — the cart's cross-sell carousel, i.e. the Order Bumps feature.
- **Card and PayPal payment** — Stripe and PayPal need native SDK integration.

Tips and automatic discounts are server-side cart behaviour, so they may still
appear in totals returned by the Store API even though the app does not drive
them.

## Open dependencies
- **Wishlist** (design screen 10) is **undecided**. Neither plugin provides a
  wishlist, so it needs a third-party plugin or custom endpoints. Not costed in
  any phase above. Awaiting a decision on v1 or v2.
- **Payment gateways** — card and PayPal are deferred, so v1 needs cash on
  delivery enabled on the WooCommerce site. To be confirmed.