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
| 7.4 | **Reorder**, on past rows and in the order footer. The plugin now keeps the selection **as submitted** on the cart item and carries it to the order line as `_fmp_addon_selection`; `GET /app/orders/{id}/reorder` hands it back as the exact payload `cart/add-item` takes. The route **adds nothing** — the app re-submits each line through the Store API, where add-on validation, branch scoping, timed products and stock already work. An order placed before this existed is refused per line with a reason, **unless its dishes take no choices**, in which case there was nothing to lose | pro + app | done |

## Phase 8 — Ordering gaps
Found by auditing both plugins against the app, not by a new design. Every
task here is a dish or an order **the website can take and the app cannot**,
so they are holes in phases 2–6 rather than new features.

They come **before hardening on purpose**: Phase 11's error sweep and test
pass would otherwise be written against a checkout about to grow fields and a
menu about to grow a state.

**Reopened after Phase 9** by a second plugin audit, which found task 8.9, and
closed again with it. The phase was closed the first time on the strength of
eight tasks that each came from reading a *feature* against the app; 8.9 came
from reading the *hooks* instead, and no earlier pass had done that
systematically. Same argument for the same place in the plan: it is an order
the website refuses and the app takes.

| # | Task | Repo | Status |
|---|---|---|---|
| 8.1 | **Variable dishes are orderable.** An attribute picker on the dish screen, the chosen variation read back for its own price and stock, and `variation` on add-to-cart. Stayed **app-only** as planned — but it needed the dev site's demo data fixed first: the three sizes had *empty* attribute values, which WooCommerce reads as "any", so no term could ever resolve to a variation. See `FINDINGS.md` | app | done |
| 8.2 | **Order Extra Fields reach the order.** `GET /app/checkout-fields` publishes the store's own questions — label, type, required, multiple, options — keyed by **position**, which is the website's own convention. The checkout draws them, validates required ones in its own `Form` pass, and posts them under `fmp_custom_fields`. **No server-side validation added**: the Store API accepts a missing required field today, exactly as the website's block checkout does, and enforcing it would change the website too — raised as an open dependency instead | pro + app | done |
| 8.3 | **A timed dish looks orderable when it is not.** `AppProductStoreApi` publishes `ingredients`, `nutrition` and `requires_choices`, and nothing about availability, so a breakfast-only dish is offered at nine at night — then refused by `woocommerce_is_purchasable` on add, or dropped from the cart by `remove_unavailable_from_cart` without a word. The website hides it or greys it out per `fmp_timed_products_behavior`. Needs the flag on the product payload and that treatment in the menu; `TimedProducts::unavailable_at()`, built for 5.2, already answers the question | pro + app | done |
| 8.4 | **No date can be chosen.** `preorder_max_days`, `first_date` and `last_date` all arrive on `/app/slots` and are used nowhere — the app shows the earliest date as a label and offers no other, while the website takes orders days ahead. Needs a date strip on the fulfilment section, bounded by those fields, with the slot list reloading per date | app | done |
| 8.5 | **Delivery has no shipping rate.** Nothing reads the cart's `shipping_rates` or calls `POST /cart/select-shipping-rate`; the app only renders `total_shipping` once something else has set it. A store with zones or more than one delivery method gives the customer no choice, and a cart with no rate selected can refuse checkout outright | app | done |
| 8.6 | **A pickup order was charged for delivery.** Confirmed on the dev store: $13.00 of food, Delivery $17.95, switch to Pickup and the $4.95 stayed. **Not the fix this plan named, and not app-only.** Dropping `shipping_address` changes nothing — WooCommerce prices shipping from the customer's profile and the fee is already on the *cart*, not the checkout body. So the cart has to be told, and nothing in either plugin has ever told it: the order type is read from `$_POST` at checkout, long after the totals. Pro now reads an `X-FMP-Order-Type` header and answers `needs_shipping: false` for a pickup cart; the app sends it on every cart route and on checkout, and the **cart is re-read when the type changes** so the total moves on the tap. The website has the same bug and is deliberately left alone — see `FINDINGS.md` | app + pro | done |
| 8.7 | **`fmp/v1/app/*` never checked `fm_food_menu_type`.** Every other ordering feature in both plugins gates on `online_ordering`; the app namespace did not, so it took orders on a site running as a showcase menu with ordering switched off — and the mode **defaults to the showcase**, so this was every store that had never opened the settings screen. `AppApiFns::check_ordering()` now refuses the nine ordering routes with `fmp_ordering_disabled`, while the account routes stay open. The app reads that one refusal off the order-types call it already makes at launch and draws an explanation where the menu would be, rather than "Nothing on the menu here yet." The **Store API checkout is deliberately not gated**: it is the website's own block checkout route, and refusing it would change the website. See `FINDINGS.md` | pro + app | done |

| 8.8 | **What the first device pass found.** Tasks 7.2–8.2 all shipped without one, and running them on the OnePlus against the dev site turned up six defects in merged work: a variable-dish order can never be reordered, add-on choices on a variable dish are silently discarded, the order screen prints internal meta and undecoded entities, the dish header keeps the price range after a size is chosen, the size is named twice on an order line, and the tracking timeline uses the store's clock while every other date uses the phone's. **Taken before 8.3**, because 8.3 edits the same product payload and menu state these do | pro + app | done |
| 8.9 | **An app order's time slot is never validated when it is placed.** The website guards a slot three times — the slot's own validity on `woocommerce_checkout_process`, the per-product cap on `woocommerce_checkout_create_order`, and the cap again on `woocommerce_check_cart_items` — and **not one of them protects an app order**. The first two are fired only by `WC_Checkout`, which the Store API never calls. The third the Store API does fire, and converts its notices into a 409, but it reads `PickupDelivery::get_selected_slot()`, which looks in `$_POST` and the `fmp_location_id` cookie — empty on a JSON request from a token client, so `check_product_limits()` returns on its first line and every caller passes. What the app has instead is read-time only: `SlotsApi::product_caps()` marks a slot full while it builds the list, which is true at that moment and never again. So the app can place an order into a slot that filled while the customer chose, past a dish's per-slot cap, or on a date and time outside the schedule altogether. The enforcement point is `woocommerce_store_api_checkout_update_order_from_request`, which Pro already handles and which runs **before payment**; the app half is the refusal's own message. **Gated on `X-FMP-App`**, because the website's own block checkout has the identical hole and closing it for everyone would change what live stores accept. See `FINDINGS.md` | pro + app | done |

## Phase 9 — Discounts and promotions
The plugin's own discount and promotion features, as distinct from
WooCommerce's sale prices, which the app has had since 2.3.

The **cart** already charges correctly — task 4.3 settled that, and
`FINDINGS.md` records why a line is not base price plus add-ons. What is
missing is everywhere else: the menu does not say a dish is discounted, and
the order does not record that it was.

| # | Task | Repo | Status |
|---|---|---|---|
| 9.1 | **The menu shows the undiscounted price.** The automatic discount reaches the website through `woocommerce_get_price_html` and the cart through `woocommerce_add_cart_item`, and never touches the product price object the Store API serves — there is no `woocommerce_product_get_price` filter in either plugin. So a dish card reads full price and the cart then charges less, with no explanation in between. Needs the charged price and the pre-discount price on the product payload, and the struck-through pair on cards, rows and the detail screen | pro + app | done |
| 9.2 | **No discount badge.** `fmp_discount_badge_display` drives the website's "x% off" badge, injected into price HTML; the app has no equivalent. Follows 9.1's payload, and finally gives the design's coupon banner something true to say | pro + app | done |
| 9.3 | **An app order was charged more than the customer agreed to.** The plan had this as a missing *note*: the total drops and nothing says why. The truth was the reverse and far worse — the fixed discount is applied to the cart and **lost when the order is created**, because the Store API calls `$order->calculate_totals()` while the classic checkout copies `WC()->cart->get_total( 'edit' )`. Measured: cart quoted $122.00, order created at $125.00, **not refused** — `expected_total` compares against the cart, which was correctly discounted. Cash on delivery then collects the larger figure. Pro now carries the quoted total onto the order and writes `fmp_discount_off` where the website reads it. **Gated on a new `X-FMP-App` header**, because the website's own block checkout has the identical bug and fixing it for everyone would change what live stores charge — so this is `pro + app`, not `pro`. See `FINDINGS.md` | pro + app | done |
| 9.4 | **Tips.** `enable_tip`, `allow_tip_for` and `show_tip_form` are a customer **input**, not server-side arithmetic as this plan assumed. The website writes the answer to the session over `admin-ajax`, which is nonce-gated and cookie-bound and so closed to a token client — so the tip rides the Store API's **own** `cart/extensions` mechanism, which shares the `Cart-Token` session the app's cart already uses. Published on the cart payload, with the store's own prompt and the kinds it allows; drawn on the checkout **and the cart**, since a store can ask on either. **There are no preset amounts to publish** — the plugin configures none, so the app offers none rather than inventing a store policy. Unlike 9.3's discount, a tip is a cart **fee**, so it reaches the order as a line item with none of that machinery | pro + app | done |
| 9.5 | **Special Menu.** `fmp_special_menus` and `fmp_menu_offer` are the plugin's own promo data — chosen dishes, offer text, a duration — and the app's banner carousel read WordPress posts instead. `GET /app/special-menu` publishes it, **scoped to the branch**, which the website's own popup is not. The carousel draws one banner per chosen dish: the offer is the badge, the dish is the title, and tapping opens it — which **closes the tap-target question 2.5 left**. Posts stay as the fallback, so a store with no promotion keeps the carousel it had and an older plugin's 404 costs nothing. Drawn as the carousel rather than the website's modal, because the design already has the band and a promotion that does not block the customer is the better of the two | pro + app | done |

## Phase 10 — Settings, reviews and notifications
Features the website has and the app does not, **none of which stops an order
being placed**. Last of the parity work for that reason.

| # | Task | Repo | Status |
|---|---|---|---|
| 10.1 | **The detail page's hidden sections are ignored.** Not eight `hide_*` toggles as this plan had it, but **one** store setting — `hide_options`, an array of section names, read in five places on the website to leave sections out of the dish page and the quick-view popup. Nothing published it, so the app drew all eight whatever the store asked for. The product payload now carries `sections`, **effective per dish**: the store's setting already combined with what the dish has, so the app keeps no second copy of the website's conditions. Two things the first reading missed. **Hiding the price hides the way to order** — `fmp_summery_price()` renders the price and `woocommerce_template_single_add_to_cart()` inside one condition — so the app drops its add bar too. And `summery` has **no app surface**: the dish screen draws the full description where the website draws the excerpt, and the excerpt only appears on a menu row, which a different setting governs — carried anyway so the gap stays visible. `_ingredient_status` and `_nutrition_status` are **deliberately not read**; see `FINDINGS.md` | pro + app | done |
| 10.2 | **The checkout's `fmp_checkout_show_*` toggles are ignored, and so are its three texts.** `GET /app/checkout-fields` now carries `sections` and `texts`, and the checkout draws the order-type switch, the branch card, the order notes and the tip row as the store asked. **The open question below answered itself in the settings UI**: the toggles are rendered inside `{ fmp_enable_custom_checkout === 'on' && … }`, so a store that never enabled the custom checkout has never *seen* them — and three of them default to **off**. Honouring them unconditionally would have stripped the order-type switch, the branch card and the tip row out of every such store, so the server sends everything-shown unless the custom checkout is on. **Three of the eight are deliberately not honoured**: `show_additional_info` already arrives as the fields' own `enabled` and is the one toggle the plugin never gated; `show_shipping_address` hides a *separate* shipping card on the website while billing still collects an address, and the app's one address card does both jobs, so honouring it would leave a delivery order with nowhere to send the food; `show_coupon` and `show_order_bumps` govern v2 features. The **texts** are not gated on the custom checkout, because they are content rather than layout. See `FINDINGS.md` | pro + app | done |
| 10.3 | **Reviews are read-only and partial.** The app showed the star, rating and count on a dish card and nothing else; the website has a full reviews tab. The list comes from `wc/store/v1/products/reviews`, which is public and needed nothing. **Leaving one needed Pro, which this plan had as `app`**: the Store API's review route is registered `READABLE` and nothing else, and WooCommerce's own `wc/v3/products/reviews` create maps to `edit_products`, a shop manager capability — so a token client had no door at all. `POST /app/products/{id}/reviews` is that door, and it re-implements three of WooCommerce's own rules because all three read `$_POST` and two answer by calling `wp_die()`. The store's review settings ride on the product payload; whether *this* customer qualifies comes from the refusal. **The design has no reviews list and no form**, so both are drawn to match, as the address and auth screens were. Gated by 10.1's `sections.reviews` | pro + app | done |
| 10.4 | **Push notifications.** The website tells a customer by email, WhatsApp and SMS; the app has no channel at all, which leaves even task 7.3's tracking as something the customer must open the app to see. Account's Notifications row is already a stub waiting for it. **The one task here that can be dropped without blocking release**: it needs Firebase and APNs setup per store, device tokens stored against the customer, and a send on every status change | pro + app | todo |

## Phase 11 — Hardening
| # | Task | Repo | Status |
|---|---|---|---|
| 11.1 | **Offline and error handling pass.** The audit found the error paths in better shape than this line assumed — every list screen already had an error state and empty states existed everywhere — and one defect under all of them: **a `SocketException` arrived as `ApiFailure.unknown`**, so the commonest failure on a phone read "Something went wrong." and, because `isRetryable` was false, was offered **no retry** anywhere. dio reserves `connectionError` for a narrow set of cases; a dropped Wi-Fi, a DNS failure, a server that is not running and a failed TLS handshake all arrive as `unknown`. One classification fix corrected the wording and the retry on every surface at once. Also: the menu **list** screen and the **dish** screen were dead ends on a failed load, and both now offer a retry — not on a 404, where asking again fetches the same answer. **No connectivity package was added**; see `FINDINGS.md` for why a persistent offline banner was judged the wrong trade | app | done |
| 11.2 | **The four areas were covered; the layer between them was not.** 974 tests over 81 files, every screen with its own, and each one pumps a single screen with a **stub** where the next belongs — so the cart's `Go to checkout` had never been pressed in a test, and a handoff could be broken in the shipped router with the suite green. `test/journeys/` pumps `FoodMenuApp` itself and walks it: menu → dish → add-ons → cart → checkout → order received, the slot list following the cart across screens, and signing in from the middle of a checkout. One captured order (`cart_with_addons.json` with `product_addons.json`, the same dish) runs the length of it, so the dish screen's preview and the plugin's line total are one assertion apart. **Two things fell out of it.** The suite had been measuring text with the *fallback test font*, which is wider than Plus Jakarta Sans — two rows "overflowed" a 390dp phone and neither does with the real font loaded, and the error runs the other way too; `flutter_test_config.dart` now loads it for every test, all 974 passing unchanged. And navigating the real app trips a debug-only riverpod assertion by two routes, neither with app code on the stack, which `journeyTest` filters narrowly and `FINDINGS.md` writes up as **deserving its own task** | app | done |
| 11.3 | **Riverpod refreshes its scope mid-build, on ordinary use.** Both routes were **riverpod's own bug, already fixed upstream** — which is what "check case 1 against upstream before writing any app code" was for, and the answer made the app-code half of this task unnecessary. flutter_riverpod closed them across 3.4.0 ("flushing a provider inside Widget lifecycle"), 3.4.2 and 3.5.0 ("resuming a consumer with a diamond-shaped provider dependency graph" — case 1 exactly). The cost was an **SDK upgrade**: 3.4.1+ needs Dart 3.12, so this moved the project from Flutter 3.41.6 to **3.50.0** (Dart 3.14.0). The journey filter is gone, and its 12 tests now pass with nothing suppressed, which is what makes a recurrence fail the suite. The jump turned up **two defects of our own** that the older SDK never mentioned: the address sheet's `ListTile`s painted their ink on a Material the sheet's own `DecoratedBox` then covered, so tapping an address gave no feedback at all, and five constructors were written the long way round. It also deprecated `package:flutter/material.dart`, which is 11.4 | app | done |
| 11.4 | **`package:flutter/material.dart` is deprecated.** Flutter 3.50 moved Material into the `material_ui` package; 115 imports swapped, and `analysis_options.yaml`'s suppression deleted with them. The import swap was the easy half. **The risk was a dependency, and it was silent**: go_router picks its page type by looking up the tree for a `MaterialApp` **by exact type**, and falls back to `NoTransitionPage` for every route when it cannot find one — and all twenty routes here are declared with `builder:`, so every one went through that lookup. `material_ui`'s `MaterialApp` is not the SDK's, so on go_router 17.5.0 the app lost every push and pop animation **with the whole suite green**, because every test `pumpAndSettle`s and a cut settles as well as a transition. go_router 18.0.0 migrated to `material_ui` itself and needs the SDK 11.3 brought in, so the bump belongs with the swap rather than after it. Measured both ways and **pinned by a new test** that reads the page types the router actually built | app | done |

## Phase 12 — Payment methods
Cash on delivery is all task 6.3 left v1 with. This phase adds the rest.

**Scoped by a ruling, 2026-11-17.** The website developer will run
**WooCommerce's built-in gateways only** — no gateway plugin, first-party or
otherwise. That empties most of this phase rather than reordering it:

- The store's whole payment set is `cod`, `bacs`, `cheque` and, if it is ever
  switched on, legacy PayPal Standard. **Surveyed on the dev store** (WooCommerce
  11.2.1): those are the only gateway classes core ships, `cod` is the only one
  enabled, and PayPal Standard is not even registered — see 12.2.
- **No native card, and no regional processors.** Stripe, WooPayments, bKash,
  SSLCommerz, Razorpay and Paystack are all out by the store's own choice, which
  deletes the old task 12.3 and most of 12.2's reach.
- **`payment_data` stays unused in v1.** `POST /checkout` takes it as
  `{key, value}` pairs and `OrderDraft.toJson` is the one place that would send
  it, but every gateway left in scope has `has_fields` false and collects
  nothing at checkout. The field was the reason card work was per-gateway; with
  card gone, nothing in this phase needs it.
- Phase 12 no longer touches platform dependencies or permissions, so it no
  longer has to precede 13.1 and 13.2 for their sake. **Phase 14 does** — see
  that phase.

What is already in place and unused:

- **Declaring a gateway** — `PaymentMethodsApi::APP_SUPPORTED` (`['cod']`) and
  the `fmp_app_supported_gateways` filter (6.3). A gateway the app can finish is
  one line.
- **Coming back** — `payment_result.redirect_url` is already parsed onto
  `PlacedOrder` and read by nothing, and the order-received screen already
  re-reads the order.
- **Failing** — task 6.5's paths. A declined payment is a declined order, and
  an abandoned redirect is one more case of the same thing.

| # | Task | Repo | Status |
|---|---|---|---|
| 12.1 | Offline gateways — bank transfer and cheque. They collect nothing at checkout (`has_fields` is false), so the only missing piece is the gateway's **payment instructions**: return them from `GET /app/orders/{id}` and show them on the order received screen, or a customer is never told where to send the money. Then add the ids to the supported list | pro + app | todo |
| 12.2 | **The redirect flow, now worth one gateway.** Open `payment_result.redirect_url`, handle the return, the cancel and the abandon, and reconcile by re-reading the order. With the ruling above, the only core gateway that redirects is **legacy PayPal Standard** — and WooCommerce hides it: `WC_Gateway_Paypal::should_load()` registers it only on a store that already had it enabled or has PayPal orders, which is why the dev store does not list it at all. **Conditional on the store enabling it** (see Open dependencies); if they do not, this task is dead code and should be dropped rather than built | app | todo |
| ~~12.3~~ | ~~Native card — Stripe via `flutter_stripe` and `payment_data`~~ **Deleted by the 2026-11-17 ruling**, not deferred: the store will not run a card gateway, so there is nothing for the app to complete. It was always the droppable task here; what dropped it was the store's answer rather than our cost estimate. Apple Pay and Google Pay go with it, since both arrive through a card gateway | — | dropped |

## Phase 13 — Release
| # | Task | Repo | Status |
|---|---|---|---|
| 13.1 | App icon, splash, display name, permissions audit on both platforms | app | todo |
| 13.2 | Release builds, signing, and store metadata | app | todo |

## Phase 14 — The vendor's own feature list
`tlp-food-menu/docs/app-feature.md`, new in free 6.0.9, is a spec for this app
written from the plugin side: Parts A (customer), B (staff) and C (app-wide),
every row marked free or Pro, backend-ready or not, and P1/P2/P3. It was
written against roughly pre-Phase-8 state, so much of what it asks for is
already merged — customer orders, tips, review writing, checkout extra fields,
slot limits, ingredients, nutrition, reorder and the status timeline all sit at
not-ready there and are done here. What follows is only what it asks for that
this plan did not have.

**This phase runs before Phase 13.** 14.1 and 14.4 are store-submission
blockers, 14.2 is a live correctness defect, and 13.1's audit covers what 14.4
adds.

| # | Task | Repo | Status |
|---|---|---|---|
| 14.1 | **There is no way to delete an account, and both stores require one.** Doc A2.8, P1. Phase 3 built register, login, profile, addresses and the whole security group and never this; Apple's 5.1.1(v) and Play's data-deletion policy both require in-app deletion for an app that creates accounts, so 13.2 as planned would have submitted a rejection. `POST /app/auth/delete-account` takes the current password, refuses an account that **runs the store**, then runs **WordPress's own registered erasers** rather than a deletion policy of its own — which is what makes the store's `woocommerce_erasure_request_removes_order_data` setting decide whether an order keeps the customer's details, and what makes the sentence the app shows the server's to compose. Orders are never deleted: they are the store's records. Two things fell out of it — **WooCommerce hides product reviews from core's comment eraser**, so a deleted customer's dish review kept their name until this added a pass of its own, and an eraser that erases shrinks the set it pages through, so advancing the page steps over records. App side: a password screen behind a confirmation dialog, reached from a destructive row of its own below Log out. **Running it on a device turned up a third defect that was none of this task's doing**: `AuthInterceptor` stripped the token from every path under `app/auth/`, so `change-password` and `change-email` had been answering "You must be signed in to do that." since task 3.11 | pro + app | done |
| 14.2 | **A paused store still takes app orders.** Doc A6.12, P1, and confirmed in the plugin: Kitchen Monitor's pause is enforced by `KitchenMonitorController::block_checkout_if_paused()` on **`woocommerce_checkout_process`**, reading `$_POST['fmp_order_time_type']` and the classic checkout's date and time fields. `POST /wc/store/v1/checkout` fires neither hook nor those fields, so the app walks straight past a pause — global or scheduled — and the store's own pause message never reaches the customer. **The same shape as 8.9 and 8.3**: the website guards a rule on a path the app does not travel. `AppPauseGuard` puts the guard on `woocommerce_store_api_checkout_update_order_from_request` at priority **4** — one ahead of 8.9's slot guard, because a paused kitchen refuses the next slot too — gated on `X-FMP-App` so the website keeps the behaviour it has. The window is judged against the **order's own slot**: a scheduled pause is about when the kitchen is shut, so an order placed now for a time outside it is fine. The read side rides on `GET /app/order-types`, already fetched before the checkout is drawn, as `ordering_paused` + the store's own `pause_message`; `checkoutReadinessProvider` blocks on it **before** the time and the address, so a customer is never asked to fill in what cannot be used. A pause that starts mid-checkout comes back as `fmp_ordering_paused`, its own failure kind, which re-reads the store so the button behind the banner goes dead | pro + app | done |
| 14.3 | **`GET /app/config` — one launch payload.** Doc A1.1, A1.2, A1.3 and A5.8. The app has no store-level call at all: it learns the store a piece at a time from `/order-types`, `/branches`, `/checkout-fields` and `/address-fields`, and at launch has no answer to *is this store in online-ordering mode*, *is Pro active*, *is ordering paused*, *what currency and time format*, *what logo and colour*, *what does the empty cart say*. Task 8.7 made every `app/*` route refuse a display-only store, which is the right floor but tells the customer nothing until they are already inside one. **The appearance question is settled here**: ruled 2026-11-17, the app takes the store's **logo and primary colour** and owns everything else — the plugins have 48 colour settings between them and every other one describes a WordPress layout this app does not have. The colour moves `brand`, `brandPressed` and `tint` together, in both modes. The pause is deliberately **not** carried: this payload is read once at launch, and an answer that must be fresh at checkout does not belong in it. `orderingDisabledProvider` now asks the store plainly instead of inferring it from task 8.7's 403, and falls back to the inference for an older Pro | pro + app | done |
| 14.4 | **The store-review surface.** Doc C7: a privacy policy link on the account screen, the deletion entry point 14.1 adds, and the data-use answers both consoles ask for before an upload. 13.1 audits the permissions; this is the content half of the same submission | app | todo |
| 14.5 | **The menu cannot be filtered or sorted.** Doc A3.5, P2. Phase 2 built search and the category filter and stopped there. The Store API already takes `tag` and `orderby=price\|popularity\|date`, and the plugin's food tags have been on the dish screen since 2.4 — nothing offers either on a list | app | todo |
| 14.6 | **Price Label, which cannot be set on a store the app serves.** Doc A3.6, P2, asks for `_tlp_fm_price_label` on products — free 6.0.9's new feature, text like `Small 5.95 \| Large 6.50` printed verbatim instead of the price. As built it is bound to the **`food-menu` post type**: the metabox registers for that type alone and `Fns::get_price_label()` returns `''` for anything else, while an `online_ordering` store's items are WooCommerce `product`s. So the **free plugin has to grow the field on a product** before there is anything for the app to read, and per the standing rule that is a plugin fix rather than a Dart workaround | free + app | todo |
| 14.7 | **A missing endpoint should hide a feature, not fail.** Doc C4. The app assumes the Pro it was built against; an older Pro 404s a route and the app reports an error for a feature the store simply does not have. **This already costs us**: the live demo site runs the *released* plugin, so every endpoint newer than it 404s there and the iPhone cannot test them (`FINDINGS.md`). A capability probe at launch — 14.3's payload, plus a 404 that disables a feature instead of raising | app | todo |
| 14.8 | **Pull-to-refresh and a cached last menu.** Doc A3.11, P2. Task 11.1 declined a connectivity package deliberately and that still holds; caching the last loaded menu is the other half of that row and was never decided either way | app | todo |
| 14.9 | **Accessibility was never audited.** Doc C8. Dark mode landed in 1.3; dynamic text size and screen-reader labels have never been looked at, and 11.2's font work is a measure of how much of this layout is sized by text | app | todo |
| 14.10 | **Notification settings, and the offer push.** Doc A8.3 and A8.4. Both sit on top of 10.4: the Account screen's Notifications row is still a stub, and the Special Menu task 9.5 built has no push or in-app popup half | pro + app | todo |

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
- **5.2 built the slot list and let that stand for the whole feature.** The
  read path got a careful endpoint; the write path was never asked about, so
  the app picks from a list the server generated and the server then accepts
  whatever comes back. Every other phase that touched a server rule went
  looking for where the website enforces it — 5.5 for the menu query, 8.3 for
  purchasability, 8.6 for shipping. Slots were the one where the list was
  mistaken for the rule. *Owned by 8.9.*
- **The audit axis was features, and features are not where hooks hide.**
  Phase 8 and Phase 9 were both built by walking the vendor's feature list and
  the settings screens. That finds anything the store can *configure* and the
  app ignores, which is why `hide_*` and the `show_*` toggles were caught. It
  does not find a rule that has no setting of its own — slot validation is
  three `add_action` calls and no field — and 8.9 sat through two audits
  because of it. The axis that found it was `add_filter`/`add_action` on
  WooCommerce hooks, diffed against what the Store API fires. *Owned by 8.9.*
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
  had. *Corrected by 9.5*, which made the Special Menu the source and left
  posts as the fallback — 2.5's work is the lesser path now, not wasted.
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

**Card payment is out for good, by the store's choice.** It was v2 on the
assumption that it needed a native SDK, then became task 12.3; the 2026-11-17
ruling — WooCommerce's built-in gateways only, no gateway plugin — deletes it
instead, and Apple Pay and Google Pay with it. PayPal survives only as legacy
PayPal Standard, if the store ever switches it on. Worth separating the two
reasons: the estimate said card was expensive, and the store said it was
unwanted. Only the second one settles anything.

**No longer out of scope:** tips. They were listed here as server-side cart
behaviour, which they are not — see "Planned or built the wrong way" — and
they are now task 9.4.

Automatic discounts *are* server-side arithmetic, and do appear in the totals
the Store API returns whether or not the app asks for them. What the app still
has to do is say so before the cart, which is Phase 9.

**The vendor's feature list schedules all of it.** `app-feature.md` puts the
staff app — its whole Part B, orders through kitchen monitor, inventory,
reports and POS printing — plus reservations, dine-in tables and QR table
ordering at P2/P3 rather than out of scope, and order bumps at P2 rather than
v2. Most of Part B is marked backend-ready, because the web dashboard is
already a React app on REST routes; the cost is the app half, plus its own
B1.4 — app-token auth on routes that currently expect a cookie and a `wp_rest`
nonce. **Reconciling that is a ruling, not a task.** Phase 14 takes only the
rows that fit the v1 already agreed; see Open dependencies.

## Open dependencies
- ~~**Do the checkout's `show_*` toggles apply to the app at all?**~~
  **Resolved by the code, not a judgement call.** The settings screen renders
  the whole block inside `{ v('fmp_enable_custom_checkout') === 'on' && ( … ) }`,
  so a store that never enabled the custom checkout has never seen those
  switches — and `show_order_type`, `show_your_location` and `show_tips` all
  default to **off**. Honouring them unconditionally would have emptied the
  checkout of every store that never opened that section. The app follows the
  gate. Settled in task 10.2.
- **A required checkout field is not enforced anywhere but the app.** Task 8.2
  validates them in the checkout's own `Form`, and the Store API accepts an
  order without them — exactly as it does for the website's own **block**
  checkout, which marks a required field with an asterisk and then lets the
  order through. Only the classic checkout enforces it. Adding the check to
  the Store API would fix both and **change the website**, so it needs a
  decision rather than a commit. To be confirmed.
- **The app requires Food Menu Pro, and the free plugin alone cannot run it.**
  Every `fmp/v1/app/*` route lives in `food-menu-pro`, so a free site has no
  accounts, no add-ons, no order types, no slots and no orders endpoint. Worth
  stating because the vendor's own feature list leads with how much is free —
  reservations, tips, discounts and the special menu among it — and none of
  that changes this. Not a decision to make, a fact to put on the listing.
- ~~**Payment gateways** — card and PayPal are deferred, so v1 needs cash on
  delivery enabled on the WooCommerce site.~~ **Settled 2026-11-17**: the
  website developer will run WooCommerce's built-in gateways only. v1's payment
  set is therefore `cod` (enabled on the dev store in task 6.2), plus `bacs` and
  `cheque` once task 12.1 lands. With no gateway at all the Store API refuses
  every order, and task 6.3 made the app say so rather than fail silently — so a
  production store still needs at least one of those three switched on.
- **Will the store enable legacy PayPal Standard?** It is the only built-in
  gateway that redirects, and the only thing left for task 12.2 to carry.
  WooCommerce hides it on any store that has not used it — `should_load()` — and
  no longer promotes it, so the honest default is **no**, which drops 12.2. Ask
  the website developer once; do not block 12.1 on the answer. To be confirmed.
- ~~**Banner tap targets**~~ **Resolved** in task 9.5. A Special Menu banner
  carries its dish and opens it; a banner built from a WordPress post still
  opens the full menu, which is the most a post can honestly promise.
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
- ~~**The app owns its appearance, and that was never decided.**~~ **Settled
  2026-11-17 and built in task 14.3**: the app takes the store's **logo and
  primary colour** and owns the rest. The two are the store's identity; the
  other 46 colour settings are its website's stylesheet. Original note, for
  the reasoning that got here: Found by walking
  the vendor feature list section by section (`FINDINGS.md`). The store's
  `primary_color`, `company_logo`, the detail page's two colour controls, the
  custom checkout heading and the Place Order button text are all configurable
  on the website and none is read by the app. Tasks 10.1 and 10.2 are in the
  plan because their toggles hide *information*; nothing covers the ones that
  restyle. Ratify as deliberate — the app honours the store's rules and data
  and owns its own look — or schedule the ones worth honouring. To be confirmed.
- **The app has no localization layer, and the server half is already
  translated.** No `lib/l10n`, no `flutter_localizations`, no `intl`: every
  string the app owns is hard-coded English, while status labels, checkout
  field labels, add-on names and error messages arrive in the site's own
  language. A translated store therefore gets a half-translated app. Free
  §15.1 ships POT files with WPML and Loco support. Decide whether v1 is
  English-only by choice. To be confirmed.
- **A custom order status has an icon the app never draws.** Pro §8.2 sells a
  colour *and* an icon per status; `AppOrdersApi::status_color()` and
  `AppTrackingApi` publish only the colour. One payload field and one widget,
  if it is wanted. To be confirmed.
- **Is `app-feature.md` the scope now, or the wish list?** It arrived in the
  free plugin with 6.0.9 and schedules work this plan excludes from v1 — the
  staff app, reservations, dine-in, QR ordering — and defers to v2 — coupons,
  order bumps. Phase 14 took only the rows that fit the agreed v1 and left the
  rest here deliberately. Whether the rest moves in, and whether v1 ships
  before it does, is a ruling. To be confirmed.
- **The appearance question has an answer from the plugin side now.** A1.1 and
  A1.2 ask the app to take the store's **company logo and primary colour** for
  the splash and the shell — which is the open question above ("The app owns
  its appearance, and that was never decided") answered in the *opposite*
  direction to where the app stands today. Task 14.3 carries the fields either
  way; what the app does with them is still the decision. To be confirmed.
- **Localization is P2 there, not "English by choice".** A1.6 and Part C ask
  for the app's own string set, following the device or site locale. The open
  question above stands unchanged, but the plugin side has now put a priority
  on it. To be confirmed.
- **Coupons are P1 and backend-ready in the doc, v2 here.** A5.4 is one field
  on the cart and a totals line the app already renders — `cart/apply-coupon`
  needs no plugin work at all. The cheapest row in the whole document, which
  is the reason it is worth re-asking rather than inheriting. To be confirmed.
- **White-label builds.** C9 wants the store name, icon, splash and colours per
  client build. Nothing in this plan contemplates more than one build, and
  13.1 and 13.2 are written for one. To be confirmed.
- **Three P3 rows are neither scheduled nor refused** — social login (A2.9),
  share a dish (A4.10) and guest order tracking by id and email (A7.7). Each
  is small on its own; none is in Phase 14. To be confirmed.
