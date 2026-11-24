"""Shared live-site session: wp-login.php cookie + rest-nonce."""
import json, os, urllib.error, urllib.parse, urllib.request
from http.cookiejar import CookieJar

BASE = "https://radiustheme.net/demos/food-menu"
_jar = CookieJar()
opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(_jar))
NONCE = None


UA = ("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/131.0 Safari/537.36")


def login():
    """wp-login.php refuses a bare POST with 403 — it wants the test cookie
    from a prior GET and a browser user agent. Both, then, before the post."""
    global NONCE
    opener.open(urllib.request.Request(
        BASE + "/wp-login.php", headers={"User-Agent": UA}), timeout=60).read()
    data = urllib.parse.urlencode({
        "log": os.environ["WP_USER"],
        "pwd": os.environ["WP_PASS"],
        "wp-submit": "Log In",
        "redirect_to": BASE + "/wp-admin/",
        "testcookie": "1",
    }).encode()
    req = urllib.request.Request(
        BASE + "/wp-login.php", data=data,
        headers={"Content-Type": "application/x-www-form-urlencoded",
                 "Referer": BASE + "/wp-login.php", "User-Agent": UA})
    opener.open(req, timeout=60).read()
    names = {c.name for c in _jar}
    if not any(n.startswith("wordpress_logged_in") for n in names):
        raise SystemExit("login failed; cookies: %s" % sorted(names))
    NONCE = opener.open(
        BASE + "/wp-admin/admin-ajax.php?action=rest-nonce", timeout=60
    ).read().decode().strip()
    return NONCE


def api(path, body=None, method=None):
    url = BASE + "/wp-json" + path
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method, headers={
        "X-WP-Nonce": NONCE, "Content-Type": "application/json",
        "Accept": "application/json", "User-Agent": UA})
    try:
        with opener.open(req, timeout=90) as r:
            return r.status, json.loads(r.read() or b"null")
    except urllib.error.HTTPError as e:
        raw = e.read()
        try:
            return e.code, json.loads(raw or b"null")
        except Exception:
            return e.code, {"raw": raw[:300].decode("utf8", "replace")}
