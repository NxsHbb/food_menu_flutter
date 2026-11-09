# Findings

Decisions, gotchas and anything learned that is not obvious from the code.

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
`/reports/valuation`, `/reports/waste-cost` etc. — and `/qr-codes` and
`/timed-products` are not registered at all. Enumerate
`?rest_route=/fmp/v1` on the running site rather than trusting the table.

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
shown up until the first release build in Phase 8.

### `com.foodmenu` is owned by one specific Apple team
Signing for a physical iPhone failed with *"The app identifier com.foodmenu
cannot be registered to your development team because it is not available"* on
team `FAAHP7377L`, and **succeeded on `M34L8S85ZF`**. A two-segment identifier
this generic is widely contested, so this is not a free choice: **device builds,
TestFlight and the App Store all require team `M34L8S85ZF`**, now set as
`DEVELOPMENT_TEAM` in the Xcode project. Anyone building on another account
will have to change the bundle ID, which has App Store consequences — worth
knowing before task 8.4.

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
