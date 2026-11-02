#!/usr/bin/env python3
"""Заливка видео на Vimeo через API (tus, чанками).

Токен берётся из VIMEO_ACCESS_TOKEN (окружение) или из файла:
   vimeo/.secrets/vimeo.env   либо   tts/.secrets/tts.env
Файлы .env в репозиторий не попадают (.gitignore).

Токен создаётся на https://developer.vimeo.com/apps → ваш app → Generate token.
Нужные scope: public, private, upload, edit.

    python3 tools/vimeo_upload.py --file render/chess_11_moves_1080p.mp4 \
        --name "11 ходов" --privacy unlisted
"""
import argparse, json, os, pathlib, re, sys, time, urllib.error, urllib.request

ROOT = pathlib.Path(__file__).resolve().parents[1]
API = "https://api.vimeo.com"
CHUNK = 16 * 1024 * 1024
ENV_CANDIDATES = [ROOT / "vimeo" / ".secrets" / "vimeo.env", ROOT / "tts" / ".secrets" / "tts.env"]


def read_env() -> dict:
    env = {}
    for path in ENV_CANDIDATES:
        if path.exists():
            for line in path.read_text().splitlines():
                line = line.strip()
                if line and not line.startswith("#") and "=" in line:
                    k, v = line.split("=", 1)
                    env.setdefault(k.strip(), v.strip())
    return env


def token() -> str:
    if os.environ.get("VIMEO_ACCESS_TOKEN"):
        return os.environ["VIMEO_ACCESS_TOKEN"].strip()
    t = read_env().get("VIMEO_ACCESS_TOKEN", "")
    if not t:
        sys.exit("нет VIMEO_ACCESS_TOKEN: положите его в vimeo/.secrets/vimeo.env "
                 "или tts/.secrets/tts.env строкой VIMEO_ACCESS_TOKEN=...")
    return t


def req(method: str, url: str, tok: str, body=None, headers=None, raw=False):
    h = {"Authorization": "Bearer " + tok, "Accept": "application/vnd.vimeo.*+json;version=3.4"}
    h.update(headers or {})
    data = None
    if body is not None:
        if isinstance(body, (dict, list)):
            data = json.dumps(body).encode()
            h["Content-Type"] = "application/json"
        else:
            data = body
            h.setdefault("Content-Type", "application/octet-stream")
    r = urllib.request.Request(url, data=data, headers=h, method=method)
    try:
        with urllib.request.urlopen(r, timeout=180) as resp:
            payload = resp.read()
            return resp.status, dict(resp.headers), payload if raw else json.loads(payload or b"{}")
    except urllib.error.HTTPError as e:
        msg = e.read().decode(errors="replace")[:500]
        if e.code == 401:
            sys.exit("401: токен не принят. Проверьте, что он скопирован целиком и не истёк.")
        if e.code == 403:
            sys.exit(f"403: не хватает прав у токена. Нужны scope: public, private, upload, edit.\n{msg}")
        sys.exit(f"{e.code} {e.reason}: {msg}")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--file", required=True)
    ap.add_argument("--name", default="11 ходов")
    ap.add_argument("--description", default="3D-ролик по шахматной партии kCpBTaXQ, собранный в Godot 4.6")
    ap.add_argument("--privacy", default="unlisted", choices=["unlisted", "anybody", "disable", "password"])
    ap.add_argument("--password", default="")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    path = (ROOT / args.file).resolve()
    if not path.exists():
        sys.exit(f"нет файла: {path}")
    size = path.stat().st_size
    print(f"файл: {path.name}  {size/1e6:.1f} MB")
    if args.dry_run:
        print("dry-run: запросы не отправлялись")
        return 0

    tok = token()

    privacy = {"view": args.privacy, "embed": "public", "download": False}
    if args.privacy == "password":
        privacy["password"] = args.password or sys.exit("для privacy=password нужен --password")
    body = {
        "upload": {"approach": "tus", "size": size},
        "name": args.name,
        "description": args.description,
        "privacy": privacy,
    }
    print("создаю ролик…")
    _, _, created = req("POST", f"{API}/me/videos", tok, body)
    uri = created["uri"]
    link = created.get("link") or f"https://vimeo.com{uri.replace('/videos/', '/')}"
    upload_link = created["upload"]["upload_link"]
    print(f"  uri={uri}")
    print(f"  страница (появится после обработки): {link}")

    offset = 0
    started = time.time()
    with path.open("rb") as f:
        while offset < size:
            chunk = f.read(CHUNK)
            _, headers, _ = req("PATCH", upload_link, tok, chunk, {
                "Tus-Resumable": "1.0.0",
                "Upload-Offset": str(offset),
                "Content-Type": "application/offset+octet-stream",
            }, raw=True)
            new_offset = int(headers.get("Upload-Offset", offset + len(chunk)))
            if new_offset <= offset:
                sys.exit("сервер не сдвинул Upload-Offset — прерываю")
            offset = new_offset
            pct = 100.0 * offset / size
            speed = offset / max(0.1, time.time() - started) / 1e6
            print(f"  {pct:5.1f}%  {offset/1e6:6.1f} MB  {speed:5.1f} MB/s", flush=True)

    print("загружено, ждём обработку…")
    deadline = time.time() + 900
    while time.time() < deadline:
        _, _, v = req("GET", f"{API}{uri}?fields=status,link,uri", tok)
        st = v.get("status")
        print(f"  status={st}")
        if st == "available":
            print(f"\nготово: {v.get('link') or link}")
            return 0
        if st in ("error", "uploading_error"):
            sys.exit(f"Vimeo вернул статус {st}")
        time.sleep(10)
    print(f"обработка затянулась, но файл загружен: {link}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
