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
| 7.3 | Live order tracking, with the status timeline, the progress strip and the estimate card. **Needed the plugin, and not the route this plan named**: the public `/track/{token}` answers only what already happened, every entry `completed`, because the website draws a history rather than a plan — and it expires, which is wrong for the customer's own order. So Pro publishes the stages on a bearer-authed `/app/orders/{id}/tracking`, **for the app only**, from the store's own drag-sorted status pipeline. The estimate card turned out to need no tracking at all | pro + app | done |
| 7.4 | **Reorder.** In the design on past rows and in the order footer, and left out of 7.2 on purpose: an order records its add-ons as *display text*, not as ids, so nothing can rebuild the selection faithfully. Needs the plugin to store a re-submittable selection on the line at checkout, then a reorder route. WooCommerce's own `order_again` does not help — neither plugin hooks `woocommerce_order_again_cart_item_data`, so it would drop every choice too | pro + app | todo |

## Phase 8 — Ordering gaps
Found by auditing both plugins against the app, not by a new design. Every
task here is a dish or an order **the website can take and the app cannot**,
so they are holes in phases 2–6 rather than new features.

They come **before hardening on purpose**: Phase 11's error sweep and test
pass would otherwise be written against a checkout about to grow fields and a
menu about to grow a state.

| # | Task | Repo | Status |
|---|---|---|---|
| 8.1 | **A variable dish cannot be ordered at all.** The detail screen has no variation picker, and `CartRepository.addItem` sends only `id`, `quantity` and the add-on extension — never `variation`. `canAddDirectly` correctly keeps the quick-add `+` off a variable dish, which lands the customer on a detail screen whose Add button is live, posts an incomplete body, and lets the server say no. Needs the attribute UI, `variation` on add-to-cart, and the button gated on a complete selection the way `requires_choices` gates add-ons. Store API already publishes `attributes` and `variations`, and the plugin already resolves a variation to its parent for add-ons and food data | app | todo |
| 8.2 | **Order Extra Fields never reach an order.** `fmp_order_custom_fields` lets a store define its own checkout fields — label, type, required, options — saved as order meta and shown on the checkout, the order form, the admin order and the kitchen monitor. `OrderDraft` hardcodes `fmp_custom_fields: {}`, so every one of them is dropped, including required ones. Needs a route publishing the definitions and the checkout section that renders, validates and submits them | pro + app | todo |
| 8.3 | **A timed dish looks orderable when it is not.** `AppProductStoreApi` publishes `ingredients`, `nutrition` and `requires_choices`, and nothing about availability, so a breakfast-only dish is offered at nine at night — then refused by `woocommerce_is_purchasable` on add, or dropped from the cart by `remove_unavailable_from_cart` without a word. The website hides it or greys it out per `fmp_timed_products_behavior`. Needs the flag on the product payload and that treatment in the menu; `TimedProducts::unavailable_at()`, built for 5.2, already answers the question | pro + app | todo |
| 8.4 | **No date can be chosen.** `preorder_max_days`, `first_date` and `last_date` all arrive on `/app/slots` and are used nowhere — the app shows the earliest date as a label and offers no other, while the website takes orders days ahead. Needs a date strip on the fulfilment section, bounded by those fields, with the slot list reloading per date | app | todo |
| 8.5 | **Delivery has no shipping rate.** Nothing reads the cart's `shipping_rates` or calls `POST /cart/select-shipping-rate`; the app only renders `total_shipping` once something else has set it. A store with zones or more than one delivery method gives the customer no choice, and a cart with no rate selected can refuse checkout outright | app | todo |
| 8.6 | **A pickup order sends a delivery address.** 6.1 sends `shipping_address` on both types, reasoning that WooCommerce copies billing into shipping anyway. It also feeds shipping calculation, so a pickup order may collect a delivery fee. Verify against a store with a shipping zone, then send it only where it belongs — the **billing** address stays required on both types, per `FINDINGS.md` | app | todo |
| 8.7 | **`fmp/v1/app/*` never checks `fm_food_menu_type`.** Every other ordering feature in both plugins gates on `online_ordering`; the app namespace does not, so it takes orders on a site running as a showcase menu with ordering switched off. Needs the gate on the ordering routes and a reason the app can show instead of a blank menu | pro + app | todo |

## Phase 9 — Discounts and promotions
The plugin's own discount and promotion features, as distinct from
WooCommerce's sale prices, which the app has had since 2.3.

The **cart** already charges correctly — task 4.3 settled that, and
`FINDINGS.md` records why a line is not base price plus add-ons. What is
missing is everywhere else: the menu does not say a dish is discounted, and
the order does not record that it was.

| # | Task | Repo | Status |
|---|---|---|---|
| 9.1 | **The menu shows the undiscounted price.** The automatic discount reaches the website through `woocommerce_get_price_html` and the cart through `woocommerce_add_cart_item`, and never touches the product price object the Store API serves — there is no `woocommerce_product_get_price` filter in either plugin. So a dish card reads full price and the cart then charges less, with no explanation in between. Needs the charged price and the pre-discount price on the product payload, and the struck-through pair on cards, rows and the detail screen | pro + app | todo |
| 9.2 | **No discount badge.** `fmp_discount_badge_display` drives the website's "x% off" badge, injected into price HTML; the app has no equivalent. Follows 9.1's payload, and finally gives the design's coupon banner something true to say | pro + app | todo |
| 9.3 | **An app order records no discount.** `fmp_discount_off` is written on `woocommerce_checkout_update_order_meta`, which the Store API never fires, so an app order's total drops by the fixed discount and nothing on the order, the emails or the admin says why. Needs the same meta written from the Store API's own order hook, next to where `AppBranchScope` already stamps the branch | pro | todo |
| 9.4 | **Tips.** `enable_tip`, `allow_tip_for` and `fmp_checkout_show_tips` are a customer **input** on the website's checkout, not server-side arithmetic as this plan assumed. Needs the configured amounts and scope published, and a tip row on the checkout that writes to the cart | pro + app | todo |
| 9.5 | **Special Menu.** `fmp_special_menus` and `fmp_menu_offer` are the plugin's own promo data — chosen dishes, offer text, a duration — and the app's banner carousel reads WordPress posts instead. Needs the special menu published and drawn, which also gives a banner a tap target and closes the open question 2.5 left | pro + app | todo |

## Phase 10 — Settings, reviews and notifications
Features the website has and the app does not, **none of which stops an order
being placed**. Last of the parity work for that reason.

| # | Task | Repo | Status |
|---|---|---|---|
| 10.1 | **The detail page's eight `hide_*` toggles are ignored.** `hide_image`, `hide_price`, `hide_summery`, `hide_taxonomy`, `hide_description`, `hide_ingredient`, `hide_nutrition` and `hide_reviews` each switch a section off on the website; the app draws all eight whatever the store asked for. Needs them published and respected | pro + app | todo |
| 10.2 | **The checkout's `fmp_checkout_show_*` toggles are ignored.** Order type, your location, shipping address, order notes, coupon and tips are each switchable on the website and fixed in the app. Needs the ones the app can honour published and respected, and the rest recorded here as deliberately app-owned rather than left looking unnoticed | pro + app | todo |
| 10.3 | **Reviews are read-only and partial.** The app shows the star, rating and count on a dish card and nothing else; the website has a full reviews tab. Needs the list via `wc/store/v1/products/reviews` and, for a signed-in customer, leaving one. Gated by 10.1's `hide_reviews` | app | todo |
| 10.4 | **Push notifications.** The website tells a customer by email, WhatsApp and SMS; the app has no channel at all, which leaves even task 7.3's tracking as something the customer must open the app to see. Account's Notifications row is already a stub waiting for it. **The one task here that can be dropped without blocking release**: it needs Firebase and APNs setup per store, device tokens stored against the customer, and a send on every status change | pro + app | todo |

## Phase 11 — Hardening
| # | Task | Repo | Status |
|---|---|---|---|
| 11.1 | Offline and error handling pass: retries, empty states, connectivity loss | app | todo |
| 11.2 | Widget and integration test coverage for cart, add-ons, slots and checkout handoff | app | todo |

## Phase 12 — Payment methods
Cash on delivery is all task 6.3 left v1 with. This phase adds the rest, in
order of what each costs, and **sits between hardening and release on
purpose**: 12.3 changes platform dependencies and permissions, which 13.1 and
13.2 then audit and sign.

Most of the machinery is already in place and unused:

- **Declaring a gateway** — `PaymentMethodsApi::APP_SUPPORTED` and the
  `fmp_app_supported_gateways` filter (6.3). A gateway the app can finish is
  one line.
- **Sending gateway data** — `POST /checkout` takes `payment_data` as
  `{key, value}` pairs. Nothing sends it yet; `OrderDraft.toJson` is the one
  place that would. **Each gateway defines its own keys**, which is why 12.3 is
  per-gateway work rather than one card flow.
- **Coming back** — `payment_result.redirect_url` is already parsed onto
  `PlacedOrder`, and the order-received screen already re-reads the order.
- **Failing** — task 6.5's paths. A declined payment is a declined order, and
  an abandoned redirect is one more case of the same thing.

| # | Task | Repo | Status |
|---|---|---|---|
| 12.1 | Offline gateways — bank transfer and cheque. They collect nothing at checkout (`has_fields` is false), so the only missing piece is the gateway's **payment instructions**: return them from `GET /app/orders/{id}` and show them on the order received screen, or a customer is never told where to send the money. Then add the ids to the supported list | pro + app | todo |
| 12.2 | Redirect gateways — open `payment_result.redirect_url`, handle the return, the cancel and the abandon, and reconcile by re-reading the order. One flow covers **PayPal and every regional processor** (bKash, SSLCommerz, Razorpay, Paystack…), with no per-gateway Dart | app | todo |
| 12.3 | Native card — Stripe via `flutter_stripe` and `payment_data`, which brings Apple Pay and Google Pay with it. **The one task here that can be dropped without blocking release**: it needs platform SDKs, a merchant setup per store, and it is per-gateway work | app + pro | todo |

## Phase 13 — Release
| # | Task | Repo | Status |
|---|---|---|---|
| 13.1 | App icon, splash, display name, permissions audit on both platforms | app | todo |
| 13.2 | Release builds, signing, and store metadata | app | todo |

## Planned or built the wrong way
From the same audit. These are **planning** mistakes rather than missing
features — a decision that was wrong, or a gap closed with a silent default
instead of a task. Each is owned by a task above; they are recorded because
the shape of each one is worth not repeating.

- **5.2 took the design's word and dropped preordering.** Returning the
  design's flat slot list "rather than a date+time matrix" quietly settled the
  plugin's own `fmp_preorder_max_days` out of the app. This is the same class
  of mistake as 5.5's branch scoping — the website does something through a
  path the app does not travel — and that one was caught. *Owned by 8.4.*
- **A missing feature was closed with an empty default.** `fmp_custom_fields:
  {}` went in as a schema requirement — every registered key, every time — and
  the feature behind the key was never written down as absent. Nothing in this
  plan mentioned custom fields until now. An empty default is how a gap stops
  looking like one. *Owned by 8.2.*
- **The detail screen leans on a server rejection for variable dishes.** The
  Add button is live, posts no `variation`, and lets the API refuse it. That is
  exactly the pattern task 4.7 was opened to fix for add-ons, reintroduced for
  the product type WooCommerce ships with. *Owned by 8.1.*
- **Pickup sends a delivery address.** The reasoning in 6.1 — WooCommerce
  copies billing into shipping anyway — is true and incomplete: the shipping
  address also feeds shipping calculation. *Owned by 8.6.*
- **Tips were filed as server-side cart behaviour.** They are a customer input
  on the website's checkout. The app can render whatever the server puts in
  totals, and can never put a tip there itself, so "it may still appear in
  totals" was never a substitute for the feature. *Owned by 9.4.* Coupons were
  filed the same way and stay v2 deliberately — unlike tips, they were always
  scheduled rather than assumed away.
- **Banners were planned around plugin code rather than with it.** 2.5 chose
  `wp/v2/posts` to avoid touching the plugin, then needed plugin code anyway
  for a tap target, and bypassed the Special Menu feature the plugin already
  had. *Owned by 9.5.*
- **Dine-in's exclusion was never costed.** Dropping it because the design has
  no screen for it is a fair call; what was never recorded is what the app does
  on a store that enables **only** dine-in — it offers no order type at all.
  See Open dependencies.

## Deliberately out of scope for v1
Staff dashboard, kitchen monitor, inventory, POS printing, role manager,
reservations and the visual floor plan, dine-in and QR table ordering.

**Reservations deserve a second look before v1 ships.** They are no longer a
Pro extra — the vendor's feature list leads the free half with them, and the
code agrees — so every site that can run this app also takes bookings the app
cannot show. Still out of scope, still the right call for v1, but now an
exclusion worth re-making rather than one inherited from when it was a Pro
feature. See `FINDINGS.md`.

Deferred to **v2**:
- **Coupons** — the cart's code field and the discount line in totals.
- **Upsells** — the cart's cross-sell carousel, i.e. the Order Bumps feature.

**No longer deferred:** card and PayPal payment were v2 on the assumption that
both needed a native SDK. PayPal does not — it is a redirect gateway, which
task 12.2 covers along with every regional processor. Card still does, and is
task 12.3.

**No longer out of scope:** tips. They were listed here as server-side cart
behaviour, which they are not — see "Planned or built the wrong way" — and
they are now task 9.4.

Automatic discounts *are* server-side arithmetic, and do appear in the totals
the Store API returns whether or not the app asks for them. What the app still
has to do is say so before the cart, which is Phase 9.

## Open dependencies
- **The app requires Food Menu Pro, and the free plugin alone cannot run it.**
  Every `fmp/v1/app/*` route lives in `food-menu-pro`, so a free site has no
  accounts, no add-ons, no order types, no slots and no orders endpoint. Worth
  stating because the vendor's own feature list leads with how much is free —
  reservations, tips, discounts and the special menu among it — and none of
  that changes this. Not a decision to make, a fact to put on the listing.
- **Payment gateways** — card and PayPal are deferred, so v1 needs cash on
  delivery enabled on the WooCommerce site. **Enabled on the dev store** in
  task 6.2; with no gateway at all the Store API refuses every order. Task 6.3
  made the app say so rather than fail silently, but a production store still
  needs one the app can complete. Phase 12 widens that to bank transfer,
  cheque and the redirect gateways. To be confirmed.
- ~~**Banner tap targets**~~ **Scheduled** as task 9.5, which draws the
  plugin's own Special Menu instead of inventing a meta field for a WordPress
  post.
- ~~**The design's coupon banner** ("10% off / SAVE10") cannot be reproduced as
  drawn, because coupons are v2.~~ Still true of the *code*, but task 9.2 gives
  the badge a real discount to name.
- **A store that enables only dine-in has no order type in the app.**
  `allow_order_type_for` and the per-type switches let a store run dine-in
  alone, and v1 serves pickup and delivery only, so the fulfilment section
  would offer nothing. Decide whether that is a refusal with an explanation, a
  reason to bring dine-in forward, or a documented limitation. To be confirmed.
- ~~**The heart is absent from dish cards and rows until task 3.6.**~~
  **Resolved** — hearts are on dish cards, menu rows and the dish detail
  screen, and the wishlist screen is reachable from Account.
- ~~**Android cleartext HTTP** is not configured.~~ **Resolved** — a debug-only
  network security config now permits it, and the app runs on a physical
  Android device against the dev site.
- **The iOS bundle ID is tied to one Apple team.** `com.foodmenu` can only be
  registered under `M34L8S85ZF`; another team is refused it outright. Device
  builds, TestFlight and the App Store all depend on that account. Anyone
  building elsewhere must change the bundle ID. Confirm before task 13.2.
- **Customer registration must be enabled on the store.** Task 3.1 follows
  WooCommerce's My Account registration setting rather than overriding it, so a
  store running the app needs `woocommerce_enable_myaccount_registration` on.
  It is off by default and was off on the dev site. To be confirmed for
  production.
- ~~**Account security endpoints are missing as a group.**~~ **Agreed and
  scheduled** as tasks 3.10 and 3.11, after coming up in 3.1, 3.2, 3.7 and 3.9.
