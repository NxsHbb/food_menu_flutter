# Progress

Newest first. One entry per completed task.

## Task 8.4 — Choosing a date
Branch `feat/date-strip`, PR #57. **App-only**, no plugin change. 12 new tests, 845 in
total.

### What landed
A row of date chips above the slot list, one per date the store takes orders
for, labelled "Today", "Tomorrow", then "Fri 13 Nov". Picking one reloads the
slot list for that day. The fields were already arriving on `/app/slots` and
had been unused since task 5.3.

### Null `last_date` means today only
It is sent **only** when `fmp_preorder_max_days` is above zero, so a store
that has never switched pre-ordering on sends null and gets exactly one date
— which is what its own website offers. Reading null as "no limit" would have
drawn a strip of dates no store had agreed to take orders on.

The route itself does not enforce the bound it publishes: with no `last_date`
its date check passes anything. Left alone, for the same reason task 8.2 left
required checkout fields unvalidated — tightening it changes the website too.
Recorded in `FINDINGS.md` as an open dependency.

### The chosen time cannot survive a date change
Slot identity is minutes within a day, so 6:30 pm on Thursday and 6:30 pm on
Friday are the same number. Moving dates clears it and the list falls back to
the earliest open slot on the new day, rather than silently carrying a choice
to a day where that time may be full or closed.

### Found by placing the order
The order-received screen said "Delivery / 12:00 am" and **not which day**.
Until this task every order was for the earliest date, so a bare time was
unambiguous; the first pre-order made it a lie. `scheduledDate` now appears on
the tile and beside the estimate, and stays empty for an ASAP order, which has
no day to be wrong about.

A closed day inside the range is still offered, and answers with the store's
own "we are closed" message. The app cannot know a store's weekly closures
without asking for that date, and a chip that explains itself beats one
silently missing.

### Verified on the Android device, against the dev site
`fmp_preorder_max_days` set to 4: the strip drew Today through Sat 14 Nov,
picking Fri 13 Nov reloaded the slots to that day's own windows — no ASAP,
since ASAP is a today-only idea — and order **#73** stored
`fmp_delivery_date = "November 13, 2026"` with `fmp_delivery_time = "12:00 am"`.

### Dev-site state
`fmp_preorder_max_days` was **restored to unset**, diffed byte-identical
against a backup. Order #73 is kept, as the other app-placed orders are.

## Task 8.3 — Timed dishes
Branch `feat/timed-dishes`, PR #56, with the plugin half on `mobile-app`
(food-menu-pro#30). 9 new tests,
833 in total.

### What landed
A `timed` block on the Store API product payload — `available`, `behavior`,
`note` — and the treatment the store asked for in the menu. A breakfast dish
at nine at night now reads "Will be Available: 8:00 am – 11:00 am" in the
store's own words, with the photo dimmed and the add button dead, or it is
gone from the menu entirely, per `fmp_timed_products_behavior`.

### Asked, not reimplemented
`available` comes from the same resolver `woocommerce_is_purchasable` uses,
and `note` from `get_schedule_text_for_product()`, which is what paints the
website's own badge. The app cannot word it differently from the web page,
and no schedule arithmetic was written in Dart. The new
`TimedProducts::app_availability()` is a reader over both.

### One line in the model did most of the work
`Product.isOrderable` folds the clock in beside stock, so the add bar, the
stepper, the quick-add `+` and `canAddDirectly` all came right without being
touched — every screen that already respected a sold-out dish now respects
the clock. `unavailableReason` picks the words, **stock first**: a dish that
is both sold out and out of hours is sold out.

### What the app decides, and what it does not
`behavior` is reported, not applied. Hiding happens in `MenuRepository`,
because the plugin's rules are not a taxonomy the Store API can filter on —
**so a page of twenty can arrive as nineteen**. The alternative was a dish
the store asked not to show.

A hidden dish still *draws* if something reaches it directly, a favourite or
a link, saying why rather than being a dead end.

### A warning that was being printed into the JSON
`find_matched_rule_for_product()` passed a `$moment` it has no parameter for.
PHP 8 warns and passes null, which is the "now" the method wants, so the
behaviour was accidentally right — but with `display_errors` on, the warning
landed in the middle of the Store API's response and the app could not parse
a single product. **This touches a website path**, minimally: the call now
uses the default, which is what PHP was already doing.

### Verified on the Android device, against the dev site
Both treatments, with two rules seeded: Margherita greyed out and refusing
with "Will be Available: 2:00 am – 4:00 am" on the row, the detail badge and
a dead add bar; then the same dish gone from search entirely once the store
was switched to `disappear`.

### Dev-site state
The behaviour setting was switched to `disappear` and **restored**, diffed
byte-identical against a backup. Of the two seeded rules, one is **kept**:
"Off the menu late", hiding Mushroom Risotto between 11:00 pm and 11:59 pm.
It blocks nothing during working hours and leaves the feature exercisable.

## Task 8.8 — What the first device pass found
Branch `fix/device-sweep`, PR #55, with the plugin half on `mobile-app`
(food-menu-pro#29). 3 new tests,
824 in total. **The backlog task**: 7.2, 7.3, 7.4, 8.1 and 8.2 had all shipped
without a device pass because the OnePlus was locked, and the phone came back.

### The sweep itself
Signed in on the device, ordered a variable dish with the store's three
checkout questions answered, placed order #72, tracked it, walked the history
both tabs, and reordered from a past row. Everything those five tasks claimed
is true — including `_fmp_custom_fields` arriving as
`{"custom_0":"Flat 3B","custom_1":"A friend","custom_2":["Nuts","Gluten"]}`,
under the key the admin metabox, kitchen monitor and emails read.

Then six defects, none of which the suite could have caught.

### The two that broke a feature outright
**A variable-dish order could never be reordered.** `AppCartAddons` skips
add-ons on a variable product on purpose, so nothing is ever recorded for one
— and `AppReorderApi::line()` asked the *parent* whether the dish takes
choices, found the dev store's global group, and refused. Order #72 was
refused by the app that had just placed it.

**The app asked a question the cart threw away.** `/app/products/{id}/addons`
published the Cutlery group for Build Your Pizza, which the website would
never render and the cart would never apply. Both now follow the same rule as
the cart.

### The three that looked broken
The order screen printed `_addons_price` and the raw `_fmp_addon_selection`
JSON at the customer, and `&#036;2.50` where a price belonged:
`get_formatted_meta_data( '', true )` overrides the `_` hide-prefix that makes
underscore meta private. **Calling it with no arguments fixed the duplicated
size too** — it drops an attribute already spelled out in a variation's name,
which is what printed `Medium` under "Build Your Pizza – Medium". Entities
needed `html_entity_decode`; `wp_specialchars_decode` knows five named ones
and this is numeric.

The dish header kept reading "from $8.50 to $15.00" over a button charging
$11.50, because only the add bar followed the resolved variation.

### The one that reverses an earlier decision
7.3 drew each stage's time on the **restaurant's** clock, server-formatted.
The dev store keeps its books in UTC, as most WordPress sites do, so the
screen showed `Today, 2:52 PM` in its header above `November 11, 2026 at
8:52 am` in its timeline. The app now re-zones `at_utc` like every other date
and keeps `at` as the fallback. See `FINDINGS.md` for why that beats the
original reasoning.

### Verified on the Android device, against the dev site
Each fix re-walked after the rebuild: no add-on group on the pizza, header
and button both $11.50, the lemonade line reading
`Medium 12" ($2.50) · Mushrooms ($0.75) · Basil · Extra napkins please`,
timeline and header agreeing on `Today, 12:29 PM`, and order #72 reordering
into a cart line that says Medium.

### Dev-site state
Order **#72 is new and kept**, set to `completed` to reach the footer reorder
path. It is the reproduction for the variable-dish reorder refusal and it
populates the Past tab. Nothing else changed.

## Task 8.2 — Order Extra Fields
Branch `feat/checkout-fields`, PR #54, with the plugin half on `mobile-app`
(food-menu-pro#28). 17 new tests, 822 in total.

**Still not run on a device.** Fifth task running.

### What landed
`GET /app/checkout-fields` publishes the store's own checkout questions, and
the checkout draws them under "Additional information": a text input or a
select, required ones marked and validated, multi-selects as checkboxes.
`OrderDraft` posts them under `fmp_custom_fields` instead of the empty map it
has sent since task 6.2.

### The key is the position
The website writes each answer under `custom_{index}` and reads it back by
pairing that key with the definition at the same index — nothing stores the
label with the answer. So the key is **published rather than derived**, and
reordering the fields in settings re-keys every past answer. That is the
website's behaviour and no route can fix it; it is now written down.

Unusable definitions are dropped **after** their index is taken, so removing
one does not shift the keys of the rest.

### What was deliberately not done
**No server-side validation.** The classic checkout enforces required fields;
the **block** checkout does not — it renders the asterisk and never blocks the
order, and the Store API saves whatever arrives. Adding the check would fix
both and **change the website**, which the app-only rule forbids without a
decision. Raised as an open dependency.

So the app validates in its own `Form` pass and a crafted request can still
skip a required answer — exactly as it can on the website today.

### Verified
Five definitions seeded on the dev site, two deliberately unusable: three come
back keyed `custom_0`–`custom_2`, with the multi-select's comma-separated
options split and its `multiple` flag resolved from the string `"true"` the
React settings form stores. An order placed through the Store API with all
three answered stored
`{"custom_0":"Flat 3B, buzzer 12","custom_1":"Instagram","custom_2":["Nuts","Gluten"]}`,
which pairs back to the right labels. The throwaway order was deleted; the
definitions are kept and documented.

## Task 8.1 — Variable dishes
Branch `feat/variations`, PR #53. 20 new tests, 805 in total. **App-only, no
plugin change** — but it needed the dev site's demo data fixed first.

**Still not run on a device.** The OnePlus is locked and in airplane mode, as
for 7.2, 7.3 and 7.4.

### What landed
An attribute picker on the dish screen, drawn like an add-on group because to
a customer "Size: small, medium, large" and "Choose your size" are the same
question. The chosen variation is read back as a product of its own for its
price and its stock, `variation` goes out on add-to-cart, and the cart line
says which size it is.

### The demo data was the first bug
`Build Your Pizza`'s three sizes had **empty** attribute values, which
WooCommerce reads as "any" — three variations matching every size, at three
different prices. Through the Store API that was `value: null` everywhere,
which looked at first like an API limitation for custom attributes. It was
not. The attribute was also named `pa_size`, which is what a customer would
have read on the website. Both fixed, and `LOCAL_DEV.md` records it.

The app still treats an empty value as a **wildcard**, because a store may
genuinely use one — "Large, any crust" is a real variation.

### Reading the live payload settled the design
No prices on `variations[]`, and `include=` does not return variations, so
they cannot be batched. But `GET /products/{variation_id}` works and carries
the variation's own price **and stock** — a size can be sold out while the
dish is not. So the chosen variation is fetched on demand and cached per id;
flipping back to a size already seen costs nothing.

Matching is on `name` and `slug`, never ids: a custom attribute comes back
with `id: 0` on the attribute and every term.

### Three things found on the way
- **The cart line would have shown nothing.** `item_data` is empty for a
  variable line; the size is only in the item's `variation` key. Two sizes of
  one dish were about to be two identical rows.
- **`_addedLine` matched the parent id**, and a variable line comes back under
  the variation's. Harmless today — the only caller ignores the result — so it
  was closed rather than left as a trap.
- **An unresolvable combination is named**, not posted. Every attribute
  answered and still no match means the store never made it, and saying so
  beats letting the server answer "no such variation", which reads as a fault.

### The fixtures were stale again
`product_variable.json` carried the broken `value: null` data, so a test could
not have caught any of this. Re-captured, along with a new
`product_variation.json` for the Medium pizza.

## Task 7.4 — Reorder
Branch `feat/reorder`, PR #52, with the plugin half on `mobile-app`
(food-menu-pro#27). 15 new tests, 785 in total. **Phase 7 is done.**

**Still not run on a device** — the OnePlus is locked and in airplane mode, as
it was for 7.2 and 7.3. Three tasks now. The route was exercised end to end
against the dev site; the screens are covered by the suite.

### What landed
Reorder on past history rows, beside "Details", and as the primary action in
the order footer. The plugin grew `GET /app/orders/{id}/reorder` and the line
meta behind it.

### The data was already there
The hard part turned out not to exist. By the time the add-to-cart filter
runs, the app has already sent exactly what a reorder needs — the payload
`cart/add-item` accepts. It was being used to build the website's cart rows
and then discarded. So the selection is now kept beside those rows, copied to
the order line, and handed back unchanged. The stored payload and the request
body are the same thing, so the round trip cannot drift. See `FINDINGS.md`.

### What the route deliberately does not do
It adds nothing to a cart. The app re-submits each line through the Store
API's own `cart/add-item`, where add-on validation, branch scoping, timed
products and stock already work — a dish sold out since, or a group that has
become required, fails exactly as it would on a first order. Rebuilding the
cart inside the plugin would have meant reproducing all four.

### Old orders, and the case that is not a refusal
A line with no recorded selection is refused — **unless the dish takes no
choices today**, in which case there was nothing to lose and it reorders fine.
On the dev site every dish matches a global add-on group, so every pre-7.4
order refuses there; on a store without global add-ons most would not.

### What the customer is told
The outcome is a toast, as the design has it. A failed *read* throws and the
cart is untouched, so the screen just says so. A line that fails to *add* is
named instead — "1 item added. 1 could not be." — because by then part of the
order is in the cart and a success message would be a lie. Nothing added at
all keeps the customer where they are rather than sending them to an unchanged
cart to work it out.

### Verified
A fresh order with a radio, two checkboxes and a textarea returns the
selection byte for byte, and posting that answer straight back to
`cart/add-item` rebuilds the line with `Medium 12"`, `Mushrooms`, `Basil` and
"Extra napkins please" intact. The same order's other line, added to the cart
before this code existed, correctly comes back `choices_not_recorded` — the
mixed case the app has to draw. Order 70 is kept on the dev site as the
fixture for it.

## Task 7.3 — Live order tracking
Branch `feat/order-tracking`, PR #50, with the plugin half on `mobile-app`
(food-menu-pro#26). 23 new tests, 770 in total.

**Not yet run on a device** — the OnePlus is locked and in airplane mode, and
the simulator cannot be signed in from a terminal. The endpoint was exercised
directly against the dev site; the screens are covered by the suite. This is
the second task in a row without a device pass, 7.2 being the first.

### What landed
The design's order screen is now whole: an estimate card, the progress strip
and the status timeline, plus the "Track order" button on order received that
had nothing to open.

The plugin grew `GET /app/orders/{id}/tracking` and a `progress` pair on the
history row's summary.

### The premise turned out to be wrong
`PLAN.md` had 7.3 as app-only work against the public `/track/{token}`,
drawing "a step out of four that only tracking knows". Neither half held:

- **The public route knows no such thing.** It answers the entries that
  happened, every one `completed`, because the website draws a history. There
  is no stage model anywhere in either plugin — see `FINDINGS.md`.
- **The estimate card never needed one.** It is the order's own `eta` and
  type, already on `/app/orders/{id}`. 7.2 withheld it for a reason that did
  not hold.

So the strip became a plugin question, and was agreed before building: Pro
publishes the stages, **for the app only**, leaving the website's route and
page untouched. The sequence is the store's own — the Order Statuses screen
drag-sorts its custom statuses and the presets ship as pipelines — so the app
still never reads a stage out of a slug.

### What the public route could not have done anyway
It expires. `fmp_tracking_link_expiry_days` closes a link that was emailed to
whoever placed the order and answers 410 after it, which is right for a shared
link and wrong for the customer's own order in their own signed-in app. The
app route is bearer-authed against the order's customer instead, and the
expiry does not apply.

### Found while building
- **A completed order read "2 of 6".** The stage builder stopped appending the
  future for a cancelled order and not for a finished one, so the declared
  pipeline was tacked on after completion. Caught by the history row, which
  draws a strip from the same numbers.
- **The estimate was about to appear twice**, once in the new card and once in
  the details list where 7.2 put it. It now sits in the card while the order
  is active and in the list once it is over, where it reads as a record of the
  slot chosen rather than a promise.
- **The captured order fixtures had gone stale**, missing `status_color` and
  `is_active` since 7.2 added them — and `is_active` defaulting to false
  silently withheld the estimate card. Diffed against the live route and
  fixed.
- **`canTrack` was removed.** It gated tracking on the tracking token, which
  the app no longer uses, so it would have withheld the button from orders
  that track perfectly well. The token stays as data.

### What 7.4 inherits
Nothing from here. Reorder still needs the plugin to record a re-submittable
add-on selection at checkout.

## Task 7.2 — The order history and order detail screens
Branch `feat/order-screens`, PR #48, with a two-field plugin addition on
`mobile-app` (food-menu-pro#25). 47 new tests, 747 in total.

**Not yet run on the device** — the OnePlus locked mid-task and needs a PIN.
Everything below is from the test suite and the fixtures captured off the dev
site, not from the phone.

### What landed
`OrdersScreen` replaces the Phase 7 placeholder: the design's two tabs over a
paged list, each tab its own query so its count is the server's. `OrderRow`
is the design's card — number, date, type, status pill, thumbnails, item
count, total — and `OrderDetailScreen` is the order in full.

The plugin grew `status_color` and `is_active` on the **single-order** payload
as well, since the detail header draws the same pill the row does and had no
colour for it.

### The status pill cannot be a lookup table
The design hard-codes a background and foreground per status, for the five it
knows. That cannot hold: the plugin lets a store invent statuses, so the app
would have no pair for "Out for delivery" at one shop and "In the oven" at
the next. The server sends **one colour per status** — its own, honouring
admin overrides — and the pill derives the pair from it, falling back to the
muted chip when there is none.

`parseHexColor` takes six digits only. CSS's eight-digit form is `#rrggbbaa`
and `Color(int)` reads `0xaarrggbb`, so accepting it would paint the status
in the wrong colour, confidently. Refusing is better than guessing.

### Three things deliberately absent
- **The timeline and the estimate card**, which are drawn from a step out of
  four that only the tracking route knows. Task 7.3.
- **The progress strip** on an active row, for the same reason. The row shows
  the status and the estimate, which it does have.
- **Reorder** — see below.

None is a stand-in saying "not built yet". Task 4.7 existed to clean one of
those up, and a test now asserts neither button is pretended at.

### Reorder turned out to be its own task
An order line records its add-ons as **display text** — `[Make it a meal] =
No thanks` — with no group id and no option id. Nothing can rebuild a
selection from that faithfully; matching labels back to the current groups
breaks the moment a store renames an option, and picks the wrong thing
silently.

WooCommerce's own `order_again` is no help either: it rebuilds a cart through
`woocommerce_order_again_cart_item_data`, and **neither plugin hooks it**, so
it would drop every choice too.

So a faithful reorder needs the plugin to store a re-submittable selection on
the line at checkout, and that only helps orders placed afterwards. Raised as
task 7.4 rather than shipped as a button that quietly loses what the customer
chose.

### Signed out is an invitation, not a 401
The first version asked for the history regardless, so a signed-out Orders tab
showed "You must be signed in to do that." over a "Try again" that could never
work. It now follows the wishlist: `isSignedInProvider` is watched in the
controller, so signing in loads the list and signing out drops it with no
invalidation anywhere, and the screen offers a sign-in instead of an error.

### Paging is tested at the controller, not the screen
A list with another page to come keeps a spinner in the tree, and
`pumpAndSettle` can never settle on one. The first attempt worked around it
with a page size of two, which also created a state that cannot occur —
`hasMore` means ten order cards are loaded, which always overflows a phone.
Paging moved to `ProviderContainer` tests; the widget tests keep to one page.

### Also new
`core/util/relative_date.dart`, because the app had no date formatting at all
and `intl` is not a dependency. "Today, 2:02 PM" / "Yesterday" / "12 Mar" /
"12 Mar 2025", always in the device's time zone — the server sends an offset,
and an order placed at 2pm must not read as 8am because the store keeps its
books in UTC.

## Task 7.1 — The order history endpoint
Plugin only, on `mobile-app` (food-menu-pro#24). No Flutter change — 700
tests, unchanged. The screens are task 7.2.

### What landed
`GET /app/orders`, paged as a bare array with `X-WP-Total` and
`X-WP-TotalPages`, which is the contract the app's pager already speaks for
the menu list.

A **summary** per order rather than the whole thing. The design's row shows
the number, the date, the order type, the status, a few dish thumbnails, a
count and the total — not the address, the customer, or each line's add-ons.
`row_items()` exists rather than slicing `items()` for the same reason: a row
draws no line totals and no add-on meta, and the first version sent both.

### The split is defined by what is *finished*
The design has Active and Past tabs. Listing the active statuses would have
been the obvious way and would have been wrong: this plugin lets a store
invent its own, so a custom "Out for delivery" would silently fall out of
both tabs. Naming the **endings** instead means anything new is active until
someone says otherwise, which is the safe direction.

`fmp_app_finished_order_statuses` covers the store whose custom status *is*
an ending. The default list is the one `OrderTracking::should_flag_as_new()`
already uses for the staff badge.

`checkout-draft` is in neither group — it is the half-finished order the
block checkout parks while the customer is still typing.

### `ltrim` does not strip prefixes
`ltrim( $slug, 'wc-' )` strips any of the *characters* `w`, `c`, `-`, so
`completed` comes back as `ompleted` and matches nothing. The filter handling
had exactly that bug before it ran. `str_starts_with` now. Grepped both
plugins: no other instance.

### Verified on the dev site
`any`/`active`/`past` → 6/4/2 with matching `X-WP-Total`; `per_page=4&page=2`
returns the last two; `per_page=5000` capped to 50; `group=wat` a 400 from the
enum; no token a 401; a **guest** order on the same site absent, since the
query is scoped by `customer_id`. `row_items()` proven to cap at four against
a six-line order. A custom status registered at runtime landed in **active**
with no configuration, and the filter moved `delivered` to past only once the
store actually registered it.

Two test orders were given `completed` and `cancelled` so the Past tab is not
empty for 7.2 — recorded in `LOCAL_DEV.md` rather than changed silently.

## Task 6.6 — A cart that outlives its branch
Branch `feat/branch-cart`, PR #46, with the plugin half on `mobile-app`
(food-menu-pro#23). 17 new tests, 700 in total. **Phase 6 is done.**

### The decision
Three options were on the table — warn, drop silently as the website does, or
let checkout refuse. **Warn at the switch, then drop**, with a server-side
refusal as the backstop.

The research is what settled it. The website's silent-drop looked like the
consistent choice until it turned out that pass
(`FoodLocation::validateCartLocation()`) is registered **only when the
`fmp_location_id` cookie is set** — and the app sends its branch as a header.
It had never run for a mobile client, and nothing else refused such a cart
either: the order was stamped with the new branch and accepted, so a kitchen
could receive an order for a dish it does not make.

So the server guard was not optional whichever option won, and once the app
has to ask the server anyway, asking *before* the switch costs one request
and turns a surprise into a choice.

### What landed
`BranchSwitcher` checks, asks, then drops and switches — in that order, so the
removals go out while the old branch is still in force. The dialog **names**
the dishes rather than counting them: whether to go ahead depends entirely on
*which* dish, and the customer should not have to back out and open the cart
to find out.

Both halves fail open. A failed check switches anyway; a failed removal
switches anyway. Stranding someone on a branch they are trying to leave is
worse than carrying a line, and the server refuses the order regardless.

### One hook, two behaviours
`AppBranchScope::unserved()` is the per-product form of the rule
`scope_query()` already expressed as a `tax_query` — including "a dish filed
under no branch is sold everywhere" — with variations resolved to the parent,
since the taxonomy is registered for `product` and never for
`product_variation`.

It hangs off `woocommerce_store_api_cart_errors`, which turned out to do both
jobs at once: on checkout the error becomes a **409**, and behind
`get_cart_errors()` the identical error lands in the cart response's `errors`
array, which the cart screen already renders. No second implementation.

The app needed no new failure classification — `CheckoutFailure` matches the
substring `cart_item`, so `fmp_cart_item_branch` already lands on the cart
kind with no retry offered. That is a coincidence of naming, so a test now
pins it.

### The bug the tests found
`check` first **sampled** the cart — `ref.read(provider).value` — and read
null as "nothing to lose". Right only once something else has loaded the cart,
and the likeliest moment to open the branch picker is a cold start where
nothing has. The dialog would not appear and the dish would go unmentioned,
which is the one thing this task exists to prevent.

A widget test caught it, because a harness has no cart bar quietly loading
the cart the way the real shell does — the same reason it would have survived
testing by hand.

### Verified on the device
On the OnePlus, against two seeded branches. Downtown chosen explicitly
dropped the menu from 18 dishes to 17 (Build Your Pizza is Uptown-only).
Garlic Bread added, cart 5 / $20.30. Switching to Uptown raised "Switch to
Uptown? … • Garlic Bread". **Cancel** left the branch, the dish and the sheet
alone. **Switch and remove** took the cart to 4 / $15.80 — exactly Garlic
Bread's $4.50 — put Uptown in the header, and brought Build Your Pizza into
the grid.

Also probed directly: the variation case (a cart line carrying variation 28
is judged by parent 27), branch 0 and a deleted branch both answering "serves
everything", the 409 at checkout, and an order at a branch that *does* serve
the dish still going through and still stamped `Downtown` / `53`.

The dev site was seeded and restored: the settings option diffs clean, both
terms are gone, all 18 products are visible again, and the throwaway scripts
are deleted.

## Task 4.7 — The quick-add `+`
Branch `feat/quick-add`, PR #45, with the plugin half on `mobile-app`
(food-menu-pro#22). 28 new tests, 683 in total. Phase 4 is done.

### What landed
`QuickAddButton` replaces the private `_AddButton` in **both** `DishCard` and
`DishRow` — one widget, so the landing grid and the menu list cannot answer a
`+` differently again. It adds the dish, spins while the request is in flight,
and opens the dish screen for anything that needs choosing first.

`QuickAddController` holds the product ids with an add in flight. State rather
than a flag on the button, because a menu list rebuilds on every cart change,
which is precisely while an add is running — a local flag would be thrown away
mid-request. A second tap is dropped, not queued.

### The task was not the one-liner it looked like
`Product.canAddDirectly` was `isPurchasable && isInStock && !hasOptions`, with
a comment claiming `has_options` covered both variations and required add-on
groups. It does not: `has_options` is WooCommerce's, and Food Menu's add-ons
never enter into it. The seeded **Fresh Lemonade** is a *simple* dish with a
required "Choose your size" group — `has_options: false` — so the `+` would
have fired an add the server refuses with `fmp_app_addon_required`.

Nothing had caught it because until this task the `+` did not add anything.

So Pro now publishes **`requires_choices`** on its Store API product
extension, and the app reads `needsChoices = hasOptions || requiresChoices`.
`has_options` was left alone on purpose: filtering
`woocommerce_product_has_options` would have fixed the app for free and
changed how every shop loop on the **website** draws its add-to-cart button
along the way.

The row's "options" label now follows `needsChoices` too, so a dish that leads
to choices says so whichever kind of choice it is.

### A second extension with the same namespace deletes the first
`requires_choices` could not be registered in a class of its own.
`ExtendSchema::register_endpoint_data()` stores callbacks at
`$extend_data[ endpoint ][ namespace ]` by plain assignment, so a second
`food-menu-pro` registration against the product schema would have *replaced*
the one publishing `ingredients` and `nutrition` — silently, with two fields
simply gone. `ProductFoodDataStoreApi` is therefore now
`Api/App/AppProductStoreApi`, which owns the whole block.

The required-ness rule moved to `AppAddonGroups::requires_choice()`, called
both by the validator that enforces it and by the field that advertises it.
They had to agree, and "required" turned out to include a group with
`min_selection > 0` that is not marked required at all.

### The snackbar that hid the thing it was confirming
A successful add first said "Iced Latte added". On the device that snackbar
landed **on top of the floating cart bar** — both are pinned to the bottom of
the shell's `Scaffold` — cutting "4 · View cart · $15.80" in half for two
seconds to say the same thing in words.

A success is now silent. The cart bar appears on the same frame and is the
design's own confirmation. Refusals keep their snackbar, and an add-on
refusal — which only a store on an older plugin can still produce — opens the
dish screen rather than leaving the customer told to choose something on a
screen with nothing to choose from.

### Verified on the device
On the OnePlus against the dev site. Iced Latte added from both the grid card
and the list row, cart 1 → 2 → 3 → 4 with the totals following; Fresh
Lemonade's `+` opened the dish screen on "Choose your size" without a request
being sent; Build Your Pizza and the sold-out dish did the same. The cart
survived the relaunch on its `Cart-Token`.

## Task 6.5 — When the order is refused
Branch `feat/checkout-failures`, PR #44. App only. 24 new tests, 655 in total.
Phase 6 is one task from done.

### What landed
`CheckoutFailure` classifies the refusal and `CheckoutErrorBanner` shows it.
A banner rather than a snackbar, because a refusal has to be read, acted on
and still be there afterwards — a missing postcode is fixed three fields away.

What the customer is offered follows the **kind**, not the message. A dropped
connection gets "Try again", because the identical order could work. A
rejected address does not, because it would be refused identically; it gets
the server's own per-field complaints instead. A rate limit gets neither — it
will work later, but not now, and a button would spend another attempt.

### The guard that was missing
The order now carries `expected_total`. WooCommerce refuses with a 409 when
the real total is **higher** than the one the customer agreed to — a price or
a fee that moved between the screen and the tap — instead of charging a total
they never saw. The refusal hands back the refreshed cart in its own body, so
the summary and the bar catch up without another request.

An early probe made the parameter look ignored: it only compares one way, and
the probe sent a number larger than the real total.

### The bug this task existed to prevent, found by its own test
The banner is inserted at the **front** of the checkout's list. Children are
matched to elements by position, so every section below shifted by one, failed
to match, and was rebuilt — new `State`, new controllers, and the name, phone
and notes gone. The one thing 6.5 promises is that a refused order keeps its
input, and the first version threw it away.

`ContactDetailsSection` is keyed now. Anything stateful below a conditionally
inserted sibling needs the same.

### Also found
WooCommerce entity-escapes its own error messages, so the total-mismatch
sentence arrives with `&#036;` where the currency symbol belongs. Every server
message now goes through `plainText()`, like every other field from WordPress.

### Verified on the device
On the OnePlus, with the wifi pulled between opening the checkout and tapping
the button: the banner scrolls itself into view, says "Your order was not
placed. Nothing has been charged.", and every field, the address and the
payment method are untouched. Wifi back on, "Try again" sends the identical
order and it lands as #67.

### What 12.2 inherits
A redirect gateway's abandoned payment is one more `CheckoutFailureKind`, and
the banner and the kept input are already there for it.

## Task 6.4 — The order received screen
Branch `feat/order-received`, PR #42, with the plugin half on `mobile-app`
(food-menu-pro#21). 20 new tests, 631 in total. Phase 6 is one task from done.

### What landed
`features/orders/`: the design's order-received screen, and the `CustomerOrder`
model Phase 7 will build on. The checkout's confirmation dialog is gone — a
placed order now navigates to `/order-received/{id}`, which **reads the order
back from the server**.

### Neither of the two obvious sources would do
`POST checkout` answers with the order, but its extension block is the
plugin's *schema* with defaults rather than what was saved, so the time the
customer chose is not in it. And `GET wc/store/v1/order/{id}` — which does
work with the app's bearer token — carries no order number, no date, no
payment title, and none of the plugin's fields, including the tracking token
the design's "Track order" button needs.

So the plugin grew `GET fmp/v1/app/orders/{id}`: the customer's own order,
with money in minor units like everything else the app parses, someone else's
order answered exactly as a missing one is, and the ASAP estimate reported
back on an order that asked for no time. Writing it turned up the ASAP label
and the currency block duplicated in two routes; both moved to `AppApiFns`.

### What is on the screen, and what is not
The design's tick, "Order placed!", the thanks line and the three tiles —
Order, the store's word for the type over its own estimate, and the total.

**"Track order" is not there.** Tracking is task 7.3 and there is nothing yet
for the button to open; the token it needs is already in this payload, so it
is a one-line change when that screen exists. Shipping a button that says
"not built yet" would have left exactly the kind of stale stand-in task 4.7
was raised for.

### A stretch in a scroll view is an infinite height
The three tiles share a height through `CrossAxisAlignment.stretch`, which
inside a `SingleChildScrollView` throws "BoxConstraints forces an infinite
height" — and arrives as a `pumpAndSettle` timeout several layers from the
cause. `IntrinsicHeight` is the fix. A throwaway probe test found it in a
minute where reading the stack traces had not.

### Verified on the device
Two real orders from the OnePlus. The screen shows `#64` / `#65`, "Delivery",
"ASAP" and `$3.95`, read back by id — the fixtures for the tests are captured
from the same endpoint. "Back to home" and the hardware back button both land
on the menu rather than dropping out of the app. Centring the content needed
a second pass: the first draft sat at the top, because `mainAxisAlignment` in
a scroll view has nothing to centre within.

## Task 6.3 — Paying
Branch `feat/payment-method`, PR #41, with the plugin half on `mobile-app`
(food-menu-pro#20). 13 new tests, 611 in total.

### What landed
The design's payment list, over a new `GET fmp/v1/app/payment-methods`. The
gateway on the order is the store's own id rather than the `cod` constant
task 6.2 left behind.

### The validation the task asked for already existed
`POST checkout` with a disabled gateway answers
`woocommerce_rest_checkout_payment_method_disabled`, naming it. So Pro adds no
validation of its own, deliberately — what it adds is the **list**. The Store
API's cart reports gateway ids and nothing else, and the words beside a radio
button are the merchant's: translated, and renamed often enough that "Cash on
delivery" cannot be a string in the client. A store that calls it "Pay the
rider" means it.

### Enabled, available, and supported are three different things
- **Enabled** is the store's setting, cart-independent — the new endpoint.
- **Available** is WooCommerce's answer for one cart, which can narrow by
  country or total — `Cart.payment_methods`, now parsed.
- **Supported** is this app's reach: cash on delivery is the only gateway v1
  can carry to a placed order. The server says which, so a site can widen it
  with `fmp_app_supported_gateways` without an app release.

An unsupported gateway is still drawn, dimmed and unselectable, because a
store running only card would otherwise show an empty section and no reason
why.

### Null is not empty
`PaymentMethods.offered` takes a nullable list of available ids. Null is "the
cart has not been read yet" and the whole list stands; an empty list is a real
answer — nothing can pay for this cart — and nothing is shown. Collapsing the
two blanked the section on first paint, and the two tests that disagreed about
it are what found it.

### Verified on the device
Cash on delivery renders with the store's own title and description, selected,
and an order placed from the handset is `cod` / "Cash on delivery" on the
server. Turning **bank transfer** on as well draws it above, dimmed, with
"Other methods are coming to the app soon." — tapping it does nothing and the
order still goes out as `cod`. The store was put back to cash-only afterwards.

## Task 6.2 — Placing the order
Branch `feat/place-order`, PR #40, with the plugin half on `mobile-app`
(food-menu-pro#19). 22 new tests, 598 in total.

### What landed
`POST wc/store/v1/checkout` behind the design's button. `OrderDraft` builds
the body, `CheckoutRepository` sends it, `PlacedOrder` reads the answer, and
`checkoutReadinessProvider` decides whether there is an order to place at all
— returning either the draft or the sentence to show.

The confirmation is a dialog for now; **task 6.4 replaces it** with the
design's order-received screen, which re-reads the order rather than trusting
the checkout response.

### Three things the server had to be asked
Probing the real route first was the only way to find any of them, and all
three are in `FINDINGS.md`:

- **The extension block is all-or-nothing.** Omit one of its nine keys and the
  whole request is rejected with `rest_invalid_param`, because the schema
  types them all as strings and a missing key is null. A delivery order still
  sends the pickup keys, and an app with no dine-in screen still sends the
  dine-in ones, empty.
- **WooCommerce wants a billing address even for pickup.** The design shows
  the branch instead of an address there, but an order with no street is
  refused whatever the type — so an address is needed to order at all, and the
  checkout says so differently per type.
- **The response's extension block is the schema's defaults**, not what was
  saved, so the order cannot be read back from it.

### The branch was not reaching the order
The free plugin stamps `fmp_location_name` from a posted field or the cookie,
and the app has neither — so every app order was filed under no branch, and
the per-slot counting, which matches orders on exactly that meta, never
counted one. A branch's cap could be exhausted by app orders while the app was
still being offered the slot.

Fixed in Pro rather than worked around in Dart: `AppBranchScope` already reads
`X-FMP-Branch` on every request, so it stamps the order too and resolves the
name from the term itself. The app sends nothing new, which is the point — a
name the client supplied could be stale or translated.

### A spinner behind a modal never settles
The first placement test timed out in `pumpAndSettle`, and the dialog was not
the cause: the button's progress indicator was still animating behind it,
because the busy flag was cleared in a `finally` that ran after the dialog was
dismissed. Clearing it first fixed the test and the screen, where a spinner
was quietly running under the confirmation.

### Verified on the device, both ways
Two real orders from the OnePlus against the dev store. The delivery one came
back as `fmp_order_time_type: delivery`, `fmp_delivery_date: November 10,
2026` and **no** `fmp_delivery_time`, which is ASAP — the plugin skips empty
values. The pickup one carried `fmp_pickup_time: 6:45 am`, the chip that was
tapped. Both are `customer_id: 8`, so the bearer token does reach the Store
API and Phase 7 will find them; both carry the billing and shipping address
from the book with the checkout's own name and phone; both are `cod`,
`processing`. The cart emptied behind the dialog and the tab badge cleared.

Cash on delivery had to be enabled on the dev store first — with no gateway at
all the Store API refuses every order. Recorded in `LOCAL_DEV.md`, and the
plan's open dependency now says so.

### Found while verifying, not fixed here
The **quick-add `+` on dish cards and menu rows still says "Add to cart is not
built yet"** — a Phase 2 stand-in that Phase 4 never picked up. Adding from
the dish screen works, which is why it survived. Written up as task 4.7 rather
than folded into this PR. *(Done: it needed a plugin field as well.)*

## Task 6.1 — The rest of the checkout screen
Branch `feat/checkout-screen`, PR #39. No plugin change — everything this
needs was already published by Phases 3, 4 and 5. 34 new tests, 576 in total.

### What landed
`features/checkout/`: the address block, contact details, the order summary
and the design's sticky total bar, around the fulfilment section task 5.4
already put there. `CheckoutScreen` moved out of `features/fulfilment` with
it — fulfilment is the type and the time, and the rest of Phase 6 (payment,
placing the order, the failure paths, order received) belongs beside the
screen that does it.

Payment is task 6.3 and placing the order is 6.2, so the card where the
design draws its payment list says so, and "Place order" validates and stops.

### One block, two sources
A delivery order needs the customer's address and a pickup order needs the
branch's, and the design draws the same pin-and-Change row for both. So the
block switches on `resolvedOrderTypeProvider` and reads a different feature
per arm — the address book, or the branch list. Pickup reuses the branch
picker sheet from 5.5 outright, and hides "Change" when the store runs no
branches, since the picker would open on a single row.

### Chosen by id, resolved on every read
The checkout stores an address **id**, never the address, and resolves it
against the book every time — exactly as the order type and the slot are
resolved. An address deleted, or a sign-in as somebody else, falls back to
the book's default rather than leaving the screen pointed at something the
server has never heard of.

### The input lives in a provider, not in the form
Name, phone and notes go into `CheckoutController` on every keystroke. Two
things already demand it: the address sheet and the address book both rebuild
the screen underneath them, and task 6.5 has to return to a checkout that
still has its input after a refused order.

That is also where two traps were, both in `FINDINGS.md`: writing
`controller.text` during `build` is a `setState` during build, via the Form
the field reports to; and one prefill flag for the card meant the phone —
which can arrive later, from the address — was never filled.

### Money is restated, never recomputed
The summary's rows are `CartTotalsRows`, extracted from the cart screen and
now shared, so the two cannot come to different conclusions about which lines
a cart has. The bar shows the cart's own `total_price`. Tax, fees and
automatic discounts are server-side arithmetic; a client that added them up
would disagree with the order it just placed.

### Running it found both spacing bugs
Tests cannot see either. `AuthField` reserves a blank helper line so the box
does not jump when an error appears — under the order notes, which cannot
error, that reserve read as a gap at the bottom of the card, and between two
fields that can, the message landed against the next label. The reserve is
now tied to having a validator.

Verified on the OnePlus against the dev store: the header follows the choice
("Delivery · ASAP", "Pickup · ASAP"), the address sheet switches Home to Work
and the block follows, pickup swaps the block to the branch with no "Change"
on this single-location store, and clearing the phone and pressing the button
scrolls the error into view. The iPhone could not be used — the live demo
site runs the released plugin and 404s the Phase 5 endpoints the screen opens
with.

### Left for the rest of the phase
The screen reads everything 6.2 has to submit, and nothing is stored that the
server has not confirmed. Task 6.6 is still open: a cart carried across a
branch switch can hold a dish the new branch does not serve, and this screen
does not yet say so.

## Task 5.5 — Choosing a branch, and the menu following it
Branch `feat/branch`, PR #38, with the plugin half on `mobile-app`
(food-menu-pro). 29 new tests, 542 in total. Phase 5 is complete with this.

### The gap 5.3 flagged, closed
The website scopes the menu to a branch on `woocommerce_product_query` with a
`fmp_location_id` cookie. The Store API fires neither, so a branch changed the
hours but not the dishes. It turned out to have a clean fix: the Store API's
`ProductQuery::get_results()` runs a plain `new WP_Query()`, so `pre_get_posts`
reaches every product listing, search and collection count. Pro hooks it, reads
an `X-FMP-Branch` header and merges in the free plugin's own `tax_query` —
including the arm that matters most, that a dish filed under no location is
sold everywhere.

The route is taken from `rest_pre_dispatch` rather than sniffed from the URI,
so the same header on `wc/v3` cannot change what an admin screen lists.

### A header, and what it costs
The branch has to reach the menu, the search, the counts and the cart. As a
parameter it would have to be threaded through every call site and the one
that was forgotten would quietly serve another branch's dishes. As a header
set by an interceptor it cannot be forgotten.

The cost: two branches produce identical-looking requests, so everything
scoped by the branch watches `activeBranchIdProvider` purely as a cache key.
That is a comment on four providers rather than a mechanism, and the part most
likely to be lost by someone tidying up.

### A provider the network layer awaits must never fail
`selectedBranchProvider` is read by the interceptor before every request, so it
cannot enter an error state and cannot retry — a throwing keystore has to mean
"no branch chosen", and Riverpod's retry backoff would hold every request
instead of letting the app run unscoped. A test that simulated an unreadable
keystore found both, by timing out at thirty seconds.

### Running it found the picker drawing under the cart bar
The sheet was shown from the menu tab's own navigator, and the shell paints the
floating cart bar in a Stack above that, so the bar covered the second branch.
`useRootNavigator: true`. The widget test pumps the sheet with no shell around
it, so there was no bar to be covered by — invisible until the handset.

### Verified on the device, A against B
Two probe branches, three dishes each, twelve sold everywhere. Searching
"Marg" under Probe South finds Margherita; the same search under Probe North
says "No dishes match". The list header goes 18 dishes to 15 on switching, and
the picker shows each branch's address with "Open now" or "Closed today".

### Left for Phase 6
**The cart is not revalidated on a branch switch.** The website drops lines the
new branch does not serve; the app cannot, so a customer can carry a dish
across. Recorded as task 6.6, and 6.2 now notes that an order has to carry the
branch **by name**, because the slot-counting queries match
`fmp_location_name`.

## Task 5.4 — The pickup/delivery toggle and the slot list
Branch `feat/fulfilment`, PR #37, with one plugin change on `mobile-app`
(food-menu-pro). First Dart of Phase 5 and the first consumer of the three
read endpoints. 54 new tests, 513 in total.

### What landed
`features/fulfilment/`: the order-type switch and the time row, on a new
`CheckoutScreen` that sits outside the tab shell as the design shows it. The
cart's "Go to checkout" now goes there instead of saying Phase 6. Contact
details, address, payment and the summary are 6.1 and drop in as further
sections.

Nothing about availability is decided in Dart. The server generates and judges
the list; the app renders it and remembers which chip was tapped. The type and
the slot are both **resolved** rather than stored as objects, so a type the
store switches off, or a slot that fills while the screen is open, falls back
instead of being submitted.

### One plugin fix was needed
A Store API cart line reports the **variation** id, and carries no parent
anywhere — verified by adding a pizza variation to a real cart. Per-dish order
limits and timed rules are set on the parent, so a cart holding a large pizza
silently missed the cap on the pizza. The client cannot resolve that, so the
slots route now does.

### Two Riverpod traps, both fetching the same slots twice
Caught by a test that counted calls; the duplicate was invisible on screen.
A `ref.watch` **after an `await`** registers late and rebuilds the provider
when that dependency settles. And a `Map` is never `==` to an equal map, so
publishing the cart as one re-triggered the fetch on every cart emission. Both
are gone: the request is a single value object, `SlotRequest`, and the cart is
published as the encoded string. Also `retry: null` on both providers, as the
cart controller already does.

### Running it on the device found what the tests could not
Against the dev store's four-slot schedule everything looked right. On the
OnePlus, pointed at a store open all day at a half-hour interval, the wrapped
chip list ran to nearly forty chips down the screen and pushed the rest of the
checkout out of sight. Switched to the design's single scrolling row, which is
bounded whatever the hours — and the reason I had avoided it does not apply in
a scroller.

Verified on the device after the change: the toggle switches the title, the
ASAP estimate and the chip format (delivery windows against pickup point
times), and tapping a chip moves the selection. The iPhone could not be used —
the live demo site runs the released plugin and 404s both endpoints.

### Fixtures are captured, not written
Six of them, taken from real responses on the dev store with a seeded
schedule: both types, a full slot, a closed day, a cart-blocked day and a
store that asks for no time at all. The store was restored afterwards and its
settings diffed against the backup.

## Task 5.3 — The branch list (plugin)
Branch `mobile-app`, PR food-menu-pro#16 — the first PR under the new rule that
all plugin work stays on one long-lived branch. The Flutter side is task 5.5.
No Dart changed. Phase 5's read endpoints are complete with this.

### It went into Pro, not the free plugin as planned
Locations *are* a free-plugin feature — `tpl-food-location` is registered in
`PostTypesController` and the term holds only what WordPress gives it. But
every per-branch **rule** is Pro's `fmp_loc_*` term meta, and the whole
`fmp/v1/app` namespace is Pro's too. Free can reference neither, and Pro
already depends on free, so there was only one direction this could go.

### The list is never empty
A store with no branches still has somewhere its customers collect from, and
the design's header says "Pick up from" on the first screen. So that case comes
back as one entry built from **WooCommerce's own store address**, with `id: 0`
— already what `branch=0` means to `/order-types` and `/slots` — and
`is_store: true`. The app has no empty case to code around.

The week is not inlined per branch; `/order-types?branch=<id>` answers it, and
repeating it per branch would make the payload grow with the store. Everything
here reads through `AppSchedules`, and the three routes were cross-checked on
the same branch to prove they agree.

### Two plugin bugs were in the way
**Coordinates were never saved.** The location screen renders Latitude and
Longitude, defaults them to Googleplex when empty and draws them on a map, but
they were missing from the save whitelist, so every value an admin typed was
dropped on Update. Fixing the save made the fake defaults actively dangerous —
pressing Update would have written a California coordinate into every branch —
so those went too, and the fields no longer hide behind the Google Maps switch.

**The address textarea corrupted its own value**, using `esc_attr()` on element
content and printing it on an indented line, so each save added more whitespace
and another layer of entity escaping. Fixed at the source, with a bounded
decode-and-trim on read for rows already damaged.

The coordinate fix had to be verified through a **real admin POST over HTTP**:
`filter_input_array( INPUT_POST, … )` ignores a hand-built `$_POST`, so a CLI
test returns null and looks exactly like the bug. Reverting the file and
re-posting showed the values dropped; restoring it showed them kept.

### The thing that changes the plan
**Branch selection does not reach the Store API.** The free plugin scopes the
menu with `woocommerce_product_query` and a `fmp_location_id` cookie, and the
Store API runs neither — so a branch changes the hours and the slots but not
which dishes come back. Task 5.5 cannot be done in Dart alone; it needs a
product-query filter in Pro's Store API layer first, mirroring the free
plugin's `tax_query` including its "no location means available everywhere"
arm. Flagged in `PLAN.md` and `FINDINGS.md` to agree before 5.5 starts.

Also recorded: an order records its branch by **name**, and the slot-counting
queries match on that name, so renaming a branch orphans the slot counts of
every order already placed against it.

### Verified on the dev store, then restored
Four branches, two of them children of a third: hierarchy, a branch with its
own pickup hours falling back to the store for delivery, an out-of-range
latitude coming back null, a branch with no coordinates, `open_now` true inside
a window and false outside, and a deliberately double-escaped address coming
back clean. Settings were backed up and diffed against the backup afterwards,
the probe branches deleted, the multi-location switch put back off, and the PHP
server stopped — it was not running before.

## Task 5.2 — Selectable slots (plugin, both of them)
Branches `mobile-app-slots` (PR food-menu-pro#15) and
`mobile-app-asap-estimate` (PR tlp-food-menu#4). The Flutter side is task 5.4.
No Dart changed.

### The website had no slot list to borrow
`pickup-delivery.js` hands the whole weekly schedule to a jQuery timepicker
that builds the times **in the browser**, and one AJAX call judges the single
slot the customer lands on. Neither half is reusable from a mobile client: one
is browser arithmetic, the other would be a request per slot. So
`GET /fmp/v1/app/slots` generates the list and judges every entry of it in one
answer — slot caps, per-window caps, per-product order limits and timed dishes.

### The thing most likely to have gone wrong quietly
The checkout stores `fmp_{type}_date` and `fmp_{type}_time` in the **site's own
display formats**, not ISO, because that is what the web inputs submit and the
Store API extension saves whatever it is handed. Slot counting then matches
those strings. An app formatting its own ISO times would have placed orders
that no slot limit counted and that the admin order column rendered unlike
every web order — and nothing would have errored. So every slot carries the
literal `value` to send, and `CONTEXT.md` says not to build one in Dart.

Counting goes the other way: it is keyed on **minutes since midnight**, because
the admin schedule screen writes 24-hour times while the checkout submits
12-hour ones, so one slot can hold both `13:00` and `1:00 pm`. Verified with two
orders written each way, both counted against the same slot.

### Timed products now answer about a moment, not just now
`check_single_condition()` only ever asked about `current_time()`. It takes an
optional timestamp now, with **null keeping every existing caller identical**,
so a cart holding a breakfast-only dish marks the afternoon slots unavailable
and names the dish. This extends what the plugin's feature means and was agreed
before building — the alternative was letting a customer preorder a breakfast
item for 3pm.

### ASAP needed a setting that did not exist
The design shows "ASAP (15 min)" and "ASAP (20–35 min)". The plugin's only
preparation setting is `delivery_preparation_day`, in **whole days**. So three
number fields were added: `pickup_prep_minutes`, `delivery_eta_min_minutes`,
`delivery_eta_max_minutes`. Blank quotes no estimate, so existing stores are
unchanged. Registration had to go in Pro — the settings save rebuilds the whole
option from `Fns::fmpAllSettingsFields()`, so an unregistered key is wiped on
every save — while the inputs had to go in the **free** plugin, which is why
this task has two PRs.

ASAP's own `value` is empty, because the plugin expresses ASAP by switching the
time picker off entirely. No slot limit can count such an order, so it is
offered only while the next real slot is still open.

### `/app/order-types` was refactored under it
Both routes have to agree about the same schedule, so the reading of it moved
into `AppSchedules`. 5.1's endpoint now calls that, and its output was diffed
before and after to prove nothing moved.

### Verified on the dev store, then restored
Two pickup windows a day with a per-window cap and Sunday closed; delivery with
Monday closed, a one-day lead and a seven-day window; per-branch schedule,
interval and cap, plus a 404 for a branch that does not exist; real orders
filling a slot; an exempt order correctly ignored; a per-product cap consumed
across a pickup and a dine-in order; a past-only window giving `no_times_left`;
an open day with no windows giving the whole day; every ASAP label variant.
Settings, orders, the branch term, the timed rule and the product meta were all
put back, and the settings option was diffed against its backup.

### Left undone, deliberately
`assets/js/admin-settings.min.js` is **not** rebuilt in the free PR, so the
three fields will not appear in admin until someone rebuilds it. That repo has
no lockfile and a build from pristine source already rewrites 13 assets; see
`FINDINGS.md`.

## Task 5.1 — Order types and their schedules (plugin)
Branch: `mobile-app-order-types`, PR food-menu-pro#14. The Flutter side is
task 5.4. First of Phase 5.

### The gap
The **write** path already existed — Pro registers a `food-menu-pro` Store API
checkout extension carrying `fmp_order_time_type` and the pickup/delivery
dates and times. Nothing exposed the **read** side, so the app could not tell
which types a store offers, never mind which days it is open.

### Read the settings the way the website reads them
An absent `enable_pickup` means **on**, so a store that has never opened the
settings screen offers both types. `lead_days` is `delivery_preparation_day`
for delivery and always zero for pickup. `last_date` is null when there is no
preorder bound rather than collapsing to today. And `time_required` is a
separate switch from `enabled`: with it off the customer picks no date or time
at all, so the app must skip the slot list rather than draw an empty one.

### Two things that would have been wrong to guess
An **open day with no windows** is a day with no stated hours, not a closed
one — and that is the dev store's own default state. And an **unknown branch**
now 404s instead of quietly returning the store-wide schedule, which would
have handed a deleted branch's customer the wrong opening hours. Both in
`FINDINGS.md`.

### Verified on the dev store
A seeded schedule with two pickup windows a day and Sunday closed; delivery
with Monday closed, a one-day lead and a seven-day preorder window; per-type
intervals and slot caps; both enable toggles; a branch with its own pickup
schedule falling back to the store's delivery one; and a 404 for a branch that
does not exist. Settings, the test branch and the multi-location toggle were
all restored afterwards.

No Dart changed in this task.

## Task 4.6 — Floating cart bar, and a cart that survives a restart
Branch: `feat/mini-cart`, PR #33. Phase 4 is complete with this.

### What was added
The design's floating bar — count, "View cart", subtotal — over the menu
branch only, because that is where a customer is while they fill a cart. A
badge on the Cart tab counting the same units. And the `Cart-Token` is now
kept in secure storage, so closing the app no longer empties the cart.

### The restore has to win the race
The Store API hands a fresh cart token to any request that arrives without
one, so restoring asynchronously "while the app starts" is not enough —
whichever request goes out first decides which cart the session is. A restore
landing a moment later orphans the saved cart.

`StoreSessionNotifier` became an `AsyncNotifier` whose `build()` reads the
token, and `StoreSessionInterceptor.read` is async and awaits it. That is the
same shape `AuthInterceptor` already uses for the keychain.

Only the cart token is stored: the nonce comes back on every response and is
short-lived. An expired token is dropped before it is sent; one that cannot be
decoded is kept, because the server is entitled to judge a shape this build
has never seen.

### The bar floats, so the screens make room
`cartBarInsetProvider` is the space to leave, and it is zero when there is no
bar — nothing is reserved for a bar that is not there. Both menu screens add
it to their bottom padding.

`HomeShell` watching `cartCountProvider` for the badge is also what triggers
the cart load at launch, which is what the restore needs.

### Verified on the Android device
A cart left with one Fresh Lemonade (`Large 15"`, $7.25) was still there after
a full stop and a cold start: the bar read "1 · View cart · $7.25", the tab
carried a badge of 1, and opening it showed the same line with its add-on. The
bar is absent on the cart screen and on a dish, as the design has it.

### Three things in FINDINGS
Why the restore must beat the first request. A widget test whose `Stack` was
sized to a `Text`, putting the bar where nothing could tap it — a miss that
reads like a widget ignoring the tap. And three tests that asserted on a
different fake from the one in use, two of which passed for the wrong reason.

## Task 4.5 — The cart
Branch: `feat/cart`, PR #32. Task 4.6 adds the floating mini cart and makes a
cart survive an app restart.

### What works now
The dish screen's Add button posts: `AddonSelection.toPayload()` goes straight
into `cart/add-item` under the plugin's extension key, the dish closes, and a
refusal is shown **in the server's own words**, which name the group. The cart
screen lists each line with what was chosen under the dish name, a quantity
stepper, a bin, the totals and the amount due. Empty is the design's own empty
state, not a blank screen, and "Clear all" asks first.

### Mutations are deliberately not optimistic
The wishlist's hearts update before the server replies, and that is right for
an idempotent flag. A cart line carries money: only the server knows what a
quantity change costs once the plugin's discounts and the add-on pricing have
had their say. Showing a total the server has not agreed to is the one thing a
cart must not do, so the line being changed is marked busy instead and the
screen redraws from the response. Every cart route returns the whole cart, so
that is one round trip, not two.

A failed change rethrows for the screen to show but leaves the cart as the
server last described it — a cart the customer is reading must not blank out
because one tap was refused.

### Read add-ons from the extension, not from `item_data`
`item_data` is the website's display copy, with the quantity baked into the
string as `x2` and no ids or prices. `item.addons` is task 4.3's block. The
row falls back to `item_data` only for a store too old to send the extension,
so an older plugin still shows something under the dish name.

### Verified on the Android device, against the dev store
Fresh Lemonade, `Large 15"` chosen, quantity 2 → added with the toast naming
it, dish closed. The cart showed `Large 15"` under the name, the line at
**$14.50** (2 × $7.25) and the same figure as subtotal, total and on the
checkout button. Stepping down to 1 redrew everything at **$7.25** and the
header at "1 item".

### Not built, on purpose
The **coupon field** and the **"Complete your meal"** carousel are in the
design and are v2 per `PLAN.md`. The discount row still appears when the
server applies one of its own. Checkout is Phase 6, so the button says so.

### Three things in FINDINGS
`DELETE cart/items` is the one route that answers with the items list rather
than the cart. A dish opened by deep link has nothing to pop, which `closeDish`
now handles for the close button too. And a test fake that fails "the next
call" fails the controller's own first read rather than the mutation under
test.

## Task 4.4 — Add-on selection on the dish screen
Branch: `feat/addon-selection`, PR #31. The first app-side consumer of the
add-ons endpoint (4.1) and the groundwork for sending selections (4.5).

### What the screen does now
Groups render under the dish's details, in the server's order: a one-of list
for `radio` and `dropdown`, a many-of list for `checkbox`, and the design's
"Special instructions" card shape for `text` and `textarea`. Each card carries
the group's rule ("Select one", "Select up to 3"), its description, and a
Required / Done / Optional badge. The add button runs a live total and names
the first unanswered group instead of adding.

### Rules are enforced twice, on purpose
`AddonSelection` is immutable and applies the same limits the plugin does —
one-of replaces, a tick past `max_selection` is refused with a message rather
than swallowed, a per-option quantity is clamped to **10** because
`AddonFields` clamps there. The server validates all of it again; the point is
not to trust the client but to stop the customer being told "no" after the
fact. `is_default` is honoured, which is why a required group can open as Done.

### Three decisions the design does not cover
A **dropdown** is drawn as a one-of list — the design has no dropdown, and on
a phone a list of three beats a menu that hides two. A group with
`option_quantity` gets a **small stepper** on the chosen row, built from the
bottom bar's own. A group's **description and rule line both show**, rather
than the description replacing the rule, which is what the first cut did.

### Verified on the Android device, against the dev store
Fresh Lemonade at $3.25: the required size group opened as **Done** with
`Small 9"` pre-ticked from `is_default`; picking `Medium 12"` replaced it and
the button went $3.25 → $5.75; ticking Mushrooms → $6.50; its stepper to 2 →
**$7.25**. That is the same 725 minor units the Store API charged for the
identical selection while task 4.3 was being verified, so the preview and the
cart agree.

### Not drawn yet
Option **images**. The payload carries one per option and nothing renders it:
the design's option row has no slot for a thumbnail, and the seeded data has
none. Say if wanted — it is a leading 36px image on the row.

### Two gotchas, in FINDINGS
The add-ons endpoint nests its `currency_*` keys while the Store API inlines
them, which fails silently as a missing `$`. And a widget test tapping a
target below the fold hits nothing without `ensureVisible` — it fails on the
assertion, looking exactly like a screen that ignored the tap.

## Task 4.3 — Add-ons on Store API cart items (plugin)
Branch: `mobile-app-cart-item-addons`, PR food-menu-pro#13. The Flutter sides
are tasks 4.4 and 4.5.

### The gap, measured before fixing
Task 4.2 got selections **into** the cart; nothing came back **out**. A cart
item carried `item_data` — the website's own name/value display strings, with
the quantity baked into the text as `x2` — and `extensions: {}`. So the app
could not tell which group a line belonged to, which option was chosen, what
the option cost, or what the dish cost before any of it. Confirmed against the
dev store first.

### Ids are recovered, not stored
A stored `fmp_addons` row holds only what the website needs to print it: the
group title, the chosen label, a price, a `field_name` and the field type. So
the group is looked up by its `field_name` and the option by matching the row's
value against the group's labels. That has a useful side effect — a cart filled
from the **web page** reads back through the app's own vocabulary too.

A group reworded after the line went into the cart gives `group_id: null`
rather than a guess, and the row is still reported, because its price effect is
real either way.

### Two totals, because one would be a lie
`addons_total` is the sum of the stored deltas, which is what the order line
item records. `addons_total_charged` is the add-on part of what was actually
charged. They diverge when the plugin's discount is set to `addon_total`.
`base_price` comes from asking the website's own `price_calculate()` what the
line would cost with its add-ons removed, so
`base_price + addons_total_charged == prices.price` holds by construction
rather than by arithmetic the app has to trust. See `FINDINGS.md`.

### A silent bug from 4.2, found by doing the read path
A group's id is its **key** in the stored add-on list, not its **position**,
and for global add-ons those differ. Task 4.2 read the position, so a selection
sent with the id the app was given landed on the wrong group or on none — with
nothing in the response to say so. On the dev store `Cutlery` is global group 1,
so every `group_id: "1"` the app sent was dropped. `AppAddonGroups` now carries
both identities and is the only place that reads them.

### Verified on the dev store
Dish with radio + checkbox ×2 + textarea: ids and per-option prices correct,
325 + 400 = 725 = `prices.price`. 20% on the dish only: base 260, charged 400,
sum 660. 20% on dish and add-ons: base 260, `addons_total` still 400, charged
320, sum 580. Global add-on by its published id: recorded, where before it was
dropped. Group renamed with the line already in the cart: ids null, price
effect intact, sum still closes. Item with no add-ons: `addons: []`,
`base_price` equal to the line price. Dropdown add-on over `GET /cart`:
395 + 325 = 720.

No Dart changed in this task.

## Task 4.2 — Add-on selections at add-to-cart (plugin)
Branch: `mobile-app-cart-addons`, PR food-menu-pro#12. The Flutter side is
task 4.4.

### The gap, measured before fixing
`cart/add-item` takes `id`, `quantity` and `variation` and nothing else, and
the website's own handler is driven by `$_POST` behind a nonce. So a dish with
a **required** add-on group went into the cart with no selections at all, at
base price, with the cart item recording nothing. Confirmed against the dev
store first, so the fix had something to be measured against.

### The app sends ids, not labels
The website matches options by their label text, which is display copy: it
carries quotes and entities, and it changes whenever the restaurant rewords a
topping. Ids are the indices task 4.1 already publishes, so the contract
survives a rename.

Those ids are then translated **back into the website's own input shape** and
handed to its `AddonFields`, so the cart entry is indistinguishable from one
the web page made — same `field_name` formula, same quantity clamp, same
reading of a non-numeric price. Pricing, the cart display, the order line item
and the admin screen all keep working with no second code path.

### The bug a wrong price caught
Checkbox and radio labels have to be **`esc_html()`-ed when matching**,
because the website compares against `esc_html( $option['label'] )` and its
form posts the already-escaped text from the rendered HTML. Sending the raw
label silently fails to match any option whose label contains a quote —
`Medium 12"` versus `Medium 12&quot;` — and the dish is added at base price
with the option recorded nowhere.

Nothing errored. It surfaced as a cart total that was 100 minor units short
(475 where 575 was expected), which is the only reason it was noticed at all.
A dropdown is the opposite: it wants the label `html_entity_decode`d with a
1-based position suffix. The two genuinely differ, and that is written down so
nobody tidies them into one.

### Seed data was on the wrong kind of dish
The add-ons seeded in task 4.1 went onto *Build Your Pizza*, which is a
**variable** product — and the website never renders add-ons on those. Moved
to *Fresh Lemonade*, which is simple. The endpoint itself skips variable
products for the same reason.

### Verified against the dev site
Every refusal (`required`, `too_few`, `too_many`, `too_long`,
`unknown_option`), the happy path priced exactly
(`325 + 250 + 2×75 = 725`), selections appearing in `item_data` through the
website's own cart display, the cart surviving a fresh request via session
restore, two different combinations making **separate cart lines**, optional
groups omitted adding at base price, and `min_selection` enforced after
temporarily raising it. Test cart cleared afterwards. No Dart changed.

## Task 4.1 — Product add-ons endpoint (plugin)
Branch: `mobile-app-addons`, PR food-menu-pro#11. Opens Phase 4; the Flutter
side is task 4.4.

### The plan had the storage wrong
`PLAN.md` said add-on definitions "live in the `fmp_product_addons` option".
They do not. They live in **`_fmp_product_addons` product meta**, per dish,
with a separate `global_addon_settings` option holding store-wide groups that
target dishes by id or by category. The plan has been corrected.

That mattered, because the two are an **either/or**, not a merge: a dish with
`_fmp_pa_global_override` set uses its own groups and ignores every global
one; otherwise it gets the globals that match it. Getting that backwards would
have shown customers add-ons the website does not offer.

### So the rule is asked, not reimplemented
`FrontendPAddon::addon_lists()` already decides it for the website, so the
route calls that rather than restating it. The app and the web page cannot
drift apart about what a dish offers, and global targeting comes along for
free. Verified all three branches: a dish with the override gets its own, a
dish targeted by a global gets that plus the all-dishes one, and an untargeted
dish gets only the all-dishes one.

### Public, unlike the rest of `fmp/v1/app/*`
The menu is public and the dish screen is reachable before sign-in, so a token
gate would hide add-ons from exactly the customer deciding whether to make an
account. Nothing in the response is customer data.

### Money needed no new client handling
Option prices come back as **minor-unit strings with a `currency` block in
WooCommerce's own `currency_*` key names** — the Store API's shape. The app's
existing `Money` and `Currency` parse it unchanged, so add-ons introduce no
second way to read a price.

### What the route refuses to guess
- A stored price is **free text**, so it can be `-`, `N/A` or empty, all
  meaning no charge. Non-numeric becomes zero, the same reading the website
  takes. Confirmed: `-` → `0`, `2.50` → `250`.
- A group with **no title or an unknown type is dropped** rather than sent
  with a guessed one — a nameless control on the dish screen is worse than an
  absent group.
- `free_label` is **resolved to a boolean** rather than passed through, since
  its empty value means "inherit" from a global setting the app cannot see.

### Dev site now has add-on test data
Three groups on *Build Your Pizza* (a required radio with price deltas, a
checkbox with `max_selection` 3 and a non-numeric price, a textarea with a
placeholder and char limit) and two global groups — one targeted at *Iced
Latte*, one applying to every dish. Task 4.4 will want them. Recorded in
`LOCAL_DEV.md`.

No Dart changed.

## Task 3.11 — Forgot password, and the Security section
Branch: `feat/account-security`. Consumes the endpoints from task 3.10 and
**closes Phase 3 for good** — the account-security gap raised in 3.1, 3.2, 3.7
and 3.9 is now shut.

### What shipped
Four screens: `ForgotPasswordScreen` and `ResetPasswordScreen` beside sign-in,
`ChangePasswordScreen` and `ChangeEmailScreen` behind a new Security card on
the account screen. The sign-in form gained a **Forgot your password?** link
that carries whatever address was already typed. The Edit profile email note
stopped saying "contact the restaurant" and now offers a **Change** button.

### Adopting the replacement session is the whole job
All four endpoints revoke **every** session and return a fresh pair, so a
screen that treats the response as a plain 200 leaves the app holding a token
the server has already forgotten — signed out on the next request, with
nothing on screen to explain it. `AuthController` adopts and persists each
one, and `FakeAuthRepository` returns tokens suffixed `_reissued` so a test
that forgets to assert the swap fails rather than passes.

### The flow never says whether an address is registered
`forgot-password` answers identically either way, so the screen advances to
the code step regardless. A screen that only moved on for real customers
would leak exactly what the server is refusing to.

### Three things the device found
1. **A stale validation message.** The code field kept "The code is six
   digits." after the code had been corrected, because a `FormField` holds its
   last error until `validate()` runs again. Fixed with
   `autovalidateMode: AutovalidateMode.onUserInteraction` plus an `onChanged`
   that clears the server error once the customer touches the field it named.
   Applied to the three new forms **and to the address form from task 3.9**,
   which had the same wart.
2. **`ScaffoldMessenger.of(context)` after `Navigator.pop`.** Both change
   screens popped and then asked for the messenger through a context that was
   already defunct. The messenger is taken before the pop now.
3. **Validation running before the rebuild.** Same shape as the address form:
   the validators read `_error`, so `validate()` had to move into a
   post-frame callback or it asked the widgets still holding the old one.

### Two renames
The submit buttons said "Change password" and "Change email", which are also
the screen titles. A button repeating its own heading reads as a second
heading, and it made the widget tests ambiguous — they are "Update password"
and "Update email" now. Same call as the address form's "Save address".

### Verified on the Android device
The whole forgot-password journey, signed out: the link carried the typed
address across, the code screen echoed it back, **the client-side check caught
a six-digit code that adb had truncated** before any round trip, and the real
code completed the reset, unwound the flow and landed on a signed-in account
screen. Server side: the code was consumed, the old password rejected with a
401, the new one accepted, and only one session left. The Security card shows
both rows. Test account restored afterwards.

20 new tests (339 total): the forgot screen advancing for a registered *and*
an unregistered address, rejecting a malformed one and reporting a 429; the
reset screen signing in, persisting, refusing a non-six-digit code and a short
password before the round trip, resending, and clearing both a stale client
error and a spent server one; change-password adopting the reissued token into
the session *and* the keychain, and placing a wrong current password on its
own field; change-email requiring the address twice, adopting the new session,
and landing an already-taken address on the right input.

## Task 3.10 — Account security endpoints (plugin)
Branch: `mobile-app-account-security`, PR food-menu-pro#10. **Agreed after
being raised in 3.1, 3.2, 3.7 and 3.9**; the Flutter half is task 3.11.

### What shipped
`forgot-password`, `reset-password`, `change-password` and `change-email`,
plus `AppPasswordReset` for the code itself.

### A 6-digit emailed code, not WordPress's reset link
`retrieve_password()` emails a URL to `wp-login.php`, which drops a mobile
customer onto a web page mid-flow and leaves them to find their way back.
Finishing in the app needs something typeable, and a 40-character key is not.

The trade is a million-value secret, so the defences are **time and attempts**
rather than length: 15 minutes, 5 guesses, either limit destroys the code, and
both routes are rate limited per IP and per account on top. Only an HMAC is
stored, which is worth less here than for an access token — a leaked row
brute-forces in a million hashes — but it keeps the plaintext out of the
database for the quarter hour it exists.

### The ordering bug the live test caught
The password was being validated **after** the code, and `verify()` consumes
the code on success. So a password that failed the length rule spent the code
and sent the customer back to their inbox for a new one. The first version
papered over it by issuing and emailing a replacement; the fix was to move the
validation ahead of the check, since nothing in it depends on the code. Both
orderings were exercised against the dev site.

### Not an account oracle
`forgot-password` answers identically whether or not the address is
registered, and swallows email failures for the same reason.
`reset-password` returns one error for an unknown address, a wrong code and an
expired one.

### Every one of them replaces the session
All four revoke every session and issue a fresh pair. The old password may be
exactly what is being reset *because* somebody else knows it, so other devices
lose their tokens; re-issuing keeps the app in hand signed in. **Task 3.11
must expect its token to be swapped by these calls** rather than treating the
response as a plain success.

`change-password` and `change-email` also require the current password on top
of a valid token — a token proves the phone, not the person.

### Written down rather than hidden
- **`change-email` sends no confirmation to the new address.** A typo locks
  the customer out of an address they can no longer prove they own. The
  current password is the bar instead.
- `validate_password()` is duplicated from `AuthApi` rather than shared,
  because that method is private and widening it would make a registration
  rule look like a shared contract.

### Verified against the dev site
Every route driven with curl: identical answers for known and unknown
addresses, the code stored hashed with its expiry, a wrong code incrementing
attempts, a weak password leaving the code pending and the same code then
working, the code consumed and all prior sessions revoked, change-password
refusing a wrong current password (403) / an unchanged one (400) /
anonymous (401) and then killing the old token, change-email refusing a wrong
password / an unchanged address / one already taken (409), the `billing_email`
mirror both updating a derived value and leaving a deliberate one alone, and
the limiter returning 429. Test account restored afterwards. No Dart changed.

## Task 3.9 — Address book
Branch: `feat/address-book`. Consumes the endpoint from task 3.8 and closes
Phase 3.

### What shipped
`features/address/` — `SavedAddress` and `AddressField` models, a repository
over the address half of `/me` plus `/address-fields`, the controller, the
book screen, the add/edit form and its two widgets. The Account screen gained
its third row.

### The form is not written in Dart
Which inputs exist, in what order, under what label, required or not, and
whether a state is a picker or free text all come from the server. On the dev
store (base country Bangladesh) the form draws **District** as a 64-option
picker and **Postcode / ZIP** with no required marker — a hard-coded US form
would have shown "State" and a required "ZIP Code", both wrong there.

`AddressFieldInput` picks its widget from `type` and `options`: a `country` is
a picker over the response's `countries` map, a `state` with options is a
picker and without them a text field, `tel` gets a phone keyboard. **A field
the server omits is not drawn at all** — `company` is absent in most locales.
Changing country refetches, and clears the state, because a state code from
the old country is meaningless under the new one.

Required-ness is the only validation the app does. Format is the server's
business: it knows a US ZIP from a UK postcode, and checking here would encode
that twice and get it wrong.

### Whole-book replace, kept in one place
`PUT /me` replaces the entire address book, so an omitted address is deleted.
Every screen writing its own list would eventually drop one, so
`AddressController` owns it: it holds the book, applies one change to a copy,
and sends the result. Add, edit, delete and set-default are all that one
operation underneath.

**Exactly one default is decided in the controller, not hoped for.** The
server promotes the first entry when nothing is marked, so sending two
defaults would silently pick one rather than honouring the choice.

### Telling "your input is wrong" from "another address is"
The server rejects with `fmp_app_invalid_address`, the offending field, **and
its index in the submitted book**. Because the book goes up whole, that index
is not necessarily the address being edited — an entry stored before the store
changed country can fail a save of a different one.

Only the controller knows where it put the address it was given, so it
resolves that and throws an `AddressSaveException` carrying
`isThisAddress`. The form lights up its own input only when that is true, and
otherwise says another saved address needs fixing. `ApiException` gained an
`index` field to carry it.

### Writes are not optimistic here
Unlike the wishlist. The server rewrites what it stores — a state code
resolved from a name, a formatted postcode, a `locality` only it can build
("Banani, Chattogram"). Showing a local guess and then correcting it would be
worse than waiting for the real answer.

### Two smaller things
- The wishlist and address book headers were identical, so the back button and
  title moved to `core/widgets/screen_header.dart` and the wishlist now uses
  it. Its tests passed unchanged.
- The form's submit button says **"Save address"** in both modes. It first
  said "Add address", which is also the screen title — a button repeating the
  heading reads as a second heading, and it made the widget test ambiguous.

### Verified on the Android device
Opened the book (two seeded addresses, no default, no badge — handled), added
one against the Bangladesh form including picking a district from the server's
list, and saw it saved with `country=BD`, `state=BD-10` resolved from the
name, and the server-built locality. Deleted it and **confirmed the other two
survived**, which is the whole-book replace working. The server promoted Home
to default on the first write, as documented.

34 new tests (319 total): the controller's add/edit/delete/set-default
preserving the book, both sides of the error-index split, and the screens'
list, empty, signed-out, error-retry, per-address actions and dark mode —
plus the form drawing the US and UK shapes differently, honouring an optional
field, and refetching on a country change.

## Task 3.8 — Address field metadata (plugin)
Branch: `mobile-app-address-fields` on `food-menu-pro`, PR food-menu-pro#9.
**A new task, agreed before building**, split out of what was task 3.8; the
app-side address book is now task 3.9.

### Why the plan changed
Starting the address form showed it could not be built correctly app-only.
`AppAddresses` validates against `WC()->countries->get_address_fields()`, so
the rules differ per country — and not only which fields are required.
WooCommerce renames them too. Measured against the dev store:

| Country | `state` | `postcode` | `city` |
|---|---|---|---|
| BD (base) | **District**, required, 64 options | optional | required |
| US | **State**, required, 54 options | **ZIP Code**, required | required |
| GB | optional, no list | **Postcode**, required | required |
| AE | optional, no list | optional | required |
| SG | optional, no list | **Postcode**, required | *optional* |
| HK | **State**, required, 3 options | optional | required |

There is **no public country list anywhere** — the Store API has no such
route (checked), and `wc/v3/data/countries` is key-authenticated. So the app's
only options were to pin every address to the store's base country, or to
hard-code one country's rules in Dart. Both are working around a plugin gap in
Dart, which this project does not do, so the choice went to the user and the
plugin endpoint was agreed.

### The route
`GET /fmp/v1/app/address-fields[?country=XX]` returns `default_country`, the
`countries` map for the picker, and `fields` for one country.

- **One country per request.** Every country's states at once would be tens of
  thousands of entries for a form that shows one country at a time.
- **`fields` is an ordered list, not a map.** WooCommerce orders address
  fields differently per country and that order is the answer; it is sorted by
  WooCommerce's own `priority`. Each entry is
  `{key, label, required, priority, type}`, plus `options` on `state` where
  the country has a state list.
- **Intersected with `AppAddresses::FIELDS`**, so the app is never told to
  collect something the address book would drop on save. A field WooCommerce
  omits is left out rather than padded back in — `company` is absent in most
  locales, and that absence is the answer.
- A base country the store does not sell to falls back to the first allowed
  one, so the app is never handed a default it cannot select.

### A cache header that did not survive
The answer is static per country, so it was given
`Cache-Control: private, max-age=3600`. The response came back
`no-cache, no-store, private`: **WordPress forces no-store onto every
authenticated REST response**, so a header set in the handler never survives.
Removed rather than left as a claim that is not true — the client holds the
answer for the session instead.

### Verified against the dev site
Driven with curl as a token-holding customer against a store selling to all
250 countries: the six countries in the table above, lowercase `?country=us`
normalising, an unknown country (400 `fmp_app_country_not_allowed`), and
unauthenticated (401). No Dart changed, so the app's analyze and test runs are
unaffected.

## Task 3.7 — Account screen and Edit profile
Branch: `feat/account-screen`. The design's screen 9, plus the form behind its
Edit button.

### What shipped
`features/account/` — `ProfileRepository` over `GET|PUT /fmp/v1/app/me`, the
red `AccountHeader`, a reusable `AccountRow`/`AccountRowCard`, the rewritten
`AccountScreen` and `EditProfileScreen`.

### Three of the design's six rows are not there
The design lists My orders, Wishlist, Saved addresses, Payment methods,
Notifications and Help & support. Three of them have nothing behind them:

- **Payment methods** shows `Visa 4242`. Card and PayPal are deferred to v2,
  and v1 is cash on delivery, so there is no stored card to name.
- **Notifications** shows `On`. Push is not in the plan at any phase.
- **Help & support** goes to a help centre that does not exist.

Rendering them would mean inventing a value and a destination, which is the
same call already made for the dish card's prep time. **Saved addresses is
also absent, but only until task 3.8** — the data is already on `/me`, the
screen is not built yet, and a row that goes nowhere is worse than no row.

So the screen ships **My orders** and **Wishlist**. Say the word if the empty
rows are wanted as placeholders; it is a few lines either way.

**My orders deliberately carries no count.** The orders endpoint is task 7.1,
and a `0` there would read as "you have never ordered" rather than "we have not
asked yet". The wishlist count is real, from the controller built in 3.6.

### The edit form writes back into the session
`PUT /me` returns the customer as the server now has them, and that result is
pushed into `AuthController.updateSession`. Without it the header would keep
showing the old name until the next sign-in, because the session — not a
provider over `/me` — is what the header reads. `updateSession` also persists
through `TokenStore`, so the change survives a restart; both are asserted.

**The PUT is partial.** Only the fields the form owns are sent, because the
endpoint treats an absent key as "leave alone" and a present one as "replace" —
sending a whole object would let this form wipe the address book it does not
even show.

### Email is shown but not editable
There is no endpoint for changing it. The form says so in a note rather than
offering a field the server would refuse. This is the third place the missing
account-security group has come up; it is still **task 3.9, still unconfirmed**.

### Verified on the Android device
Signed in, opened the header's Edit, changed the first name and saved: the
server took it (`first_name`, and `display_name` followed via the sync built in
task 3.2), the header updated to the new name and initials immediately, and a
force-stop and relaunch kept it. Test data restored afterwards.

18 new tests (285 total), **all pumped at the reported device's width** rather
than the default 800x600 — the lesson from the banner fix. They cover the
header, the two rows and the absence of the other four, the real wishlist
count, both navigations, the end-to-end save through to the session and the
keychain, each validation rule, the error path keeping the typing, the busy
state, a very long name and email, and dark mode.

## Banner card layout on a phone — reported from a device screenshot
Branch: `fix/banner-card-layout`. A defect in the task 2.5 carousel, found by
looking at the running app rather than by any test.

### What was wrong
Two things, both in `_BannerCard`:

1. **The title ran under the artwork.** The copy column was a hard-coded
   `width: 180`, and the artwork a hard-coded `width: 150` anchored to the
   right. Each is plausible alone; together they overlap on any card narrower
   than about 346pt. On the reported 360dp phone the card is ~319pt and the
   overlap measured **28.8pt** — enough to put "Chicken" behind the photo.
2. **The artwork was letterboxed.** `BoxFit.contain` in a full-height box left
   the card's red showing above, below and beside the photo, so it read as a
   floating rectangle instead of art bleeding off the card edge.

### Why the tests did not catch it
The banner widget tests pump at Flutter's default 800x600 surface, which is
wider than any phone. At that width the two hard-coded numbers have room and
nothing overlaps. **A layout bug that only appears below a certain width needs
a test that sets the width** — `tester.view.physicalSize`. Added, at the
reported device's own 1080x2400 @3x.

Neither failure throws, either. A `Stack` happily draws one child over another
and `BoxFit.contain` is a legal fit, so there is no overflow banner and no
exception to assert on. The new tests measure geometry instead: the title's
right edge against the artwork's left edge, and the `Image`'s `fit`.

### The fix: ratios, not pixels
The design's banner is a **fixed 330x160** card — text column 170 wide,
artwork 170 wide bleeding 10 off the right, inset 20 from the top, 120 tall,
with `border-radius: 60px 0 0 60px` and `object-fit: cover`. Those pixel
values are only meaningful at 330pt. Here the card is a fraction of the
viewport, so `_BannerMetrics` holds the design's numbers as **ratios of that
330x160 card** and derives everything from the actual card size.

The copy column is then derived by subtraction from the artwork's left edge
rather than stated independently, so the two can no longer drift apart — which
was the whole bug. It is floored at zero, because a derived width goes negative
before it goes small.

One deliberate departure: **the design lets its copy overlap the artwork by
20px**, relying on the rounded left edge to curve away under the text. That
only works at exactly 330pt, so the copy stops a gutter short of the artwork
instead. The rounded left edge is reproduced (`artworkHeight / 2`, which is the
design's 60 on a 120-tall band), so the band still reads as drawn.

### Verified on the Android device
Both seeded banners re-checked on the phone the report came from: copy fully
clear of the artwork, artwork filling its band and bleeding off the right edge
with the rounded left. 267 tests pass, including three new banner tests — the
overlap, the fit, and a 280pt card that would have produced a negative width.

## Task 3.6 — Wishlist screen and the hearts
Branch: `feat/wishlist-screen`. Consumes the endpoints from task 3.5 and
closes the client half of the wishlist.

### What shipped
`features/wishlist/` — a repository, a controller, the screen (design 10), the
heart and the wishlist row. Hearts went onto dish cards, menu rows and the dish
detail screen; the Account screen gained one row to reach the wishlist from.

### One load per sign-in, read by every heart
A grid of dishes means a dozen hearts on screen at once, so asking the server
per card would be a request per card for something one request already carries.
`WishlistController` loads the list once per sign-in and holds it;
`wishlistIdsProvider` derives the id set and every heart watches that.

`build()` watches `isSignedInProvider`, so signing in loads the wishlist and
signing out drops it with **no explicit invalidation anywhere**. The id set is
derived from the returned products rather than read from the response's
`product_ids`, because the two are the same thing and deriving it cannot drift.

### Optimistic, with the whole list as the undo
`toggle()` updates the list, then calls the server, and restores the previous
list on failure. A heart that waits for a round trip feels broken, and the
write is idempotent either way. Because the heart always sits next to a dish
the app has already loaded, favouriting can **prepend the product itself**, so
the wishlist screen is correct the moment the heart fills — no refetch.

Two details worth keeping:
- **`toggle()` awaits the first load before touching state.** Otherwise a tap
  during the opening request silently does nothing, and that window is exactly
  when a customer is first looking at the menu.
- **A 404 also invalidates the controller.** The dish has left the menu, so the
  held list is stale in more ways than that one heart; reverting alone would
  leave a dish on screen that the server has already dropped.

### The heart is shown to everyone
Signed out, tapping it opens sign-in rather than calling the API — the journey
the router was already built for ("the customer is sent here mid-task …
saving a favourite"). Hiding it would leave a signed-out customer no way to
discover that dishes can be saved. This **reverses the note written in
`CONTEXT.md` during task 3.5**, which said the heart should only be shown to a
signed-in customer; that section has been rewritten.

### Two places the design was followed, and one where it was not
- The wishlist screen uses its own compact **`WishlistRow`**, not `DishRow`.
  The design drops the description, rating and add button here, because the
  list is decisions already made rather than a menu to browse. The earlier
  `CONTEXT.md` note predicting `DishCard` reuse was wrong.
- The screen is **nested under the Account tab**, so the tab bar stays and
  Account stays highlighted, which is what the design shows.
- **The menu row heart is not in the design**, which draws hearts on the grid
  card and the detail screen only. `PLAN.md` asks for cards *and* rows, and
  being able to save a dish from the grid but not from the list of the same
  dishes is a gap a customer would notice, so it was added beside the name —
  not over the 76px thumbnail, which a 30px disc would dominate, and not next
  to the add button it would compete with.

### Riverpod's auto-retry had to be switched off
Riverpod 3 retries a failed provider build on its own with backoff. Left on, it
kept a timer firing while the customer sat on the error screen, meant `.future`
never completed with the error, and leaked a pending timer into every test that
rendered the Account screen. The screen already offers "Try again", so the
provider sets `retry: (_, _) => null`.

### Verified on the Android device, against the local site
Signed in, favourited from a dish card and from a menu row — both written
server-side, and the row tap did **not** also open the dish. The filled state
is shared across screens, so a dish favourited on the grid shows filled in the
list. Removed from the wishlist screen, saw the row go and the empty state
appear with the design's own wording.

Then the cross-device claim: two favourites were written **directly to the
server**, standing in for another device, and the app was **force-stopped and
relaunched**. The session restored and both came back — including
`Sold Out Special`, confirming out-of-stock favourites survive on purpose.

32 new tests (258 total): the controller's optimistic paths, revert, the 404
reload, the cap, the tap-during-load window and the signed-out case; the
screen's list, empty, signed-out, error-and-retry and dark-mode states; the
heart's fill, both write directions, the sign-in journey and its error wording;
and the hearts in a card and a row, including that the card heart does not
swallow a tap meant for the card.

## Task 3.5 — Wishlist endpoints (plugin)
Branch: `mobile-app-wishlist` on `food-menu-pro`. Opens the server half of the
wishlist; the Flutter half is task 3.6.

### What shipped
`GET|POST /fmp/v1/app/wishlist` and `DELETE /fmp/v1/app/wishlist/{product_id}`,
token-authenticated like the rest of `fmp/v1/app/*`. Two new files,
`app/Api/App/AppWishlist.php` (storage) and `app/Api/App/WishlistApi.php`
(routes), plus one line in `FMP::controllers()`.

### One meta row per favourite, not a serialized list
The decision the task turned on. A stored list would make every heart tap a
read-modify-write, and hearts are tapped fast — two taps 200ms apart are two
requests that both read the old list, and the second write silently discards
the first favourite. The customer sees a filled heart that is gone on refresh.

`_fmp_app_wishlist` is therefore a **repeated** meta key: adding is one INSERT,
removing is one DELETE, and there is no lost update to guard against — no
compare-and-swap, no lock, no retry. **Verified: ten simultaneous adds from an
empty wishlist kept all ten rows.**

Compare-and-swap was the first idea and does not work here. WordPress applies
`update_user_meta()`'s `$prev_value` guard under `! empty( $prev_value )`, so
the guard is skipped exactly when the previous value is an empty array — the
first-favourite case, which is the one that matters.

Ordering falls out of `umeta_id`, which is monotonic, so **no timestamp is
stored**; `all()` reverses the rows to put the newest favourite first. Nothing
in design 10 shows a date.

### GET returns products, not IDs
The wishlist screen draws the same dish cards as the menu, so bare IDs would
force a second round trip and hand the app a list it cannot render. The route
hydrates by dispatching `wc/store/v1/products` internally through
`rest_do_request()`, with `include` + `orderby=include` so the Store API
returns them in wishlist order. No second product serializer to keep in step,
and the `food-menu-pro` extension fields come along free — **confirmed in the
response**.

### What happens when a favourited dish leaves the menu
Hydration asks for `catalog_visibility=catalog`, the same visibility the app's
menu screens use, so the wishlist can never show a dish the menu hides. That
splits into two cases, both verified end to end:

- **Hidden, or unpublished** — drops out of the response but **stays in
  storage**, and comes back when the dish does. A dish pulled from the menu for
  an afternoon should not cost the customer their favourite.
- **Deleted outright** — pruned on read, since nothing will bring it back.

So `product_ids` is the IDs of what is in `items`, not of what is in storage:
the app uses it to decide which hearts are filled, and a heart it cannot show
must not be in the list. There is deliberately no `count` field, which would
have had to mean one or the other.

### Verified against the dev site
Every route driven with curl as a real token-holding customer: empty list, add,
add again (200, not an error), newest-first ordering, delete, delete again,
delete a dish never favourited, 401 unauthenticated on every method. Refusals:
unknown product and a page ID (404), a variation (400 — the heart is on the
dish, not an option), a hidden product (404), `product_id` missing or 0 (400).
Cap behaviour through the `fmp_app_wishlist_max_items` filter: over the cap is
409, and **re-tapping a filled heart still succeeds on a full wishlist**,
because the already-present check runs before the cap check. Two customers'
wishlists stay separate. Forced duplicate rows collapse on read and one DELETE
clears all of them.

Out of stock is deliberately allowed — saving a dish that has sold out is the
point of a wishlist. Not rate limited: the routes are token-gated, each write
is one indexed INSERT or DELETE, and the cap bounds growth.

**No Dart changed in this task**, so the app's analyze and test runs are
unaffected; the plugin has no PHPUnit suite and PHPCS is not installed in this
checkout, so the PHP was syntax-checked and then exercised live.

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

## Task 3.4 — Token persistence, auto-refresh, logout on 401
Branch: `feat/token-persistence`. Completes the client half of Phase 3 auth.

### What shipped
- **`TokenStore`** — Keychain on iOS, EncryptedSharedPreferences on Android,
  via `flutter_secure_storage` (the one new dependency). Not
  `SharedPreferences`: a refresh token is a bearer credential good for thirty
  days and the server accepts it from anywhere. Expiry is stored as an
  **absolute** timestamp, because the app may be closed for days and a
  lifetime captured at issue time would be meaningless on restore.
- **`AuthController` is now an `AsyncNotifier`.** "We do not know yet" is a
  real state: at launch the session is being read back, and treating that as
  signed-out would flash a sign-in prompt at somebody already signed in. The
  account screen shows a spinner for it.
- **Single-flight refresh.** Every caller awaits one shared future. This is
  correctness, not efficiency: the plugin rotates refresh tokens and revokes
  the session if a spent one is replayed, so two concurrent refreshes would
  sign the customer out.
- **`AuthRefreshInterceptor`** — a 401 triggers one refresh and one replay, and
  the retried request is marked so a second 401 gives up instead of looping.
- Failed refresh signs out and clears storage; a **network blip does not**,
  because losing a thirty-day session to a dropped tunnel is worse than
  retrying on the next request.

### Two bugs found while building it
1. **A `QueuedInterceptor` deadlocks on retry.** `dio.fetch` re-enters the
   interceptor chain, and the replayed request waits on the queue slot the
   error handler is still holding — the test hung for the full 30s timeout.
   Deduplication belongs in the controller's single-flight future, so the
   interceptor is a plain `Interceptor` now.
2. **A cold-start race.** `AuthInterceptor` read the token synchronously, so
   any request made while the keychain read was still in flight went out
   without its token. `readToken` is async now and awaits the restore.

### Verified on the Android device, against the local site
Signed in (session recorded server-side as `device="Android"`), **force-stopped
the app with `am force-stop` and relaunched** — still signed in, restored from
encrypted storage, with no sign-in flash. Then logged out, confirmed the server
session was revoked, force-stopped and relaunched again — still signed out.

**Auto-refresh is not yet observable on a device**, because no screen makes an
authenticated request until task 3.7 adds the account screen. It is covered by
17 new tests, including the burst case and the deadlock that broke it.

### Reactive, not pre-emptive
Refresh happens on a 401 rather than on a token that looks expired. One wasted
request per hour is cheap, and it keeps a single code path that has to work
anyway: the server can revoke a session at any time, so "the token looked valid
but was not" must be handled regardless.

## iOS on a physical device — what was actually wrong
Branch: `fix/ios-local-network`. Follows the Android/iOS signing work below.

The iPhone showed no products and "could not reach server". Three separate
things were going on, and two of them were me measuring the wrong thing.

1. **The app was never running.** A debug Flutter build cannot be launched from
   the iOS home screen; tapping the icon shows a black placeholder and the Dart
   code never executes. `devicectl process launch` reports success anyway, and
   the process exists, so "launched successfully" was not evidence of anything.
   **`--profile` is required on a physical iPhone.**
2. **iOS needs two permissions, not one.** `NSAllowsLocalNetworking` only
   relaxes ATS. Since iOS 14 a LAN connection also needs the Local Network
   privacy permission, which requires `NSLocalNetworkUsageDescription`. Without
   it the system denies the connection **silently, with no packets leaving the
   device**. Simulators do not enforce it. The key is now set.
3. **The dev server was hiding the evidence.** PHP's built-in server does not
   log requests handled by `router.php`, so a working REST API looks silent. A
   temporary `muplugins_loaded` logger gave ground truth and showed the iPhone
   (192.168.0.116) sending *nothing* while Safari on the same handset loaded
   the site fine — which is what finally separated network from app.

### How it was resolved
Habib opened up the live site, which runs the merged Pro plugin over **HTTPS**.
A public HTTPS host needs neither cleartext ATS nor the Local Network
permission, so it is now the iOS testing target. He confirmed **Account → Sign
in works on the iPhone** against it.

The residual "iPhone cannot reach the LAN dev site" problem is therefore unproven —
most likely stale privacy state from the installs that predated the usage
string. The `Info.plist` key is correct regardless and stays.

### The live site is now seeded
It started as a **non-WooCommerce** install, which usefully exercised the
fallback paths: registration fell back to `wp_insert_user`, and the address
endpoints returned a clean `503 fmp_app_woocommerce_missing` rather than
crashing. After WooCommerce was installed it was seeded to mirror the local
demo — 16 products (one variable, one out of stock, three on sale), 6
categories, 7 tags, 6 uploaded images and 2 banner posts. Verified through the
app's own API calls, then rendered on the Android device against the live site.

A test customer was created there: `claude.devicetest@foodmenu.test`.

## Device enablement — Android network config, iOS signing
Branch: `fix/android-network-config`. Not a planned task: it came out of
running task 3.3's work on the attached physical devices rather than only the
simulator.

### What was broken
- **Android could not reach the network at all.** Cleartext HTTP has been
  blocked by default since API 28 and the dev site is plain HTTP, so every
  request failed before leaving the device. The app had never been run on
  Android. Fixed with a debug-only network security config; release builds
  keep Android's HTTPS-only default.
- **A release build would have had no `INTERNET` permission.** Flutter's
  template declares it only in the debug and profile manifests. Would not have
  surfaced until the release phase — Phase 13 now, Phase 8 when this was written.
- **iOS device builds had no development team**, and once set, `com.foodmenu`
  turned out to be registrable under **only one** of the two Apple teams on this
  machine. See `FINDINGS.md` — it constrains release signing (task 13.2,
  numbered 8.4 when this was written).

### What running on a real device proved that tests could not
Driving the Android device with `adb shell input`, end to end against the dev
site: the menu, banners and categories loading over the LAN; a **real rejected
sign-in** rendering the server's own message in the error banner — the state
the simulator could not reach, and the one gap called out in task 3.3's PR; a
successful sign-in; **Google Password Manager offering to save the
credentials**, which confirms the `autofillHints` are wired correctly and is
pure platform behaviour no widget test can show; and logout clearing the
session both on screen and server-side.

The device label also came out right: the session the app created was stored as
`device="Android"`.

### One scare, and what it was
A sign-in kept returning 401 with visibly correct credentials on screen, while
the identical request from curl succeeded. A temporary `rest_pre_dispatch` log
showed the app's request was **byte-identical** to curl's — so the app was
fine, and the earlier failures were `adb shell input text` silently corrupting
the email. Recorded in `FINDINGS.md`, because it looks exactly like an app bug.

## Task 3.3 — Flutter auth flow
Branch: `feat/auth-flow`. First app-side task of Phase 3.

### The design has no auth screens
Its ten screens are home, menu, product, cart, checkout, success, orders,
order, account and wishlist. There is no sign-in, no register and no password
screen anywhere, and the account screen simply assumes somebody is signed in —
its **Log out** is a `toast()` stub like the rest. Both screens here are
therefore drawn from the design's own vocabulary: the `page` background, 16px
gutters, the `field` input fill with a `line` hairline, and the full-width
48px brand-red call to action from checkout. Recorded as an agreed decision in
`PLAN.md`, matching the one already taken for the address screens.

### What shipped
- `features/auth/domain/` — `AuthUser`, `AuthTokens`, `AuthSession` and
  `AuthValidation`. The validators are pure and Flutter-free, and **mirror the
  server's rules rather than inventing stricter ones**, so a form that passes
  locally is not then rejected by the API.
- `features/auth/data/auth_repository.dart` — the four auth routes.
- `features/auth/data/auth_controller.dart` — the session. `null` *is* the
  signed-out state, so no status flag can disagree with it. **In memory only**;
  task 3.4 persists it.
- `features/auth/presentation/` — `LoginScreen`, `RegisterScreen`, and the
  shared `AuthShell`, `AuthField` and `AuthErrorBanner`.
- `core/network/auth_interceptor.dart` — attaches the bearer token to every
  request except the auth routes themselves.
- The account screen now shows who is signed in and can sign out. Deliberately
  minimal — the design's full account screen is task 3.7.

### Decisions worth knowing
- **Both names are required at registration** even though the API treats them
  as optional, because WooCommerce requires `first_name` and `last_name` on
  every address and the design's checkout requires a full name. Collecting them
  once at signup avoids asking again at the first order.
- **Auth is pushed, not navigated to.** The customer is sent there mid-task, so
  the screens pop back with a result and the gated action resumes. There is no
  tab or destination for them, which also matches the design having none.
- **Logout always succeeds locally**, even if the server call fails. Leaving
  someone signed in because the network blipped is the worse of the two
  outcomes.
- **A 429 is not "retryable".** It will succeed eventually but not now, so the
  banner reports the wait from `data.retry_after` instead of offering a button
  that would spend another attempt.

### Core changes this needed
`ApiException` gained `retryAfter` and `field`, both lifted from the server's
`data` object, plus `isRateLimited`. `ApiClient` gained `put`, which task 3.7
needs for `/me`.

### Verified
`flutter analyze` clean, **209 tests pass** (51 new). Run on the iPhone 17 Pro
simulator against the dev site and looked at: sign-in and register in light and
dark, and the signed-out account screen. Field alignment, the brand red, the
`field` fill and the dark ramp all render as intended. The error banner is
covered by widget test rather than on-device, because `simctl` cannot tap and
reaching a populated error state needs input.

### Still missing
Password reset, and changing the account email or password — see the task 3.9
recommendation in `PLAN.md`. The sign-in screen deliberately ships **without** a
"Forgot password?" link rather than with one that goes nowhere.

## Task 3.2 — Profile and address book (plugin)
Branch: `mobile-app-me` on `radiustheme/food-menu-pro`, PR #7. Nothing in this
repo changes except these docs.

`GET|PUT /fmp/v1/app/me`, authenticated by the bearer token from 3.1.

### The design decided the data model
Checkout shows one address card — `Deliver to / 6391 Elgin St. /
Celina, Delaware 10299 · Home` — whose **Change** button is a toast stub, and
the Account screen has a **Saved addresses: 2** row that is also a stub. So the
design implies labelled, multiple addresses but never draws the screen for
them. Agreed: build the labelled address book, mirror the default into
WooCommerce, and draw the missing screens to match the app's existing design
language (new tasks 3.7 and 3.8).

WooCommerce models exactly one billing and one shipping address per customer,
so the book is new storage: entries in `_fmp_app_addresses` user meta with the
default ID in its own meta key, so "exactly one default" is structurally true
rather than something every write re-asserts. Fields use WooCommerce's own
names so the mirror is a straight copy and Phase 6's checkout payload needs no
translation layer.

### Payload the Flutter client will consume
```json
{ "user": { "id": 8, "email": "…", "username": "…", "first_name": "…",
            "last_name": "…", "display_name": "…", "phone": "…",
            "avatar_url": "…" },
  "addresses": [
    { "id": "11635e347477", "label": "Home", "is_default": true,
      "first_name": "…", "last_name": "…", "company": "",
      "address_1": "6391 Elgin St.", "address_2": "Apt 4B",
      "city": "Celina", "state": "DE", "postcode": "10299",
      "country": "US", "phone": "…",
      "locality": "Celina, Delaware 10299" } ] }
```

`locality` is pre-rendered server-side because only the server can resolve
`DE` → `Delaware`. `PUT` is partial; `addresses`, when present, replaces the
whole book.

### What the live run caught
Two real bugs, both fixed before the PR:

1. **Saving an address silently rewrote the account's contact phone.** The
   mirror was copying the address phone into `billing_phone`, which is also
   where `/me` reads `user.phone` from. Postal fields now come from the
   address, the contact phone stays owned by the profile, and
   `shipping_phone` takes the address's.
2. **`display_name` would not follow a rename.** The "was this generated?"
   check held a `WP_User` snapshot, but that object's magic getters read
   through the user meta cache that `wp_update_user()` refreshes — so the
   "before" values came back as the *new* ones. Snapshotted as plain strings
   instead.

### Verified against the running dev site
Empty book; two addresses with the design's own data; state accepted as both
`DE` and `Delaware`; per-country required fields for US/GB/AE/BD; invalid
state, postcode and country each rejected with the offending `field` and
`index`; the 20-address cap; partial `PUT` leaving the book intact; IDs stable
across an edit; default switching re-mirroring to WooCommerce; deletion by
omission promoting a new default; emptying the book; profile phone surviving an
address save; all three `display_name` cases; two customers unable to see or
affect each other's book; and cookie-authenticated admin requests to `wp/v2`
and the staff `fmp/v1` routes still returning 200.

### Gaps recorded, not fixed
Changing the account email or password. With password reset from 3.1 that is
now a cluster of three missing account-security flows, recommended as task 3.9
in `PLAN.md`.

## Task 3.1 — Customer auth endpoints (plugin)
Branch: `mobile-app` on `radiustheme/food-menu-pro`, PR #6. Nothing in this
repo changes except these docs.

Opens Phase 3. `fmp/v1/app/*` is now a real namespace with a bearer layer
underneath it, which 3.2 (profile) and 3.5 (wishlist) build on directly.

### What shipped
Four routes, all public by permission and gated on rate limiting and transport
instead:

| Route | Limit |
|---|---|
| `POST /fmp/v1/app/auth/register` | 5/hour per IP |
| `POST /fmp/v1/app/auth/login` | 20/15min per IP, 15/15min per account |
| `POST /fmp/v1/app/auth/refresh` | 60/5min per IP |
| `POST /fmp/v1/app/auth/logout` | idempotent, `all_devices` option |

- `AppAuthentication` filters `determine_current_user`, so a bearer token makes
  capability checks, WooCommerce customer sessions and `get_current_user_id()`
  behave as they do for a logged-in browser. This is the piece that unblocks
  every later authenticated route. A cookie session still wins, so the plugin's
  React dashboards are untouched.
- `AppTokens` mints opaque `fmpa_{user_id}_{session_id}_{secret}` tokens and
  stores only HMAC-SHA256 hashes of the secrets in `_fmp_app_sessions` user
  meta. Refresh rotates the pair and detects reuse: replaying a spent refresh
  token revokes the session.
- `AppRateLimit` holds fixed-window counters in transients, keyed on
  `REMOTE_ADDR`.
- `AppApiFns` carries the shared user payload, the HTTPS check and the
  `no-store` header, ready for 3.2 and 3.5.

### Response shape the Flutter client will consume
```json
{ "token_type": "Bearer", "access_token": "fmpa_…", "expires_in": 3600,
  "refresh_token": "fmpa_…", "refresh_expires_in": 2592000,
  "user": { "id": 8, "email": "…", "username": "…", "first_name": "…",
            "last_name": "…", "display_name": "…", "phone": "…",
            "avatar_url": "…" } }
```

### Verified against the running dev site
Register returning 201 with the `customer` role and the phone in
`billing_phone`; login by email; a bearer token resolving `wp/v2/users/me`;
rotation issuing a new pair and killing the old access token; replay of a spent
refresh token revoking the session and both rotated tokens; single-session and
all-devices logout; logout idempotent on an already-dead token; the 10-session
cap evicting oldest-first; an expired access token rejected while its refresh
token still recovers the session; both login buckets and the register bucket
tripping at their stated thresholds; `no-store` on every token response;
registration refused when the WooCommerce setting is off; a non-`fmpa_` bearer
token left unclaimed; and cookie-authenticated admin requests to both `wp/v2`
and the staff `fmp/v1` routes still returning 200.

### Gaps recorded, not fixed
Password reset, email verification and social sign-in are outside 3.1 as
planned — see the open dependency in `PLAN.md`. PHPCS could not be run: the
plugin's `composer cs` needs a `phpcs` binary that is not installed, and
`vendor/` holds only the autoloader.

## Task 2.7 — Ingredients and nutrition (plugin + app)
Branches: `mobile-app` on `radiustheme/food-menu-pro` (merged as #5), and
`feat/dish-food-data` here.

Completes Phase 2. The blocker from task 2.4 is gone.

### Plugin side — food-menu-pro#5
- `PostTypesController::taxonomies()` honours an optional `object_types` key,
  **merged with** `food-menu` rather than replacing it, so no site can lose an
  association. Ingredient, nutrition and unit gain `product` in
  online-ordering mode, following the free plugin's `food-location` pattern.
  `food-menu-tag` deliberately left alone — products have `product_tag`.
- A **separate, self-contained** metabox writes the fields on products.
  `Admin\Metabox\PostMeta` was not touched: its save is guarded by
  `TLPFoodMenu()->post_type !== $post->post_type`, and relaxing that guard
  would run the whole `singleFoodMetaFields()` loop on every product save.
- The save requires **its own nonce to be present**, so a programmatic
  `$product->save()` or a REST update cannot look like an empty form and wipe
  the rows. Verified against all three paths.
- Storage is byte-identical to the post type's, so
  `FnsPro::get_fm_ingredient_list()` keeps working unchanged.
- Exposed through `woocommerce_store_api_register_endpoint_data` on the
  product schema, under the existing `food-menu-pro` namespace.

### App side
- `FoodDataRow` parses the extension block, tolerating every level being
  absent — a site on an older plugin simply shows no sections.
- Rows with an empty name are dropped rather than rendered as a blank line,
  and a row with no amount still renders its name, because the amount is
  optional in the admin.
- `FoodDataSection` renders a labelled list rather than a table: a two-column
  table collapses badly once an ingredient name wraps.
- Added `NSAllowsLocalNetworking` to the iOS `Info.plist`. iOS blocks
  cleartext HTTP, so the app could not reach an HTTP dev or staging site at
  all. Scoped to local-network addresses, so production still requires HTTPS.
  **Android has no equivalent yet** and will need one before it can reach an
  HTTP dev site.

### Found by running the app on a simulator
Ran the app on an iPhone 17 Pro simulator against the dev site — the first
time it has been run rather than only tested. Two things only visible that
way:

- **The dish screen was showing the bottom tab bar.** The design shows it on
  home, menu, cart, orders, account and wishlist only
  (`showTabs=['home','menu','cart','orders','account','wish'].includes(sc)`),
  not on a dish, which is full-screen with its own close button. The route was
  nested inside the shell in task 2.3; it is now top-level and pushed, so it
  covers the bar and pops back. Checkout, order received and order tracking
  belong there too. Two tests lock it.
- iOS blocked the dev site outright until `NSAllowsLocalNetworking` was added,
  so the app could not have reached any HTTP backend at all.

158 tests pass, `flutter analyze` clean.

## Task 2.6 — Category suggestions on an empty search
Branch `feat/search-suggestions`

Closes Phase 2, apart from blocked task 2.7.

- `suggestCategories()` is a pure function in `features/menu/domain`, so the
  matching rules are testable without a widget. Matched against the categories
  **already loaded for the chip row**, so a dead-end search costs no extra
  request.
- Handles singular/plural **both ways** — "burger" finds Burgers, "pizzas"
  finds Pizza — and whole words inside longer names, so "course" finds Main
  Course. Ranked, so an exact match beats a partial one.
- **It relates words; it does not guess at synonyms.** "italian" does not find
  Pizza and should not — a wrong suggestion is worse than none, because it
  sends the customer somewhere they did not ask for.
- A substring-only match needs **four characters or more**. Three is
  coincidence ("ink" inside Drinks); four is usually intent.
- Tapping a suggestion clears the **search field's text** as well as the
  query. Leaving "pizza" in the box while showing the Pizza category reads as
  the search having worked.
- `browseCategory()` sets the category and clears the search in one state
  change, so the list is not rebuilt twice.

One test correction worth recording: my first expectation said a four-letter
substring should not match, which contradicted the threshold rule I had just
written. The rule is the sensible one, so the test now documents it instead.

149 tests pass, `flutter analyze` clean.

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
