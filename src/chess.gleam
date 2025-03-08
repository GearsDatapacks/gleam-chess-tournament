import chess/game
import chess/move
import engine/evaluation

pub fn move(fen: String) -> Result(move.Move, String) {
  fen
  |> game.from_fen
  |> evaluation.best_move
  |> Ok
}
