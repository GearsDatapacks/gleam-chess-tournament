import chess/board
import chess/game
import chess/move
import gleam/int
import gleam/list
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

fn perft_all(fen: String, expected: List(Int)) {
  expected
  |> list.index_map(fn(expected, index) { perft(fen, index + 1, expected) })
  Nil
}

fn perft(fen: String, depth: Int, expected_moves: Int) {
  do_perft(game.from_fen(fen), depth - 1) |> should.equal(expected_moves)
}

fn do_perft(game: game.Game, depth: Int) -> Int {
  let legal_moves = move.legal(game)
  case depth {
    0 -> list.length(legal_moves)
    _ ->
      list.map(legal_moves, fn(move) {
        game
        |> move.apply(move)
        |> do_perft(depth - 1)
      })
      |> int.sum
  }
}

pub fn perft_initial_position_test() {
  perft_all("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1", [
    20, 400, 8902, 197_281, 4_865_609, 119_060_324,
  ])
}

fn test_apply_move(starting_fen: String, moves: List(String), final_fen: String) {
  let moves = list.map(moves, move.from_string)

  starting_fen
  |> game.from_fen
  |> list.fold(moves, _, move.apply)
  |> game.to_fen
  |> should.equal(final_fen)
}

pub fn apply_move_test() {
  test_apply_move(
    board.starting_fen,
    ["a2a4"],
    "rnbqkbnr/pppppppp/8/8/P7/8/1PPPPPPP/RNBQKBNR b KQkq a3 0 1",
  )

  test_apply_move(
    board.starting_fen,
    ["g1f3"],
    "rnbqkbnr/pppppppp/8/8/8/5N2/PPPPPPPP/RNBQKB1R b KQkq - 1 1",
  )

  test_apply_move(
    board.starting_fen,
    ["a2a4", "b8c6"],
    "r1bqkbnr/pppppppp/2n5/8/P7/8/1PPPPPPP/RNBQKBNR w KQkq - 1 2",
  )

  test_apply_move(
    board.starting_fen,
    ["a2a4", "b7b5"],
    "rnbqkbnr/p1pppppp/8/1p6/P7/8/1PPPPPPP/RNBQKBNR w KQkq b6 0 2",
  )

  test_apply_move(
    "rnbqkbnr/p1p1pppp/8/Pp1p4/8/8/1PPPPPPP/RNBQKBNR w KQkq b6 0 3",
    ["a5b6"],
    "rnbqkbnr/p1p1pppp/1P6/3p4/8/8/1PPPPPPP/RNBQKBNR b KQkq - 0 3",
  )

  test_apply_move(
    "rnbqkbnr/pp3ppp/8/2ppp3/4P3/5N2/PPPPBPPP/RNBQK2R w KQkq - 0 4",
    ["O-O"],
    "rnbqkbnr/pp3ppp/8/2ppp3/4P3/5N2/PPPPBPPP/RNBQ1RK1 b kq - 1 4",
  )

  test_apply_move(
    "rnbqkbnr/ppp2ppp/8/3pp3/3P4/2N1B3/PPPQPPPP/R3KBNR w KQkq - 0 5",
    ["O-O-O"],
    "rnbqkbnr/ppp2ppp/8/3pp3/3P4/2N1B3/PPPQPPPP/2KR1BNR b kq - 1 5",
  )

  test_apply_move(
    "rnbqk2r/ppppbppp/5n2/4p3/2PPP3/8/PP3PPP/RNBQKBNR b KQkq - 0 4",
    ["O-O"],
    "rnbq1rk1/ppppbppp/5n2/4p3/2PPP3/8/PP3PPP/RNBQKBNR w KQ - 1 5",
  )

  test_apply_move(
    "r3kbnr/pppqpppp/2n1b3/3p4/3PP3/8/PPP2PPP/RNBQKBNR b KQkq - 0 5",
    ["O-O-O"],
    "2kr1bnr/pppqpppp/2n1b3/3p4/3PP3/8/PPP2PPP/RNBQKBNR w KQ - 1 6",
  )
}
