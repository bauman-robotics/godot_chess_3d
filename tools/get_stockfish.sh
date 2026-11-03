#!/usr/bin/env bash
# Ставит Stockfish 19 в .tmp/sf (в репозиторий не попадает).
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .tmp/sf
cd .tmp/sf
URL="https://github.com/official-stockfish/Stockfish/releases/download/sf_19/stockfish-linux-x86-64-universal.tar.gz"
[ -f stockfish/stockfish-linux-x86-64-universal ] && { echo "уже установлен"; exit 0; }
curl -sSL -C - -o sf.tar.gz "$URL"
tar xzf sf.tar.gz
chmod +x stockfish/stockfish-linux-x86-64-universal
printf 'uci\nquit\n' | ./stockfish/stockfish-linux-x86-64-universal | grep "id name"
