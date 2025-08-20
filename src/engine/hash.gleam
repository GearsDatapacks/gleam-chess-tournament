//// An implementation of [Zobrist Hashing](https://www.chessprogramming.org/Zobrist_Hashing).

import chess/board
import chess/game
import chess/move
import chess/piece
import gleam/dict
import gleam/int
import gleam/option
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

/// Data structure for storing randomly generated data used for hashing positions
pub opaque type HashData {
  HashData(table: iv.Array(Int), black_to_move: Int)
}

const max_64_bit_int = 18_446_744_073_709_552_000

pub fn generate_data() -> HashData {
  let table =
    iv.initialise(num_pieces * board.side_length * board.side_length, fn(_) {
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

  iv.index_fold(game.board, hash, fn(hash, square, position) {
    case square {
      board.Empty -> hash
      board.Occupied(piece) -> toggle_hash_square(hash, position, piece, data)
    }
  })
}

fn toggle_hash_square(
  hash: Int,
  position: Int,
  piece: piece.Piece,
  data: HashData,
) -> Int {
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
  let index = position * num_pieces + piece_index
  int.bitwise_exclusive_or(iv.get_or_default(data.table, index, 0), hash)
}

/// Update an existing hash with a move. This is faster than recalculating the
/// hash with the new board as it only has to change a few squares.
pub fn update(hash: Int, move_info: move.MoveInfo, data: HashData) -> Int {
  let move.MoveInfo(
    capture:,
    moved_from:,
    moved_piece:,
    moved_to:,
    promotion:,
    ..,
  ) = move_info

  let hash =
    hash
    |> int.bitwise_exclusive_or(data.black_to_move)
    |> toggle_hash_square(moved_from, moved_piece, data)
    |> toggle_hash_square(
      moved_to,
      case promotion {
        option.None -> moved_piece
        option.Some(piece) -> piece
      },
      data,
    )
  case capture {
    option.None -> hash
    option.Some(#(position, piece)) ->
      toggle_hash_square(hash, position, piece, data)
  }
}

pub type CachedPosition {
  CachedPosition(depth: Int, kind: CacheKind, eval: Int)
}

/// When we cache a position, due to alpha-beta pruning, we don't always know
/// for sure what the evaluation of that position is. We either know its exact
/// evaluation, because it hasn't been pruned, or we know that it is at most a
/// certain score, or we know that it is a least a certain score, due to pruning.
/// This changes the way we treat the position when retrieving from the cache.
pub type CacheKind {
  Exact
  AtMost
  AtLeast
}

pub type Cache =
  dict.Dict(Int, CachedPosition)

/// Retrieve a cached position from the cache, if applicable.
pub fn get(
  cache: Cache,
  hash: Int,
  depth: Int,
  depth_searched: Int,
  best_eval: Int,
  best_opponent_move: Int,
) -> Result(Int, Nil) {
  case dict.get(cache, hash) {
    Ok(cached) if cached.depth >= depth -> {
      let eval = case is_mate_score(cached.eval) {
        False -> cached.eval
        True -> {
          case cached.eval > 0 {
            True -> cached.eval - depth_searched
            False -> cached.eval + depth_searched
          }
        }
      }

      case cached.kind {
        Exact -> Ok(eval)
        AtLeast if eval >= best_opponent_move -> Ok(best_opponent_move)
        AtMost if eval <= best_eval -> Ok(best_eval)
        _ -> Error(Nil)
      }
    }
    _ -> Error(Nil)
  }
}

/// Store a position in the cache so we don't need to recalculate its evaluation
/// later.
pub fn set(
  cache: Cache,
  hash: Int,
  depth: Int,
  depth_searched: Int,
  kind: CacheKind,
  eval: Int,
) -> Cache {
  let eval = case is_mate_score(eval) {
    False -> eval
    True -> {
      case eval > 0 {
        True -> eval + depth_searched
        False -> eval - depth_searched
      }
    }
  }

  dict.insert(cache, hash, CachedPosition(depth:, kind:, eval:))
}

fn is_mate_score(score: Int) -> Bool {
  int.absolute_value(score) >= mate_score - max_mate_depth
}

const mate_score = 1_000_000

const max_mate_depth = 1000
