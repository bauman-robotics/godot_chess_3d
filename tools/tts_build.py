#!/usr/bin/env python3
"""Yandex SpeechKit → озвучка по репликам.

Берёт реплики из render/cues.json, нормализует шахматную нотацию под речь,
синтезирует каждую строку, подгоняет скорость под окно титра и складывает
в vo/lines/. Рядом пишет vo/lines.json с таймингами и фактическими длительностями.

    python3 tools/tts_build.py --voice filipp [--speed 0.96] [--only 1,2,3]
"""
import argparse, json, os, pathlib, re, subprocess, sys, time, urllib.parse, urllib.request

ROOT = pathlib.Path(__file__).resolve().parents[1]
VO = ROOT / "vo"
LINES = VO / "lines"
ENV = ROOT / "tts" / ".secrets" / "tts.env"

LETTERS = {"a": "а", "b": "бэ", "c": "цэ", "d": "дэ", "e": "е", "f": "эф", "g": "же", "h": "аш"}
DIGITS = {"1": "один", "2": "два", "3": "три", "4": "четыре",
          "5": "пять", "6": "шесть", "7": "семь", "8": "восемь"}



def load_env() -> dict:
    env = {}
    for line in ENV.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, v = line.split("=", 1)
        env[k.strip()] = v.strip()
    return env


def normalize(text: str) -> str:
    # квадраты вида e4 / h2 → «е четыре»
    def sq(m):
        f, r = m.group(1), m.group(2)
        return f"{LETTERS[f]} {DIGITS[r]}"

    text = re.sub(r"\b([a-h])([1-8])\b", sq, text)
    # одиночные файлы: «линию h» → «линию аш»
    text = re.sub(r"\b([a-h])\b", lambda m: LETTERS[m.group(1)], text)
    text = text.replace("O-O", "рокировка")
    text = text.replace("«", " ").replace("»", " ")
    text = re.sub(r"\s+", " ", text).strip()
    return text


def synth(text: str, voice: str, speed: float, out: pathlib.Path, env: dict) -> None:
    params = {
        "text": text,
        "lang": "ru-RU",
        "voice": voice,
        "format": "mp3",
        "sampleRateHertz": "48000",
        "speed": f"{speed:.2f}",
        "folderId": env["YANDEX_FOLDER_ID"],
    }
    data = urllib.parse.urlencode(params).encode()
    req = urllib.request.Request(
        "https://tts.api.cloud.yandex.net/speech/v1/tts:synthesize", data=data,
        headers={"Authorization": "Api-Key " + env["YANDEX_API_KEY"]})
    for attempt in range(4):
        try:
            with urllib.request.urlopen(req, timeout=90) as r:
                body = r.read()
            break
        except Exception as e:
            if attempt == 3:
                raise
            time.sleep(2.0 * (attempt + 1))
    if len(body) < 2000:
        raise RuntimeError(f"короткий ответ TTS: {body[:200]!r}")
    out.write_bytes(body)


def duration(path: pathlib.Path) -> float:
    out = subprocess.check_output(["ffprobe", "-v", "error", "-show_entries",
                                   "format=duration", "-of", "csv=p=0", str(path)])
    return float(out.strip())


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--voice", default="filipp")
    ap.add_argument("--speed", type=float, default=0.96)
    ap.add_argument("--only", default="")
    ap.add_argument("--cues", default="render/cues.json")
    ap.add_argument("--dir", default="vo")
    args = ap.parse_args()

    env = load_env()
    cues = json.loads((ROOT / args.cues).read_text())
    out_dir = ROOT / args.dir
    lines_dir = out_dir / "lines"
    lines_dir.mkdir(parents=True, exist_ok=True)

    only = {int(x) for x in args.only.split(",") if x.strip()} if args.only else None
    result, overflow = [], []
    prev_end = 0.0
    for cap in cues["captions"]:
        i = cap["i"]
        if only and i not in only:
            continue
        # когда реально начинать: не раньше окна, но и не наезжая на предыдущую фразу
        at = max(cap["start"], prev_end + 0.28)
        end = max(cap["end"], at + 1.6)
        avail = end - at
        text = normalize(cap["text"])
        out = lines_dir / f"{i:02d}.mp3"
        speed = args.speed
        synth(text, args.voice, speed, out, env)
        dur = duration(out)
        # не влезли — аккуратно ускоряемся, но текст не режем
        if dur > avail - 0.15 and speed < 1.32:
            speed = min(1.32, speed * dur / (avail - 0.15))
            synth(text, args.voice, speed, out, env)
            dur = duration(out)
        at_eff = at
        if dur > avail - 0.05:
            # сдвигаем начало назад, если впереди было окно
            at_eff = max(prev_end + 0.28, end - dur - 0.05)
        prev_end = at_eff + dur
        rec = {"i": i, "at": round(at_eff, 3), "caption_start": cap["start"],
               "end": cap["end"], "window": round(cap["end"] - cap["start"], 2),
               "dur": round(dur, 3), "speed": round(speed, 2),
               "text": cap["text"], "tts": text, "file": str(out.relative_to(ROOT))}
        result.append(rec)
        flag = "" if at_eff + dur <= cap["end"] + 0.05 else "  ← выходит за окно"
        if flag:
            overflow.append(rec)
        print(f"{i:02d}  {at_eff:6.2f} +{dur:5.2f}s / окно до {cap['end']:6.2f}  x{speed:4.2f}  {text[:46]}{flag}")

    payload = {"voice": args.voice, "speed": args.speed, "lines": result}
    if only:
        old = json.loads((out_dir / "lines.json").read_text()) if (out_dir / "lines.json").exists() else {"lines": []}
        merged = {l["i"]: l for l in old.get("lines", [])}
        for l in result:
            merged[l["i"]] = l
        payload["lines"] = [merged[k] for k in sorted(merged)]
    (out_dir / "lines.json").write_text(json.dumps(payload, ensure_ascii=False, indent=1))
    print(f"\nсгенерировано {len(result)} реплик, выходит за окно: {len(overflow)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
