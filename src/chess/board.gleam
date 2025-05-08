import chess/piece.{type Piece}
import gleam/int
import gleam/string
import iv

pub const size = 8

pub type Board =
  iv.Array(Square)

pub fn set(board: Board, position: Position, square: Square) -> Board {
  case iv.set(board, position, square) {
    Ok(board) -> board
    Error(_) -> board
  }
}

pub type Square {
  Empty
  Occupied(Piece)
}

/// file = position % 8
/// rank = position / 8
/// To construct:
/// position = rank * 8 + file
pub type Position =
  Int

pub type Positions {
  Positions(white: Position, black: Position)
}

pub fn position_to_string(position: Position) -> String {
  let file = case position % 8 {
    0 -> "a"
    1 -> "b"
    2 -> "c"
    3 -> "d"
    4 -> "e"
    5 -> "f"
    6 -> "g"
    7 -> "h"
    _ -> "a"
  }

  file <> int.to_string(position / 8 + 1)
}

pub fn position_from_string(string: String) -> Position {
  let assert Ok(#(file, rank)) = string.pop_grapheme(string)
  let file = case file {
    "a" -> 0
    "b" -> 1
    "c" -> 2
    "d" -> 3
    "e" -> 4
    "f" -> 5
    "g" -> 6
    "h" -> 7
    _ -> 0
  }
  let assert Ok(rank) = int.parse(rank)
  rank * 8 + file - 8
}

pub fn empty() -> Board {
  iv.repeat(Empty, size * size)
}

pub const starting_fen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"

// pub const starting_fen = "8/3K4/4P3/8/8/8/6k1/7q w - - 0 1"

pub fn from_fen(fen: String) -> Board {
  from_fen_loop(fen, 0, size - 1, empty())
}

fn from_fen_loop(fen: String, file: Int, rank: Int, board: Board) -> Board {
  case string.pop_grapheme(fen) {
    Error(_) -> board
    Ok(#("/", fen)) -> from_fen_loop(fen, 0, rank - 1, board)
    Ok(#(char, fen)) ->
      case int.parse(char) {
        Ok(empty_spaces) -> from_fen_loop(fen, file + empty_spaces, rank, board)
        Error(_) ->
          case piece.from_fen(char) {
            Error(_) -> board
            Ok(piece) -> {
              let board = set(board, rank * 8 + file, Occupied(piece))
              from_fen_loop(fen, file + 1, rank, board)
            }
          }
      }
  }
}

pub fn to_fen(board: Board) -> String {
  to_fen_loop(board, 0, size - 1, 0, "")
}

fn to_fen_loop(
  board: Board,
  file: Int,
  rank: Int,
  empty: Int,
  fen: String,
) -> String {
  let fen = case file == 0 {
    True ->
      case rank == size - 1 || rank < 0 {
        False -> fen <> "/"
        True -> fen
      }
    False -> fen
  }

  let #(next_file, next_rank) = case file + 1 >= size {
    False -> #(file + 1, rank)
    True -> #(0, rank - 1)
  }

  case iv.get(board, rank * 8 + file) {
    Error(_) -> fen
    Ok(Empty) ->
      case next_file == 0 {
        False -> to_fen_loop(board, next_file, next_rank, empty + 1, fen)
        True ->
          to_fen_loop(
            board,
            next_file,
            next_rank,
            0,
            fen <> int.to_string(empty + 1),
          )
      }
    Ok(Occupied(piece)) -> {
      let fen = case empty {
        0 -> fen
        _ -> fen <> int.to_string(empty)
      }
      to_fen_loop(board, next_file, next_rank, 0, fen <> piece.to_fen(piece))
    }
  }
}
