# Чем считали

## Движок

**Stockfish 19**, сборка `stockfish-linux-x86-64-universal` из официального релиза
[`sf_19`](https://github.com/official-stockfish/Stockfish/releases/tag/sf_19).

- Путь на этой машине: `.tmp/sf/stockfish/stockfish-linux-x86-64-universal` (99 МБ)
- В репозиторий не входит: каталог `.tmp/` в `.gitignore`. Скачать заново — `tools/get_stockfish.sh`
- Обёртка: `python-chess` 1.11.2 (`chess.engine.SimpleEngine`), 4 потока, Hash 256 МБ
- NNUE включён по умолчанию, GPU не нужен

## Глубина

Глубина задавалась вручную через `chess.engine.Limit(depth=N)`, N — в полуходах:

| Что считали | Глубина | Результат |
|---|---|---|
| `17…Be6` против альтернатив | 18 | `Be6` — единственный ход с перевесом; альтернативы (`Nb5`, `Bxf3`) ведут к равной или худшей позиции |
| Ответы белых после `17…Be6` | 17 | `Qxc3` −3.4, `Be2` −5.0, `Bd6` −5.5, `Bxb6` (как в партии) −7.4 |
| `18.Bxe6` — линия мата | 20–22 | **#-6**: `Qb5+ 19.Bc4 Qxc4+ 20.Kg1 Ne2+ 21.Kf1 Ng3+` |
| `18.Bxb6` — мельница | 16 | `Bxc4+ Kg1 Ne2+ Kf1 Nxd4+ Kg1` и далее |

Оценки — в сантипешках с точки зрения белых (`inf["score"].white()`).

## Что это дало для текста

- Ход века — **слон** `g4→e6`, а не ферзь. Ферзь на b6 остаётся под боем слона c5.
- Взять слона нельзя: форсированный мат в 6.
- Взять ферзя можно, и Бирн взял — но это ведёт к мельнице и −7.4.
- Лучшим было `18.Qxc3` (взять коня), но и там −3.4: у чёрных просто лучше.

## Воспроизвести

```bash
./tools/get_stockfish.sh
PYTHONPATH=.tmp/py python3 - <<'PY'
import chess, chess.pgn, chess.engine
eng = chess.engine.SimpleEngine.popen_uci(".tmp/sf/stockfish/stockfish-linux-x86-64-universal")
eng.configure({"Threads": 4, "Hash": 256})
g = chess.pgn.read_game(open("docs/game2.pgn"))
b = g.board()
for m in list(g.mainline_moves())[:34]:
    b.push(m)
b.push(chess.Move.from_uci("c4e6"))          # 18.Bxe6
inf = eng.analyse(b, chess.engine.Limit(depth=22))
print(inf["score"].white(), inf.get("pv", [])[:6])
eng.quit()
PY
```
