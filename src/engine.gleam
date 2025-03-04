import chess
import chess/game
import chess/move
import chess/piece
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
    handle_request
    |> wisp_mist.handler(secret_key_base)
    |> mist.new
    |> mist.bind("0.0.0.0")
    |> mist.port(8000)
    |> mist.start_http

  process.sleep_forever()
}

fn handle_request(request: Request) -> Response {
  case wisp.path_segments(request) {
    ["move"] -> handle_move(request)
    ["legal"] -> handle_legal(request)
    _ -> wisp.ok()
  }
}

fn move_decoder() {
  use fen <- decode.field("fen", decode.string)
  use failed_moves <- decode.field("failed_moves", decode.list(decode.string))
  decode.success(#(fen, failed_moves))
}

fn handle_move(request: Request) -> Response {
  use body <- wisp.require_string_body(request)
  let decode_result = json.parse(body, move_decoder())
  case decode_result {
    Error(_) -> wisp.bad_request()
    Ok(move) -> {
      let move_result = chess.move(move.0, move.1)
      case move_result {
        Ok(move) -> wisp.ok() |> wisp.string_body(move)
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
    Ok(move) -> {
      wisp.log_info("Getting legal moves for position: " <> move.0)
      let game = game.from_fen(move.0)
      let moves = game |> move.legal |> json.array(move_to_json(game, _))
      wisp.ok()
      |> wisp.string_body(json.to_string(moves))
      |> wisp.set_header("Access-Control-Allow-Origin", "*")
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
            #("file", json.int(move.from.file)),
            #("rank", json.int(move.from.rank)),
          ]),
        ),
        #(
          "to",
          json.object([
            #("file", json.int(move.to.file)),
            #("rank", json.int(move.to.rank)),
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
