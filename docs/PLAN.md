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
| v1 features | Menu browse + detail, cart + add-ons, **pickup/delivery** with slots, order tracking, wishlist |
| Wishlist | **In v1, server-backed.** New endpoints on the `mobile-app` branch, favourites stored against the customer's WP user. Depends on Phase 3 accounts |
| Banners | **WordPress posts in a category.** Reuses `wp/v2/posts`, edited in WordPress today, no plugin code |
| Search | Names only, with **category suggestions when a search returns nothing** |
| Saved addresses | **A labelled address book**, stored by the plugin, with the default **mirrored into WooCommerce billing/shipping** so the web account page, order emails and admin all stay correct |
| Address screens | **Not in the design** — the address list and add/edit form are drawn to match the app's existing design language |
| Cart vs. branch | **Warn at the switch, then drop.** The app asks before changing branch, naming the dishes the new one will not serve, and removes them only on confirm. The server refuses such a cart at checkout regardless |
| Auth screens | **Also not in the design** — it has no sign-in or register screen at all, so both are drawn from the design's own vocabulary |

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
| 1.3 | Theme and design system: colors, typography, spacing, light/dark, shared widgets | app | done |
| 1.4 | Store API models for product, category, cart, cart item, totals, with serialization tests | app | done |

## Phase 2 — Menu browsing
Runs entirely against today's Store API. No plugin changes.

| # | Task | Repo | Status |
|---|---|---|---|
| 2.1 | Category list and menu landing screen | app | done |
| 2.2 | Product list with pagination, category filter and search | app | done |
| 2.3 | Product detail: images, description, variable and sale pricing, stock state | app | done |
| 2.4 | Food tags on the detail screen, via `product_tag` | app | done |
| 2.7 | Ingredients and nutrition on the detail screen — plugin extended to allow both on WooCommerce products and expose them via the Store API (food-menu-pro#5), then rendered in the app | pro + app | done |
| 2.5 | Banner carousel on the landing screen, sourced from WordPress posts in a dedicated category via `wp/v2/posts` | app | done |
| 2.6 | Category suggestions when a search returns no dishes, so "pizza" offers the Pizza category instead of an empty screen | app | done |

## Phase 3 — Customer accounts
`fmp/v1` is nonce-gated and unusable from a mobile client (see `FINDINGS.md`),
so customer auth is new work. No nonce gate on these routes — token only.

| # | Task | Repo | Status |
|---|---|---|---|
| 3.1 | `POST /fmp/v1/app/auth/register`, `/login`, `/refresh`, `/logout` — token issue and rotation, rate limited | pro | done |
| 3.2 | `GET/PUT /fmp/v1/app/me` — profile and saved addresses | pro | done |
| 3.3 | Flutter auth flow: register, login, validation, error states | app | done |
| 3.4 | Secure token storage, auto-refresh, and logout-on-401 across the client | app | done |
| 3.5 | `GET/POST/DELETE /fmp/v1/app/wishlist` — favourites against the customer's WP user | pro | done |
| 3.6 | Wishlist screen (design 10) and the heart on dish cards and rows | app | done |
| 3.7 | Account screen (design 9) and the Edit profile form | app | done |
| 3.8 | `GET /fmp/v1/app/address-fields` — allowed countries, their states, which fields are required and WooCommerce's own labels, so the form is not hard-coded | pro | done |
| 3.9 | Address book: list, add/edit form, set default — **designed to match**, since the design stubs both | app | done |
| 3.10 | `POST /fmp/v1/app/auth/{forgot-password,reset-password,change-password,change-email}` — the account-security group, agreed after it came up in 3.1, 3.2, 3.7 and 3.9 | pro | done |
| 3.11 | Forgot password on sign-in, and a Security section on the account screen — **designed to match**, since the design has no auth screens | app | done |

## Phase 4 — Cart and add-ons
Store API `cart/add-item` accepts only `id`, `quantity`, `variation`, so add-on
selections cannot be submitted as-is. Add-on definitions live in
`_fmp_product_addons` **product meta**, or in the `global_addon_settings`
option for store-wide ones — not in a single option as first assumed — and
were not exposed anywhere until task 4.1.

Task 4.7 needed **Pro** as well as the app, which the plan had not expected:
nothing on a Store API product said whether a dish's add-ons were optional, so
the app could not tell a one-tap dish from one the server would refuse.

| # | Task | Repo | Status |
|---|---|---|---|
| 4.1 | `GET /fmp/v1/app/products/{id}/addons` — add-on groups, field types, required flags, price deltas | pro | done |
| 4.2 | Accept add-on selections on Store API add-to-cart via `woocommerce_store_api_add_to_cart_data`, validating required groups server-side | pro | done |
| 4.3 | Surface chosen add-ons and their price effect in Store API cart item responses | pro | done |
| 4.4 | Flutter add-on selection UI on the product detail screen, with live price preview | app | done |
| 4.5 | Flutter cart: add, update quantity, remove, totals, empty state | app | done |
| 4.6 | Floating mini cart, persisted across app restarts via the `Cart-Token` | app | done |
| 4.7 | Wire the **quick-add `+`** on dish cards and menu rows. Found while verifying 6.2: it still answered "Add to cart is not built yet", a Phase 2 stand-in that Phase 4 never picked up. Grew a plugin half: `canAddDirectly` was gated on WooCommerce's `has_options`, which knows about variations and **nothing about add-ons**, so a simple dish with a required group offered a one-tap add the server refused. Pro now publishes `requires_choices` | pro + app | done |

## Phase 5 — Order type and time slots
Pickup and delivery only — the design has no dine-in, which also makes QR
table ordering moot. The **write** path already exists: Pro registers a
`food-menu-pro` Store API checkout extension with `fmp_order_time_type` and the
pickup/delivery dates and times. Only the **read** path is missing.

Task 5.2 turned out to need the **free** plugin too: the design's ASAP estimate
("15 min", "20–35 min") had no setting anywhere — the only preparation setting
is in whole days — and settings *inputs* live in the free plugin while their
*registration* lives in Pro.

Task 5.3 went the other way, into **Pro** rather than the free plugin as
planned: locations are a free-plugin taxonomy, but every per-branch *rule* is
Pro term meta and the whole `fmp/v1/app` namespace is Pro's, which free cannot
reference.

Task 5.5 needed the plugin too, as 5.3 flagged: the website scopes the menu
through `woocommerce_product_query` and a `fmp_location_id` cookie, and the
Store API runs neither. Agreed and built — Pro now scopes Store API product
queries by an `X-FMP-Branch` header. **The cart was not revalidated on a
branch change**, which the website does, so a customer could carry a dish
their new branch does not serve. Settled in task 6.6.

| # | Task | Repo | Status |
|---|---|---|---|
| 5.1 | `GET /fmp/v1/app/order-types` — whether pickup and delivery are enabled, with their weekly schedules | pro | done |
| 5.2 | `GET /fmp/v1/app/slots` — selectable slots for a type and branch, respecting slot limits and timed products. Returns the design's flat list (`ASAP (15 min)`, `12:45`, …) rather than a date+time matrix | free + pro | done |
| 5.3 | `GET /fmp/v1/app/branches` — branch list with per-branch rules | pro | done |
| 5.4 | Flutter pickup/delivery toggle and slot list, driven by server availability | app + pro | done |
| 5.5 | Flutter branch selection, persisted and applied to menu and cart requests | app + pro | done |

## Phase 6 — Native checkout
The design's checkout is a single native screen: a pickup/delivery toggle, the
address block, contact details, a payment method list and an order summary.
No webview, so the earlier cart-handoff problem disappears.

| # | Task | Repo | Status |
|---|---|---|---|
| 6.1 | Flutter checkout screen: contact details, address block, order summary, per the design | app | done |
| 6.2 | Place the order via `POST /wc/store/v1/checkout`, sending the `food-menu-pro` extension fields for order type, date and time, **and the branch** — the slot-counting queries match `fmp_location_name`, which the plugin now writes from the `X-FMP-Branch` header | app + pro | done |
| 6.3 | Cash on delivery as the v1 payment method, with server-side validation that it is an enabled gateway | pro + app | done |
| 6.4 | Order received screen, read back from the API after the order is placed — needed a plugin route, since the Store API's own order endpoint carries no order number, no time and no tracking token | pro + app | done |
| 6.5 | Failure paths — declined order, validation errors, connectivity loss — return to a checkout that keeps its input | app | done |
| 6.6 | A cart carried across a branch switch can hold a dish the new branch does not serve. **Decided: warn at the switch, then drop** — the app names the dishes and asks before switching, with a server-side refusal at checkout as the backstop. The website's own pass cannot help here: it hangs off the `fmp_location_id` cookie, which a mobile client never sends | app + pro | done |

## Phase 7 — Orders and tracking
| # | Task | Repo | Status |
|---|---|---|---|
| 7.1 | `GET /fmp/v1/app/orders` — order history for the signed-in customer, paged, with the design's Active/Past split defined as "not finished" so a store's own custom statuses land in Active unasked | pro | done |
| 7.2 | Flutter order history and order detail screens. The plugin grew `status_color` and `is_active` on the single-order payload too, since the detail header draws the same pill the row does | app + pro | done |
| 7.3 | Live order tracking against the existing public `GET /fmp/v1/track/{token}`, with the status timeline. **Also owns the design's progress strip and estimate card**, both of which are drawn from a step out of four that only tracking knows — 7.2 left the space rather than guessing a step from the status slug | app | todo |
| 7.4 | **Reorder.** In the design on past rows and in the order footer, and left out of 7.2 on purpose: an order records its add-ons as *display text*, not as ids, so nothing can rebuild the selection faithfully. Needs the plugin to store a re-submittable selection on the line at checkout, then a reorder route. WooCommerce's own `order_again` does not help — neither plugin hooks `woocommerce_order_again_cart_item_data`, so it would drop every choice too | pro + app | todo |

## Phase 8 — Hardening
| # | Task | Repo | Status |
|---|---|---|---|
| 8.1 | Offline and error handling pass: retries, empty states, connectivity loss | app | todo |
| 8.2 | Widget and integration test coverage for cart, add-ons, slots and checkout handoff | app | todo |

## Phase 9 — Payment methods
Cash on delivery is all task 6.3 left v1 with. This phase adds the rest, in
order of what each costs, and **sits between hardening and release on
purpose**: 9.3 changes platform dependencies and permissions, which 10.1 and
10.2 then audit and sign.

Most of the machinery is already in place and unused:

- **Declaring a gateway** — `PaymentMethodsApi::APP_SUPPORTED` and the
  `fmp_app_supported_gateways` filter (6.3). A gateway the app can finish is
  one line.
- **Sending gateway data** — `POST /checkout` takes `payment_data` as
  `{key, value}` pairs. Nothing sends it yet; `OrderDraft.toJson` is the one
  place that would. **Each gateway defines its own keys**, which is why 9.3 is
  per-gateway work rather than one card flow.
- **Coming back** — `payment_result.redirect_url` is already parsed onto
  `PlacedOrder`, and the order-received screen already re-reads the order.
- **Failing** — task 6.5's paths. A declined payment is a declined order, and
  an abandoned redirect is one more case of the same thing.

| # | Task | Repo | Status |
|---|---|---|---|
| 9.1 | Offline gateways — bank transfer and cheque. They collect nothing at checkout (`has_fields` is false), so the only missing piece is the gateway's **payment instructions**: return them from `GET /app/orders/{id}` and show them on the order received screen, or a customer is never told where to send the money. Then add the ids to the supported list | pro + app | todo |
| 9.2 | Redirect gateways — open `payment_result.redirect_url`, handle the return, the cancel and the abandon, and reconcile by re-reading the order. One flow covers **PayPal and every regional processor** (bKash, SSLCommerz, Razorpay, Paystack…), with no per-gateway Dart | app | todo |
| 9.3 | Native card — Stripe via `flutter_stripe` and `payment_data`, which brings Apple Pay and Google Pay with it. **The one task here that can be dropped without blocking release**: it needs platform SDKs, a merchant setup per store, and it is per-gateway work | app + pro | todo |

## Phase 10 — Release
| # | Task | Repo | Status |
|---|---|---|---|
| 10.1 | App icon, splash, display name, permissions audit on both platforms | app | todo |
| 10.2 | Release builds, signing, and store metadata | app | todo |

## Deliberately out of scope for v1
Staff dashboard, kitchen monitor, inventory, POS printing, role manager,
reservations and the visual floor plan, dine-in and QR table ordering, tips.

Deferred to **v2**:
- **Coupons** — the cart's code field and the discount line in totals.
- **Upsells** — the cart's cross-sell carousel, i.e. the Order Bumps feature.

**No longer deferred:** card and PayPal payment were v2 on the assumption that
both needed a native SDK. PayPal does not — it is a redirect gateway, which
task 9.2 covers along with every regional processor. Card still does, and is
task 9.3.

Tips and automatic discounts are server-side cart behaviour, so they may still
appear in totals returned by the Store API even though the app does not drive
them.

## Open dependencies
- **Payment gateways** — card and PayPal are deferred, so v1 needs cash on
  delivery enabled on the WooCommerce site. **Enabled on the dev store** in
  task 6.2; with no gateway at all the Store API refuses every order. Task 6.3
  made the app say so rather than fail silently, but a production store still
  needs one the app can complete. Phase 9 widens that to bank transfer,
  cheque and the redirect gateways. To be confirmed.
- **Banner tap targets** — a banner currently opens the full menu, because
  `wp/v2/posts` only exposes *registered* meta and registering a field needs
  plugin code. Per-banner targets are a small follow-up: one
  `register_post_meta` call plus a field on `PromoBanner`. Say if wanted.
- **The design's coupon banner** ("10% off / SAVE10") cannot be reproduced as
  drawn, because coupons are v2. The seeded equivalent carries an "Offer"
  badge and no code.
- ~~**The heart is absent from dish cards and rows until task 3.6.**~~
  **Resolved** — hearts are on dish cards, menu rows and the dish detail
  screen, and the wishlist screen is reachable from Account.
- ~~**Android cleartext HTTP** is not configured.~~ **Resolved** — a debug-only
  network security config now permits it, and the app runs on a physical
  Android device against the dev site.
- **The iOS bundle ID is tied to one Apple team.** `com.foodmenu` can only be
  registered under `M34L8S85ZF`; another team is refused it outright. Device
  builds, TestFlight and the App Store all depend on that account. Anyone
  building elsewhere must change the bundle ID. Confirm before task 10.2.
- **Customer registration must be enabled on the store.** Task 3.1 follows
  WooCommerce's My Account registration setting rather than overriding it, so a
  store running the app needs `woocommerce_enable_myaccount_registration` on.
  It is off by default and was off on the dev site. To be confirmed for
  production.
- ~~**Account security endpoints are missing as a group.**~~ **Agreed and
  scheduled** as tasks 3.10 and 3.11, after coming up in 3.1, 3.2, 3.7 and 3.9.