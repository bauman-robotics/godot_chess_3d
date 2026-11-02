#!/usr/bin/env python3
"""Единый источник правды — godot/scripts/timeline.gd.
Достаёт реплики и ходы, пишет SRT, cues.json и storyboard.md."""
import json, re, pathlib

ROOT = pathlib.Path(__file__).resolve().parents[1]
TL = ROOT / "godot" / "scripts" / "timeline.gd"
OUT_SUB = ROOT / "render" / "subs"
OUT_DOC = ROOT / "docs"
OUT_SUB.mkdir(parents=True, exist_ok=True)


def grab(name: str) -> str:
    src = TL.read_text()
    i = src.index(f"const {name} := [")
    depth = 0
    for j in range(i, len(src)):
        if src[j] == "[":
            depth += 1
        elif src[j] == "]":
            depth -= 1
            if depth == 0:
                return src[i:j + 1]
    raise ValueError(name)


def parse_triples(block: str):
    rows = []
    for m in re.finditer(r'\[\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*"((?:[^"\\]|\\.)*)"\s*\]', block):
        rows.append((float(m.group(1)), float(m.group(2)), m.group(3)))
    return rows


def parse_pairs(block: str):
    rows = []
    for m in re.finditer(r'\[\s*([\d.]+)\s*,\s*"((?:[^"\\]|\\.)*)"\s*\]', block):
        rows.append((float(m.group(1)), m.group(2)))
    return rows


def ts(t: float) -> str:
    h = int(t // 3600)
    m = int((t % 3600) // 60)
    s = int(t % 60)
    ms = int(round((t - int(t)) * 1000))
    if ms == 1000:
        ms, s = 0, s + 1
    return f"{h:02d}:{m:02d}:{s:02d},{ms:03d}"


def main() -> None:
    caps = parse_triples(grab("CAPTIONS"))
    tags = parse_pairs(grab("MOVE_TAGS"))

    srt = []
    for i, (t0, t1, text) in enumerate(caps, start=1):
        srt.append(f"{i}\n{ts(t0)} --> {ts(t1)}\n{text}\n")
    (OUT_SUB / "subtitles.srt").write_text("\n".join(srt))

    cues = {
        "fps": 30,
        "duration": 180.0,
        "captions": [
            {"i": i, "start": t0, "end": t1, "text": text}
            for i, (t0, t1, text) in enumerate(caps, start=1)
        ],
        "moves": [{"t": t, "san": s} for t, s in tags if s],
        "beats": [
            {"t": 0.0, "kind": "cold_open"},
            {"t": 10.6, "kind": "title"},
            {"t": 158.0, "kind": "mate_move"},
            {"t": 160.6, "kind": "mate_land"},
            {"t": 170.4, "kind": "end_card"},
        ],
    }
    (ROOT / "render" / "cues.json").write_text(json.dumps(cues, ensure_ascii=False, indent=1))

    # storyboard.md
    shots = [
        ("S1", 0.0, 9.0, "Облёт доски сверху", "тёмный зал, свет проявляет доску"),
        ("S2", 9.0, 18.0, "Кран вверх", "титул «11 ХОДОВ»"),
        ("S3", 18.0, 26.0, "Общий план", "рейтинги, часы, eval 0.0"),
        ("S4", 26.0, 34.0, "Крупный, слежение за e2", "1. e4"),
        ("S5", 34.0, 42.0, "Общий план", "1… c6"),
        ("S6", 42.0, 52.0, "Слежение за конём g1", "2. Nf3, 2… d5"),
        ("S7", 52.0, 64.0, "Слежение за пешкой e", "3. exd5 cxd5 — первое взятие"),
        ("S8", 64.0, 74.0, "Низкий боковой", "4. Be2"),
        ("S9", 74.0, 84.0, "Слежение за королём", "5. O-O — король уходит на g1"),
        ("S10", 84.0, 94.0, "Низкий боковой (другая сторона)", "6. d4 Nc6"),
        ("S11", 94.0, 102.0, "Общий план", "7. c3 e6"),
        ("S12", 102.0, 112.0, "Крупный, слежение за конём", "8. Nh4 Bg6"),
        ("S13", 112.0, 126.0, "Проводка вдоль линии h", "9. Nxg6 hxg6 — линия h открыта"),
        ("S14", 126.0, 136.0, "Низкий боковой", "10. Nd2"),
        ("S15", 136.0, 146.0, "Наезд на ферзя", "10… Qd6 — диагональ работает"),
        ("S16", 146.0, 156.0, "Наезд", "11. b3 — «форточка»"),
        ("S17", 156.0, 170.0, "Слежение за ферзём + отъезд", "11… Qxh2# — замедление, падение короля"),
        ("S18", 170.0, 180.0, "Верхний план", "0—1, финальная плашка"),
    ]
    lines = ["# Раскадровка", "",
             "Сгенерировано из `godot/scripts/timeline.gd`. Длительность 3:00, 30 fps, 5400 кадров.", "",
             "| # | Вход | Выход | План | Что происходит |", "|---|---|---|---|---|"]
    for sid, t0, t1, kind, what in shots:
        lines.append(f"| {sid} | {ts(t0)[3:8].replace(',', '.')} | {ts(t1)[3:8].replace(',', '.')} | {kind} | {what} |")
    lines += ["", "## Реплики", "", "| Вход | Выход | Текст |", "|---|---|---|"]
    for t0, t1, text in caps:
        lines.append(f"| {ts(t0)[3:8].replace(',', '.')} | {ts(t1)[3:8].replace(',', '.')} | {text} |")
    (OUT_DOC / "storyboard.md").write_text("\n".join(lines) + "\n")

    print(f"SRT: {len(caps)} реплик")
    print(f"cues: {len(tags)} ходов")
    print("storyboard:", OUT_DOC / "storyboard.md")


if __name__ == "__main__":
    main()
