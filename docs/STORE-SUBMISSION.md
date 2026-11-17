# Store submission — the privacy answers

For whoever fills in **App Store Connect → App Privacy** and **Play Console →
Data safety** before an upload. Everything here was read off the code on
2026-11-17 (task 14.4); if the app grows a field, this is the file to correct.

Keep it with the app, not with a store: the answers describe what the *app*
does, and every store that ships a build gives the same ones.

---

## The short version

The app collects what a restaurant needs to take an order from a named
customer, sends it to that restaurant's own WordPress site, and does nothing
else with it. **No analytics, no crash reporting, no advertising, no
third-party SDK that collects anything.** `pubspec.yaml` is the evidence: the
only network dependency is `dio`, talking to one host.

Nothing is used for **tracking** in Apple's sense — the app never links data to
third-party data for advertising, and never shares with a data broker.

---

## Data collected, as the consoles classify it

| What | Apple category | Play category | Linked to identity | Why |
|---|---|---|---|---|
| Name | Contact Info → Name | Personal info → Name | Yes | Goes on the order |
| Email | Contact Info → Email Address | Personal info → Email address | Yes | Account, and the order confirmation |
| Phone | Contact Info → Phone Number | Personal info → Phone number | Yes | The driver or the kitchen calls it |
| Delivery address | Contact Info → Physical Address | Personal info → Address | Yes | Where the order goes |
| Order history | Purchases → Purchase History | Financial info → Purchase history | Yes | "My orders", reorder, tracking |
| Wishlist | User Content → Other | App activity → Other user-generated content | Yes | The customer's own favourites |
| Dish reviews | User Content → Customer Support / Other | App activity → Other UGC | Yes | Written by the customer, shown publicly on the dish |
| "iPhone" / "Android" | *Not collected* | *Not collected* | — | A session label on the account's device list. **Not an identifier** — the literal string is one of two words (`auth_controller.dart`) |

**Payment details: none.** v1 takes cash on delivery, bank transfer and cheque
(Phase 12), none of which collect anything at checkout. The app has no card
field and no payment SDK. If a card gateway is ever added, this table changes
and so does the console answer.

**Location: not collected.** The app never asks for device location. A delivery
address is typed or chosen from the account's saved list.

**No data is collected from children**, and the app has no age gate; it is a
restaurant ordering app.

---

## Account deletion — both consoles check this

- **In-app:** Account → Delete account (task 14.1). Asks for the password,
  confirms, then deletes.
- **What it does:** removes the WordPress user and runs WordPress's own
  registered erasers, so the customer's saved addresses, wishlist, payment
  tokens and dish reviews go with it.
- **Orders are kept** as the store's accounting records; whether they keep the
  customer's name and address follows the store's own
  `woocommerce_erasure_request_removes_order_data` setting, and the app tells
  the customer which way it went.
- **Play's external URL field:** Play asks for a web page where deletion can
  also be requested. Each store's own My Account page is the honest answer, and
  it is **per store**, so it cannot be hard-coded here — see Open questions.

---

## Permissions

| Platform | Declared | Why |
|---|---|---|
| Android | `INTERNET` | The app is a client for a WordPress site |
| Android | `<queries>` for `http`/`https` VIEW intents | So the privacy policy row can find a browser on API 30+ (task 14.4) |
| iOS | `NSLocalNetworkUsageDescription` | Development against a LAN dev site |

**Nothing else.** No camera, no location, no contacts, no notifications yet —
push is task 10.4 and will add one, on both platforms, when it lands.

Task 13.1 audits this list against the shipped build; this file says what it
*should* be.

---

## Privacy policy link

The app shows the **store's own** published policy on the account screen, read
from `GET /app/config` (task 14.4).

**A store that has not published one shows no row**, because WordPress creates
that page as a draft and most installs never publish it. Both consoles require
a reachable policy URL, so:

> **Before submitting a build for any store: check that store has a published
> privacy policy page.** `curl .../wp-json/fmp/v1/app/config` and look at
> `privacy_policy_url`. Empty means the console requirement is not met.

---

## Open questions for whoever submits

1. **Who is the data controller?** The customer's data lives on the
   restaurant's WordPress site, not on any server the app publisher runs — but
   the console asks the *publisher* what the app collects, and the answers
   above are written from the app's point of view. A lawyer should decide
   whether the listing also needs the publisher's own policy alongside each
   store's.
2. **One listing or one per store?** The answers here hold either way, but
   Play's deletion URL and the policy link do not: both are per store. This is
   the white-label question (vendor spec C9) and it has not been decided — see
   `PLAN.md` open dependencies.
