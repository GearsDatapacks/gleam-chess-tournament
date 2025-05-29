import birl
import chess
import chess/game
import chess/move
import chess/piece
import engine/hash
import engine/table
import gleam/dynamic/decode
import gleam/erlang/process
import gleam/json
import mist
import wisp.{type Request, type Response}
import wisp/wisp_mist

pub fn main() {
  wisp.configure_logger()
  let secret_key_base = wisp.random_string(64)

  let assert Ok(_) =
    handle_request(_, hash.generate_data(), table.construct_tables())
    |> wisp_mist.handler(secret_key_base)
    |> mist.new
    |> mist.bind("0.0.0.0")
    |> mist.port(8000)
    |> mist.start_http

  process.sleep_forever()
}

fn handle_request(
  request: Request,
  hash_data: hash.HashData,
  piece_tables: table.PieceTables,
) -> Response {
  case wisp.path_segments(request) {
    ["move"] -> handle_move(request, hash_data, piece_tables)
    ["legal"] -> handle_legal(request)
    ["dbg_move"] -> handle_dbg_move(request, hash_data, piece_tables)
    _ -> wisp.ok()
  }
}

fn move_decoder() {
  use fen <- decode.field("fen", decode.string)
  decode.success(fen)
}

fn handle_move(
  request: Request,
  hash_data: hash.HashData,
  piece_tables: table.PieceTables,
) -> Response {
  let now = birl.monotonic_now()
  use body <- wisp.require_string_body(request)
  let decode_result = json.parse(body, move_decoder())
  case decode_result {
    Error(_) -> wisp.bad_request()
    Ok(fen) -> {
      let move_result = chess.move(fen, now, hash_data, piece_tables)
      case move_result {
        Ok(move) -> wisp.ok() |> wisp.string_body(move.to_string(move))
        Error(reason) ->
          wisp.internal_server_error() |> wisp.string_body(reason)
      }
    }
  }
}

fn handle_legal(request: Request) -> Response {
  use body <- wisp.require_string_body(request)
  let decode_result = json.parse(body, move_decoder())
  case decode_result {
    Error(_) -> wisp.bad_request()
    Ok(fen) -> {
      wisp.log_info("Getting legal moves for position: " <> fen)
      let game = game.from_fen(fen)
      let moves = game |> move.legal |> json.array(move_to_json(game, _))
      wisp.ok()
      |> wisp.string_body(json.to_string(moves))
      |> wisp.set_header("Access-Control-Allow-Origin", "*")
    }
  }
}

fn handle_dbg_move(
  request: Request,
  hash_data: hash.HashData,
  piece_tables: table.PieceTables,
) -> Response {
  let now = birl.monotonic_now()
  use body <- wisp.require_string_body(request)
  let decode_result = json.parse(body, move_decoder())
  case decode_result {
    Error(_) -> wisp.bad_request()
    Ok(fen) -> {
      let move_result = chess.move(fen, now, hash_data, piece_tables)
      case move_result {
        Ok(move) ->
          wisp.ok()
          |> wisp.string_body(
            json.to_string(move_to_json(game.from_fen(fen), move)),
          )
          |> wisp.set_header("Access-Control-Allow-Origin", "*")
        Error(reason) ->
          wisp.internal_server_error()
          |> wisp.string_body(reason)
      }
    }
  }
}

fn move_to_json(game: game.Game, move: move.Move) -> json.Json {
  let fen = game.to_fen(move.apply(game, move))

  case move, game.to_move {
    move.Basic(move), _ | move.Promotion(move, _), _ ->
      json.object([
        #(
          "from",
          json.object([
            #("file", json.int(move.from % 8)),
            #("rank", json.int(move.from / 8)),
          ]),
        ),
        #(
          "to",
          json.object([
            #("file", json.int(move.to % 8)),
            #("rank", json.int(move.to / 8)),
          ]),
        ),
        #("fen", json.string(fen)),
      ])
    move.LongCastle, piece.White ->
      json.object([
        #("from", json.object([#("file", json.int(4)), #("rank", json.int(0))])),
        #("to", json.object([#("file", json.int(2)), #("rank", json.int(0))])),
        #("fen", json.string(fen)),
      ])
    move.LongCastle, piece.Black ->
      json.object([
        #("from", json.object([#("file", json.int(4)), #("rank", json.int(7))])),
        #("to", json.object([#("file", json.int(2)), #("rank", json.int(7))])),
        #("fen", json.string(fen)),
      ])
    move.ShortCastle, piece.White ->
      json.object([
        #("from", json.object([#("file", json.int(4)), #("rank", json.int(0))])),
        #("to", json.object([#("file", json.int(6)), #("rank", json.int(0))])),
        #("fen", json.string(fen)),
      ])
    move.ShortCastle, piece.Black ->
      json.object([
        #("from", json.object([#("file", json.int(4)), #("rank", json.int(7))])),
        #("to", json.object([#("file", json.int(6)), #("rank", json.int(7))])),
        #("fen", json.string(fen)),
      ])
  }
}
