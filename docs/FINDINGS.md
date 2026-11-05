# Findings

Decisions, gotchas and anything learned that is not obvious from the code.

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
