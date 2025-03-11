import chess/board
import chess/game.{type Game}
import chess/move.{type Move}
import chess/piece
import engine/hash
import engine/table
import gleam/dict
import gleam/int
import gleam/option.{None, Some}
import gleam/pair
import iv
import utils/list
import wisp

const search_depth = 5

pub fn best_move(game: Game) -> Result(Move, Nil) {
  wisp.log_info("Finding best move for: " <> game.to_fen(game))
  let SearchResult(eval:, nodes_searched:, cache_hits:, best_move: move, ..) =
    search(
      game,
      search_depth,
      -1_000_000_000,
      1_000_000_000,
      Error(Nil),
      0,
      0,
      SearchData(
        piece_tables: table.construct_tables(),
        hash_data: hash.generate_data(),
        cached_positions: dict.new(),
      ),
    )
  case move {
    Ok(move) ->
      wisp.log_info(
        "Best move "
        <> move.to_string(move)
        <> ", with score "
        <> int.to_string(eval)
        <> ", searched "
        <> int.to_string(nodes_searched)
        <> " positions, with "
        <> int.to_string(cache_hits)
        <> " cache hits.",
      )
    Error(_) -> wisp.log_info("No legal moves found")
  }

  move
}

type SearchResult {
  SearchResult(
    eval: Int,
    nodes_searched: Int,
    cache_hits: Int,
    best_move: Result(Move, Nil),
    cached_positions: dict.Dict(Int, Int),
  )
}

type SearchData {
  SearchData(
    piece_tables: table.PieceTables,
    hash_data: hash.HashData,
    cached_positions: dict.Dict(Int, Int),
  )
}

fn search(
  game: Game,
  depth: Int,
  best_eval: Int,
  best_opponent_move: Int,
  best_move: Result(Move, Nil),
  nodes_searched: Int,
  cache_hits: Int,
  data: SearchData,
) -> SearchResult {
  case depth {
    0 -> {
      let hash = hash.hash_position(game, data.hash_data)
      case dict.get(data.cached_positions, hash) {
        Ok(eval) ->
          SearchResult(
            eval,
            nodes_searched,
            cache_hits + 1,
            best_move,
            data.cached_positions,
          )
        Error(_) -> {
          let eval = evaluate(game, data.piece_tables)
          SearchResult(
            eval,
            nodes_searched + 1,
            cache_hits,
            best_move,
            dict.insert(data.cached_positions, hash, eval),
          )
        }
      }
    }
    // TODO: Cache eval when searching higher than depth 1 (currently
    // this only makes the program slower or worse at evaluation).
    _ -> {
      let attack_information = move.attack_information(game)
      let legal_moves = move.do_legal(game, attack_information)

      case legal_moves {
        [] -> {
          let eval = case attack_information.in_check {
            // Stalemate
            False -> 0
            // Checkmate
            True -> -1_000_000
          }
          SearchResult(
            eval,
            nodes_searched,
            cache_hits,
            Error(Nil),
            data.cached_positions,
          )
        }
        moves ->
          search_loop(
            game,
            order_moves(game, moves),
            depth,
            best_eval,
            best_opponent_move,
            best_move,
            nodes_searched,
            cache_hits,
            data,
          )
      }
    }
  }
}

fn search_loop(
  game: Game,
  moves: List(Move),
  depth: Int,
  best_eval: Int,
  best_opponent_move: Int,
  best_move: Result(Move, Nil),
  nodes_searched: Int,
  cache_hits: Int,
  data: SearchData,
) -> SearchResult {
  case moves {
    [] ->
      SearchResult(
        best_eval,
        nodes_searched,
        cache_hits,
        best_move,
        data.cached_positions,
      )
    [move, ..moves] -> {
      let SearchResult(eval, nodes_searched, cache_hits, _, cached_positions) =
        search(
          move.apply(game, move),
          depth - 1,
          -best_opponent_move,
          -best_eval,
          best_move,
          nodes_searched,
          cache_hits,
          data,
        )
      let eval = -eval

      case eval >= best_opponent_move {
        // This move is worse for our opponent than another possible move,
        // so the other side will not let us get to this position.
        True ->
          SearchResult(
            best_opponent_move,
            nodes_searched,
            cache_hits,
            best_move,
            cached_positions,
          )
        False -> {
          let #(best_eval, best_move) = case eval > best_eval {
            False -> #(best_eval, best_move)
            True -> #(eval, Ok(move))
          }
          search_loop(
            game,
            moves,
            depth,
            best_eval,
            best_opponent_move,
            best_move,
            nodes_searched,
            cache_hits,
            SearchData(..data, cached_positions:),
          )
        }
      }
    }
  }
}

pub fn evaluate(game: Game, piece_tables: table.PieceTables) -> Int {
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
          evaluate_for_colour(game, game.to_move, piece_tables)
          - evaluate_for_colour(
            game,
            piece.reverse_colour(game.to_move),
            piece_tables,
          )
        // + 10
        // * list.length(legal_moves)
      }
    }
  }
}

fn evaluate_for_colour(
  game: Game,
  colour: piece.Colour,
  piece_tables: table.PieceTables,
) -> Int {
  use eval, square, index <- iv.index_fold(game.board, 0)
  case square {
    board.Occupied(piece) if piece.colour == colour ->
      eval
      + piece_score(piece.kind)
      + table.piece_score(piece_tables, piece, index)
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
        iv.get(game.board, move.from),
        iv.get(game.board, move.to)
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
