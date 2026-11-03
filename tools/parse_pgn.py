#!/usr/bin/env python3
"""PGN -> godot/data/game.json (плюс проверки и таблица FEN)."""
import json, sys, pathlib
import chess
import chess.pgn

import argparse
ROOT = pathlib.Path(__file__).resolve().parents[1]
ap = argparse.ArgumentParser()
ap.add_argument("--pgn", default="docs/game.pgn")
ap.add_argument("--out", default="godot/data/game.json")
_args = ap.parse_args()
PGN = ROOT / _args.pgn
OUT = ROOT / _args.out

def main() -> int:
    game = chess.pgn.read_game(PGN.open())
    if game.errors:
        print("PGN errors:", game.errors, file=sys.stderr)
    board = game.board()

    meta = {
        "white": game.headers.get("White"),
        "black": game.headers.get("Black"),
        "white_elo": int(game.headers.get("WhiteElo", 0)),
        "black_elo": int(game.headers.get("BlackElo", 0)),
        "date": game.headers.get("Date"),
        "utc_date": game.headers.get("UTCDate"),
        "utc_time": game.headers.get("UTCTime"),
        "event": game.headers.get("Event"),
        "site": game.headers.get("Site"),
        "time_control": game.headers.get("TimeControl"),
        "eco": game.headers.get("ECO"),
        "opening": game.headers.get("Opening"),
        "result": game.headers.get("Result"),
        "termination": game.headers.get("Termination"),
    }

    moves = []
    for i, m in enumerate(game.mainline_moves(), start=1):
        side = "w" if board.turn == chess.WHITE else "b"
        captured = board.piece_at(m.to_square)
        castle = board.is_castling(m)
        rec = {
            "ply": i,
            "num": (i + 1) // 2,
            "side": side,
            "san": board.san(m),
            "from": chess.square_name(m.from_square),
            "to": chess.square_name(m.to_square),
            "piece": board.piece_at(m.from_square).symbol().lower(),
            "capture": captured.symbol().lower() if captured else None,
            "castle": castle,
            "check": False,
            "mate": False,
        }
        if castle:
            rank = "1" if side == "w" else "8"
            rec["rook_from"] = ("h" if m.to_square > m.from_square else "a") + rank
            rec["rook_to"] = ("f" if m.to_square > m.from_square else "d") + rank
        board.push(m)
        rec["check"] = board.is_check()
        rec["mate"] = board.is_checkmate()
        rec["fen"] = board.fen()
        moves.append(rec)

    data = {
        "meta": meta,
        "start_fen": game.board().fen(),
        "final_fen": board.fen(),
        "moves": moves,
    }
    OUT.write_text(json.dumps(data, ensure_ascii=False, indent=1))

    print(f"{'ply':>3} {'san':<8} {'piece':<5} {'cap':<4} from-to      check mate")
    for r in moves:
        print(f"{r['ply']:>3} {r['san']:<8} {r['piece']:<5} {str(r['capture']):<4} "
              f"{r['from']}-{r['to']:<6} {str(r['check']):<5} {r['mate']}")

    # Проверки
    assert moves[-1]["mate"], "последний ход должен быть матом"
    print(f"полуходов: {len(moves)}, финал: {moves[-1]['san']}, мат: {moves[-1]['mate']}")
    print("JSON:", OUT.relative_to(ROOT))
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
