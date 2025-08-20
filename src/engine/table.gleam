//// Piece tables indicating stronger and weaker positions for each piece type.
//// For example, knights are stronger in the centre of the board and weaker near
//// the edge.
//// Each table is made from white's perspective. To get scores for black, simply
//// reverse the squares.

import chess/piece
import iv

const pawn = [
  0, 0, 0, 0, 0, 0, 0, 0, 30, 30, 30, 30, 30, 30, 30, 30, 10, 10, 20, 30, 30, 20,
  10, 10, 5, 5, 10, 25, 25, 10, 5, 5, 0, 0, 0, 20, 20, 0, 0, 0, 5, -5, -10, 0, 0,
  -10, -5, 5, 5, 10, 10, -20, -20, 10, 10, 5, 0, 0, 0, 0, 0, 0, 0, 0,
]

const knight = [
  -50, -40, -30, -30, -30, -30, -40, -50, -40, -20, 0, 0, 0, 0, -20, -40, -30, 0,
  10, 15, 15, 10, 0, -30, -30, 5, 15, 20, 20, 15, 5, -30, -30, 0, 15, 20, 20, 15,
  0, -30, -30, 5, 10, 15, 15, 10, 5, -30, -40, -20, 0, 5, 5, 0, -20, -40, -50,
  -40, -30, -30, -30, -30, -40, -50,
]

const bishop = [
  -20, -10, -10, -10, -10, -10, -10, -20, -10, 0, 0, 0, 0, 0, 0, -10, -10, 0, 5,
  10, 10, 5, 0, -10, -10, 5, 5, 10, 10, 5, 5, -10, -10, 0, 10, 10, 10, 10, 0,
  -10, -10, 10, 10, 10, 10, 10, 10, -10, -10, 5, 0, 0, 0, 0, 5, -10, -20, -10,
  -10, -10, -10, -10, -10, -20,
]

const rook = [
  0, 0, 0, 0, 0, 0, 0, 0, 5, 10, 10, 10, 10, 10, 10, 5, -5, 0, 0, 0, 0, 0, 0, -5,
  -5, 0, 0, 0, 0, 0, 0, -5, -5, 0, 0, 0, 0, 0, 0, -5, -5, 0, 0, 0, 0, 0, 0, -5,
  -5, 0, 0, 0, 0, 0, 0, -5, 0, 0, 0, 5, 5, 0, 0, 0,
]

const queen = [
  -20, -10, -10, -5, -5, -10, -10, -20, -10, 0, 0, 0, 0, 0, 0, -10, -10, 0, 5, 5,
  5, 5, 0, -10, -5, 0, 5, 5, 5, 5, 0, -5, 0, 0, 5, 5, 5, 5, 0, -5, -10, 5, 5, 5,
  5, 5, 0, -10, -10, 0, 5, 0, 0, 0, 0, -10, -20, -10, -10, -5, -5, -10, -10, -20,
]

const king = [
  -30, -40, -40, -50, -50, -40, -40, -30, -30, -40, -40, -50, -50, -40, -40, -30,
  -30, -40, -40, -50, -50, -40, -40, -30, -30, -40, -40, -50, -50, -40, -40, -30,
  -20, -30, -30, -40, -40, -30, -30, -20, -10, -20, -20, -20, -20, -20, -20, -10,
  20, 20, 0, 0, 0, 0, 20, 20, 20, 30, 10, 0, 0, 10, 30, 20,
]

/// In the beginning and middle of the game, the king must be kept safe, however
/// as the game progresses towards the end, the king should become more aggressive
/// so we use a different set of scores for kings in the endgame.
const king_endgame = [
  -50, -40, -30, -20, -20, -30, -40, -50, -30, -20, -10, 0, 0, -10, -20, -30,
  -30, -10, 20, 30, 30, 20, -10, -30, -30, -10, 30, 40, 40, 30, -10, -30, -30,
  -10, 30, 40, 40, 30, -10, -30, -30, -10, 20, 30, 30, 20, -10, -30, -30, -30, 0,
  0, 0, 0, -30, -30, -50, -30, -30, -30, -30, -30, -30, -50,
]

/// A type which keeps track of the table for each piece
pub opaque type PieceTables {
  PieceTables(
    pawn: iv.Array(Int),
    knight: iv.Array(Int),
    bishop: iv.Array(Int),
    rook: iv.Array(Int),
    queen: iv.Array(Int),
    king: iv.Array(Int),
    king_endgame: iv.Array(Int),
  )
}

/// Turn the `List`s which are in the constants into `iv.Arrays` for faster
/// accessing
pub fn construct_tables() -> PieceTables {
  PieceTables(
    pawn: iv.from_list(pawn),
    knight: iv.from_list(knight),
    bishop: iv.from_list(bishop),
    rook: iv.from_list(rook),
    queen: iv.from_list(queen),
    king: iv.from_list(king),
    king_endgame: iv.from_list(king_endgame),
  )
}

/// Calculate the score for a given piece at a position at some point in the game
pub fn piece_score(
  tables: PieceTables,
  piece: piece.Piece,
  position: Int,
  endgame_weight: Int,
) -> Int {
  let table = case piece.kind {
    piece.Pawn -> tables.pawn
    piece.Bishop -> tables.bishop
    piece.Knight -> tables.knight
    piece.Queen -> tables.queen
    piece.Rook -> tables.rook
    piece.King -> tables.king
  }

  // If the piece is black, the table must be reversed to we index from the end
  // instead.
  let index = case piece.colour {
    piece.White -> position
    piece.Black -> 63 - position
  }

  let score = iv.get_or_default(table, index, 0)
  case piece.kind {
    // If we are nearing the endgame, we interpolate between the king's early
    // game table and the endgame table.
    piece.King if endgame_weight > 0 ->
      {
        score
        * { 100 - endgame_weight }
        + iv.get_or_default(tables.king_endgame, index, 0)
        * endgame_weight
      }
      / 100

    _ -> score
  }
}
