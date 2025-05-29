import chess/game
import chess/move
import engine/evaluation
import engine/hash
import engine/table
import gleam/result

pub fn move(
  fen: String,
  now: Int,
  hash_data: hash.HashData,
  piece_tables: table.PieceTables,
) -> Result(move.Move, String) {
  fen
  |> game.from_fen
  |> evaluation.best_move(now, hash_data, piece_tables)
  |> result.replace_error("No legal moves found")
}
