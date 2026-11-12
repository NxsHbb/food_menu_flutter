# Findings

Decisions, gotchas and anything learned that is not obvious from the code.

## A pickup order is still charged for delivery — confirmed, and it is 8.6's
Seeding the dev store's first shipping zone for task 8.5 made task 8.6
reproducible, and it reproduces immediately: choose Express delivery at
$9.95, switch the order type to **Pickup**, and the total stays $22.95. The
Delivery method section disappears, correctly, and the fee it chose does not.

Nothing tells the cart the order is being collected. The Store API prices
shipping from the customer's shipping address, which the app sets at checkout
for both types — and the rate stays selected on the cart in the meantime. The
store also has no `local_pickup` method, so WooCommerce has nothing to switch
to that costs nothing.

Not fixed here: it is task 8.6's, and the fix is a decision between telling
the cart the destination has changed and not sending a shipping address on a
pickup order at all. Written down with its reproduction so 8.6 starts from
evidence rather than from the plan's guess.

## `last_date: null` means today only, and the route does not enforce it
`/app/slots` sends `last_date` only when `fmp_preorder_max_days` is above
zero. A store that has never switched pre-ordering on sends null, and the
website's own picker then offers the earliest fulfillable date and nothing
else — "zero means today only, which is the default and not an omission", as
the order-types route puts it.

The route's own date check reads it the other way:

```php
if ( null !== $last && $date > $last ) {
    return 'after_last_date';
}
```

With `$last` null there is no upper bound, so a crafted request can ask for a
date six months out and get slots for it. The app does not rely on that: the
date strip is built from the range, and a store with no `last_date` gets one
date.

Left as it is, deliberately and for the same reason task 8.2 left required
checkout fields unvalidated: tightening it changes what the **website's** own
block checkout accepts, which is not the app's call. Raised as an open
dependency rather than fixed quietly.

## The website already writes the words for a timed dish
`get_schedule_text_for_product()` composes "Unavailable", "Will be Available:
8:00 am – 11:00 am" and "Will be Unavailable: …" for the badge the storefront
paints, translated and in the store's own date and time formats. The app
publishes that string rather than its own, so the two can never word the same
rule differently — the same reason the add-ons route calls
`FrontendPAddon::addon_lists()` instead of reading the meta.

What the app does **not** take from it is the bare "Available". The text falls
back to that for a dish no rule covers, which on a normal menu would be a
label on every card and information about none, so the route drops it by
comparing against the same translated literal.

## `$moment` was undefined in the plugin's own rule matcher
`find_matched_rule_for_product()` passed `$moment` to `is_rule_unavailable()`.
The method has no such parameter, so PHP 8 emitted a warning and passed null
on every call — which happens to be the "now" the branch above it asks for, so
the behaviour was accidentally correct and nobody noticed.

It was noticed from the app, because a warning printed mid-response made the
Store API's JSON unparseable and the menu would not load at all on a site with
`display_errors` on. Fixed by using the default, which is exactly what PHP was
already doing.

The lesson is narrower than "run with WP_DEBUG": **a REST payload is the one
place a harmless PHP notice is not harmless**, because it lands inside the
response body rather than beside it.

## Add-ons and variable dishes are mutually exclusive, in three places
The website never renders add-ons on a variable product, and
`AppCartAddons::add_to_cart_data()` says so in as many words — it returns
early for one, so no `fmp_addons` is built and no `fmp_addon_selection` is
recorded. Two other places had not been told:

- **`/app/products/{id}/addons` published them anyway.** Build Your Pizza
  offered a Cutlery group the cart then dropped without a word. A customer
  answered a question that could not reach the order.
- **`AppReorderApi::line()` asked the parent whether the dish takes choices.**
  With no recorded selection and a parent carrying a global group, every
  variable order was refused `choices_not_recorded` — including one the app
  itself had placed a minute earlier.

Both now apply the same rule as the cart. The test for it is not a unit test:
order a variable dish on a store with a global add-on group, then reorder it.

## Internal line meta is only hidden if you let WooCommerce hide it
`get_formatted_meta_data( '', true )` looks like "give me everything, I will
pick" and is, which is why the order screen showed the customer
`_addons_price` and the raw `_fmp_addon_selection` JSON. Both are
underscore-prefixed, which is the whole convention for "not for display".

Calling it with **no arguments** does three jobs at once:

- drops underscore-prefixed meta — the internal keys,
- drops an attribute already spelled out in a variation's name, which is what
  printed `Medium` under "Build Your Pizza – Medium",
- resolves `display_key` through `wc_attribute_label`.

And `wp_strip_all_tags` is not enough on its own: the value carries a price as
`woocommerce-Price-amount` markup, and stripping it leaves `&#036;2.50`.
`wp_specialchars_decode` does not help — it knows five named entities and this
one is numeric. `html_entity_decode( …, ENT_QUOTES, 'UTF-8' )` does. Safe
here because the app draws the string as text and never as markup.

## The timeline now uses the phone's clock, reversing task 7.3
7.3 rendered each stage's time server-side, on the restaurant's clock, arguing
that "ready at 9:33 pm" only means something in the kitchen. A device
disproved it: the dev store keeps its books in UTC — as a great many
WordPress sites do, since nobody changes the default — so one screen showed a
header reading `Today, 2:52 PM` above a timeline reading
`November 11, 2026 at 8:52 am`, for the same order, neither labelled.

The app now draws `at_utc` through `relativeDateTime`, like every other date
in the app, and keeps the server's `at` string as the fallback for a payload
that carries no instant. The store's clock is still the right idea for a
*store* that has set its time zone; it is not worth a contradiction on the
screen for every store that has not.

## Five tasks without a device pass cost six defects
7.2, 7.3, 7.4, 8.1 and 8.2 all shipped green — analyzer, 822 tests — and
every one of the defects above survived that. The suite could not have caught
them: three were plugin payload decisions no Dart test sees, and the other
three needed a real order, a real store time zone and a real variable dish on
screen at once.

The practical rule: **a task that changes what a customer sees is not done
until it has been run.** When the phone is unavailable, say so in
`PROGRESS.md` — that is what made this sweep possible — and clear the backlog
at the first opportunity rather than letting it reach five.

## A checkout field's key is its position, and that is load-bearing
The website writes each Order Extra Field answer under `custom_{index}` — the
field's index in the `fmp_order_custom_fields` option — and the admin order
screen, the kitchen monitor and every slip read it back by pairing that key
with the definition at the same index. Nothing stores the label alongside the
answer.

Two consequences:

- **The app does not derive the key**, it is published. Deriving it would mean
  a second implementation of a convention that is only a convention.
- **Reordering the fields in settings re-keys every past answer.** An old
  order then shows its answers against the wrong questions. That is the
  website's behaviour and no route can fix it; it is written down so nobody
  blames the app for it.

A definition that cannot be drawn — no label, unknown type, or a select with
no options — is **dropped after its index is taken**, so removing one does not
shift the keys of the ones after it.

## A required checkout field is not required on the block checkout
The classic checkout validates them: `PickupDelivery::validate_custom_checkout_fields`
adds a `wc_add_notice` error and the order stops. The **block** checkout does
not — `checkout-pickup-delivery/index.js` renders the asterisk and never calls
`setValidationErrors`, and the Store API saves whatever arrives without
checking. So a store on the block checkout has required fields that are not.

That is a pre-existing gap and not one the app created, but it decided the
shape of task 8.2: the app validates in its own `Form` pass, and **no
validation was added server-side**, because the Store API is shared with the
website's block checkout and enforcing it there would start rejecting orders
that store accepts today. Raised in `PLAN.md` as an open dependency instead.

The honest limit: a crafted request can still place an order without a
required answer. The same is true of the website.

## An empty variation attribute means "any", and looks like broken data
`Build Your Pizza`'s three sizes were seeded with **empty** attribute values —
`{"pa_size": ""}` on every variation. WooCommerce reads an empty value as
**any**, so all three matched every size, at three different prices, and the
website would have served whichever came first.

Through the Store API that surfaced as `value: null` on every variation, which
made the dish unorderable by anything that matches a term to a variation. The
first read of it looked like a Store API limitation for custom attributes. It
was not; it was the demo data.

The attribute was also *named* `pa_size`, as if it were a taxonomy, when it is
a custom attribute — so "pa_size" is what a customer would have read on the
website too. Both fixed on the dev site: the attribute is `Size`, and the
variations carry `Small`, `Medium`, `Large`.

**The app still honours "any".** `VariationSelection` treats an empty value as
a wildcard rather than a literal, because a store may genuinely use one — a
"Large, any crust" variation is a real thing. Matching it literally would make
it match nothing.

## What the Store API gives for a variable dish, and what it does not
Settled by reading the live payload rather than the docs:

- `attributes[]` has `name`, `taxonomy`, `has_variations` and `terms[]`. For a
  **custom** attribute — what a restaurant types in rather than registering —
  `taxonomy` is null and **every id is 0**, on the attribute and on every
  term. So nothing can be matched on ids; `name` and `slug` are the only
  identifiers that work for both custom and taxonomy attributes.
- `variations[]` has `id` and the attribute values that name it, **and no
  prices**. There is no price per variation anywhere on the parent.
- `GET /products/{variation_id}` *does* work and returns the variation as a
  product of its own, with its price and its own stock state. A variation can
  be sold out while the dish is not, so this is worth reading rather than
  interpolating from the parent's range.
- `include=28,29,30` returns **nothing**: the products collection excludes
  variations. They can only be fetched one at a time.

So the app reads the chosen variation on demand, cached per id by
`productProvider`, and flipping back to a size already seen costs no request.

### The add-to-cart contract
`{ id: <parent>, quantity, variation: [{ attribute, value }] }`. The **parent's**
id, not the variation's — the server resolves it and answers with a line under
the variation's own id, which `FINDINGS.md` already records elsewhere.

`attribute` is sent **verbatim from the payload**. The Store API sanitises it
to the variation's meta key itself, so `Size` and `size` both resolve to
`attribute_size`; sending what the payload gave us keeps one fewer rule in the
app.

### `item_data` is empty for a variable line
The chosen size is in the cart item's **`variation`** key and nowhere else, so
a line summary built only from `item_data` shows two sizes of one dish as two
identical rows. Order lines are fine without any of this:
`get_formatted_meta_data()` already formats the variation attributes, so
`/app/orders/{id}` carries "Size: Small" as ordinary line meta.

## The selection was always there — just never kept
The reorder problem looked like it needed new data. It did not. By the time
`AppCartAddons::add_to_cart_data` runs, the app has already sent exactly what a
reorder needs: `{group_id, option_ids, quantities}` or `{group_id, text}`, the
payload `cart/add-item` accepts. That array was used to build the website's own
cart rows — names, values and prices, through `AddonFields` — and then thrown
away, and only the rows reached the order line.

So task 7.4 is three lines of real work: keep the submitted array on the cart
item beside the display rows, copy it to the order line at checkout, hand it
back. Nothing is reshaped anywhere, which is the point — **the stored payload
and the request body are the same thing**, so the round trip cannot drift. The
alternative, reconstructing a selection from `[Make it a meal] = No thanks`,
had no way to be right.

Verified by re-submitting the route's own answer, unmodified, to
`cart/add-item`: a radio, two checkboxes and a textarea came back as
`Medium 12"`, `Mushrooms`, `Basil` and "Extra napkins please".

### Presence is the signal, not content
`_fmp_addon_selection` is written **even when empty**, so its presence means
"this line's choices were recorded" and its absence means the order predates
the feature. Content alone could not tell the two apart: a line with no
add-ons and a line whose add-ons were lost both have nothing to show.

That absence is not an automatic refusal. If the dish takes **no choices
today**, an old order is still reorderable — there was nothing to lose. Only
an old line whose dish has add-on groups comes back
`choices_not_recorded`. On the dev site every dish matches a global add-on
group, so in practice every pre-7.4 order refuses; on a store without global
add-ons most will not.

### App-only fell out of the design rather than being bolted on
`keep_selection` guards on the **cart item key**, not on the request: only
`woocommerce_store_api_add_to_cart_data` writes `fmp_addon_selection`, so a
website order has nothing to copy and the hook returns immediately. No request
sniffing, no `is_rest` check, nothing to get wrong later. The meta is
underscore-prefixed and added to `woocommerce_hidden_order_itemmeta`, so it
reaches no order page, email or slip.

## Every line of the vendor list, against the plan
The section below settles whether `FEATURES-FROM-DEVELOPER.md` is *accurate*.
This one settles whether the plan **covers** it: all 39 sections walked against
`PLAN.md` and `PROGRESS.md` on 2026-11-12, so "checked line by line" is
auditable rather than asserted.

**Nothing new is missing from the ordering path.** Phase 8 found those, and a
second walk found no more. The three gaps this one did turn up are all
presentation, which is the result worth keeping — see the end.

Verdicts used below:

- **Done** — shipped; the owning task is in brackets
- **Scheduled** — a `todo` task owns it
- **Server-side** — works for an app order with no app code; the app neither
  helps nor hinders
- **v1 exclusion** / **v2** — deliberate, per `PLAN.md`
- **Website-only** — can have no app counterpart: shortcodes, layouts, page
  builders, wp-admin
- **App-owned** — the app decides this for itself and does not read the
  store's setting
- **Gap** — real, and no task owns it

### Free — 15 sections
| § | Section | Verdict |
|---|---|---|
| 1 | Two Data Sources, One Menu | **Done, with one gate missing.** WooCommerce mode is the app's whole premise [2.1–2.3] and categories are WooCommerce's `product_cat` [2.1]. A site in `food_menu_post` mode has no Store API and no `fmp/v1/app` routes, and the app does not yet say so — 8.7, scheduled. Menu slug and the admin screens are website-only |
| 2 | Layout Library That Sells Food | **Website-only.** Layout families, isotope, masonry, responsive columns and numbered paging are shortcode rendering. The app's counterparts are its own: category filter and paging [2.2], design system [1.3] |
| 3 | Shortcode Generator | **Website-only.** An app has no shortcodes — the same reason §5.4 is not a gap |
| 4 | Works With Your Page Builder | **Website-only.** Gutenberg, Elementor, WPBakery |
| 5 | Detail Page Control | **Scheduled.** The eight `hide_*` toggles are 10.1. The two colour controls are **app-owned** [1.3]. "Per-item overrides" are per *shortcode*, not per dish |
| 6 | Food Location & Multi-Branch | **Done.** Branch list [5.3], menu scoped by `X-FMP-Branch` [5.5], branch on the order [6.2], cart revalidated at the switch [6.6]. The floating location button is website UI; the app has its own selector [5.5]. `fmp_checkout_show_location` is 10.2 |
| 7 | Online Ordering with WooCommerce | **Done.** AJAX add-to-cart [4.5, 4.6], stock and availability [2.3, 8.1, 8.3]. "Blocks support" is **load-bearing rather than irrelevant**: the Store API *is* the Blocks API, so every app read and write rides the route the block cart uses — including its looser required-field behaviour [8.2]. Gateways: cash on delivery [6.3], the rest Phase 12 |
| 8 | Floating Mini Cart | **Done / app-owned.** The app has its own mini cart [4.6], with add-on and fee lines [4.3] and its own empty state [4.5]. Drawer side, opening behaviour, overlay, CSS-class binding, page exclusions and theming are website settings with no app meaning. The coupon form is **v2** |
| 9 | Table Reservation (now Free) | **v1 exclusion** — and the one worth re-making deliberately, per the section below |
| 10 | Tips & Gratuity (now Free) | **Scheduled** — 9.4 |
| 11 | Automatic Discounts (now Free) | **Partly done.** The cart already charges the discounted price [4.3]. Saying so on the menu is 9.1, the badge 9.2, recording it on the order 9.3 |
| 12 | Special Menu Popup (now Free) | **Scheduled** — 9.5, which also gives the banner carousel a real tap target |
| 13 | Currency, Pricing & Formatting | **Done.** `Money` holds minor units and formats from the Store API's own currency block — separators, decimal places, prefix and suffix [1.4]. The plugin's own currency settings are dead in the mode the app needs: `Fns::getCurrency()` only labels admin fields and prices the post type, and `trailing_zeroes` is guarded by `! has_pro()` while the app requires Pro. WooCommerce mode formats through `wc_price`, which is what the Store API reports |
| 14 | Branding & Experience | **App-owned.** `primary_color` and `company_logo` are never read; the app's theme is 1.3. The preloader and the React settings panel are website and wp-admin. See the end |
| 15 | Built for Real Sites | **Server-side, bar one.** HPOS is safe: the `fmp/v1/app` routes use WC CRUD, and their only `get_post_meta` calls are on **products**, which are still posts. Performance, upgrades and docs are the server's. **Translation is a gap** — see the end |

### Pro — 24 sections
| § | Section | Verdict |
|---|---|---|
| 1 | Premium Layout Library | **Website-only.** 20+ layouts, detail popups, AJAX pagination and Elementor widgets are all shortcode rendering |
| 2 | Rich Menu Item Data | **Done, bar one.** Variable pricing [8.1], regular and sale price [2.3], ingredients and nutrition [2.7], food tags [2.4]. Reviews are star and count only; the list and leaving one is 10.3 |
| 3 | Product Add-ons | **Done, all seven.** Groups and field types [4.1], server-side validation [4.2], price impact [4.3], and the quick-add gate via `requires_choices` [4.7]. §3.7 "carried through" holds for an **app** order too: `AppCartAddons` writes the website's own `fmp_addons` cart shape, so `FrontendCartAction::display_checkout_order_line_item` fires on a Store API order and the selection reaches the admin order, the emails and every slip. The separate `_fmp_addon_selection` [7.4] is the one that stays hidden, on purpose |
| 4 | QR Code Table Ordering | **v1 exclusion** — moot without dine-in |
| 5 | Pickup, Delivery & Dine In | **Done, minus dine-in.** Pickup and delivery with their own schedules [5.1, 5.4], date and time [8.4], closed days and holidays [5.2], pre-order window [8.4], per-branch overrides [5.3], order type on every surface [6.2]. Dine-in and its table list are the exclusion — and a store running **only** dine-in still has no order type in the app, which is an open dependency rather than a task. §5.6's "5 minutes" does not hold |
| 6 | Time Slot Order Limits | **Done.** Pickup and delivery caps and the statuses that count [5.2], per-branch overrides [5.3]. Of the three enforcement gates the app uses the API one, and checkout refuses a full slot regardless [6.2]. Dine-in caps follow dine-in |
| 7 | Timed Products | **Done** — 8.3 publishes availability and the menu honours `fmp_timed_products_behavior`. `TimedProducts::unavailable_at()` answers both it and 5.2 |
| 8 | Custom Order Statuses | **Done, bar the icon.** Unlimited statuses land in Active unasked [7.1], the colour draws the pill [7.2], and the drag-sorted pipeline builds the tracking stages [7.3]. Per-status email, SMS and WhatsApp are **server-side**. The per-status **icon** is a gap — see the end |
| 9 | Order Timeline & Customer Tracking | **Done, by a different route.** `/app/orders/{id}/tracking` rather than the public page [7.3]. §9.3 and §9.4 are two of the four claims that do not hold. The tracking page's own title and notes are website surface; new-order flagging is wp-admin |
| 10 | Order Bumps | **v2** — upsells, the cart's cross-sell carousel |
| 11 | Custom Checkout | **App-owned / scheduled.** The app's checkout is native and single-screen by design [6.1]; layout options, the custom heading and the Place Order text are website settings it does not read. Section-level visibility is 10.2 |
| 12 | Checkout Extra Fields | **Done** — 8.2, keyed by position because that is the website's own convention. Required is validated in the app's own `Form` only: the Store API accepts a missing one exactly as the block checkout does, raised as an open dependency instead of committed |
| 13 | Visual Table Reservation & Layout Designer | **v1 exclusion** — follows reservations |
| 14 | Advanced Discounts | **Scheduled.** 9.1–9.3 cover the fixed, scoped and threshold discounts the same way as the free percentage engine — the payload and the order meta are shared |
| 15 | POS Printing | **v1 exclusion** as a feature — no app prints — but **server-side** in effect: every slip is fed by app order data, and §3.7 above is why the kitchen slip has its add-ons |
| 16 | SMS & WhatsApp Notifications | **Server-side.** Fires for an app order as for a website one, custom statuses included. The app's own channel is push, 10.4 |
| 17 | Kitchen Monitor | **v1 exclusion** — staff |
| 18 | Front-End Staff Dashboard | **v1 exclusion** — staff |
| 19 | Order Management (Front-End) | **v1 exclusion** — staff |
| 20 | Inventory Management | **v1 exclusion** as a screen, **server-side** in effect: deduction on sale, restore on cancel or refund, and overselling protection all apply to an app order |
| 21 | Inventory Reports & Analytics | **v1 exclusion** — staff |
| 22 | Role Manager | **v1 exclusion** — staff. The app authenticates customers only [3.1] |
| 23 | Developer & Integration | **Why Phase 3 exists.** §23.1's `fmp/v1` is nonce-gated and unusable from a mobile client, which is the whole reason for the `fmp/v1/app` namespace |
| 24 | License, Updates & Support | **Website-only** — wp-admin |

### The walk found three gaps, and all three are presentation
Recorded as open dependencies in `PLAN.md` rather than as tasks, because each
is a decision before it is work.

- **The app reads none of the store's presentation settings.** `primary_color`,
  `company_logo`, the detail page's two colour controls, the custom checkout
  heading and the Place Order button text are all configurable on the website
  and all ignored. The scheduled exceptions prove the rule: 10.1 and 10.2 are
  in the plan because their toggles **hide information**, not because they
  restyle it. So the line is that the app honours the store's *rules* and
  *data* and owns its own *appearance*. Worth writing down because nobody
  decided it — it fell out of designing every screen from `All Screens.dc.html`.
- **The app has no localization layer at all.** No `lib/l10n`, no
  `flutter_localizations`, no `intl`, no `AppLocalizations` — every string the
  app owns is hard-coded English. What the *server* sends arrives in the site's
  language: status labels, checkout field labels, add-on names, error messages.
  So a translated store already gets a **half-translated app**, which is worse
  than an obviously English one. Free §15.1 ships POT files and WPML and Loco
  support; no task owns the app half.
- **A custom status has an icon, and the app draws only its colour.**
  `AppOrdersApi::status_color()` and `AppTrackingApi` publish `status_color`
  and nothing publishes the icon, while Pro §8.2 sells both. The smallest of
  the three: one payload field and one widget.

None of the three blocks an order, which is why Phase 8's audit did not catch
them — it looked for orders **the website can take and the app cannot**. These
are orders the app takes and then draws in its own clothes.

## What the vendor's own feature list does and does not settle
`FEATURES-FROM-DEVELOPER.md`, from the plugin developer, lives **outside this
repo** in the sibling folder `../food menu files/`. It is the master inventory
behind the Food Menu landing page — 24 Pro sections, 15 free ones, written
from the settings panel and controllers.

Checked line by line against both plugin codebases on 2026-11-11. It is
substantially accurate and is the best statement of *intent* available, but it
is marketing copy and **not a specification**. Four claims do not hold:

| Claim | What the code does |
|---|---|
| 9.3 "customers check progress with order ID and email" | The tracking page is keyed solely on `fmp_tracking_token` from the URL. There is no lookup form anywhere |
| 9.4 "configurable link format" | `fmp_tracking_link_format` is an `htmlFor` on a read-only `<code>` block showing `/fmp-track/{token}`. Nothing writes or reads it as an option. The **expiry** is configurable |
| 5.6 "Minimum lead time — no orders for 5 minutes from now" | The lead time is `delivery_preparation_day`, in **whole days**. `pickup_prep_minutes` exists but is consumed only by `AppApiFns::asap_label()`, which this project added; it gates nothing on the website |
| 5.4 detail page "per-item overrides" | Per **shortcode**, not per dish — `$scDetailsMetaFields` / `fmp_sc_details_settings`. There is no app equivalent, and none is wanted: an app has no shortcodes |

So: treat it as a map of what the product claims to be, and the code as what it
is. Where the two disagree the code wins, and the disagreement is worth sending
back — these four were.

## Reservations, tips, discounts and the special menu are now free features
The vendor list marks all four "(now Free)", and the code agrees: the
controllers live in `tlp-food-menu`, and the `has_pro()` calls inside them gate
**extras** only — the reservation form's country list, the special menu's
presets and page exclusions, and a guard in `Discount` that steps aside so Pro
can price the cart item without double-discounting. Switch Pro off and all four
still work.

This does not change v1's scope, but it changes the weight of one exclusion.
**Reservations are no longer a Pro extra**; they lead the free half of the
product, so every site that can run this app also has a booking engine the app
has no screen for. Recorded so the decision is re-made deliberately rather than
inherited.

## Two parity worries that turned out to be already handled
Checked while reviewing the vendor list, and both were already right. Recorded
so nobody investigates them twice:

- **Closed days and holidays.** `AppSchedules::closed_days()` calls the same
  `FnsPro::get_offday_schedule()` the website's own checkout uses, so a day the
  store is shut has no slots in the app either. Task 5.2 covered it.
- **Per-branch overrides.** `AppSchedules::interval()` and `slot_cap()` both
  take the location, so a branch running its own hours, intervals and slot caps
  is honoured. Task 5.3 covered it.

The pattern worth keeping: a feature named in the vendor list is not a gap
until the `fmp/v1/app` namespace has been grepped for it. Two of the five
things that looked missing were not.

## The tracking route answers a history, and the design wanted a plan
`GET fmp/v1/track/{token}` returns the timeline entries an order has passed
through and nothing else. **Every one carries `completed: true`** — the
website's own tracking page (`Timeline.js`) draws them as a list, marks the
last one current unless it matches `fmp_tracking_completed_status`, and stops
there. There is no four-step model, no percentage and no notion of a stage
still to come anywhere in either plugin.

The design assumes the opposite: four fixed steps, `pct` of `[12,45,78,100]`,
and different labels for pickup and delivery. Task 7.2 had recorded the gap as
"a step index only the tracking route knows", which turned out to be wrong in
both halves — the tracking route does not know it, and the estimate card never
needed it.

Three consequences, agreed before building:

- **The estimate card needed no tracking at all.** It is the order's own `eta`
  and type, both already on `/app/orders/{id}`. It was withheld for a reason
  that did not hold.
- **The progress strip needed a stage model that did not exist.** Inferring
  one from a status slug is exactly what 7.1 and 7.2 both refused.
- **So the plugin publishes it**, for the app only. The website's route keeps
  its payload and its expiry, and its page keeps drawing the history.

## A store declares its order of statuses by dragging them
The only sequence either plugin has. The Order Statuses screen sorts with
`@dnd-kit/sortable`, `save_statuses` replaces the whole array in that order,
and the shipped presets are pipelines — *Order Received, Prepping, In Oven,
Ready*. The admin copy calls them "workflow steps".

It covers the **middle only**. WooCommerce's own statuses are in
`PROTECTED_SLUGS` and cannot be redefined, so `pending`, `processing` and
`completed` sit outside the declared list and no end-to-end pipeline exists to
count against. `AppTrackingApi` therefore builds an order's stages as:

1. **What happened** — the timeline in time order, every entry reached.
2. **What is still to come** — the enabled custom statuses, in the declared
   order, not recorded *and* falling after the last one that was. A step
   earlier in the pipeline that never happened was skipped, not pending.
3. **The end** — `fmp_tracking_completed_status`, unless already present.

A store with no custom statuses gets **two** stages, not the design's four:
where the order is, and completed. That is the honest answer for a store that
never described a pipeline, and the strip reads it the same way.

### A finished order has no future, and completed is the easy one to miss
The early return was written for cancelled and refunded, which is the obvious
case — nothing is still to come for an order nobody is cooking. **Completed
needed it just as much**: without it the declared pipeline was appended after
completion and a delivered order read "2 of 6", with three steps apparently
still ahead of it. Caught only once the history row started drawing a strip
from the same numbers.

`is_failed` separates the two endings as finished-minus-completed, rather than
by listing cancelled, refunded and failed — so a store that renames
*completed* to "Picked up" still has exactly one success and the rest
failures.

## The order fixtures had gone stale by two fields
`order_delivery.json` and `order_pickup.json` were captured before task 7.2
added `status_color` and `is_active` to the single-order payload, so every
test using them was asserting against a payload the server no longer sends —
and `is_active` defaulting to false silently withheld the new estimate card
from both.

Re-capturing was not an option: the only pickup order on the dev site has
since been cancelled, and there is no processing one to capture. Diffed
against the live route instead, which showed the two missing keys and nothing
else of shape, and both were added with the values the live route returns.

The lesson is about captures generally: a fixture stops being a capture the
moment the payload grows, and nothing fails to say so — the parser fills the
gap with a default and the tests keep passing.

## A cash-on-delivery order's first stage reads "Pending payment"
WooCommerce writes `pending` and then `processing` in the same second, and the
timeline records both, so the strip opens on a status about money for an order
that was never going to be paid online. The website's own page shows it too,
and it is the store's own label, so it is drawn as recorded rather than
filtered — the app is not the place to decide a store's statuses are noise.
Worth knowing before anyone reads it as a bug.

## An order does not record its add-ons in a re-submittable form
An order line keeps its chosen add-ons as **display text** —
`[Make it a meal] = No thanks` — with no group id and no option id. So
nothing can rebuild a selection from an order: matching labels back to the
store's current groups breaks the moment an option is renamed, and picks the
wrong one silently rather than failing.

WooCommerce's own `order_again` does not help. It rebuilds a cart through
`woocommerce_order_again_cart_item_data`, and **neither plugin hooks it**, so
it drops every choice too.

A faithful "Reorder" therefore needs the plugin to store a re-submittable
selection on the line at checkout — and even then only for orders placed
afterwards. Task 7.4; kept out of 7.2 rather than shipped lossy.

## A pending page keeps a spinner, and `pumpAndSettle` never settles
Any list that reports another page to come holds a footer
`CircularProgressIndicator`, which animates forever — so a widget test of
paging times out before it can assert anything.

The first attempt worked around it with a page size of two, which quietly
created a state the app cannot reach: `hasMore` means a full page is loaded,
and ten order cards always overflow a phone, so the scroll listener always
has something to fire on. Testing an impossible state is worse than not
testing it.

Paging is tested through a `ProviderContainer` instead, and the widget tests
keep to a single page. The same applies to the menu list, which has the same
shape.

## `ltrim( $s, 'wc-' )` strips characters, not a prefix
PHP's `ltrim` takes a **character list**, so `ltrim( 'completed', 'wc-' )` is
`'ompleted'` — it ate the leading `c`. Task 7.1's status filter normalised
slugs that way and would have matched nothing for exactly the statuses it
cared about. `str_starts_with` instead.

Caught before it ran, and grepped across both plugins: no other instance.
Worth knowing because `wc-` prefixing is everywhere in WooCommerce code and
the failure is silent — a list that simply never matches.

## Define a status group by its endings, not its members
The app's order history splits Active from Past. The obvious implementation
lists the active statuses, and it is wrong here: this plugin lets a store
create its own, so a custom "Out for delivery" would fall out of **both**
tabs and vanish from the screen.

Naming the **finished** statuses instead — completed, cancelled, refunded,
failed — makes anything unrecognised active by default, which is the safe
direction: a store sees an order it is still working on rather than losing it.
`fmp_app_finished_order_statuses` covers the store whose custom status is an
ending.

The same rule, same default, already existed in
`OrderTracking::should_flag_as_new()` for the staff badge.

## The website's branch-vs-cart pass can never run for the app
`FoodLocation::validateCartLocation()` in the free plugin removes cart lines
the chosen location does not serve, and it is hooked on
`woocommerce_cart_loaded_from_session` — but **only when the
`fmp_location_id` cookie is set**. The app sends its branch as the
`X-FMP-Branch` header and has no cookie at all, so that pass never registers
for a mobile client.

The hole was not theoretical: the app could fill a cart at one branch, switch
to another, and have the order stamped with — and routed to — a branch that
cannot make it. Nothing in either plugin refused it. `AppBranchScope` scoped
product *queries* and stamped order meta; `AppCartAddons` validates add-ons
and never looks at the location; `SlotsApi` evaluates the cart against a
branch but only for *time*, and only as advice on a GET.

## One Store API hook both warns and refuses
`woocommerce_store_api_cart_errors` is called from `CartController::validate_cart()`,
which has two callers that behave differently:

- **checkout** lets the `InvalidCartException` out, so the order is refused
  with a **409** whose top-level `code` is the first `WP_Error` code added —
  `fmp_cart_item_branch`, not WooCommerce's own `woocommerce_cart_error` — and
  whose `data.cart` carries the refreshed cart, exactly like a total mismatch;
- **`get_cart_errors()`** catches it and merges it into the cart response's
  `errors` array instead, which the cart screen already renders.

So one hook gives both the warning on the cart screen and the hard refusal at
checkout, with no second implementation to keep in step. The app needed no
new classification either: `CheckoutFailure` matches on the substring
`cart_item`, so `fmp_cart_item_branch` already lands on
`CheckoutFailureKind.cart` with no retry offered. A test pins that, because it
is true by coincidence of naming rather than by design.

## Sampling an `AsyncValue` answers for a cart that has not loaded
`BranchSwitcher.check` first read `ref.read(cartControllerProvider).value` and
treated null as "nothing in the cart to lose". That is right only once
something else has loaded the cart — and the likeliest moment for the branch
picker to be opened is a **cold start**, where nothing has. The dialog would
not appear, and the dish would go without being mentioned: precisely the
failure task 6.6 exists to prevent.

`await ref.read(provider.future)` instead. A widget test caught it, because a
test harness has no cart bar quietly loading the cart in the background the
way the real shell does — which is the same reason the bug would have survived
manual testing.

## `has_options` knows about variations and nothing about add-ons
WooCommerce's `has_options` is `WC_Product::has_options()`, which is true for a
variable product and false for a simple one. Food Menu's add-on groups are the
plugin's own feature and never enter into it, so a **simple** dish carrying a
*required* add-on group arrives over the Store API as
`has_options: false, type: "simple"` — indistinguishable from a dish that
needs nothing. The seeded "Fresh Lemonade" is exactly that dish, and the
quick-add `+` offered a one-tap add the server then refused with
`fmp_app_addon_required`.

`Product.canAddDirectly` had carried a comment claiming `has_options` covered
both since task 2.3. Nothing had exercised it, because until task 4.7 the `+`
did not add anything.

The plugin now publishes `requires_choices` (food-menu-pro#22) on its Store API product
extension, and the app reads `needsChoices = hasOptions || requiresChoices`.
`has_options` is left alone: filtering `woocommerce_product_has_options` would
have fixed the app for free, and changed how every shop loop on the **website**
renders its add-to-cart button along the way.

## Two Store API extensions with the same namespace: the second wins, silently
`ExtendSchema::register_endpoint_data()` stores callbacks at
`$extend_data[ $endpoint ][ $namespace ]`. A plain assignment — no check, no
warning. So registering `food-menu-pro` against the product schema a second
time to add `requires_choices` would have *replaced* the registration that
publishes `ingredients` and `nutrition`, and the only symptom would have been
two fields quietly gone from the product response.

One class per endpoint and namespace, therefore. Pro's is
`Api/App/AppProductStoreApi.php` (was `ProductFoodDataStoreApi`, renamed
because it is no longer only about food data), and anything new about a
product goes into its payload rather than into a class of its own.

## A required add-on group is not only one marked required
`AppCartAddons` refuses a group with nothing chosen when it is `required`
**or** when `min_selection > 0` — the admin screen lets a group ask for two
of something without ticking required. A free-text group is the exception: it
goes by `required` alone, since there is no minimum to apply.

The rule now lives once, in `AppAddonGroups::requires_choice()`, called both
by the validator that enforces it and by the Store API field that advertises
it. Had they been written twice they would have drifted, and the symptom
would be the worst kind: a `+` that offers an add the server then refuses.

## Inserting a widget at the top of a list throws away the state below it
The checkout's refusal banner goes in at the front of the `ListView`'s
children. Children are matched to elements **by position**, so every section
after the insertion point shifted by one, failed to match, and was rebuilt
from scratch — new `State`, new `TextEditingController`s, and the customer's
name, phone and notes gone.

That is precisely the failure task 6.5 exists to prevent, and the test for
"keeps every field the customer filled in" is what caught it. The fix is a
key on `ContactDetailsSection`, which makes the match by identity rather than
position. Anything stateful below a conditionally-inserted sibling needs one.

## `expected_total` only refuses a total that went *up*
WooCommerce's checkout takes `expected_total` in **minor units** and compares
with `(int) $actual_total <= (int) $expected_total` — so sending a number
larger than the real total passes, which made an early probe look as though
the parameter was ignored.

What it does guard is the case that matters: a price or fee that rose between
the screen being drawn and the button being pressed is refused with a 409
`woocommerce_rest_checkout_total_mismatch` rather than silently charged. And
the refusal **carries the refreshed cart** under `data.cart`, so the summary
can catch up without another request.

## WooCommerce entity-escapes its own error messages
The total-mismatch sentence arrives as "The order total changed from
&#036;0.01 to &#036;3.95" — `esc_html` applied to a `wc_price()` string. Any
server message shown to a customer therefore has to go through `plainText()`,
the same as every other field from WordPress. It is easy to miss because most
error messages contain no markup at all.

## The Store API can read an order back, but not enough of one
`GET wc/store/v1/order/{id}?key=…` exists and answers with the items, the
totals and the addresses — for the signed-in customer, with the app's bearer
token, which is the part that was in doubt.

It is still not enough. It carries **no order number**, no date, no payment
title, and none of the plugin's own fields: not the order type, not the
pickup or delivery time the customer chose, and not `_fmp_tracking_token`,
without which the design's "Track order" button has nothing to open. Its
`extensions` block comes back empty.

The checkout's own response is no better — that one echoes the plugin's
extension *schema* with its defaults rather than the saved order. So neither
can be used, and `GET fmp/v1/app/orders/{id}` (food-menu-pro#21) is what the
order-received screen reads.

## `CrossAxisAlignment.stretch` in a scroll view asks for infinite height
The order-received screen's three tiles are a `Row` with `stretch`, so they
share a height. Inside a `SingleChildScrollView` that throws:
"BoxConstraints forces an infinite height" — stretch means "as tall as the
Row", and the Row's height is unbounded in a scroller.

`IntrinsicHeight` around the Row is the fix. Worth knowing because the
failure arrives as a `pumpAndSettle` timeout in whatever test touches the
screen, several layers from the cause.

## WooCommerce already refuses a gateway the store has switched off
Task 6.3 was written as "server-side validation that it is an enabled
gateway", and that validation turned out to exist: `POST checkout` with
`payment_method: cheque` on a store where cheque is disabled answers
`woocommerce_rest_checkout_payment_method_disabled` — "Check payments is not
available for this order—please choose a different payment method".

So Pro adds no validation of its own, deliberately. What it adds is the
**list**: the Store API's cart reports gateway ids and nothing else, and the
words beside a radio button are the merchant's, translated and often renamed.
`GET fmp/v1/app/payment-methods` answers with the title and description, and
with `supported` — whether this app can carry that gateway through to a
placed order, which is the app's reach rather than the store's.

## Enabled is not available, and an empty list is not an unknown one
Two different questions, and the app needs both. `/app/payment-methods` lists
what the store has **enabled**, which does not depend on a cart and is stable
for the session. `Cart.payment_methods` lists what is **available for that
cart**, which WooCommerce recomputes per order and can narrow by country or
total. The checkout intersects them.

`PaymentMethods.offered` therefore takes a **nullable** list: null is "the
cart has not been read yet" and leaves the whole list standing, while an
empty list is a real answer — nothing can pay for this cart — and leaves
nothing to show. Collapsing the two blanked the section on first paint.

## The checkout extension is all-or-nothing
`POST wc/store/v1/checkout` rejects the whole request with
`rest_invalid_param` when the `food-menu-pro` extension block is missing *any*
of its nine keys — "extensions > food-menu-pro > fmp_pickup_date is not of
type string". The schema types them all as strings and an omitted key arrives
as null.

So a delivery order still sends the pickup keys, and an app with no dine-in
screen still sends `fmp_dinein_date`, `fmp_dinein_time` and
`fmp_dinein_table`, all empty, plus `fmp_custom_fields: {}`. `OrderDraft`
builds the full block every time for that reason, and a test counts the keys.

Going the other way, the **response's** extension block is the schema's
defaults — all empty — not what was saved. The order cannot be read back from
the checkout response; task 6.4 re-reads it.

## WooCommerce wants a billing address even for a pickup order
A pickup customer never gives an address in the design, which draws the branch
instead. WooCommerce does not care: `POST checkout` with a name, email and
phone and no street is refused with `woocommerce_rest_invalid_address` —
"Street address is required, Town / City is required" — whatever the order
type, and whether or not the cart needs shipping.

So an address is required to order at all, not only to have one delivered.
The checkout asks for one on both types, and says so differently: "Add a
delivery address first." against "Add an address to your account first.".

## The branch never reached an order placed from the app
The free plugin writes `fmp_location_name` from a posted checkout field or the
`fmp_location_id` cookie, and the app has neither — so every app order was
filed under no branch, and the per-slot counting, which matches orders on
exactly that meta, never counted one. A branch's cap could be used up by app
orders while the app was still being offered the slot.

Fixed in the plugin (food-menu-pro#19) rather than worked around in Dart:
`AppBranchScope` already reads `X-FMP-Branch` on every REST request, so it
stamps the order too, resolving the name from the term server-side. The app
sends nothing new — a name the client supplied could be stale or translated.

## A spinner behind a modal is a frame loop that never settles
`pumpAndSettle` timed out on the first "it places the order" test. The cause
was not the dialog: the button's `CircularProgressIndicator` was still
animating behind it, because the busy flag was cleared in a `finally` that ran
*after* the dialog was dismissed.

Clearing it before showing the dialog fixes both the test and the real screen,
where a spinner was quietly running under the confirmation.

## Seeding a text field from a provider is a setState during build
The checkout prefills its name and phone from the account, which arrives a
frame or two after the first build. Writing `controller.text` from inside
`build` looks harmless and is not: the controller notifies its `TextFormField`,
which calls `FormState._fieldDidChange`, which calls `setState` on the ancestor
`Form` — while that same `Form` is building. The framework throws.

`ref.listen` is the fix, not `ref.watch`: the listener fires after the frame.
The initial value still comes from a `ref.read` in `initState`, which is
before the first build rather than during it. The address form gets away with
`_seed` in `build` only because it seeds **before** its controllers exist, by
constructing them with the text already in place.

## A prefill flag per form locks out the field that arrives late
The same prefill originally had one `_seeded` flag for the whole card. The
name comes from the account and the phone can come from the chosen address,
which is a round trip behind it — so the name seeded first, set the flag, and
a customer whose number was only on their address never saw it filled in.

One flag per field. They are also set when the customer types, so a field
they deliberately cleared is not refilled when the address book lands.

## A reserved error line reads as a gap when nothing can be reported
`AuthField` sets `helperText: ' '` so the box does not jump when an error
appears. On the checkout's order notes — the one field with no validator —
that blank line sat at the bottom of the card looking like a mistake, and
between two fields that *can* error, the message landed hard against the next
label. Both were only visible on the handset. The reserve is now tied to
having a validator, and the checkout puts 8dp between its fields.

## An open day with no hours is not a closed day
The plugin stores a weekly schedule as `{ day: { is_open, slots: [{start,
end}] } }`, and a day can legitimately be **open with no slots at all** —
which the website reads as no time restriction, not as closed. The dev store
is in exactly that state out of the box.

So "closed" cannot be derived from an empty slot list. `get_offday_schedule()`
is the only thing entitled to decide it, and it has a second rule worth
knowing: a day whose slots are *all* malformed — a start with no end — counts
as closed, while a day with no slots at all does not.

## A silent fallback can send someone to a closed door
`GET /app/order-types?branch=<id>` first answered an unknown branch with the
store-wide schedule, because the helper it leans on returns null both for "no
such branch" and for "this branch has no schedule of its own" — and the second
of those *must* fall back.

Those two cases needed separating. A branch that no longer exists is now a
404; a real branch without its own hours still falls back, per type, so a
location with custom pickup hours and no delivery hours does not lose
delivery. The failure mode of getting this wrong is not an error message —
it is a customer shown the wrong opening hours standing outside a shut
branch.

## Restoring a cart has to beat the first request to the server
The `Cart-Token` identifies a guest cart, and the Store API issues a fresh one
to any request that arrives without it. So reading the stored token
*asynchronously while the app starts* is not enough: whichever request goes
out first decides which cart the session belongs to, and a restore that lands
a moment later is already too late — the saved cart is orphaned and the
customer sees an empty one.

`StoreSessionNotifier` is therefore an `AsyncNotifier` whose `build()` does the
restore, and `StoreSessionInterceptor.read` is async and awaits it. That
mirrors what `AuthInterceptor` already does with the keychain, for the same
reason.

Only the cart token is persisted. The nonce comes back on every response and
is short-lived, so storing it buys nothing and risks replaying a stale one.

## A Stack sized to a Text puts a floating bar where nothing can tap it
The floating cart bar is `Positioned(bottom: 0)` inside the shell's `Stack`,
whose other child is `navigationShell` and therefore fills. A widget test that
stood in a bare `Text` for that child got a Stack sized to the text, which put
the bar outside the viewport — and `tester.tap()` reported only a hit-test
*warning* before failing on the assertion afterwards.

The harness now uses `Positioned.fill`. Worth watching for generally: a tap
that silently misses reads exactly like a widget that ignored it.

## A test helper that takes an object can be handed a different one
Three of the store-session tests passed a freshly built fake into the
container helper and then asserted on the `setUp` instance. One failed
honestly; the other two **passed for the wrong reason**, asserting an empty
write log on a store nothing had ever written to.

The helper now builds the fake itself and keeps it, so a test can only assert
on the instance actually in use. Any fake reachable by two names is one
refactor away from this.

## Clearing the cart is the one Store API route that does not return a cart
`GET /cart`, `cart/add-item`, `cart/update-item` and `cart/remove-item` all
answer with the whole cart, which is why a mutation never needs a follow-up
read. `DELETE /cart/items` does not: it answers with the **items list**, which
after a clear is `[]`. Taking that as the new state would leave the totals
showing the old amount on an empty cart, so `CartRepository.clear()` reads the
cart back.

## A dish opened by deep link has nothing to pop
`context.pop()` throws `GoError: There is nothing to pop` when the dish is the
first route in the stack — which is what a deep link, a notification tap or a
cold start on a dish URL produces. The dish is normally pushed over the menu,
so this never showed up in the app itself; it surfaced in a widget test that
pumped the dish as the router's initial location.

`closeDish()` pops when it can and otherwise goes to the menu. It is used by
the close button, the error screen's "Back to the menu" and the add-to-cart
success path alike.

## A fake that fails "the next call" fails the wrong one
`FakeCartRepository.failNext` was spent on the controller's own first read
rather than on the mutation the test meant to fail: a controller reads the
cart the moment it is first touched, and in a widget test that happens inside
the tap being tested. The symptom is a test that sees no error anywhere and no
obvious reason why.

Hence `failNextWrite`, which only fires on a mutating call. Worth copying into
any fake whose subject loads lazily.

## The add-ons endpoint nests its currency; the Store API does not
`GET /fmp/v1/app/products/{id}/addons` returns `{ product_id, currency: {…},
groups }`, with the `currency_*` keys **inside** a `currency` object. Every
Store API price block repeats those same keys **inline** instead, and the
cart-item extension added in task 4.3 follows the Store API.

`Currency.fromJson` reads the keys off whatever map it is handed, so pointing
it at the wrong level does not fail — it falls back to USD with an empty
prefix and quietly renders `2.50` where the store wanted `$2.50`. Caught by a
fixture taken from the live dev store rather than written by hand, which is
the argument for capturing fixtures from real responses.

`ProductAddons.fromJson` now reads the nested block when there is one and the
root otherwise, so the same model can also read a cart item's
`extensions['food-menu-pro']`.

## A widget test taps nothing when the target is below the fold
The dish screen's add-on groups sit well past the bottom of the default
800×600 test surface. `tester.tap()` on an off-screen widget does not throw —
it derives an offset outside the viewport, hits nothing, and the test then
fails on the *assertion* instead, which reads exactly like the screen
ignoring the tap.

Anything inside the scrolling body is tapped through a helper that calls
`tester.ensureVisible()` first. Worth remembering for every screen whose
content grew past one viewport — see also the phone-width note below.

## An add-on group's id is its key, not its position
This one had no symptom. `addon_lists()` returns a dish's add-on groups, and a
group has two numbers attached to it:

- its **array key**, which is the id `GET /fmp/v1/app/products/{id}/addons`
  publishes and therefore the id the app sends back, and
- its **position** in that array, which is what the website counts with when
  it builds the `field_name` stamped on every cart entry.

They agree for a dish carrying its own add-ons, because that is a plain list.
They do not agree for **global** add-ons: `get_global_addon_data()` filters the
stored groups by their targeting and assigns into `$addons[ $key ]`, so a dish
matched by the second and fourth global group gets back keys 1 and 3 sitting at
positions 0 and 1.

Task 4.2 read the position. A selection sent with the id the app was given
landed on the wrong group, or on no group at all, and **nothing in the response
said so** — no error, no missing field, just a cart line without the add-on.
On the dev store `Cutlery` is global group 1, so every `group_id: "1"` the app
sent was silently discarded. Found in task 4.3, because the read path has to
publish truthful group ids; fixed there, with `AppAddonGroups` now the one
place that holds both identities.

The lesson that generalises: an id the plugin hands out and an index the plugin
counts with are not the same thing, even when they match on the data in front
of you. The seeded dev data had them matching for product-level add-ons, which
is why 4.2 looked right.

## A cart line is not always base price plus add-ons
The obvious way to give the app a price breakdown — send the add-on deltas and
let the app subtract — is wrong on this plugin. `price_calculate()` runs every
cart item through `Fns::discount_price()`, which takes a percentage off the
dish, and off the add-ons as well when `fmp_applicable_discount` is
`addon_total`. So `prices.price` can be less than base + the deltas, and by
different amounts depending on a setting the app cannot see.

Task 4.3 publishes two numbers instead of one:

- `addons_total` — the stored deltas added up. This is what the order line item
  records and what the website labels "Addons price".
- `addons_total_charged` — the add-on part of the price actually charged.

and derives `base_price` by asking `price_calculate()` what the line would cost
**with its add-ons removed**, then taking the add-on part as the remainder of
what the cart charged. That keeps
`base_price + addons_total_charged == prices.price` true by construction,
through any pricing rule, and parks rounding residue on the add-on side rather
than letting it break the sum. Distributing a percentage across the individual
add-ons and summing would have been the natural-looking alternative, and would
drift by a minor unit against the server's single-shot calculation — the same
class of bug as the 100-short total in task 4.2.

## Bundle ID is two-segment
`com.foodmenu` has no third segment, so `flutter create --org` could not
produce it (it always appends the project name). The IDs were set by hand in
`android/app/build.gradle.kts` and `ios/Runner.xcodeproj/project.pbxproj`.
Any future `flutter create` re-run over this project will reintroduce
`com.example` — re-check both files if that happens.

## Hook activation is per-clone
`core.hooksPath` lives in `.git/config`, which is not versioned. A fresh clone
has **no** attribution guard until `tool/setup_hooks.sh` is run. Worth a CI
check later if commits start arriving from other machines.

## The guard allows human co-authors
`.githooks/commit-msg` only blocks trailers naming AI tools
(claude/anthropic/copilot/gpt/openai/gemini/cursor/codex), bot addresses and
the 🤖 emoji. A normal `Co-authored-by: Name <email>` still passes, which is
intentional. Commented (`#`) lines are ignored.

## The plugin's `fmp/v1` API is a browser-only staff API
40 routes are registered under `fmp/v1`, and they cover back-office work:
inventory, purchase orders, suppliers, stock alerts, reports, order CRUD with
line items, dashboard stats. Exactly **one** is public: `GET /fmp/v1/track/{token}`
(customer order tracking).

The blocker is authentication. 34 handler sites across 10 API files begin with:

```php
$nonce = $request->get_header( 'x-wp-nonce' );
if ( ! wp_verify_nonce( $nonce, 'wp_rest' ) ) {
    return new \WP_Error( 'unauthorized', 'Authentication failed', [ 'status' => 401 ] );
}
```

A `wp_rest` nonce is derived from the logged-in **cookie session**, so no token
scheme can produce one. Verified against the running site: with a WordPress
Application Password, `GET /fmp/v1/dashboard/stats` returns 200 (it checks a
capability, not a nonce) while `GET /fmp/v1/orders` returns 401. These routes
are not reachable from a mobile client as written — they were built for the
plugin's own React dashboards, which run inside an authenticated browser.

Consequence: a staff-side app needs an auth path added on the plugin's
`mobile-app` branch — swap the nonce gate for a capability check that also
accepts Application Passwords (or a token), keeping the nonce as one accepted
credential so the existing React dashboards keep working.

> **Customer side resolved** by food-menu-pro#6 (task 3.1), which takes the
> other route: rather than relax the gate on 34 handler sites, it adds a
> `fmp/v1/app/*` prefix that never had one. The staff routes are untouched and
> still unreachable from a mobile client — which is fine, because the app is
> customer-facing. See *Bearer tokens, not a relaxed nonce gate* below.

## Customer-side ordering has a real headless path, via WooCommerce
The plugin exposes no customer menu/cart/checkout REST API — that flow is PHP
templates plus `admin-ajax` calls. But WooCommerce's own Store API
(`wc/store/v1`) is present and designed for headless clients:

- `GET /wc/store/v1/products` is public, no auth, and returns prices, sale
  flags and currency.
- Cart writes need two headers the API itself hands back: `Nonce` (a Store API
  nonce, returned on every response) and `Cart-Token` (a JWT identifying the
  guest cart). Verified: `POST /wc/store/v1/cart/add-item` with both headers
  added 2 × Iced Latte and returned a correct total.

So menu browsing and a guest cart work today with no plugin changes. What is
**not** covered is everything Food Menu layers on top of the cart — add-on
groups, pickup/delivery/dine-in order types with their time slots and per-branch
rules, tips, automatic discounts, branch selection. Those are cart/checkout
hooks and form fields, so they need Store API extension
(`woocommerce_store_api_register_endpoint_data`) or dedicated endpoints.

## The Pro CLAUDE.md REST table is partly stale
It documents `/qr-codes`, `/order-statuses`, `/timed-products`, `/reports`,
`/inventory-logs` and `/order-timeline` as top-level routes. On a live install
the actual paths differ — `/orders/statuses`, `/orders/{id}/timeline`,
`/reports/valuation`, `/reports/waste-cost` etc. Enumerate
`?rest_route=/fmp/v1` on the running site rather than trusting the table.

> **Corrected 2026-11-11.** This originally said `/qr-codes` and
> `/timed-products` "are not registered at all". They are — **when the feature
> is switched on**. Both register conditionally, and QR table ordering and
> timed products were off on the dev site when this was first written. A later
> enumeration with them on returned 71 routes including both. The lesson is the
> one the entry already gives, pointed at itself: enumerate the running site,
> and say *when* you enumerated it, because a conditional route is absent and
> present on the same install.

## Ingredients and nutrition in online-ordering mode — RESOLVED
> **Resolved** by food-menu-pro#5, which adds both to WooCommerce products and
> exposes them through the Store API. The analysis below is kept because it
> explains why the fix is shaped the way it is. The one line to carry forward:
> **do not merge the product Food Data box into `Admin\Metabox\PostMeta`** —
> its save is guarded by a post-type check, and relaxing that would run the
> whole `singleFoodMetaFields()` loop on every product save.

### Original analysis — ingredients and nutrition did not exist for products
The plugin's "rich menu item data — ingredients, nutrition facts, food tags"
applies to its **own `food-menu` post type**, not to WooCommerce products. The
app runs against products, because that is what online ordering requires, so
two of those three fields are unreachable.

Traced on a live install:

- `food-menu-ingredient`, `food-menu-nutrition`, `food-menu-tag` and
  `food-menu-unit` are registered for **`food-menu` only**. `get_object_taxonomies('product')`
  returns none of them.
- The **Food Data** metabox that captures them is registered against
  `TLPFoodMenu()->post_type`, i.e. `food-menu`
  (`food-menu-pro/app/Controllers/Admin/Metabox/PostMeta.php`). The only
  `add_meta_box( …, 'product', … )` in either plugin is for Reviews.
- The data itself is post meta — `_ingredient` and `_nutrition`, each an array
  of `{id, unit_id, value}` referencing ingredient and unit terms
  (`FnsPro::get_fm_ingredient_list()`).
- The tabs that display them render through the plugin's own
  `fmp_single_details` action, not WooCommerce's `woocommerce_product_tabs`.
- On the dev site: 18 products, **0** carrying `_ingredient` meta, and there is
  no admin UI that could add it.

**Food tags are fine**, via a different route: WooCommerce's own `product_tag`
taxonomy, which the Store API returns as `tags` on each product. That is what
task 2.4 shipped. It is *not* the plugin's `food-menu-tag` taxonomy.

To get ingredients and nutrition into the app, one of:
1. extend the Food Data metabox and its meta to `product` on the `mobile-app`
   branch, then expose both through REST — the faithful option, and it also
   fixes the plugin's own web UI in online-ordering mode;
2. model them as WooCommerce product attributes, which the Store API already
   returns — no plugin code, but a different data model from the plugin's and
   a manual migration for anyone already using `food-menu` posts;
3. leave both out of v1.

Option 1 was chosen and shipped. The taxonomies now take an optional
`object_types` key that is **merged with** `food-menu` rather than replacing
it, a separate self-contained metabox writes the same `_ingredient` /
`_nutrition` rows on products, and a Store API extension returns them under
the `food-menu-pro` namespace. Storage is byte-identical to the post type's,
so `FnsPro::get_fm_ingredient_list()` was untouched.

## Bearer tokens, not a relaxed nonce gate
Task 3.1 added `fmp/v1/app/auth/{register,login,refresh,logout}` plus the layer
the rest of the app API sits on. The decisions behind it, because several were
close calls:

- **A new prefix, not a relaxed gate.** Editing the nonce check on 34 existing
  handler sites would have put every staff route one mistake away from being
  public. The app's routes are new files that never had a nonce.
- **`determine_current_user`, not a custom permission callback per route.**
  Resolving the token into the actual WordPress current user means capability
  checks, WooCommerce customer sessions and `get_current_user_id()` all work
  untouched, which is what lets Phase 4's cart and Phase 6's checkout run
  against WooCommerce's own Store API rather than re-implementing them. The
  filter must be attached before anything first asks who is logged in, so it is
  booted from `FMP::init_hooks()` rather than the plugin's `controllers()` list,
  which runs on `init` and is skipped in debug mode.
- **No JWT.** `vendor/` is committed in both plugins, so a dependency would
  mean committing a library to ship four routes. Opaque tokens
  (`fmpa_{user_id}_{session_id}_{secret}`) carry the ids in plain text so a
  token resolves in one `get_user_meta()` read instead of a meta query, and only
  HMAC-SHA256 hashes of the secrets are stored — a leaked database row is not
  replayable. HMAC rather than `wp_hash_password()` because the secret is 256
  random bits, so there is nothing to brute force, and bcrypt on every
  authenticated request would be a self-inflicted denial of service.
- **Refresh reuse revokes the session.** Standard OAuth 2.0 BCP, and it has a
  direct consequence for task 3.4: **the Flutter client must serialise
  refreshes behind a single mutex.** Two concurrent 401s each triggering their
  own refresh will sign the user out. A 401 from `/refresh` means logout, not
  retry.
- **The per-account login limit is looser than the per-IP one.** Counting
  failures against the account being *targeted* is what stops a distributed
  attack on one customer, but a tight limit there lets anyone lock a known
  customer out by guessing badly on their behalf. 15/15min per account against
  20/15min per IP is the compromise.
- **`REMOTE_ADDR` only.** `X-Forwarded-For` is client-supplied, so trusting it
  by default would let anyone defeat every limit by sending a new value per
  request. Sites behind a proxy opt in through `fmp_app_client_ip`.
- **Registration follows WooCommerce's setting.** It is off by default — and
  was off on the dev site — so this is a real deployment step, now recorded as
  an open dependency in `PLAN.md`. Overriding it would mean the app creating
  users on a store whose owner deliberately turned registration off.
- **HTTPS is required only when the site is already HTTPS.** Enforcing it
  unconditionally would break the plain-HTTP dev site; not enforcing it at all
  would let a real install be downgraded into leaking passwords.

Every failed sign-in returns one identical error. `wp_authenticate`
distinguishes an unknown user from a wrong password, and passing that through
would have made the route an account enumeration oracle.

### Still missing
Password reset, email verification and social sign-in. None were in the plan
for 3.1, but password reset is the one a real store will notice: a customer who
forgets their password has no in-app route back today.

### PHPCS could not be run
The plugin's `composer cs` shells out to a `phpcs` binary that is not installed
on this machine, and its committed `vendor/` holds only the Composer
autoloader. The new files were written to the plugin's conventions — tabs,
docblocks, Yoda conditions, sanitised `$_SERVER` reads — and checked with
`php -l`, but not machine-verified against WordPress-Core.

## The address book, and the two things WordPress does not tell you
Task 3.2 added `GET|PUT /fmp/v1/app/me`. WooCommerce stores exactly **one**
billing and **one** shipping address per customer, so the design's labelled
"Home" address and its "Saved addresses: 2" row are not WooCommerce concepts.
The book is plugin storage, with the default **mirrored into** WooCommerce's
billing and shipping fields so the web account page, order emails and the admin
order screen keep agreeing with the app. The mirror is one-way: the book is the
source of truth, Woo's fields are a derived copy.

Two things bit during the live run and are worth remembering:

### `billing_phone` is the account's phone, not an address's
`/me` returns `user.phone` from `billing_phone`, because that is the meta key
WooCommerce uses for a customer's contact number and the one checkout and order
emails read. The address book also has a per-address `phone`. Mirroring that
onto `billing_phone` meant **saving an address silently rewrote the customer's
contact number**. Postal fields now come from the default address; the contact
phone stays owned by the profile; `shipping_phone` takes the address's, since a
per-delivery contact is a real thing.

The underlying point: WooCommerce's customer meta is a flat namespace shared by
the profile and the address, so any new address store has to decide, per field,
which side owns it.

### A `WP_User` is not a snapshot
`display_name` should follow a rename only when it still looks generated, which
means comparing it against the name it was generated *from*. Holding
`get_userdata()` across the write does not work: `WP_User`'s magic getters read
through the user meta cache, and `wp_update_user()` refreshes that cache, so
the "before" object hands back the **new** values a moment later. The fix is to
copy the fields out as plain strings first. Anything else that needs a
before-and-after around a user write has the same trap.

### Address validation belongs to WooCommerce
`WC()->countries->get_address_fields( $country )` already knows what each
country requires — the US wants a state and a ZIP, the UK a postcode but no
state, the UAE neither, Bangladesh a state but no postcode. Hard-coding those
would be wrong in most of the world. Its field labels are localised too, so a
US customer is told "ZIP Code" rather than "Postcode".

One API wrinkle: `WC()->countries->get_states( $country )` returns **`false`**,
not an empty array, for countries with no state list.

### The address screens do not exist in the design
Checkout's **Change** button and the Account screen's **Saved addresses** row
are both `toast()` stubs — `'Address book opens here'`. Agreed to draw the list
and the add/edit form to match the app's existing design language, now tasks
3.7 and 3.8.

## The design has no auth screens, and never did
Its ten screens are home, menu, product, cart, checkout, success, orders,
order, account and wishlist. There is no sign-in, no register, no password
screen. The account screen assumes a signed-in customer — "Richard Davis" is
hard-coded — and its **Log out** is a `toast('Logged out (demo)')` stub, as are
**Edit profile**, **Saved addresses**, **Payment methods** and **Help**.

So task 3.3's screens, like the address screens before them, are drawn from the
design's own vocabulary rather than copied from it: `page` background, 16px
gutters, `field` input fill with a `line` hairline, brand red only on focus and
error, and the full-width 48px call to action from checkout. The design's
account screen does use a full-width button (`width: calc(100% - 32px)`), which
is why the empty state's **Sign in** is full width too.

Worth remembering when the remaining stub rows come up in task 3.7: the design
shows what each row *says*, never where it goes.

## Validate like the server, not more strictly
`AuthValidation` mirrors the plugin's rules — eight characters, a password that
is not the email address — and deliberately stops there. A client that rejects
input the server would have accepted is a worse failure than one that lets the
server have the last word, because the customer has no way to argue with it.
The email pattern is loose for the same reason: the real grammar is not worth
encoding, and a false rejection is unrecoverable from the user's side.

The one place the app is **stricter** than the API is registration requiring a
first and last name, and that is not stylistic: WooCommerce requires both on
every address, and the design's checkout requires a full name, so an account
without them would just be asked again at the first order.

## A 429 is not a retryable error
`ApiException.isRetryable` deliberately excludes 429. It will succeed
eventually, but not now, and offering an immediate "Try again" to a
rate-limited customer just spends another attempt against the limit. The
plugin sends the remaining window as `data.retry_after`, so the banner says how
long to wait instead. `data.field` is lifted the same way, for the address form
in task 3.8.

## Running on physical devices
Both platforms needed configuration that neither simulator nor emulator ever
exercises, so none of it surfaced until a real device was attached.

### Android could not reach the network at all
Android has blocked cleartext HTTP by default since API 28, and the dev site is
plain HTTP on the LAN, so every request failed before leaving the device.
Fixed with a network security config under **`android/app/src/debug/`**, which
compiles into the debug build alone — release builds keep Android's HTTPS-only
default. It is deliberately not scoped to the dev machine's address: the config
matches domains, not CIDR ranges, and the LAN IP changes between networks, so
pinning it would only break on the next move. The build type is the boundary
that matters.

### A release build would have had no network permission
Flutter's template declares `INTERNET` only in the **debug and profile**
manifests, which is enough for hot reload. The app is a client for a WordPress
backend, so it now declares it in the main manifest too. This would not have
shown up until the first release build in Phase 13.

### `com.foodmenu` is owned by one specific Apple team
Signing for a physical iPhone failed with *"The app identifier com.foodmenu
cannot be registered to your development team because it is not available"* on
team `FAAHP7377L`, and **succeeded on `M34L8S85ZF`**. A two-segment identifier
this generic is widely contested, so this is not a free choice: **device builds,
TestFlight and the App Store all require team `M34L8S85ZF`**, now set as
`DEVELOPMENT_TEAM` in the Xcode project. Anyone building on another account
will have to change the bundle ID, which has App Store consequences — worth
knowing before task 13.2 (release builds and signing).

### What each target can actually verify
| | Simulator / emulator | Physical Android | Physical iOS |
|---|---|---|---|
| Layout and theming | yes | yes | by eye only |
| Typed input, real keyboard | no | **yes**, via `adb shell input` | no |
| Screenshots from CLI | `simctl io` | `adb exec-out screencap` | **none** |
| Platform autofill | no | **yes** | by eye only |

Physical Android is the only target that can be driven end to end from a
terminal, so it is where the interactive states belong. There is no CLI
screenshot or input API for a physical iPhone, so iOS visual checks are either
the simulator or a human looking at the device.

### `adb shell input text` is not reliable
It silently drops and duplicates characters in longer strings, and the
device-side shell eats `#` unless the literal is single-quoted
(`adb shell "input text 'A@2020##'"`). A mangled email produced a genuine 401
that looked exactly like an app bug. If a login fails unexpectedly, **read the
field back** — tap the reveal icon on the password — before suspecting the code.
Typing character by character with a short sleep is the reliable form.

## A debug build will not launch from the iOS home screen
Tapping the app icon on a physical iPhone shows a black screen reading *"In
iOS 14+, debug mode Flutter apps can only be launched from Flutter tooling,
IDEs with Flutter plugins or from Xcode."* The Dart code never runs.

This cost real time, because it is indistinguishable from a broken app: the
screen is not the app's own error state, so "no products, could not reach
server" looked like a networking fault when nothing was running at all. Worse,
`xcrun devicectl device process launch` **reports success** for a debug build
and the process genuinely exists — it is just sitting on that placeholder. Do
not treat a successful launch command as evidence the app is running.

**Use `flutter run --profile` for anything on a physical iPhone.** A profile
build launches from the home screen like a normal app.

## iOS needs two separate permissions to reach a LAN server
`NSAllowsLocalNetworking` only relaxes App Transport Security. Since iOS 14 a
connection to a local-network address *also* needs the **Local Network privacy
permission**, which requires `NSLocalNetworkUsageDescription` in `Info.plist`.
Without a purpose string the system denies it outright, **silently, with no
packets leaving the device** — so the server sees nothing and there is nothing
to debug from either end. Simulators do not enforce it, which is why the app
worked there for weeks.

The key is now set. It costs production nothing, because the prompt is
triggered by actually touching the local network rather than by the key
existing, so a build pointed at a public HTTPS host never asks.

Honest caveat: adding it did **not** by itself make the handset reach the LAN
dev site. The symptom was resolved by pointing the app at the live HTTPS site
instead, so the residual LAN-on-iPhone problem is unproven — most likely stale
privacy state from the installs that predated the key. The key is correct
regardless, which is why it stays.

## Prove the app is running before debugging the network
Three separate false trails came from measuring the wrong thing:

1. PHP's built-in server **does not log requests handled by `router.php`**, so
   the access log shows only static files and makes a working REST API look
   silent. A one-line `muplugins_loaded` logger writing `REMOTE_ADDR` and
   `REQUEST_URI` gives ground truth.
2. An ATS experiment that "proved" ATS was innocent had actually run on a debug
   build that was never executing.
3. `adb shell input text` corrupting an email produced a genuine 401 that
   looked exactly like an auth bug.

The order that works: confirm the app is *running*, then that its packets
*arrive*, then look at the response. Checking Safari on the same handset
separates network from app in one step.

## Testing targets, after the live site was opened up
`https://radiustheme.net/demos/food-menu` runs the merged Pro plugin over
HTTPS, which makes it the **only practical target for a physical iPhone**: a
public HTTPS host needs neither cleartext ATS nor the Local Network permission.
It is seeded to mirror the local site — 16 products, 6 categories, 7 tags, one
variable product, one out of stock, three on sale, and two banner posts in
`app-banners`.

Note it began as a **non-WooCommerce** install, which usefully exercised the
fallback paths: registration fell back to `wp_insert_user`, and the address
endpoints returned a clean `503 fmp_app_woocommerce_missing` rather than
crashing. WooCommerce is installed there now.

## A dio QueuedInterceptor cannot retry its own request
The obvious shape for refresh-on-401 is a `QueuedInterceptor`, so dio
serialises the callbacks and a burst of 401s cannot each start a refresh. It
deadlocks. `dio.fetch` re-enters the interceptor chain, so the replayed
request's callbacks queue behind the error handler that is still waiting for
them. The test hung for its full 30-second timeout rather than failing.

`AuthRefreshInterceptor` is therefore a plain `Interceptor`, and
deduplication lives where it belongs: a single-flight future in
`AuthController.refresh` that every caller awaits. The retried request carries
an `extra` marker so a second 401 gives up instead of looping.

That split is worth keeping in mind generally — the interceptor handles *one*
request, the controller owns what is true for the *session*.

## Reading auth state synchronously races the keychain
`AuthInterceptor` originally read the access token synchronously. At a cold
start the session is still being read back from secure storage, so every
request made in that window went out unauthenticated — silently, and only on a
real launch, which no widget test reproduces.

`readToken` is async now and awaits the controller's restore before deciding
there is no token. The cost is that early public requests wait a few
milliseconds on a keychain read; the alternative is a first authenticated
request that fails for no visible reason.

## Store token expiry as an absolute time
The server sends `expires_in` — a lifetime in seconds. Persisting that is
useless: the app may be closed for days, and on restore the number says nothing
about whether the token is still good. `AuthTokens` resolves lifetimes against
the clock at issue time and `TokenStore` writes the resulting absolute
timestamps.

## A serialized meta list cannot be amended safely
Task 3.5 started out storing the wishlist as one serialized list in user meta,
which is how `_fmp_app_addresses` works. That is fine for an address book —
the app holds the whole list and PUTs it back — but wrong for a heart, which is
tapped one dish at a time and fast. Two taps 200ms apart are two requests that
both read the old list; the second write discards the first favourite, and the
customer sees a filled heart that is gone on refresh.

Compare-and-swap was the obvious fix and does not work. `update_user_meta()`
takes a `$prev_value`, but applies it under `! empty( $prev_value )`:

```php
if ( ! empty( $prev_value ) ) {
    $where['meta_value'] = maybe_serialize( $prev_value );
}
```

An empty array is `empty()`, so the guard is silently skipped exactly when the
previous value is the empty list — the first-favourite case, which is the one
that races. Nor does WordPress offer any other atomic amend for a serialized
value, and `add_metadata` is reached before the `$prev_value` clause when no
row exists yet, so two simultaneous first writes create two rows.

**Use a repeated meta key instead.** One row per item makes adding a single
INSERT and removing a single DELETE-by-value, so there is no read-modify-write
and nothing to guard. Ten simultaneous adds from an empty wishlist kept all
ten. Two further things come free: `umeta_id` is monotonic, so insertion order
needs no stored timestamp, and `delete_user_meta( $id, $key, $value )` deletes
*every* matching row, so a duplicate left by a race disappears on the next
removal.

The trade is that `get_user_meta()` primes the whole user-meta cache, so N rows
load whenever anything touches that user's meta. At a 100-item cap that is
negligible. Reach for this pattern whenever single items are written
independently; keep the serialized list when the client always owns the whole
collection.

## Hydrate through `rest_do_request()`, not a second serializer
The wishlist screen draws the same dish cards as the menu, so the endpoint has
to return products, not IDs. Writing a product serializer in the plugin would
have meant a second payload shape to keep in step with the Store API's — and
it would have missed the `food-menu-pro` extension block that task 2.7 added.

Dispatching the Store API's own route internally avoids both:

```php
$request = new WP_REST_Request( 'GET', '/wc/store/v1/products' );
$request->set_query_params( [ 'include' => $ids, 'orderby' => 'include', … ] );
$response = rest_do_request( $request );
```

`include` + `orderby` → `include` maps to `post__in`, so the Store API returns
the dishes in the order they were asked for and nothing needs re-sorting in
PHP. `per_page` tops out at 100, which is why the wishlist cap is 100 — a full
wishlist hydrates in one pass. The products route takes no nonce (only the
cart routes do), so an internal dispatch needs no special handling.

## The Store API hides out-of-stock products when the store says to
`ProductQuery` checks `woocommerce_hide_out_of_stock_items` and, when it is
`yes`, adds `AND wc_product_meta_lookup.stock_status NOT IN ('outofstock')`.
It is `no` on the dev site, so this does not show up in local testing.

It matters for the wishlist: favouriting an out-of-stock dish is allowed and is
rather the point, but on a store with that setting on, such a favourite will
not come back from hydration — the same as it not appearing in the menu. The
behaviour is consistent either way; just do not read a missing wishlist item as
a bug without checking the setting first.

## Riverpod retries a failed provider build, and it is not always wanted
Riverpod 3 retries any provider whose `build()` throws, with exponential
backoff, unless the provider says otherwise. Three consequences, all of which
showed up in task 3.6:

- `.future` **never completes with the error**, because the provider is still
  trying. Anything awaiting it hangs rather than failing.
- The timer keeps firing while the customer looks at the error screen, so an
  explicit "Try again" button competes with a retry already in flight.
- A widget test that renders the screen fails with *"A Timer is still pending
  even after the widget tree was disposed"* — which points at the widget, not
  at the provider three layers down that is quietly retrying a network call.

That last one is the tell. When a test that never mentions a provider starts
failing on a pending timer, look for a provider it pulls in transitively whose
build is failing — in this case the Account screen reached the wishlist for a
count, and the wishlist had no repository override.

Switch it off per provider where the UI owns recovery:

```dart
AsyncNotifierProvider<WishlistController, List<Product>>(
  WishlistController.new,
  retry: (retryCount, error) => null,
);
```

Keep the default where a silent recovery is genuinely better than an error
state — a read-only feed that nothing awaits, for instance.

## Optimistic writes need the load awaited, not skipped
The obvious shape for an optimistic toggle reads the current value, flips it,
then calls the server:

```dart
final current = state.value;
if (current == null) return; // ← drops the tap
```

`state.value` is null while the first load is in flight, so that guard silently
ignores the tap — during exactly the window when the customer is first looking
at the screen. `await future` instead: the tap waits for the load and then
applies, and the only cost is that one tap takes as long as the load it was
already waiting on.

The same function should revert to **the whole previous list**, not to the
inverse of the flip. Reverting by flipping back assumes nothing else changed
in between, which is false as soon as two writes overlap.

## A heart inside a tappable row needs no manual gesture handling
`DishRow` and `DishCard` are each one big `InkWell`, and the heart is another
`InkWell` inside them. Flutter's hit testing gives the gesture to the innermost
one, so tapping the heart saves the dish **without** also opening it, and no
`GestureDetector` juggling or `stopPropagation` equivalent is needed — the
design's own `e.stopPropagation()` has no counterpart here. Worth a test
anyway, because a later layout change that moves the heart out of the inner
subtree would silently restore the double action.

## The design's pixel values are ratios of the design's own viewport
The supplied design is drawn at 390pt wide and its components carry fixed
pixel sizes — the promo banner is a `330x160` card holding a `170`-wide copy
column and a `170`-wide artwork. Transcribing those numbers into Dart as
constants looks faithful and is not: the Flutter card is a *fraction of the
viewport*, so on a 360dp phone it is ~319pt and two independently-stated
widths that fit at 330 start overlapping.

That is exactly how the banner shipped broken in task 2.5 — a `width: 180`
copy column and a `width: 150` artwork, each reasonable alone, overlapping by
28.8pt on a real phone.

Two habits that prevent it:

- **Convert the design's pixels to ratios of the design's own frame**, then
  multiply by the real size. `_BannerMetrics` in `banner_carousel.dart` is the
  worked example.
- **Derive the second measurement from the first** rather than stating both.
  The copy column is now `artworkLeft - padding - gutter`, so it cannot drift
  away from the artwork no matter how the card is sized. Floor it at zero: a
  width derived by subtraction goes negative before it goes small.

Also note which design behaviours depend on the fixed width. The banner's copy
is *meant* to overlap its artwork by 20px, hidden by a 60px rounded left edge
curving away under the text. That is only true at 330pt, so it was dropped in
favour of stopping the copy short.

## A layout bug below a certain width needs a test that sets the width
`flutter test` pumps at an 800x600 surface by default — wider than any phone,
and wide enough that the banner's two hard-coded widths never collided. Every
banner test passed while the card was visibly broken on a device.

```dart
tester.view.physicalSize = const Size(1080, 2400);
tester.view.devicePixelRatio = 3;
addTearDown(tester.view.reset);
```

Neither failure mode throws, either: a `Stack` draws one child over another
without complaint and `BoxFit.contain` is a legal fit, so there is no overflow
banner to catch and `tester.takeException()` stays null. Assert on geometry
instead — `tester.getRect(...)` on the two widgets and compare edges.

Widget tests that only check *presence* ("the title is on screen") will pass
through this entire class of bug. Where a layout has a constraint worth stating
— this must not cover that — state it as a measurement.

## A FormField keeps its last error until something re-validates it
Two related warts, both found by using the app rather than by a test.

**A corrected field keeps complaining.** Flutter's `FormField` holds the
message from the last `validate()` call, so after a failed submit the error
stays on screen while the customer fixes the input — and only clears on the
*next* submit. On the reset screen that meant "The code is six digits."
sitting under a code that was now six digits.

**A server error outlives the input it described.** Where a validator reports
something the server said — a rejected postcode, a wrong password, a spent
reset code — editing the field does not make that message any less visible,
and it is now describing a value that no longer exists.

One fix covers both:

```dart
Form(
  key: _formKey,
  autovalidateMode: AutovalidateMode.onUserInteraction,
  onChanged: () {
    if (_error != null) setState(() => _error = null);
  },
  ...
)
```

`onUserInteraction` re-runs the validators as the customer types, but only
after they have interacted, so a pristine form does not open covered in red.
The `onChanged` drops the held server error, which the validators read —
without it they would keep returning the same message on every keystroke.

Applied to the reset, change-password, change-email and address forms.

## Setting state does not update the widgets you are about to ask
A validator that reads screen state cannot be re-run in the same turn that
sets it:

```dart
setState(() => _error = error);
_formKey.currentState?.validate();   // asks the OLD widgets
```

`validate()` walks the `FormField`s currently mounted, which still hold the
previous build's validators. Schedule it instead:

```dart
WidgetsBinding.instance.addPostFrameCallback((_) {
  if (mounted) _formKey.currentState?.validate();
});
```

Hit twice — in the address form and again in both account-security forms —
because it looks correct and fails silently: the call runs, finds nothing
wrong, and the message simply never appears.

## Take the messenger before you pop
```dart
Navigator.of(context).pop(true);
ScaffoldMessenger.of(context).showSnackBar(...);  // throws
```
After the pop this route's context is defunct, so the lookup fails. Capture
`ScaffoldMessenger.of(context)` into a local **before** popping and call
`showSnackBar` on that — it belongs to an ancestor that outlives the route.

## Reusing server code means matching how it was called, not just what it takes
Task 4.2 hands add-on selections to the website's own `AddonFields` so the
cart entry it builds is identical to the one the web page makes. That is the
right instinct, but the method does not only take data — it takes data in the
shape its *original caller* produced, and that caller was an HTML form.

`get_checkbox_options_data()` matches with
`esc_html( $option['label'] )`. The web form posts the already-escaped text
from the rendered page, so the comparison lines up. Passing the raw stored
label does not: `Medium 12"` never matches `Medium 12&quot;`.

Nothing errored. The option simply was not found, so the dish went into the
cart at base price with the selection recorded nowhere. It surfaced as a total
that was 100 minor units short of what the test expected.

Two lessons worth carrying into the rest of Phase 4:

- When calling into code written for a form, **read what the form sent**, not
  just the parameter names. Escaping, 1-based counters and string suffixes are
  all part of the contract.
- **Assert on a computed total, not on "it worked".** A line that adds would
  have passed every presence check. Only the arithmetic caught it.

The sibling method is the opposite — `get_dropdown_options_data()` wants
`html_entity_decode( $label ) . '-' . $oneBasedPosition`. They look like they
should be the same and are not, which is now written down in the plugin's own
notes so nobody unifies them.

## Order date and time are stored in the site's display format, not ISO
This one would have shipped silently. The checkout stores `fmp_{type}_date` and
`fmp_{type}_time` as the **site's own `date_format` and `time_format`** —
`November 10, 2026` and `1:00 pm` on the dev store — because the web checkout's
inputs submit `fmParams.fm_date_format`/`fm_time_format`, and the Store API
checkout extension saves whatever string it is given with no validation at all.

Slot limits then count by matching those strings. So an app that sent
`2026-11-10` and `13:00` would have produced orders that:

- no slot limit counted, because nothing matched;
- the admin order column and the kitchen monitor rendered unlike every order
  placed on the web.

Nothing would have errored. `/app/slots` therefore returns `date_value` and a
per-slot `value` holding the exact strings to submit, and the Dart side is not
allowed to format its own.

The reverse holds when *reading*: the admin schedule screen writes 24-hour
times while the checkout submits 12-hour ones, so one slot can hold both
`13:00` and `1:00 pm`. Counting is keyed on **minutes since midnight** so the
two are one slot, and the date is matched against both formats.

## The web timepicker offers a time the availability check then refuses
`applyScheduleBounds()` sets the picker's `maxTime` to the day's last closing
time, inclusive, so a window of `11:00`–`13:00` offers `13:00`. But
`is_time_within_schedule()` accepts `t >= start && t < end`, so the AJAX check
answers "We are not open at this time" for the very time the picker just
offered.

`/app/slots` follows the check, not the picker: times step while `t < end`, so
`13:00` is never offered for that window. Worth reporting upstream as a website
bug rather than quietly reproducing it in the app.

A related divergence, chosen on purpose: the web picker lays one grid across
the whole day from the first opening time and then disables the gaps, so at an
interval that does not divide the gap it can miss a later window's own opening
minute — windows of `11:00`–`13:00` and `18:00`–`19:30` at 45 minutes offer
`18:30` but not `18:00`. The endpoint starts each window on its own minute,
which `is_time_within_schedule()` accepts.

## Timed products only ever asked about now
The whole timed-products feature evaluates its rules against `current_time()`:
`check_single_condition()` compares the rule to today's date, this minute and
this weekday. Nothing in the plugin could ask whether a dish is servable at
some *other* moment, which is exactly what a slot list needs — otherwise a
customer can preorder a breakfast-only dish for three in the afternoon.

Agreed before building: evaluate the same rules at the slot's own moment. The
method took an optional timestamp, with **null preserving every existing
caller byte for byte**, and `TimedProducts::unavailable_at()` became the public
way in. `fmp_timed_products_behavior` is deliberately not consulted there —
that setting decides whether the *menu* hides or greys out a dish unorderable
right now, which says nothing about whether the kitchen can serve it tomorrow.

Checked at the boundaries: a 07:00–11:00 rule leaves 11:00 available and blocks
11:01, because the plugin's own comparison is inclusive at both ends.

## Per-product slot limits stop counting when slot limits are switched off
`_fmp_slot_limit_exempt` is written to **every** order placed while
`fmp_enable_order_slot_limits` is off, and the combined per-product query
excludes exempt orders. So a store that uses per-product order limits but not
slot caps counts nothing toward those limits — the per-product feature has its
own switch and looks independent, but is not.

`/app/slots` reproduces this on purpose. The checkout's own validation
(`validate_product_limits_checkout`) uses the same query, so an endpoint that
counted more honestly would mark slots unavailable that the checkout then
happily accepted, which is worse than agreeing with it. Flagged on the PR as a
plugin bug to fix in its own change.

## A settings key must be registered in PHP or it is wiped on every save
The free plugin's settings save is a whole-option rebuild: it walks
`Fns::fmpAllSettingsFields()` and writes `$data[$key]` for each registered
field, then `update_option()` with that array. Five schedule keys are explicitly
preserved; everything else not in the registry is **dropped**.

So adding a setting is two changes in two repos, and skipping either one is
worse than doing nothing:

- registered in Pro (`PickupDeliveryFns::settings_field()` and friends), or the
  value is written back empty every time an admin presses Save;
- rendered in the free plugin's React section, or there is no way to set it —
  and a registered-but-unrendered key is posted empty by `buildFormData`,
  which posts the whole settings state.

## The free plugin's built assets cannot be reproduced
`tlp-food-menu` commits its built `assets/js/*.min.js` but has **no
`package-lock.json`**, so a fresh checkout cannot rebuild them as they are:

- `npm install` fails on a peer conflict (`date-fns@4` against
  `react-day-picker@8`, which wants `^2 || ^3`) — `--legacy-peer-deps` gets past it;
- `npm run prod` then fails because webpack 5.112 rejects `webpackbar@5.0.2`'s
  ProgressPlugin options — pinning webpack to 5.89 locally builds;
- and a build from **pristine source** already rewrites 13 asset files, with
  `admin-settings.min.js` alone growing ~18KB with no source change at all.

So a three-field settings change cannot be shipped with its asset without
dragging ~18KB of toolchain churn into that file plus twelve other rewritten
files. Task 5.2's free PR therefore commits source only and says so; the asset
is left to whoever owns the release toolchain. Anything needing a free-plugin
asset rebuild should expect the same, and a lockfile is the real fix.

## Branch selection does not reach the Store API
The free plugin scopes the menu to the chosen branch in two places —
`FoodLocation::filterByLocation()` on the `rt_fm_sc_query_args` filter, for
shortcodes, and `FoodLocation::filterShopByLocation()` on
`woocommerce_product_query`, for the shop page. Both read the branch from a
**`fmp_location_id` cookie**, and both add the same `tax_query`: products in
this location, **OR** products with no location at all.

The app browses through `wc/store/v1/products`, and the Store API builds its
own query. It does not fire `woocommerce_product_query`, and it has no cookie.
So today, passing a branch to the app's API changes the hours and the slots but
**not which dishes come back** — every product from every branch is listed.

This makes task 5.5 ("branch selection, persisted and applied to menu and cart
requests") impossible in Dart alone, and setting a cookie from the client is
not the fix either: the Store API would still not consult it, and the app has
no business pretending to be a browser. The work belongs in Pro's Store API
layer — a product-query filter honouring a branch parameter, mirroring the
free plugin's `tax_query` including its "no location means everywhere" arm.
Agree it before 5.5 starts.

Related, and already handled: the cart is validated against the branch
(`validateCartLocation()` removes items belonging to another one), so switching
branch can empty a cart. The app has to expect that rather than assume its
local cart survives a branch change.

## An order records its branch by name, not by id
`FoodLocation::location_update_meta()` stores **both** `fmp_location_name` and
`fmp_location_id` on the order, but the per-slot counting queries match on
**`fmp_location_name`** — `PickupDelivery::get_slot_order_count()` and
`get_combined_slot_order_ids()` both look up the term and compare its `name`.
`/app/slots` does the same, because agreeing with the checkout matters more
than being tidy.

So an order placed by the app must carry the branch's **name**, spelled exactly
as the term is, or it will not count against that branch's slot limits. Renaming
a branch in WordPress therefore orphans the slot counts of every order already
placed against it — worth knowing before anyone renames one, and an argument
for fixing the plugin to count on the id at some point.

## Two bugs found on the food location screen
Both were in the way of task 5.3 and are fixed in food-menu-pro#16.

**Coordinates were never saved.** The location term screen renders Latitude and
Longitude, defaults them to Googleplex (`37.4224428, -122.0842467`) when empty,
and feeds them to a map preview — but `location_save_meta_field()`'s whitelist
did not include them, so `filter_input_array()` never read them and every value
an admin typed was dropped on Update. Fixing the save made the fake defaults
dangerous rather than merely odd: with saving working, pressing Update would
have written a California coordinate into every branch. Both the save and the
defaults are fixed, and the fields no longer hide behind the Google Maps
switch, since coordinates are a fact about the store rather than a map feature.

**The address textarea corrupted its own value**, escaping element content with
`esc_attr()` instead of `esc_textarea()` and printing it on its own indented
line. Each save round-tripped more leading whitespace and another layer of
entity escaping, so `&` became `&amp;` and then `&amp;amp;`. Fixed at the
source; `BranchesApi` also decodes and trims on read to clean existing rows.

Worth remembering for the other `fmp_loc_*` fields: that whitelist is the only
thing that saves them, so a field added to the markup and not to the list looks
completely normal and silently does nothing.

## `filter_input_array( INPUT_POST, … )` cannot be tested from the CLI
It reads the real request, not `$_POST`, so assigning `$_POST` in a script and
calling the handler proves nothing — it returns null and the handler quietly
does nothing, which looks exactly like the bug it was meant to prove fixed.

The coordinate fix above was verified through a **real admin POST**: log in to
`wp-login.php` with curl keeping a cookie jar, fetch
`term.php?taxonomy=tpl-food-location&tag_ID=<id>`, scrape `_wpnonce`, then post
to `edit-tags.php` with `action=editedtag`. Reverting the file and re-posting
showed the values being dropped; restoring it showed them persisting. That
round trip is the only honest check of any `filter_input`-based save.

## A Store API cart line reports the variation id, never the parent
`/app/slots` takes the cart so it can apply per-dish order limits and
timed-product rules — both of which are set on the **parent** dish. But a
Store API cart item's `id` is the *variation* id for a variable product, and
the response carries no parent anywhere: checked by adding a Build Your Pizza
variation to a real cart, which came back as `id: 28` with parent 27 nowhere
in sight.

So a cart holding a large pizza silently missed the cap set on the pizza. The
client cannot fix this — it has no way to learn the parent — so the server
resolves a variation to its parent on the way in, and two variations of one
dish sum against the one cap. Fixed in food-menu-pro on `mobile-app`.

## Two Riverpod traps, both of which fetched the same slots twice
Found by a test that counted calls, not by watching the screen — the duplicate
request was invisible in the UI.

**A `ref.watch` after an `await` registers late.** `slotsProvider` awaited the
order types and *then* watched the cart and the choice. The dependency is
registered when the body resumes, and the provider is rebuilt when it settles,
so the server was asked twice for one cart. Every watch now happens before any
await — and better, the whole request is one value object.

**A map is never `==` to an equal map.** The cart was published as
`Map<int,int>`, so every emission from the cart controller looked like a
change and re-triggered the fetch. It is published as the encoded string
instead, which compares by value and is also exactly what the request needs.

The general shape: **give an async provider one comparable key.** `SlotRequest`
holds the type, the date and the encoded cart, and can only change when the
answer would.

## Running it found what 54 tests could not
The tests all passed against a store whose schedule had a handful of slots. On
the real device, pointed at a store open all day at a half-hour interval, the
wrapped chip list ran to nearly forty slots down the screen and pushed the rest
of the checkout out of sight.

The design draws a single scrolling row, which is bounded whatever the store's
hours — and the reason I had moved away from it (a delivery window label is too
wide to sit beside another at 320pt) does not apply in a scroller, where every
chip gets its natural width. The widget test still guards the narrow case; it
simply asserts no overflow rather than a wrapped layout.

Worth remembering when picking fixtures: a schedule with four slots is not a
realistic store, and the layout only breaks at a realistic one.

## The Store API runs a plain `WP_Query`, so `pre_get_posts` reaches it
The branch gap from task 5.3 turned out to have a clean fix. WooCommerce's
`StoreApi\Utilities\ProductQuery::get_results()` builds its args and then runs
`new \WP_Query()`, so `pre_get_posts` fires for every Store API product
listing, search and collection-count. Pro hooks that, reads the branch from an
`X-FMP-Branch` header and merges in the free plugin's own `tax_query`.

Two details that make it safe:

- **The route comes from `rest_pre_dispatch`**, not from sniffing
  `REQUEST_URI`, so "is this the Store API" is exact and the same header on
  `wc/v3` or a staff route is ignored. Verified: `wp/v2/posts` is unaffected.
- **Merged under `AND`**, so a category filter and the branch both hold. A
  category of three burgers, one filed to another branch, correctly returns
  two — and that test only means anything because one of them is filed
  somewhere; with all three "sold everywhere" the merge looks right while
  doing nothing.

## A header is a better carrier than a parameter for a cross-cutting scope
The branch has to reach the menu, the search, the collection counts and the
cart. As a query parameter it would have to be threaded through every call
site, and the one that was forgotten would silently return another branch's
dishes. As a header set by an interceptor it cannot be forgotten.

The cost is that **requests become indistinguishable to a cache**: two
branches produce the same URL. So everything scoped by the branch watches
`activeBranchIdProvider` as a cache key even though it does not use the value.
That is a comment on four providers rather than a mechanism, and it is the
part most likely to be dropped by someone tidying up.

## A provider the network layer awaits must never fail
`selectedBranchProvider` is read by an interceptor before every request. Two
things follow, and a test that simulated an unreadable keystore found both:

- **It cannot enter an error state.** A throwing store has to mean "no branch
  chosen", or the first menu load hangs behind a keychain problem.
- **It cannot retry.** Riverpod retries a failed build with a growing backoff;
  with the interceptor awaiting it, that holds every request rather than
  letting the app run unscoped. The test timed out at thirty seconds, which is
  what the backoff looks like from the outside.

The same reasoning already applies to the cart token, and is worth applying to
anything else the interceptors come to depend on.

## A bottom sheet from a shell branch comes up under the shell's own overlay
The branch picker was shown with `showModalBottomSheet(context)` from the menu
tab, and the floating cart bar drew **over** it, hiding the second branch. The
shell paints that bar in a `Stack` above its `navigationShell`, so a sheet
pushed onto the branch's own navigator is below it. `useRootNavigator: true`
fixes it.

Only visible by running it: the widget test pumps the sheet without the shell
around it, so there is no cart bar to be covered by.
