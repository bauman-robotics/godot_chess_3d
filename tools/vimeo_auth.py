#!/usr/bin/env python3
"""OAuth-авторизация Vimeo без Personal access token.

1) Печатает ссылку, по которой владелец аккаунта нажимает «Allow»:
   python3 tools/vimeo_auth.py url --client-id 12345 --redirect-uri https://github.com/bauman-robotics/godot_chess_3d

2) Меняет полученный code на access token и кладёт его в vimeo/.secrets/vimeo.env:
   python3 tools/vimeo_auth.py exchange --client-id 12345 \
       --redirect-uri https://github.com/bauman-robotics/godot_chess_3d \
       --redirect-url "https://github.com/.../?code=XXXX&state=chess"

Client secret берётся из VIMEO_CLIENT_SECRET или VIMEO_ACCESS_TOKEN в vimeo/.secrets/vimeo.env.
"""
import argparse, base64, json, pathlib, re, sys, urllib.error, urllib.parse, urllib.request

ROOT = pathlib.Path(__file__).resolve().parents[1]
ENV = ROOT / "vimeo" / ".secrets" / "vimeo.env"
SCOPES = "public private upload edit"
STATE = "chess"


def read_env() -> dict:
    if not ENV.exists():
        return {}
    out = {}
    for line in ENV.read_text().splitlines():
        line = line.strip()
        if line and not line.startswith("#") and "=" in line:
            k, v = line.split("=", 1)
            out[k.strip()] = v.strip()
    return out


def secret() -> str:
    env = read_env()
    s = env.get("VIMEO_CLIENT_SECRET") or env.get("VIMEO_ACCESS_TOKEN", "")
    if not s:
        sys.exit("нет client secret: положите VIMEO_CLIENT_SECRET=... в vimeo/.secrets/vimeo.env")
    return s


def cmd_url(a) -> None:
    q = urllib.parse.urlencode({
        "response_type": "code",
        "client_id": a.client_id,
        "redirect_uri": a.redirect_uri,
        "scope": SCOPES,
        "state": STATE,
    })
    print("Откройте в браузере, нажмите «Allow/Authorize» и пришлите адрес, на который перекинет:\n")
    print(f"https://api.vimeo.com/oauth/authorize?{q}")


def cmd_exchange(a) -> None:
    m = re.search(r"[?&]code=([^&\s]+)", a.redirect_url)
    if not m:
        sys.exit("в присланном адресе нет параметра code=")
    code = urllib.parse.unquote(m.group(1))
    data = urllib.parse.urlencode({
        "grant_type": "authorization_code",
        "code": code,
        "redirect_uri": a.redirect_uri,
    }).encode()
    auth = base64.b64encode(f"{a.client_id}:{secret()}".encode()).decode()
    req = urllib.request.Request(
        "https://api.vimeo.com/oauth/access_token", data=data,
        headers={"Authorization": "Basic " + auth,
                 "Content-Type": "application/x-www-form-urlencoded"})
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            resp = json.loads(r.read())
    except urllib.error.HTTPError as e:
        sys.exit(f"{e.code}: {e.read().decode(errors='replace')[:400]}")
    tok = resp.get("access_token")
    if not tok:
        sys.exit(f"в ответе нет access_token: {resp}")
    env = read_env()
    env.pop("VIMEO_ACCESS_TOKEN", None)
    env["VIMEO_ACCESS_TOKEN"] = tok
    ENV.write_text("\n".join(f"{k}={v}" for k, v in env.items()) + "\n")
    print(f"access_token получен, длина {len(tok)}, записан в {ENV.relative_to(ROOT)}")
    print("scope:", resp.get("scope"))


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("cmd", choices=["url", "exchange"])
    ap.add_argument("--client-id", required=True)
    ap.add_argument("--redirect-uri", required=True)
    ap.add_argument("--redirect-url", default="")
    a = ap.parse_args()
    cmd_url(a) if a.cmd == "url" else cmd_exchange(a)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
