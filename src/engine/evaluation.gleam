import birl
import chess/board
import chess/game.{type Game}
import chess/move.{type Move}
import chess/piece
import engine/hash
import engine/table
import gleam/dict
import gleam/float
import gleam/int
import gleam/option.{None, Some}
import gleam/pair
import gleam/result
import iv
import utils/list
import wisp

pub fn best_move(game: Game) -> Result(Move, Nil) {
  let start_time = birl.monotonic_now()
  wisp.log_info("Finding best move for: " <> game.to_fen(game))
  let SearchResult(
    value: move,
    nodes_searched:,
    cache_hits:,
    time_finished:,
    ..,
  ) =
    iteratively_deepen(
      game,
      move.legal(game),
      SearchData(
        piece_tables: table.construct_tables(),
        hash_data: hash.generate_data(),
        cached_positions: dict.new(),
        depth_searched: 0,
        start_time:,
      ),
    )
  case move {
    Ok(IterationResult(move:, eval:, depth:)) -> {
      let time_taken =
        int.to_float(birl.monotonic_now() - start_time) /. 1_000_000.0
      let main_calc = int.to_float(time_finished - start_time) /. 1_000_000.0

      case time_taken >. 5.0 {
        False -> Nil
        True ->
          wisp.log_error(
            "Exceeded allowed time, took "
            <> float.to_string(time_taken)
            <> " seconds.",
          )
      }

      wisp.log_info(
        "Best move "
        <> move.to_string(move)
        <> ", with score "
        <> int.to_string(eval)
        <> ", searched "
        <> int.to_string(nodes_searched)
        <> " positions, with "
        <> int.to_string(cache_hits)
        <> " cache hits, at depth "
        <> int.to_string(depth)
        <> " in "
        <> float.to_string(time_taken)
        <> " seconds, final search finished in "
        <> float.to_string(main_calc)
        <> " seconds.",
      )
    }
    Error(_) -> wisp.log_info("No legal moves found")
  }

  case move {
    Error(Nil) -> Error(Nil)
    Ok(IterationResult(move:, ..)) -> Ok(move)
  }
}

type SearchResult(a) {
  SearchResult(
    value: a,
    nodes_searched: Int,
    cache_hits: Int,
    cached_positions: hash.Cache,
    eval_kind: hash.CacheKind,
    finished: Bool,
    time_finished: Int,
  )
}

type SearchData {
  SearchData(
    piece_tables: table.PieceTables,
    hash_data: hash.HashData,
    cached_positions: hash.Cache,
    depth_searched: Int,
    start_time: Int,
  )
}

type IterationResult {
  IterationResult(eval: Int, move: Move, depth: Int)
}

fn iteratively_deepen(
  game: Game,
  moves: List(Move),
  data: SearchData,
) -> SearchResult(Result(IterationResult, Nil)) {
  case moves {
    [] ->
      SearchResult(
        value: Error(Nil),
        nodes_searched: 0,
        cache_hits: 0,
        cached_positions: dict.new(),
        eval_kind: hash.Exact,
        finished: True,
        time_finished: 0,
      )
    _ ->
      iteratively_deepen_loop(
        game,
        0,
        0,
        0,
        Error(Nil),
        moves,
        data,
        birl.monotonic_now(),
      )
  }
}

fn iteratively_deepen_loop(
  game: Game,
  depth: Int,
  nodes_searched: Int,
  cache_hits: Int,
  best_move: Result(#(Int, Move), Nil),
  moves: List(Move),
  data: SearchData,
  time_finished: Int,
) -> SearchResult(Result(IterationResult, Nil)) {
  case
    search_top_level(
      game,
      depth,
      nodes_searched,
      cache_hits,
      -1_000_000_000,
      data,
      moves,
      [],
      Error(Nil),
    )
  {
    Error(_) ->
      SearchResult(
        value: result.map(best_move, fn(best_move) {
          IterationResult(eval: best_move.0, move: best_move.1, depth:)
        }),
        nodes_searched:,
        cache_hits:,
        cached_positions: data.cached_positions,
        eval_kind: hash.Exact,
        finished: True,
        time_finished:,
      )
    Ok(result) -> {
      let #(moves, eval, best_move) = result.value
      let ordered_moves = list.sort(moves, fn(a, b) { int.compare(b.0, a.0) })

      let best_move = case best_move {
        Error(_) -> Error(Nil)
        Ok(move) -> Ok(#(eval, move))
      }

      iteratively_deepen_loop(
        game,
        depth + 1,
        result.nodes_searched,
        result.cache_hits,
        best_move,
        list.map(ordered_moves, pair.second),
        SearchData(..data, cached_positions: result.cached_positions),
        birl.monotonic_now(),
      )
    }
  }
}

fn search_top_level(
  game: Game,
  depth: Int,
  nodes_searched: Int,
  cache_hits: Int,
  best_eval: Int,
  data: SearchData,
  moves: List(Move),
  evaluated: List(#(Int, Move)),
  best_move: Result(Move, Nil),
) -> Result(SearchResult(#(List(#(Int, Move)), Int, Result(Move, Nil))), Nil) {
  case moves {
    [] ->
      Ok(SearchResult(
        value: #(evaluated, best_eval, best_move),
        nodes_searched:,
        cache_hits:,
        cached_positions: data.cached_positions,
        eval_kind: hash.Exact,
        finished: True,
        time_finished: 0,
      ))
    [move, ..moves] -> {
      let result =
        search(
          move.apply(game, move),
          depth,
          -1_000_000_000,
          -best_eval,
          nodes_searched,
          cache_hits,
          data,
        )
      case result.finished {
        False -> Error(Nil)
        True -> {
          let eval = -result.value
          let #(best_eval, best_move) = case eval > best_eval {
            True -> #(eval, Ok(move))
            False -> #(best_eval, best_move)
          }

          let eval = case result.eval_kind {
            hash.AtLeast -> eval - 1
            hash.AtMost -> eval - 1
            hash.Exact -> eval
          }

          search_top_level(
            game,
            depth,
            result.nodes_searched,
            result.cache_hits,
            best_eval,
            SearchData(..data, cached_positions: result.cached_positions),
            moves,
            [#(eval, move), ..evaluated],
            best_move,
          )
        }
      }
    }
  }
}

const time_allowed = 4_500_000

fn search(
  game: Game,
  depth: Int,
  best_eval: Int,
  best_opponent_move: Int,
  nodes_searched: Int,
  cache_hits: Int,
  data: SearchData,
) -> SearchResult(Int) {
  let hash = hash.hash_position(game, data.hash_data)
  case
    hash.get(data.cached_positions, hash, depth, best_eval, best_opponent_move)
  {
    Ok(eval) ->
      SearchResult(
        eval,
        nodes_searched,
        cache_hits + 1,
        data.cached_positions,
        hash.Exact,
        True,
        0,
      )
    Error(_) -> {
      let elapsed = birl.monotonic_now() - data.start_time

      case elapsed < time_allowed {
        False ->
          SearchResult(
            0,
            nodes_searched,
            cache_hits,
            data.cached_positions,
            hash.Exact,
            False,
            0,
          )
        True ->
          case depth {
            0 -> {
              let eval = evaluate(game, data.piece_tables, data.depth_searched)
              SearchResult(
                eval,
                nodes_searched + 1,
                cache_hits,
                dict.insert(
                  data.cached_positions,
                  hash,
                  hash.CachedPosition(depth:, kind: hash.Exact, eval:),
                ),
                hash.Exact,
                True,
                0,
              )
            }
            _ -> {
              let attack_information = move.attack_information(game)
              let legal_moves = move.do_legal(game, attack_information)

              case legal_moves {
                [] -> {
                  let eval = case attack_information.in_check {
                    // Stalemate
                    False -> 0
                    // Checkmate
                    True -> -1_000_000 + data.depth_searched
                  }
                  SearchResult(
                    eval,
                    nodes_searched,
                    cache_hits,
                    dict.insert(
                      data.cached_positions,
                      hash,
                      hash.CachedPosition(depth:, kind: hash.Exact, eval:),
                    ),
                    hash.Exact,
                    True,
                    0,
                  )
                }
                moves -> {
                  let result =
                    search_loop(
                      game,
                      order_moves(game, moves),
                      depth,
                      best_eval,
                      best_opponent_move,
                      nodes_searched,
                      cache_hits,
                      data,
                      hash.AtMost,
                    )

                  SearchResult(
                    ..result,
                    cached_positions: dict.insert(
                      result.cached_positions,
                      hash,
                      hash.CachedPosition(
                        depth:,
                        kind: result.eval_kind,
                        eval: result.value,
                      ),
                    ),
                  )
                }
              }
            }
          }
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
  nodes_searched: Int,
  cache_hits: Int,
  data: SearchData,
  cache_kind: hash.CacheKind,
) -> SearchResult(Int) {
  case moves {
    [] ->
      SearchResult(
        best_eval,
        nodes_searched,
        cache_hits,
        data.cached_positions,
        cache_kind,
        True,
        0,
      )
    [move, ..moves] -> {
      let SearchResult(
        value: eval,
        nodes_searched:,
        cache_hits:,
        cached_positions:,
        finished:,
        ..,
      ) as result =
        search(
          move.apply(game, move),
          depth - 1,
          -best_opponent_move,
          -best_eval,
          nodes_searched,
          cache_hits,
          SearchData(..data, depth_searched: data.depth_searched + 1),
        )

      case finished {
        False -> result
        True -> {
          let eval = -eval

          case eval >= best_opponent_move {
            // This move is worse for our opponent than another possible move,
            // so the other side will not let us get to this position.
            True ->
              SearchResult(
                best_opponent_move,
                nodes_searched,
                cache_hits,
                cached_positions,
                hash.AtLeast,
                True,
                0,
              )
            False -> {
              let #(best_eval, cache_kind) = case eval > best_eval {
                False -> #(best_eval, cache_kind)
                True -> #(eval, hash.Exact)
              }
              search_loop(
                game,
                moves,
                depth,
                best_eval,
                best_opponent_move,
                nodes_searched,
                cache_hits,
                SearchData(..data, cached_positions:),
                cache_kind,
              )
            }
          }
        }
      }
    }
  }
}

pub fn evaluate(
  game: Game,
  piece_tables: table.PieceTables,
  depth_searched: Int,
) -> Int {
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
            True -> -1_000_000 + depth_searched
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
  let material_eval =
    iv.index_fold(game.board, 0, fn(eval, square, index) {
      case square {
        board.Occupied(piece) if piece.colour == colour ->
          eval
          + piece_score(piece.kind)
          + table.piece_score(piece_tables, piece, index)
        _ -> eval
      }
    })

  let #(king_position, enemy_king_position) = find_kings(game, colour)
  let endgame_eval =
    endgame_force_king_to_corner_eval(
      king_position,
      enemy_king_position,
      endgame_weight(game, piece.reverse_colour(colour)),
    )

  material_eval + endgame_eval
}

/// rook_value * 2 + bishop_value + knight_value
const endgame_material_count = 16

fn endgame_weight(game: Game, colour: piece.Colour) -> Int {
  let material =
    iv.fold(game.board, 0, fn(eval, square) {
      case square {
        board.Occupied(piece)
          if piece.colour == colour && piece.kind != piece.Pawn
        -> eval + piece_score(piece.kind)
        _ -> eval
      }
    })
  100 - int.min(100, material / endgame_material_count)
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

fn find_kings(
  game: Game,
  for_colour: piece.Colour,
) -> #(board.Position, board.Position) {
  use #(king, enemy_king), square, position <- iv.index_fold(game.board, #(0, 0))
  case square {
    board.Occupied(piece.Piece(kind: piece.King, colour:))
      if colour == for_colour
    -> #(position, enemy_king)
    board.Occupied(piece.Piece(kind: piece.King, ..)) -> #(king, position)
    _ -> #(king, enemy_king)
  }
}

fn endgame_force_king_to_corner_eval(
  king_position: board.Position,
  enemy_king_position: board.Position,
  endgame_weight: Int,
) -> Int {
  let enemy_king_rank = enemy_king_position / 8
  let enemy_king_file = enemy_king_position % 8

  let enemy_king_distance_from_centre_rank =
    int.max(3 - enemy_king_rank, enemy_king_rank - 4)
  let enemy_king_distance_from_centre_file =
    int.max(3 - enemy_king_file, enemy_king_file - 4)
  let enemy_kind_distance_from_centre =
    enemy_king_distance_from_centre_file + enemy_king_distance_from_centre_rank

  let king_rank = king_position / 8
  let king_file = king_position % 8

  let rank_distance = int.absolute_value(king_rank - enemy_king_rank)
  let file_distance = int.absolute_value(king_file - enemy_king_file)
  let distance = file_distance + rank_distance

  { enemy_kind_distance_from_centre * 10 + { 14 - distance } * 4 }
  * endgame_weight
  / 10
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
