import chess/board
import chess/game.{type Game}
import chess/move.{type Move}
import chess/piece
import gleam/int
import gleam/option.{None, Some}
import gleam/pair
import iv
import utils/list
import wisp

const search_depth = 5

pub fn best_move(game: Game) -> Move {
  wisp.log_info("Finding best move for: " <> game.to_fen(game))
  let #(eval, nodes_searched, move) =
    search(game, search_depth, -1_000_000, 1_000_000, move.LongCastle, 0)
  wisp.log_info(
    "Best move "
    <> move.to_string(move)
    <> ", with score "
    <> int.to_string(eval)
    <> ", searched "
    <> int.to_string(nodes_searched)
    <> " positions",
  )
  move
}

fn search(
  game: Game,
  depth: Int,
  best_eval: Int,
  beta: Int,
  best_move: Move,
  nodes_searched: Int,
) -> #(Int, Int, Move) {
  case depth {
    0 -> #(evaluate(game), nodes_searched + 1, best_move)
    _ -> {
      search_loop(
        game,
        order_moves(game, move.legal(game)),
        depth,
        best_eval,
        beta,
        best_move,
        nodes_searched,
      )
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
  nodes_searched: Int,
) -> #(Int, Int, Move) {
  case moves {
    [] -> #(best_eval, nodes_searched, best_move)
    [move, ..moves] -> {
      let #(eval, nodes_searched, _) =
        search(
          move.apply(game, move),
          depth - 1,
          -best_opponent_move,
          -best_eval,
          best_move,
          nodes_searched,
        )
      let eval = -eval

      case eval >= best_opponent_move {
        // This move is worse for our opponent than another possible move,
        // so the other side will not let us get to this position.
        True -> #(best_opponent_move, nodes_searched, best_move)
        False -> {
          let #(alpha, best_move) = case eval > best_eval {
            False -> #(best_eval, best_move)
            True -> #(eval, move)
          }
          search_loop(
            game,
            moves,
            depth,
            alpha,
            best_opponent_move,
            best_move,
            nodes_searched,
          )
        }
      }
    }
  }
}

pub fn evaluate(game: Game) -> Int {
  // Fifty move rule
  case game.half_moves >= 50 {
    True -> 0
    False -> {
      let attack_information = move.attack_information(game)
      let legal_moves = move.do_legal(game, attack_information)

      case legal_moves {
        [] ->
          case attack_information.in_check {
            // Stalemate
            False -> 0
            // Checkmate
            True -> -1_000_000
          }
        _ ->
          evaluate_for_colour(game, game.to_move)
          - evaluate_for_colour(game, piece.reverse_colour(game.to_move))
        // + 10
        // * list.length(legal_moves)
      }
    }
  }
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

fn order_moves(game: Game, moves: List(Move)) -> List(Move) {
  moves
  |> list.map(fn(move) { #(move, guess_eval(game, move)) })
  |> list.sort(fn(a, b) { int.compare(a.1, b.1) })
  |> list.map(pair.first)
}

fn guess_eval(game: Game, full_move: Move) -> Int {
  case full_move {
    move.LongCastle | move.ShortCastle -> 0
    move.Basic(move) | move.Promotion(move:, ..) -> {
      let promotion_kind = case full_move {
        move.Promotion(new_kind:, ..) -> Some(new_kind)
        _ -> None
      }

      let guess = 0

      let guess = case
        board.at(game.board, move.from),
        board.at(game.board, move.to)
      {
        Ok(board.Occupied(moving_piece)), Ok(board.Occupied(captured_piece)) ->
          guess
          + piece_score(captured_piece.kind)
          * 10
          - piece_score(moving_piece.kind)
        _, _ -> guess
      }

      let guess = case promotion_kind {
        None -> guess
        Some(kind) -> guess + piece_score(kind)
      }

      // TODO: Reduce score for moving into pawn attacks (we currently don't have enough info to deduce this)

      guess
    }
  }
}
