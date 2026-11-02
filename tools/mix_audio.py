#!/usr/bin/env python3
"""Сборка звука: голос по таймкодам + музыка с «дакингом» (sidechain).

    python3 tools/mix_audio.py \
        --video render/chess_11_moves_1080p.mp4 \
        --music "Классическая музыка из кинофильмов/02 - Г.Ф.Гендель - Сарабанда.mp3" \
        --music-start 0 --music-gain 0.22 --out render/demo_60s.mp4 --duration 60

Голос берётся из vo/lines.json (поле at). Музыка подрезается по длине ролика,
проседает под речью (sidechaincompress) и поднимается в паузах.
"""
import argparse, json, pathlib, subprocess

ROOT = pathlib.Path(__file__).resolve().parents[1]


def build_cmd(args, lines) -> list[str]:
    dur = args.duration
    vs = args.video_start
    cmd = ["ffmpeg", "-v", "error", "-y"]
    if vs > 0:
        cmd += ["-ss", f"{vs:.3f}"]
    cmd += ["-i", str(ROOT / args.video),
           "-f", "lavfi", "-t", f"{dur:.3f}", "-i", "anullsrc=r=48000:cl=stereo"]
    for l in lines:
        cmd += ["-i", str(ROOT / l["file"])]
    cmd += ["-i", str(ROOT / args.music)]

    chains, labels = [], []
    for k, l in enumerate(lines):
        idx = 2 + k
        ms = int(round((l["at"] - args.video_start) * 1000))
        chains.append(f"[{idx}:a]aresample=48000,aformat=sample_fmts=fltp:channel_layouts=stereo,"
                      f"volume={args.voice_gain},adelay={ms}|{ms}[v{k}]")
        labels.append(f"[v{k}]")
    # голосовая дорожка ровно длиной ролика: подмешиваем тишину
    chains.append("[1:a]" + "".join(labels) +
                  f"amix=inputs={len(labels) + 1}:normalize=0:dropout_transition=0[voice]")

    music_idx = 2 + len(lines)
    chains.append(f"[{music_idx}:a]aresample=48000,aformat=sample_fmts=fltp:channel_layouts=stereo,"
                  f"atrim=start={args.music_start:.3f},asetpts=N/SR/TB,"
                  f"apad=whole_dur={dur:.3f},atrim=0:{dur:.3f},"
                  f"volume={args.music_gain}[music]")
    chains.append("[voice]asplit=2[voice_mix][voice_key]")
    chains.append(f"[music][voice_key]sidechaincompress=threshold={args.threshold}:ratio={args.ratio}:"
                  f"attack=12:release=340:level_sc=1.0:makeup=1[duck]")
    chains.append("[voice_mix][duck]amix=inputs=2:normalize=0:dropout_transition=0,"
                  f"loudnorm=I={args.lufs}:TP=-1.5:LRA=11,"
                  "alimiter=limit=0.97:level=false[mix]")

    cmd += ["-filter_complex", ";".join(chains),
            "-map", "0:v:0", "-map", "[mix]",
            "-c:v", "copy", "-c:a", "aac", "-b:a", "256k",
            "-t", f"{dur:.3f}", "-movflags", "+faststart", str(ROOT / args.out)]
    return cmd


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--video", default="render/chess_11_moves_1080p.mp4")
    ap.add_argument("--music", required=True)
    ap.add_argument("--music-start", type=float, default=0.0)
    ap.add_argument("--music-gain", type=float, default=0.22)
    ap.add_argument("--voice-gain", type=float, default=1.0)
    ap.add_argument("--threshold", type=float, default=0.02)
    ap.add_argument("--ratio", type=float, default=6.0)
    ap.add_argument("--lufs", type=float, default=-16.0)
    ap.add_argument("--duration", type=float, default=180.0)
    ap.add_argument("--video-start", type=float, default=0.0)
    ap.add_argument("--out", required=True)
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    data = json.loads((ROOT / "vo" / "lines.json").read_text())
    hi = args.video_start + args.duration
    lines = sorted([l for l in data["lines"]
                    if args.video_start <= l["at"] < hi], key=lambda l: l["at"])

    cmd = build_cmd(args, lines)
    if args.dry_run:
        print(" ".join(cmd))
        return 0
    subprocess.run(cmd, check=True)
    print(f"готово: {args.out}  ({len(lines)} реплик)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
