import chess/board
import chess/game
import chess/piece
import gleam/int
import iv

const white_pawn = 0

const black_pawn = 1

const white_knight = 2

const black_knight = 3

const white_bishop = 4

const black_bishop = 5

const white_rook = 6

const black_rook = 7

const white_queen = 8

const black_queen = 9

const white_king = 10

const black_king = 11

const num_pieces = 12

pub type HashData {
  HashData(table: iv.Array(Int), black_to_move: Int)
}

const max_64_bit_int = 18_446_744_073_709_552_000

pub fn generate_data() -> HashData {
  let table =
    iv.initialise(num_pieces * board.size * board.size, fn(_) {
      int.random(max_64_bit_int)
    })
  let black_to_move = int.random(max_64_bit_int)
  HashData(table:, black_to_move:)
}

pub fn hash_position(game: game.Game, data: HashData) -> Int {
  let hash = case game.to_move {
    piece.Black -> data.black_to_move
    piece.White -> 0
  }

  use hash, square, index <- iv.index_fold(game.board, hash)
  case square {
    board.Empty -> hash
    board.Occupied(piece) -> {
      let piece_index = case piece.kind, piece.colour {
        piece.Pawn, piece.White -> white_pawn
        piece.Bishop, piece.White -> white_bishop
        piece.King, piece.White -> white_king
        piece.Knight, piece.White -> white_knight
        piece.Queen, piece.White -> white_queen
        piece.Rook, piece.White -> white_rook
        piece.Bishop, piece.Black -> black_bishop
        piece.King, piece.Black -> black_king
        piece.Knight, piece.Black -> black_knight
        piece.Pawn, piece.Black -> black_pawn
        piece.Queen, piece.Black -> black_queen
        piece.Rook, piece.Black -> black_rook
      }
      let index = index * num_pieces + piece_index
      int.bitwise_exclusive_or(iv.get_or_default(data.table, index, 0), hash)
    }
  }
}
