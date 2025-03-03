import chess/game
import chess/move
import gleam/list
import gleam/result

pub fn move(fen: String, failed_moves: List(String)) -> Result(String, String) {
  let failed_moves = list.map(failed_moves, move.from_string)

  fen
  |> game.from_fen
  |> move.legal
  |> list.find(fn(move) { !list.contains(failed_moves, move) })
  |> result.map(move.to_string)
  |> result.replace_error("No legal moves")
}
