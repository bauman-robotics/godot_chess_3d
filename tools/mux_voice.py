#!/usr/bin/env python3
"""Подкладывает озвучку к готовому ролику без перерендера.

Ожидает папку с файлами 01.wav, 02.wav, … (номер = реплика в cues.json).
Каждый файл ставится на таймкод начала реплики; всё микшируется в одну дорожку.
"""
import json, pathlib, subprocess, sys

ROOT = pathlib.Path(__file__).resolve().parents[1]


def main() -> int:
    if len(sys.argv) < 4:
        print("usage: mux_voice.py <video> <voice_dir> <out>")
        return 1
    video, voice_dir, out = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2]), pathlib.Path(sys.argv[3])
    cues = json.loads((ROOT / "render" / "cues.json").read_text())
    caps = {c["i"]: c for c in cues["captions"]}

    inputs, filters, labels = ["-i", str(video)], [], []
    idx = 1
    for wav in sorted(voice_dir.glob("*.wav")):
        try:
            n = int(wav.stem)
        except ValueError:
            continue
        cap = caps.get(n)
        if not cap:
            print(f"пропуск {wav.name}: нет реплики #{n}")
            continue
        delay = int(round(cap["start"] * 1000))
        inputs += ["-i", str(wav)]
        filters.append(f"[{idx}:a]adelay={delay}|{delay},volume=1.0[a{idx}]")
        labels.append(f"[a{idx}]")
        idx += 1

    if not labels:
        print("не найдено ни одного файла озвучки")
        return 1

    graph = ";".join(filters) + ";" + "".join(labels) + \
        f"amix=inputs={len(labels)}:normalize=0:dropout_transition=0[aout]"
    cmd = ["ffmpeg", "-v", "error", "-y", *inputs,
           "-filter_complex", graph, "-map", "0:v", "-map", "[aout]",
           "-c:v", "copy", "-c:a", "aac", "-b:a", "192k",
           "-movflags", "+faststart", str(out)]
    subprocess.run(cmd, check=True)
    print("готово:", out)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
