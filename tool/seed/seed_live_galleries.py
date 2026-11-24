#!/usr/bin/env python3
"""Task 15.2 — give the live demo's dishes real photos and a gallery.

Idempotent twice over: a photo already in the live library is matched by
filename and never uploaded again, and a product whose gallery is already
what the plan says is left untouched.

Run with WP_USER / WP_PASS in the environment.
"""
import json, mimetypes, os, sys, urllib.error, urllib.request

import live_session as s

LOCAL_UPLOADS = os.path.expanduser('~/dev/wp/foodmenu-dev/wp-content/uploads')

# live product id -> the photos it should carry, first one featured.
# A name in quotes is a file from the local demo; a bare int is a photo the
# live site already has, kept because nothing local is closer.
PLAN = {
    37: ['build-your-pizza.jpg', 'margherita.jpg', 'pepperoni.jpg', 'quattro-formaggi.jpg'],
    36: ['sold-out-special.jpg', 'loaded-fries.jpg', 'halloumi-fries.jpg'],
    35: ['fresh-lemonade.jpg', 'mango-lassi.jpg', 'iced-latte.jpg'],
    34: ['iced-latte.jpg', 'espresso.jpg', 'fresh-lemonade.jpg'],
    33: ['chocolate-fondant.jpg', 'tiramisu.jpg', 'new-york-cheesecake.jpg'],
    32: ['lamb-biryani.jpg', 'midnight-ramen.jpg', 'mushroom-risotto.jpg'],
    31: ['wagyu-tasting-menu.jpg', 'chef-s-slow-braised-short-rib-with-truffle-mash-and-winter-g.jpg', 'grilled-salmon.jpg'],
    30: [20, 'loaded-fries.jpg', 'halloumi-fries.jpg'],
    29: [16, 'loaded-fries.jpg', 'halloumi-fries.jpg'],
    28: ['classic-cheeseburger.jpg', 'double-smash.jpg', 'loaded-fries.jpg'],
    27: ['crispy-chicken-burger.jpg', 'chicken-wings.jpg', 'loaded-fries.jpg'],
    26: ['pepperoni.jpg', 'margherita.jpg', 'quattro-formaggi.jpg'],
    25: ['margherita.jpg', 'quattro-formaggi.jpg', 'pepperoni.jpg'],
    24: [19, 'seasonal-soup.jpg', 'halloumi-fries.jpg'],
    23: ['chicken-wings.jpg', 'loaded-fries.jpg', 'halloumi-fries.jpg'],
    22: [17, 'chicken-wings.jpg', 'loaded-fries.jpg'],
}


def find_local(name):
    for root, _, files in os.walk(LOCAL_UPLOADS):
        if name in files:
            return os.path.join(root, name)
    raise SystemExit('local photo not found: %s' % name)


def live_library():
    """filename -> attachment id, for what the live site already holds."""
    st, media = s.api('/wp/v2/media?per_page=100&_fields=id,source_url')
    if st != 200:
        raise SystemExit('could not read the media library: %s %s' % (st, media))
    return {m['source_url'].rsplit('/', 1)[-1]: m['id'] for m in media}


def upload(path):
    name = os.path.basename(path)
    boundary = '----fmp152seed'
    head = ('--%s\r\nContent-Disposition: form-data; name="file"; filename="%s"'
            '\r\nContent-Type: %s\r\n\r\n'
            % (boundary, name, mimetypes.guess_type(name)[0] or 'image/jpeg'))
    body = head.encode() + open(path, 'rb').read() + ('\r\n--%s--\r\n' % boundary).encode()
    req = urllib.request.Request(
        s.BASE + '/wp-json/wp/v2/media', data=body, method='POST',
        headers={'X-WP-Nonce': s.NONCE, 'User-Agent': s.UA,
                 'Content-Type': 'multipart/form-data; boundary=%s' % boundary})
    with s.opener.open(req, timeout=180) as r:
        return json.loads(r.read())['id']


def main():
    s.login()
    library = live_library()
    uploaded = 0

    wanted = {n for photos in PLAN.values() for n in photos if isinstance(n, str)}
    for name in sorted(wanted):
        if name in library:
            continue
        library[name] = upload(find_local(name))
        uploaded += 1
        print('uploaded %-62s -> %s' % (name, library[name]))

    changed = 0
    for product, photos in sorted(PLAN.items()):
        ids = [n if isinstance(n, int) else library[n] for n in photos]
        st, current = s.api('/wc/v3/products/%d' % product)
        if st != 200:
            print('%-4s could not be read: %s' % (product, current))
            continue
        if [i['id'] for i in (current.get('images') or [])] == ids:
            print('%-4s %-22s already seeded' % (product, current['name'][:22]))
            continue
        st, after = s.api('/wc/v3/products/%d' % product,
                          {'images': [{'id': i} for i in ids]}, method='PUT')
        ok = st == 200 and [i['id'] for i in after.get('images', [])] == ids
        print('%-4s %-22s %s %s' % (product, current['name'][:22],
                                    'set' if ok else 'FAILED %s' % st, ids))
        changed += 1 if ok else 0

    print('\nuploaded %d photo(s), changed %d product(s)' % (uploaded, changed))


if __name__ == '__main__':
    main()
