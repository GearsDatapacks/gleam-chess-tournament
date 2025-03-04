import chess/board.{type Position}
import chess/game.{type Game, Game}
import chess/move/direction.{type Direction}
import chess/piece.{Black, King, Piece, Rook, White}
import gleam/dict
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string

pub type Move {
  ShortCastle
  LongCastle
  Basic(BasicMove)
  Promotion(move: BasicMove, new_kind: piece.Kind)
}

pub type BasicMove {
  Move(from: Position, to: Position)
}

pub fn to_string(move: Move) -> String {
  case move {
    ShortCastle -> "O-O"
    LongCastle -> "O-O-O"
    Basic(move) ->
      board.position_to_string(move.from) <> board.position_to_string(move.to)
    Promotion(move, new_kind) ->
      board.position_to_string(move.from)
      <> board.position_to_string(move.to)
      <> piece.to_fen(Piece(Black, new_kind))
  }
}

pub fn from_string(string: String) -> Move {
  case string, string.length(string) {
    "O-O", _ -> ShortCastle
    "O-O-O", _ -> LongCastle
    _, 5 -> {
      let from = string |> string.drop_end(3) |> board.position_from_string
      let to =
        string
        |> string.drop_start(2)
        |> string.drop_end(1)
        |> board.position_from_string
      let new_kind =
        string
        |> string.drop_start(4)
        |> piece.from_fen
        |> result.map(fn(piece) { piece.kind })
        |> result.unwrap(piece.Pawn)
      Promotion(Move(from:, to:), new_kind)
    }
    _, _ -> {
      let from = string |> string.drop_end(2) |> board.position_from_string
      let to = string |> string.drop_start(2) |> board.position_from_string
      Basic(Move(from:, to:))
    }
  }
}

// TODO: check
pub fn legal(game: Game) -> List(Move) {
  use moves, position, square <- dict.fold(game.board, [])
  case square {
    board.Occupied(piece) if piece.colour == game.to_move ->
      list.append(get_moves_for_piece(game, piece, position), moves)
    _ -> moves
  }
}

fn get_moves_for_piece(
  game: Game,
  piece: piece.Piece,
  position: Position,
) -> List(Move) {
  case piece.kind {
    piece.Bishop ->
      get_sliding_moves(game, position, direction.bishop_directions)
    piece.Queen -> get_sliding_moves(game, position, direction.queen_directions)
    Rook -> get_sliding_moves(game, position, direction.rook_directions)
    King -> get_king_moves(game, position)
    piece.Pawn -> get_pawn_moves(game, position)
    piece.Knight -> get_knight_moves(game, position)
  }
}

type MoveValidity {
  Valid
  Invalid
  ValidThenStop
}

fn move_validity(square: board.Square, colour: piece.Colour) -> MoveValidity {
  case square {
    board.Empty -> Valid
    board.Occupied(piece) if piece.colour == colour -> Invalid
    board.Occupied(_) -> ValidThenStop
  }
}

fn maybe_move(
  game: Game,
  from: Position,
  direction: Direction,
  allow_captures: Bool,
) -> Result(BasicMove, Nil) {
  case direction.in_direction(from, direction) {
    Error(_) -> Error(Nil)
    Ok(to) ->
      case dict.get(game.board, to) {
        Error(_) -> Error(Nil)
        Ok(square) ->
          case move_validity(square, game.to_move) {
            Valid -> Ok(Move(from:, to:))
            ValidThenStop if allow_captures -> Ok(Move(from:, to:))
            _ -> Error(Nil)
          }
      }
  }
}

fn get_sliding_moves(
  game: Game,
  position: Position,
  directions: List(Direction),
) -> List(Move) {
  list.flat_map(
    directions,
    get_sliding_moves_loop(game, position, position, _, []),
  )
}

fn get_sliding_moves_loop(
  game: Game,
  original_position: Position,
  position: Position,
  direction: Direction,
  moves: List(Move),
) -> List(Move) {
  case direction.in_direction(position, direction) {
    Error(_) -> moves
    Ok(new_position) ->
      case
        dict.get(game.board, new_position)
        |> result.map(move_validity(_, game.to_move))
      {
        Error(_) | Ok(Invalid) -> moves
        Ok(ValidThenStop) -> [
          Basic(Move(from: original_position, to: new_position)),
          ..moves
        ]
        Ok(Valid) ->
          get_sliding_moves_loop(
            game,
            original_position,
            new_position,
            direction,
            [Basic(Move(from: original_position, to: new_position)), ..moves],
          )
      }
  }
}

fn get_king_moves(game: Game, position: Position) -> List(Move) {
  direction.queen_directions
  |> list.filter_map(fn(direction) {
    maybe_move(game, position, direction, True) |> result.map(Basic)
  })
  |> list.append(get_castling_moves(game))
}

fn get_castling_moves(game: Game) -> List(Move) {
  let moves = case game.to_move {
    Black if game.castling.black_kingside ->
      case
        dict.get(game.board, board.Position(4, 7)),
        dict.get(game.board, board.Position(5, 7)),
        dict.get(game.board, board.Position(6, 7)),
        dict.get(game.board, board.Position(7, 7))
      {
        Ok(board.Occupied(Piece(Black, King))),
          Ok(board.Empty),
          Ok(board.Empty),
          Ok(board.Occupied(Piece(Black, Rook)))
        -> [ShortCastle]
        _, _, _, _ -> []
      }
    White if game.castling.white_kingside ->
      case
        dict.get(game.board, board.Position(4, 0)),
        dict.get(game.board, board.Position(5, 0)),
        dict.get(game.board, board.Position(6, 0)),
        dict.get(game.board, board.Position(7, 0))
      {
        Ok(board.Occupied(Piece(White, King))),
          Ok(board.Empty),
          Ok(board.Empty),
          Ok(board.Occupied(Piece(White, Rook)))
        -> [ShortCastle]
        _, _, _, _ -> []
      }
    _ -> []
  }
  case game.to_move {
    Black if game.castling.black_queenside ->
      case
        dict.get(game.board, board.Position(4, 7)),
        dict.get(game.board, board.Position(3, 7)),
        dict.get(game.board, board.Position(2, 7)),
        dict.get(game.board, board.Position(1, 7)),
        dict.get(game.board, board.Position(0, 7))
      {
        Ok(board.Occupied(Piece(Black, King))),
          Ok(board.Empty),
          Ok(board.Empty),
          Ok(board.Empty),
          Ok(board.Occupied(Piece(Black, Rook)))
        -> [LongCastle, ..moves]
        _, _, _, _, _ -> moves
      }
    White if game.castling.white_queenside ->
      case
        dict.get(game.board, board.Position(4, 0)),
        dict.get(game.board, board.Position(3, 0)),
        dict.get(game.board, board.Position(2, 0)),
        dict.get(game.board, board.Position(1, 0)),
        dict.get(game.board, board.Position(0, 0))
      {
        Ok(board.Occupied(Piece(White, King))),
          Ok(board.Empty),
          Ok(board.Empty),
          Ok(board.Empty),
          Ok(board.Occupied(Piece(White, Rook)))
        -> [LongCastle, ..moves]
        _, _, _, _, _ -> moves
      }
    _ -> moves
  }
}

fn get_knight_moves(game: Game, position: Position) -> List(Move) {
  direction.knight_directions
  |> list.filter_map(fn(direction) {
    maybe_move(game, position, direction, True) |> result.map(Basic)
  })
}

fn get_pawn_moves(game: Game, position: Position) -> List(Move) {
  let #(direction, take_directions) = case game.to_move {
    Black -> #(direction.down, [direction.down_left, direction.down_right])
    White -> #(direction.up, [direction.up_left, direction.up_right])
  }

  let can_double_move = case game.to_move, position.rank {
    Black, 6 | White, 1 -> True
    _, _ -> False
  }

  let moves =
    take_directions
    |> list.filter_map(fn(direction) {
      case direction.in_direction(position, direction) {
        Error(_) -> Error(Nil)
        Ok(to) ->
          case dict.get(game.board, to) {
            Error(_) -> Error(Nil)
            Ok(square) ->
              case
                move_validity(square, game.to_move),
                game.en_passant == Some(to)
              {
                _, True | ValidThenStop, _ ->
                  Ok(Basic(Move(from: position, to:)))
                _, _ -> Error(Nil)
              }
          }
      }
    })

  case maybe_move(game, position, direction, False), can_double_move {
    Ok(move), False ->
      case game.to_move, move.to.rank {
        White, 7 | Black, 0 ->
          piece.promotion_kinds
          |> list.map(Promotion(move, _))
          |> list.append(moves)
        _, _ -> [Basic(move), ..moves]
      }
    Ok(single_move), True ->
      case maybe_move(game, position, direction.multiply(direction, 2), False) {
        Error(_) -> [Basic(single_move), ..moves]
        Ok(double_move) -> [Basic(single_move), Basic(double_move), ..moves]
      }
    Error(_), _ -> moves
  }
}

pub fn apply(game: Game, move: Move) -> Game {
  let game = case move {
    ShortCastle -> {
      let board = case game.to_move {
        Black ->
          game.board
          |> dict.insert(board.Position(4, 7), board.Empty)
          |> dict.insert(
            board.Position(5, 7),
            board.Occupied(Piece(Black, Rook)),
          )
          |> dict.insert(
            board.Position(6, 7),
            board.Occupied(Piece(Black, King)),
          )
          |> dict.insert(board.Position(7, 7), board.Empty)
        White ->
          game.board
          |> dict.insert(board.Position(4, 0), board.Empty)
          |> dict.insert(
            board.Position(5, 0),
            board.Occupied(Piece(White, Rook)),
          )
          |> dict.insert(
            board.Position(6, 0),
            board.Occupied(Piece(White, King)),
          )
          |> dict.insert(board.Position(7, 0), board.Empty)
      }
      let castling = case game.to_move {
        Black ->
          game.Castling(
            ..game.castling,
            black_kingside: False,
            black_queenside: False,
          )
        White ->
          game.Castling(
            ..game.castling,
            white_kingside: False,
            white_queenside: False,
          )
      }
      Game(
        ..game,
        board:,
        castling:,
        en_passant: None,
        half_moves: game.half_moves + 1,
      )
    }
    LongCastle -> {
      let board = case game.to_move {
        Black ->
          game.board
          |> dict.insert(board.Position(4, 7), board.Empty)
          |> dict.insert(
            board.Position(3, 7),
            board.Occupied(Piece(Black, Rook)),
          )
          |> dict.insert(
            board.Position(2, 7),
            board.Occupied(Piece(Black, King)),
          )
          |> dict.insert(board.Position(1, 7), board.Empty)
          |> dict.insert(board.Position(0, 7), board.Empty)
        White ->
          game.board
          |> dict.insert(board.Position(4, 0), board.Empty)
          |> dict.insert(
            board.Position(3, 0),
            board.Occupied(Piece(White, Rook)),
          )
          |> dict.insert(
            board.Position(2, 0),
            board.Occupied(Piece(White, King)),
          )
          |> dict.insert(board.Position(1, 0), board.Empty)
          |> dict.insert(board.Position(0, 0), board.Empty)
      }
      let castling = case game.to_move {
        Black ->
          game.Castling(
            ..game.castling,
            black_kingside: False,
            black_queenside: False,
          )
        White ->
          game.Castling(
            ..game.castling,
            white_kingside: False,
            white_queenside: False,
          )
      }
      Game(
        ..game,
        board:,
        castling:,
        en_passant: None,
        half_moves: game.half_moves + 1,
      )
    }
    Basic(move) -> apply_basic_move(game, move, None)
    Promotion(move, new_kind) -> apply_basic_move(game, move, Some(new_kind))
  }

  let #(to_move, move_increment) = case game.to_move {
    Black -> #(White, 1)
    White -> #(Black, 0)
  }

  Game(..game, to_move:, full_moves: game.full_moves + move_increment)
}

fn apply_basic_move(
  game: Game,
  move: BasicMove,
  new_kind: Option(piece.Kind),
) -> Game {
  let newly_occupied = dict.get(game.board, move.to)
  let #(board, moved_piece) = case dict.get(game.board, move.from) {
    Error(_) -> #(game.board, board.Empty)
    Ok(square) -> {
      let square = case square, new_kind {
        board.Empty, _ | board.Occupied(_), None -> square
        board.Occupied(piece), Some(new_kind) ->
          board.Occupied(Piece(piece.colour, new_kind))
      }
      #(
        game.board
          |> dict.insert(move.to, square)
          |> dict.insert(move.from, board.Empty),
        square,
      )
    }
  }

  let was_capture = case newly_occupied {
    Ok(board.Occupied(_)) -> True
    _ -> False
  }

  let was_pawn_move = case moved_piece {
    board.Occupied(Piece(kind: piece.Pawn, ..)) -> True
    _ -> False
  }

  let half_moves = case was_capture || was_pawn_move {
    False -> game.half_moves + 1
    True -> 0
  }

  let en_passant = case was_pawn_move, move.to.rank - move.from.rank {
    True, 2 -> Some(board.Position(file: move.to.file, rank: move.to.rank - 1))
    True, -2 -> Some(board.Position(file: move.to.file, rank: move.to.rank + 1))
    _, _ -> None
  }

  let board = case Some(move.to) == game.en_passant && was_pawn_move {
    False -> board
    True -> {
      let captured_pawn =
        board.Position(file: move.to.file, rank: move.from.rank)
      dict.insert(board, captured_pawn, board.Empty)
    }
  }

  let castling = case moved_piece, move.from.file {
    board.Occupied(Piece(White, piece.King)), _ ->
      game.Castling(
        ..game.castling,
        white_kingside: False,
        white_queenside: False,
      )
    board.Occupied(Piece(Black, kind: piece.King)), _ ->
      game.Castling(
        ..game.castling,
        black_kingside: False,
        black_queenside: False,
      )
    board.Occupied(Piece(White, piece.Rook)), 7 ->
      game.Castling(..game.castling, white_kingside: False)
    board.Occupied(Piece(White, piece.Rook)), 0 ->
      game.Castling(..game.castling, white_queenside: False)
    board.Occupied(Piece(Black, piece.Rook)), 7 ->
      game.Castling(..game.castling, black_kingside: False)
    board.Occupied(Piece(Black, piece.Rook)), 0 ->
      game.Castling(..game.castling, black_queenside: False)
    _, _ -> game.castling
  }

  Game(..game, board:, half_moves:, en_passant:, castling:)
}
