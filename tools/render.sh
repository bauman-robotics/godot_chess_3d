#!/usr/bin/env bash
# Сборка ролика. Godot 4.6.2 + ffmpeg.
#
#   ./tools/render.sh preview            # 1280x720, Compatibility  (~10 мин)
#   ./tools/render.sh final              # 1920x1080, Forward+     (~2 ч)
#   ./tools/render.sh stills 20 115 160  # стоп-кадры в render/stills/
#   ./tools/render.sh mux voice=vo/      # подложить озвучку без перерендера
#
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$PWD"
GODOT="$ROOT/Godot_v4.6.2-stable_linux.x86_64"
PROJ="$ROOT/godot"
RENDER="$ROOT/render"
export XDG_DATA_HOME="$ROOT/.tmp/data"
export XDG_CONFIG_HOME="$ROOT/.tmp/config"
export XDG_CACHE_HOME="$ROOT/.tmp/cache"
mkdir -p "$RENDER" "$RENDER/stills" .tmp/data .tmp/config .tmp/cache

cmd="${1:-preview}"
shift || true

set_resolution() { # $1=width $2=height $3=method
  cp "$PROJ/project.godot" "$PROJ/project.godot.bak"
  sed -i "s/^window\/size\/viewport_width=.*/window\/size\/viewport_width=$1/;
          s/^window\/size\/viewport_height=.*/window\/size\/viewport_height=$2/;
          s/^renderer\/rendering_method=.*/renderer\/rendering_method=\"$3\"/" "$PROJ/project.godot"
  trap 'mv -f "$PROJ/project.godot.bak" "$PROJ/project.godot"' EXIT
}

to_mp4() { # $1=in.avi $2=out.mp4 $3=crf
  ffmpeg -v error -y -i "$1" \
    -c:v libx264 -preset slow -crf "${3:-16}" -pix_fmt yuv420p \
    -movflags +faststart -an "$2"
  ffprobe -v error -show_entries format=duration,size -show_entries stream=width,height,r_frame_rate \
    -of default=nw=1 "$2"
}

case "$cmd" in
  preview)
    set_resolution 1280 720 gl_compatibility
    "$GODOT" --path "$PROJ" --write-movie "$RENDER/preview.avi" --fixed-fps 30 --rendering-method gl_compatibility
    to_mp4 "$RENDER/preview.avi" "$RENDER/preview_720p.mp4" 20
    ;;
  final)
    set_resolution 1920 1080 forward_plus
    "$GODOT" --path "$PROJ" --write-movie "$RENDER/final.avi" --fixed-fps 30
    to_mp4 "$RENDER/final.avi" "$RENDER/chess_11_moves_1080p.mp4" 15
    ;;
  stills)
    set_resolution 1920 1080 forward_plus
    for t in "$@"; do
      "$GODOT" --path "$PROJ" --write-movie "$RENDER/stills/s_$t.avi" --fixed-fps 30 -- --frames=3 --start="$t" >/dev/null 2>&1 || true
      ffmpeg -v error -y -i "$RENDER/stills/s_$t.avi" -vf "select=eq(n\,1)" -vframes 1 "$RENDER/stills/still_$t.png"
      rm -f "$RENDER/stills/s_$t.avi"
    done
    ls "$RENDER/stills"/*.png
    ;;
  mux)
    # mux voice=vo/  (файлы 01.wav, 02.wav, … подкладываются по таймкодам из cues.json)
    VO=""
    for a in "$@"; do case "$a" in voice=*) VO="${a#voice=}" ;; esac; done
    IN="$RENDER/chess_11_moves_1080p.mp4"
    [ -f "$IN" ] || IN="$RENDER/preview_720p.mp4"
    if [ -z "$VO" ] || [ ! -d "$VO" ]; then
      echo "нужна папка с озвучкой: ./tools/render.sh mux voice=vo/"; exit 1
    fi
    python3 tools/mux_voice.py "$IN" "$VO" "$RENDER/with_voice.mp4"
    ;;
  *)
    echo "неизвестная команда: $cmd"; exit 1
    ;;
esac
