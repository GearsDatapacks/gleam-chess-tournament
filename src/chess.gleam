import chess/game
import chess/move
import engine/evaluation
import gleam/result

pub fn move(fen: String, now: Int) -> Result(move.Move, String) {
  fen
  |> game.from_fen
  |> evaluation.best_move(now)
  |> result.replace_error("No legal moves found")
}
