import chess/piece
import iv

const pawn = [
  0, 0, 0, 0, 0, 0, 0, 0, 50, 50, 50, 50, 50, 50, 50, 50, 10, 10, 20, 30, 30, 20,
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

const king_white = [
  -30, -40, -40, -50, -50, -40, -40, -30, -30, -40, -40, -50, -50, -40, -40, -30,
  -30, -40, -40, -50, -50, -40, -40, -30, -30, -40, -40, -50, -50, -40, -40, -30,
  -20, -30, -30, -40, -40, -30, -30, -20, -10, -20, -20, -20, -20, -20, -20, -10,
  20, 20, 0, 0, 0, 0, 20, 20, 20, 30, 10, 0, 0, 10, 30, 20,
]

const king_black = [
  20, 30, 10, 0, 0, 10, 30, 20, 20, 20, 0, 0, 0, 0, 20, 20, -10, -20, -20, -20,
  -20, -20, -20, -10, -20, -30, -30, -40, -40, -30, -30, -20, -30, -40, -40, -50,
  -50, -40, -40, -30, -30, -40, -40, -50, -50, -40, -40, -30, -30, -40, -40, -50,
  -50, -40, -40, -30, -30, -40, -40, -50, -50, -40, -40, -30,
]

// TODO: King squares for endgame

pub type PieceTables {
  PieceTables(
    pawn: iv.Array(Int),
    knight: iv.Array(Int),
    bishop: iv.Array(Int),
    rook: iv.Array(Int),
    queen: iv.Array(Int),
    king_white: iv.Array(Int),
    king_black: iv.Array(Int),
  )
}

pub fn construct_tables() -> PieceTables {
  PieceTables(
    pawn: iv.from_list(pawn),
    knight: iv.from_list(knight),
    bishop: iv.from_list(bishop),
    rook: iv.from_list(rook),
    queen: iv.from_list(queen),
    king_white: iv.from_list(king_white),
    king_black: iv.from_list(king_black),
  )
}

pub fn piece_score(
  tables: PieceTables,
  piece: piece.Piece,
  position: Int,
) -> Int {
  let table = case piece.kind, piece.colour {
    piece.Pawn, _ -> tables.pawn
    piece.Bishop, _ -> tables.bishop
    piece.King, piece.White -> tables.king_white
    piece.King, piece.Black -> tables.king_black
    piece.Knight, _ -> tables.knight
    piece.Queen, _ -> tables.queen
    piece.Rook, _ -> tables.rook
  }

  iv.get_or_default(table, position, 0)
}
