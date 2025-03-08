import chess/board
import chess/game.{type Game}
import chess/move.{type Move}
import chess/piece
import iv

const search_depth = 4

pub fn best_move(game: Game) -> Move {
  search(game, search_depth, -1_000_000, 1_000_000, move.LongCastle).1
}

fn search(
  game: Game,
  depth: Int,
  best_eval: Int,
  beta: Int,
  best_move: Move,
) -> #(Int, Move) {
  case depth {
    0 -> #(evaluate(game), best_move)
    _ -> {
      search_loop(game, move.legal(game), depth, best_eval, beta, best_move)
    }
  }
}

fn search_loop(
  game: Game,
  moves: List(Move),
  depth: Int,
  best_eval: Int,
  best_opponent_move: Int,
  best_move: Move,
) -> #(Int, Move) {
  case moves {
    [] -> #(best_eval, best_move)
    [move, ..moves] -> {
      let eval =
        -search(
          move.apply(game, move),
          depth - 1,
          -best_opponent_move,
          -best_eval,
          best_move,
        ).0

      case eval >= best_opponent_move {
        // This move is worse for our opponent than another possible move,
        // so the other side will not let us get to this position.
        True -> #(best_opponent_move, best_move)
        False -> {
          let #(alpha, best_move) = case eval > best_eval {
            False -> #(best_eval, best_move)
            True -> #(eval, move)
          }
          search_loop(game, moves, depth, alpha, best_opponent_move, best_move)
        }
      }
    }
  }
}

pub fn evaluate(game: Game) -> Int {
  evaluate_for_colour(game, game.to_move)
  - evaluate_for_colour(game, piece.reverse_colour(game.to_move))
}

fn evaluate_for_colour(game: Game, colour: piece.Colour) -> Int {
  use eval, square <- iv.fold(game.board, 0)
  case square {
    board.Occupied(piece) if piece.colour == colour ->
      eval + piece_score(piece.kind)
    _ -> eval
  }
}

fn piece_score(kind: piece.Kind) -> Int {
  case kind {
    piece.King -> 0
    piece.Queen -> 900
    piece.Rook -> 500
    piece.Bishop -> 300
    piece.Knight -> 300
    piece.Pawn -> 100
  }
}
