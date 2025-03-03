import chess/board.{type Position, Board}
import chess/game.{type Game, Game}
import chess/move/direction.{type Direction}
import chess/piece
import gleam/dict
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import gleam/string

pub type Move {
  Move(from: Position, to: Position)
}

pub fn to_string(move: Move) -> String {
  board.position_to_string(move.from) <> board.position_to_string(move.to)
}

pub fn from_string(string: String) -> Move {
  let from = string |> string.drop_end(2) |> board.position_from_string
  let to = string |> string.drop_start(2) |> board.position_from_string
  Move(from:, to:)
}

// TODO: castling, check
pub fn legal(game: Game) -> List(Move) {
  use moves, position, square <- dict.fold(game.board.squares, [])
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
    piece.Rook -> get_sliding_moves(game, position, direction.rook_directions)
    piece.King -> get_king_moves(game, position)
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
) -> Result(Move, Nil) {
  case direction.in_direction(from, direction) {
    Error(_) -> Error(Nil)
    Ok(to) ->
      case dict.get(game.board.squares, to) {
        Error(_) -> Error(Nil)
        Ok(square) ->
          case move_validity(square, game.to_move) {
            Invalid -> Error(Nil)
            Valid | ValidThenStop -> Ok(Move(from:, to:))
          }
      }
  }
}

fn get_sliding_moves(
  game: Game,
  position: Position,
  directions: List(Direction),
) -> List(Move) {
  list.flat_map(directions, get_sliding_moves_loop(game, position, _, []))
}

fn get_sliding_moves_loop(
  game: Game,
  position: Position,
  direction: Direction,
  moves: List(Move),
) -> List(Move) {
  case direction.in_direction(position, direction) {
    Error(_) -> moves
    Ok(new_position) ->
      case
        dict.get(game.board.squares, new_position)
        |> result.map(move_validity(_, game.to_move))
      {
        Error(_) | Ok(Invalid) -> moves
        Ok(ValidThenStop) -> [Move(from: position, to: new_position), ..moves]
        Ok(Valid) ->
          get_sliding_moves_loop(game, new_position, direction, [
            Move(from: position, to: new_position),
            ..moves
          ])
      }
  }
}

fn get_king_moves(game: Game, position: Position) -> List(Move) {
  direction.queen_directions |> list.filter_map(maybe_move(game, position, _))
}

fn get_knight_moves(game: Game, position: Position) -> List(Move) {
  direction.knight_directions |> list.filter_map(maybe_move(game, position, _))
}

fn get_pawn_moves(game: Game, position: Position) -> List(Move) {
  let #(direction, take_directions) = case game.to_move {
    piece.Black -> #(direction.down, [direction.down_left, direction.down_right])
    piece.White -> #(direction.up, [direction.up_left, direction.up_right])
  }
  let directions = case game.to_move, position.rank {
    piece.Black, 6 | piece.White, 1 -> [
      direction,
      direction.multiply(direction, 2),
    ]
    _, _ -> [direction]
  }
  directions
  |> list.filter_map(maybe_move(game, position, _))
  |> list.append(
    take_directions
    |> list.filter_map(fn(direction) {
      case direction.in_direction(position, direction) {
        Error(_) -> Error(Nil)
        Ok(to) ->
          case dict.get(game.board.squares, to) {
            Error(_) -> Error(Nil)
            Ok(square) ->
              case
                move_validity(square, game.to_move),
                game.en_passant == Some(to)
              {
                _, True | ValidThenStop, _ -> Ok(Move(from: position, to:))
                _, _ -> Error(Nil)
              }
          }
      }
    }),
  )
}

pub fn apply_move(game: Game, move: Move) -> Game {
  let newly_occupied = dict.get(game.board.squares, move.to)
  let #(squares, moved_piece) = case dict.get(game.board.squares, move.from) {
    Error(_) -> #(game.board.squares, board.Empty)
    Ok(square) -> #(
      game.board.squares
        |> dict.insert(move.to, square)
        |> dict.insert(move.from, board.Empty),
      square,
    )
  }

  let #(to_move, move_increment) = case game.to_move {
    piece.Black -> #(piece.White, 1)
    piece.White -> #(piece.Black, 0)
  }

  let was_capture = case newly_occupied {
    Ok(board.Occupied(_)) -> True
    _ -> False
  }

  let was_pawn_move = case moved_piece {
    board.Occupied(piece.Piece(kind: piece.Pawn, ..)) -> True
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

  let squares = case Some(move.to) == game.en_passant && was_pawn_move {
    False -> squares
    True -> {
      let captured_pawn =
        board.Position(file: move.to.file, rank: move.from.rank)
      dict.insert(squares, captured_pawn, board.Empty)
    }
  }

  Game(
    ..game,
    to_move:,
    board: Board(squares:),
    half_moves:,
    full_moves: game.full_moves + move_increment,
    en_passant:,
  )
}
