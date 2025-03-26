import chess/board.{type Position}
import chess/game.{type Game, Game}
import chess/move/direction.{type Direction}
import chess/piece.{Bishop, Black, King, Knight, Pawn, Piece, Queen, Rook, White}
import gleam/dict
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import iv
import utils/list

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
        |> result.unwrap(Pawn)
      Promotion(Move(from:, to:), new_kind)
    }
    _, _ -> {
      let from = string |> string.drop_end(2) |> board.position_from_string
      let to = string |> string.drop_start(2) |> board.position_from_string
      Basic(Move(from:, to:))
    }
  }
}

pub type AttackInformation {
  AttackInformation(
    attacks: List(Position),
    in_check: Bool,
    check_attack_lines: List(List(Position)),
    check_block_line: List(Position),
    pin_lines: dict.Dict(Position, List(Position)),
  )
}

fn is_pinned(
  from: Position,
  to: Position,
  attack_information: AttackInformation,
) -> Bool {
  case dict.get(attack_information.pin_lines, from) {
    Error(_) -> False
    Ok(line) -> !list.contains(line, to)
  }
}

fn piece_can_move(
  move: BasicMove,
  attack_information: AttackInformation,
) -> Bool {
  case attack_information.in_check {
    False -> !is_pinned(move.from, move.to, attack_information)
    True ->
      list.contains(attack_information.check_block_line, move.to)
      && !is_pinned(move.from, move.to, attack_information)
  }
}

pub fn attack_information(game: Game) -> AttackInformation {
  let attacks =
    attacks(Game(..game, to_move: piece.reverse_colour(game.to_move)))

  let king_position =
    iv.index_fold(game.board, 0, fn(acc, square, position) {
      case square {
        board.Occupied(piece.Piece(colour:, kind: piece.King))
          if colour == game.to_move
        -> position
        _ -> acc
      }
    })

  let in_check = list.contains(attacks, king_position)
  let check_attack_lines = case in_check {
    False -> []
    True -> get_check_attack_lines(game)
  }
  let check_block_line = case in_check {
    False -> []
    True ->
      case get_check_block_line(game, king_position) {
        Single(line) -> line
        Multiple -> []
        NoLine -> []
      }
  }

  let pin_lines = get_pin_lines(game)

  AttackInformation(
    attacks:,
    in_check:,
    check_attack_lines:,
    check_block_line:,
    pin_lines:,
  )
}

pub fn legal(game: Game) -> List(Move) {
  do_legal(game, attack_information(game))
}

fn get_check_attack_lines(game: Game) -> List(List(Position)) {
  use lines, square, position <- iv.index_fold(game.board, [])

  case square {
    board.Occupied(piece) if piece.colour != game.to_move ->
      case piece.kind {
        Rook ->
          case
            get_sliding_check_moves(game, position, direction.rook_directions)
          {
            Error(_) -> lines
            Ok(line) -> [line, ..lines]
          }
        Bishop ->
          case
            get_sliding_check_moves(game, position, direction.bishop_directions)
          {
            Error(_) -> lines
            Ok(line) -> [line, ..lines]
          }
        Queen ->
          case
            get_sliding_check_moves(game, position, direction.queen_directions)
          {
            Error(_) -> lines
            Ok(line) -> [line, ..lines]
          }
        _ -> lines
      }
    _ -> lines
  }
}

fn get_sliding_check_moves(
  game: Game,
  position: Position,
  directions: List(Direction),
) -> Result(List(Position), Nil) {
  list.find_map(directions, get_sliding_check_moves_loop(
    game,
    position,
    _,
    [],
    False,
  ))
}

fn get_sliding_check_moves_loop(
  game: Game,
  position: Position,
  direction: Direction,
  squares: List(Position),
  found_king: Bool,
) -> Result(List(Position), Nil) {
  case direction.in_direction(position, direction) {
    Error(_) if found_king -> Ok(squares)
    Error(_) -> Error(Nil)
    Ok(new_position) ->
      case iv.get(game.board, new_position) {
        Ok(board.Empty) ->
          get_sliding_check_moves_loop(
            game,
            new_position,
            direction,
            [new_position, ..squares],
            found_king,
          )
        Ok(board.Occupied(Piece(colour:, kind: piece.King)))
          if colour == game.to_move
        ->
          get_sliding_check_moves_loop(
            game,
            new_position,
            direction,
            [new_position, ..squares],
            True,
          )
        Error(_) if found_king -> Ok(squares)
        Error(_) -> Error(Nil)
        Ok(board.Occupied(_)) if found_king -> Ok([new_position, ..squares])
        Ok(board.Occupied(_)) -> Error(Nil)
      }
  }
}

fn get_pin_lines(game: Game) -> dict.Dict(Position, List(Position)) {
  use lines, square, position <- iv.index_fold(game.board, dict.new())

  case square {
    board.Occupied(piece) if piece.colour != game.to_move ->
      case piece.kind {
        Rook ->
          case
            get_sliding_pin_moves(game, position, direction.rook_directions)
          {
            Error(_) -> lines
            Ok(#(pinned, line)) -> dict.insert(lines, pinned, line)
          }
        Bishop ->
          case
            get_sliding_pin_moves(game, position, direction.bishop_directions)
          {
            Error(_) -> lines
            Ok(#(pinned, line)) -> dict.insert(lines, pinned, line)
          }
        Queen ->
          case
            get_sliding_pin_moves(game, position, direction.queen_directions)
          {
            Error(_) -> lines
            Ok(#(pinned, line)) -> dict.insert(lines, pinned, line)
          }
        _ -> lines
      }
    _ -> lines
  }
}

fn get_sliding_pin_moves(
  game: Game,
  position: Position,
  directions: List(Direction),
) -> Result(#(Position, List(Position)), Nil) {
  list.find_map(directions, get_sliding_pin_moves_loop(
    game,
    position,
    _,
    [position],
    None,
  ))
}

fn get_sliding_pin_moves_loop(
  game: Game,
  position: Position,
  direction: Direction,
  squares: List(Position),
  pinned_piece: Option(Position),
) -> Result(#(Position, List(Position)), Nil) {
  case direction.in_direction(position, direction), pinned_piece {
    Error(_), _ -> Error(Nil)
    Ok(new_position), _ ->
      case iv.get(game.board, new_position), pinned_piece {
        Ok(board.Empty), _ ->
          get_sliding_pin_moves_loop(
            game,
            new_position,
            direction,
            [new_position, ..squares],
            pinned_piece,
          )
        Ok(board.Occupied(Piece(colour:, kind: piece.King))), Some(pinned)
          if colour == game.to_move
        -> Ok(#(pinned, squares))
        Ok(board.Occupied(piece)), None if piece.colour == game.to_move ->
          get_sliding_pin_moves_loop(
            game,
            new_position,
            direction,
            [new_position, ..squares],
            Some(new_position),
          )
        Ok(board.Occupied(_)), _ -> Error(Nil)
        Error(_), _ -> Error(Nil)
      }
  }
}

type CheckLine {
  NoLine
  Single(List(Position))
  Multiple
}

fn get_check_block_line(game: Game, king_position: Position) -> CheckLine {
  let game = Game(..game, to_move: piece.reverse_colour(game.to_move))
  use line, square, position <- iv.index_fold(game.board, NoLine)

  case square {
    board.Occupied(piece) if piece.colour == game.to_move ->
      case piece.kind {
        Rook ->
          case
            line,
            get_sliding_lines(game, position, direction.rook_directions)
            |> list.filter(list.any(_, fn(move) { move.to == king_position }))
          {
            NoLine, [line] ->
              Single([position, ..list.map(line, fn(move) { move.to })])
            _, [] -> line
            _, _ -> Multiple
          }
        Bishop ->
          case
            line,
            get_sliding_lines(game, position, direction.bishop_directions)
            |> list.filter(list.any(_, fn(move) { move.to == king_position }))
          {
            NoLine, [line] ->
              Single([position, ..list.map(line, fn(move) { move.to })])
            _, [] -> line
            _, _ -> Multiple
          }
        Queen ->
          case
            line,
            get_sliding_lines(game, position, direction.queen_directions)
            |> list.filter(list.any(_, fn(move) { move.to == king_position }))
          {
            NoLine, [line] ->
              Single([position, ..list.map(line, fn(move) { move.to })])
            _, [] -> line
            _, _ -> Multiple
          }
        _ ->
          case
            line,
            get_attacks_for_piece(game, piece, position, [])
            |> list.contains(king_position)
          {
            _, False -> line
            NoLine, True -> Single([position])
            _, _ -> Multiple
          }
      }
    _ -> line
  }
}

pub fn do_legal(game: Game, attack_information: AttackInformation) -> List(Move) {
  use moves, square, position <- iv.index_fold(game.board, [])

  case square {
    board.Occupied(piece) if piece.colour == game.to_move ->
      get_moves_for_piece(game, attack_information, piece, position, moves)
    _ -> moves
  }
}

fn get_moves_for_piece(
  game: Game,
  attack_information: AttackInformation,
  piece: piece.Piece,
  position: Position,
  moves: List(Move),
) -> List(Move) {
  case piece.kind {
    Bishop ->
      get_sliding_moves(
        game,
        position,
        direction.bishop_directions,
        attack_information,
        moves,
      )
    Queen ->
      get_sliding_moves(
        game,
        position,
        direction.queen_directions,
        attack_information,
        moves,
      )
    Rook ->
      get_sliding_moves(
        game,
        position,
        direction.rook_directions,
        attack_information,
        moves,
      )
    King -> get_king_moves(game, attack_information, position, moves)
    Pawn -> get_pawn_moves(game, position, attack_information, moves)
    Knight -> get_knight_moves(game, position, attack_information, moves)
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
      case iv.get(game.board, to) {
        Error(_) -> Error(Nil)
        Ok(board.Empty) -> Ok(Move(from:, to:))
        Ok(board.Occupied(Piece(colour:, ..)))
          if colour != game.to_move && allow_captures
        -> Ok(Move(from:, to:))
        _ -> Error(Nil)
      }
  }
}

fn get_sliding_moves(
  game: Game,
  position: Position,
  directions: List(Direction),
  attack_information: AttackInformation,
  moves: List(Move),
) -> List(Move) {
  directions
  |> list.fold(moves, fn(moves, direction) {
    get_sliding_moves_loop(
      game,
      position,
      position,
      direction,
      attack_information,
      moves,
    )
  })
}

fn get_sliding_moves_loop(
  game: Game,
  original_position: Position,
  position: Position,
  direction: Direction,
  attack_information: AttackInformation,
  moves: List(Move),
) -> List(Move) {
  case direction.in_direction(position, direction) {
    Error(_) -> moves
    Ok(new_position) ->
      case iv.get(game.board, new_position) {
        Ok(board.Occupied(Piece(colour:, ..))) if colour != game.to_move -> {
          let move = Move(from: original_position, to: new_position)
          case piece_can_move(move, attack_information) {
            False -> moves
            True -> [Basic(move), ..moves]
          }
        }
        Ok(board.Empty) -> {
          let move = Move(from: original_position, to: new_position)
          let moves = case piece_can_move(move, attack_information) {
            False -> moves
            True -> [Basic(move), ..moves]
          }
          get_sliding_moves_loop(
            game,
            original_position,
            new_position,
            direction,
            attack_information,
            moves,
          )
        }
        _ -> moves
      }
  }
}

fn get_sliding_lines(
  game: Game,
  position: Position,
  directions: List(Direction),
) -> List(List(BasicMove)) {
  list.map(directions, get_sliding_lines_loop(game, position, position, _, []))
}

fn get_sliding_lines_loop(
  game: Game,
  original_position: Position,
  position: Position,
  direction: Direction,
  moves: List(BasicMove),
) -> List(BasicMove) {
  case direction.in_direction(position, direction) {
    Error(_) -> moves
    Ok(new_position) ->
      case iv.get(game.board, new_position) {
        Ok(board.Occupied(Piece(colour:, ..))) if colour != game.to_move -> [
          Move(from: original_position, to: new_position),
          ..moves
        ]
        Ok(board.Empty) ->
          get_sliding_lines_loop(
            game,
            original_position,
            new_position,
            direction,
            [Move(from: original_position, to: new_position), ..moves],
          )
        _ -> moves
      }
  }
}

fn king_can_move(move: BasicMove, attack_information: AttackInformation) -> Bool {
  case attack_information.in_check {
    False -> !list.contains(attack_information.attacks, move.to)
    True ->
      !list.any(attack_information.check_attack_lines, list.contains(_, move.to))
      && !list.contains(attack_information.attacks, move.to)
  }
}

fn get_king_moves(
  game: Game,
  attack_information: AttackInformation,
  position: Position,
  moves: List(Move),
) -> List(Move) {
  let moves =
    direction.queen_directions
    |> list.fold(moves, fn(moves, direction) {
      case maybe_move(game, position, direction, True) {
        Error(_) -> moves
        Ok(move) ->
          case king_can_move(move, attack_information) {
            True -> [Basic(move), ..moves]
            False -> moves
          }
      }
    })
  case attack_information.in_check {
    True -> moves
    False -> get_castling_moves(game, attack_information, moves)
  }
}

fn get_castling_moves(
  game: Game,
  attack_information: AttackInformation,
  moves: List(Move),
) -> List(Move) {
  let is_free = fn(position) {
    case iv.get(game.board, position) {
      Ok(board.Empty) -> !list.contains(attack_information.attacks, position)
      _ -> False
    }
  }

  let moves = case game.to_move {
    Black if game.castling.black_kingside ->
      case
        iv.get(game.board, 60),
        is_free(61),
        is_free(62),
        iv.get(game.board, 63)
      {
        Ok(board.Occupied(Piece(Black, King))),
          True,
          True,
          Ok(board.Occupied(Piece(Black, Rook)))
        -> [ShortCastle, ..moves]
        _, _, _, _ -> moves
      }
    White if game.castling.white_kingside ->
      case
        iv.get(game.board, 4),
        is_free(5),
        is_free(6),
        iv.get(game.board, 7)
      {
        Ok(board.Occupied(Piece(White, King))),
          True,
          True,
          Ok(board.Occupied(Piece(White, Rook)))
        -> [ShortCastle, ..moves]
        _, _, _, _ -> moves
      }
    _ -> moves
  }
  case game.to_move {
    Black if game.castling.black_queenside ->
      case
        iv.get(game.board, 60),
        is_free(59),
        is_free(58),
        iv.get(game.board, 57),
        iv.get(game.board, 56)
      {
        Ok(board.Occupied(Piece(Black, King))),
          True,
          True,
          Ok(board.Empty),
          Ok(board.Occupied(Piece(Black, Rook)))
        -> [LongCastle, ..moves]
        _, _, _, _, _ -> moves
      }
    White if game.castling.white_queenside ->
      case
        iv.get(game.board, 4),
        is_free(3),
        is_free(2),
        iv.get(game.board, 1),
        iv.get(game.board, 0)
      {
        Ok(board.Occupied(Piece(White, King))),
          True,
          True,
          Ok(board.Empty),
          Ok(board.Occupied(Piece(White, Rook)))
        -> [LongCastle, ..moves]
        _, _, _, _, _ -> moves
      }
    _ -> moves
  }
}

fn get_knight_moves(
  game: Game,
  position: Position,
  attack_information: AttackInformation,
  moves: List(Move),
) -> List(Move) {
  direction.knight_directions
  |> list.fold(moves, fn(moves, direction) {
    case maybe_move(game, position, direction, True) {
      Error(_) -> moves
      Ok(move) ->
        case piece_can_move(move, attack_information) {
          True -> [Basic(move), ..moves]
          False -> moves
        }
    }
  })
}

fn add_pawn_moves(
  move: BasicMove,
  to_move: piece.Colour,
  moves: List(Move),
) -> List(Move) {
  case to_move, move.to / 8 {
    Black, 0 | White, 7 ->
      piece.promotion_kinds
      |> list.fold(moves, fn(moves, new_kind) {
        [Promotion(move:, new_kind:), ..moves]
      })
    _, _ -> [Basic(move), ..moves]
  }
}

fn get_pawn_moves(
  game: Game,
  position: Position,
  attack_information: AttackInformation,
  moves: List(Move),
) -> List(Move) {
  let #(direction, take_left, take_right) = case game.to_move {
    Black -> #(direction.down, direction.down_left, direction.down_right)
    White -> #(direction.up, direction.up_left, direction.up_right)
  }

  let can_double_move = case game.to_move, position / 8 {
    Black, 6 | White, 1 -> True
    _, _ -> False
  }

  let moves =
    moves
    |> pawn_capture(game, position, take_left, attack_information)
    |> pawn_capture(game, position, take_right, attack_information)

  case maybe_move(game, position, direction, False) {
    Ok(move) -> {
      let moves = case piece_can_move(move, attack_information) {
        False -> moves
        True -> add_pawn_moves(move, game.to_move, moves)
      }
      case can_double_move {
        False -> moves
        True ->
          case
            maybe_move(game, position, direction.multiply(direction, 2), False)
          {
            Error(_) -> moves
            Ok(move) ->
              case piece_can_move(move, attack_information) {
                False -> moves
                True -> add_pawn_moves(move, game.to_move, moves)
              }
          }
      }
    }
    Error(_) -> moves
  }
}

fn pawn_capture(
  moves: List(Move),
  game: Game,
  position: Position,
  direction: direction.Direction,
  attack_information: AttackInformation,
) -> List(Move) {
  case direction.in_direction(position, direction) {
    Error(_) -> moves
    Ok(to) ->
      case iv.get(game.board, to) {
        Ok(board.Occupied(Piece(colour:, ..))) if colour != game.to_move -> {
          let move = Move(from: position, to:)
          case piece_can_move(move, attack_information) {
            False -> moves
            True -> add_pawn_moves(move, game.to_move, moves)
          }
        }
        Ok(board.Empty) ->
          case check_for_en_passant(game, position, to, attack_information) {
            False -> moves
            True ->
              add_pawn_moves(Move(from: position, to:), game.to_move, moves)
          }
        _ -> moves
      }
  }
}

fn check_for_en_passant(
  game: Game,
  position: Position,
  target: Position,
  attack_information: AttackInformation,
) -> Bool {
  case game.en_passant == Some(target) {
    False -> False
    True -> {
      let captured_pawn = position / 8 * 8 + target % 8

      case attack_information.in_check {
        False -> !is_pinned(position, target, attack_information)
        True ->
          list.contains(attack_information.check_block_line, captured_pawn)
          && !is_pinned(position, target, attack_information)
      }
      && !in_check_after_en_passant(
        game,
        position,
        position / 8 * 8 + target % 8,
      )
    }
  }
}

type FoundPiece {
  NoPiece
  KingPiece
  EnemyPiece
  Both
}

fn sort(a: Position, b: Position) -> #(Position, Position) {
  case a % 8 < b % 8 {
    True -> #(a, b)
    False -> #(b, a)
  }
}

fn in_check_after_en_passant(
  game: Game,
  pawn_position: Position,
  captured_pawn_position: Position,
) -> Bool {
  let #(left_position, right_position) =
    sort(pawn_position, captured_pawn_position)

  case
    in_check_after_en_passant_loop(game, left_position, direction.left, NoPiece)
  {
    NoPiece | Both -> False
    found_piece ->
      in_check_after_en_passant_loop(
        game,
        right_position,
        direction.right,
        found_piece,
      )
      == Both
  }
}

fn in_check_after_en_passant_loop(
  game: Game,
  position: Position,
  direction: Direction,
  found_piece: FoundPiece,
) -> FoundPiece {
  case direction.in_direction(position, direction) {
    Error(_) -> found_piece
    Ok(new_position) ->
      case iv.get(game.board, new_position), found_piece {
        Error(_), _ -> found_piece
        Ok(board.Empty), _ ->
          in_check_after_en_passant_loop(
            game,
            new_position,
            direction,
            found_piece,
          )
        Ok(board.Occupied(Piece(kind: King, colour:))), NoPiece
          if colour == game.to_move
        -> KingPiece
        Ok(board.Occupied(Piece(kind: King, colour:))), EnemyPiece
          if colour == game.to_move
        -> Both
        Ok(board.Occupied(Piece(kind: Rook, colour:))), NoPiece
        | Ok(board.Occupied(Piece(kind: Queen, colour:))), NoPiece
          if colour != game.to_move
        -> EnemyPiece
        Ok(board.Occupied(Piece(kind: Rook, colour:))), KingPiece
        | Ok(board.Occupied(Piece(kind: Queen, colour:))), KingPiece
          if colour != game.to_move
        -> Both
        Ok(board.Occupied(_)), _ -> found_piece
      }
  }
}

fn attacks(game: Game) -> List(Position) {
  use positions, square, position <- iv.index_fold(game.board, [])

  case square {
    board.Occupied(piece) if piece.colour == game.to_move ->
      get_attacks_for_piece(game, piece, position, positions)
    _ -> positions
  }
}

fn get_attacks_for_piece(
  game: Game,
  piece: piece.Piece,
  position: Position,
  positions: List(Position),
) -> List(Position) {
  case piece.kind {
    Bishop ->
      get_sliding_attacks(
        game,
        position,
        direction.bishop_directions,
        positions,
      )
    Queen ->
      get_sliding_attacks(game, position, direction.queen_directions, positions)
    Rook ->
      get_sliding_attacks(game, position, direction.rook_directions, positions)
    King -> get_king_attacks(position, positions)
    Pawn -> get_pawn_attacks(game, position, positions)
    Knight -> get_knight_attacks(position, positions)
  }
}

fn get_sliding_attacks(
  game: Game,
  position: Position,
  directions: List(Direction),
  positions: List(Position),
) -> List(Position) {
  list.fold(directions, positions, fn(positions, direction) {
    get_sliding_attacks_loop(game, position, direction, positions)
  })
}

fn get_sliding_attacks_loop(
  game: Game,
  position: Position,
  direction: Direction,
  positions: List(Position),
) -> List(Position) {
  case direction.in_direction(position, direction) {
    Error(_) -> positions
    Ok(new_position) ->
      case iv.get(game.board, new_position) {
        Ok(board.Empty) ->
          get_sliding_attacks_loop(game, new_position, direction, [
            new_position,
            ..positions
          ])
        _ -> [new_position, ..positions]
      }
  }
}

fn get_king_attacks(
  position: Position,
  positions: List(Position),
) -> List(Position) {
  direction.queen_directions
  |> list.fold(positions, fn(positions, direction) {
    case direction.in_direction(position, direction) {
      Error(_) -> positions
      Ok(position) -> [position, ..positions]
    }
  })
}

fn get_knight_attacks(
  position: Position,
  positions: List(Position),
) -> List(Position) {
  direction.knight_directions
  |> list.fold(positions, fn(positions, direction) {
    case direction.in_direction(position, direction) {
      Error(_) -> positions
      Ok(position) -> [position, ..positions]
    }
  })
}

fn get_pawn_attacks(
  game: Game,
  position: Position,
  positions: List(Position),
) -> List(Position) {
  let take_directions = case game.to_move {
    Black -> [direction.down_left, direction.down_right]
    White -> [direction.up_left, direction.up_right]
  }
  take_directions
  |> list.fold(positions, fn(positions, direction) {
    case direction.in_direction(position, direction) {
      Error(_) -> positions
      Ok(position) -> [position, ..positions]
    }
  })
}

pub fn apply(game: Game, move: Move) -> Game {
  let game = case move {
    ShortCastle -> {
      let board = case game.to_move {
        Black ->
          game.board
          |> board.set(60, board.Empty)
          |> board.set(61, board.Occupied(Piece(Black, Rook)))
          |> board.set(62, board.Occupied(Piece(Black, King)))
          |> board.set(63, board.Empty)
        White ->
          game.board
          |> board.set(4, board.Empty)
          |> board.set(5, board.Occupied(Piece(White, Rook)))
          |> board.set(6, board.Occupied(Piece(White, King)))
          |> board.set(7, board.Empty)
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
          |> board.set(60, board.Empty)
          |> board.set(59, board.Occupied(Piece(Black, Rook)))
          |> board.set(58, board.Occupied(Piece(Black, King)))
          |> board.set(57, board.Empty)
          |> board.set(56, board.Empty)
        White ->
          game.board
          |> board.set(4, board.Empty)
          |> board.set(3, board.Occupied(Piece(White, Rook)))
          |> board.set(2, board.Occupied(Piece(White, King)))
          |> board.set(1, board.Empty)
          |> board.set(0, board.Empty)
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
  let newly_occupied = iv.get(game.board, move.to)
  let #(board, moved_piece) = case iv.get(game.board, move.from) {
    Error(_) -> #(game.board, board.Empty)
    Ok(square) -> {
      let square = case square, new_kind {
        board.Empty, _ | board.Occupied(_), None -> square
        board.Occupied(piece), Some(new_kind) ->
          board.Occupied(Piece(piece.colour, new_kind))
      }
      #(
        game.board
          |> board.set(move.to, square)
          |> board.set(move.from, board.Empty),
        square,
      )
    }
  }

  let was_capture = case newly_occupied {
    Ok(board.Occupied(_)) -> True
    _ -> False
  }

  let was_pawn_move = case moved_piece {
    board.Occupied(Piece(kind: Pawn, ..)) -> True
    _ -> False
  }

  let half_moves = case was_capture || was_pawn_move {
    False -> game.half_moves + 1
    True -> 0
  }

  let en_passant = case was_pawn_move, move.to / 8 - move.from / 8 {
    True, 2 -> Some(move.to - 8)
    True, -2 -> Some(move.to + 8)
    _, _ -> None
  }

  let board = case Some(move.to) == game.en_passant && was_pawn_move {
    False -> board
    True -> {
      let captured_pawn = move.from / 8 * 8 + move.to % 8
      board.set(board, captured_pawn, board.Empty)
    }
  }

  let castling = case moved_piece, move.from % 8 {
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

pub type MoveInfo {
  MoveInfo(
    moved_from: Position,
    moved_to: Position,
    moved_piece: piece.Piece,
    promotion: Option(piece.Piece),
    capture: Option(#(Position, piece.Piece)),
    new_en_passant_square: Option(Position),
    new_castling: game.Castling,
    reset_half_move_counter: Bool,
  )
}

pub fn info(game: Game, move: Move) -> Result(MoveInfo, Nil) {
  case move {
    Basic(move) -> Ok(basic_move_info(game, move, None))
    Promotion(move, new_kind) -> Ok(basic_move_info(game, move, Some(new_kind)))
    LongCastle | ShortCastle -> Error(Nil)
  }
}

fn basic_move_info(
  game: Game,
  move: BasicMove,
  new_kind: Option(piece.Kind),
) -> MoveInfo {
  let newly_occupied = iv.get_or_default(game.board, move.to, board.Empty)
  let #(moved_piece, promotion) = case iv.get(game.board, move.from) {
    Ok(board.Occupied(piece)) ->
      case new_kind {
        None -> #(piece, None)
        Some(new_kind) -> #(piece, Some(Piece(piece.colour, new_kind)))
      }
    _ -> #(Piece(game.to_move, Pawn), None)
  }

  let was_capture = case newly_occupied {
    board.Occupied(_) -> True
    _ -> False
  }

  let was_pawn_move = moved_piece.kind == Pawn

  let reset_half_move_counter = was_capture || was_pawn_move

  let en_passant = case was_pawn_move, move.to / 8 - move.from / 8 {
    True, 2 -> Some(move.to - 8)
    True, -2 -> Some(move.to + 8)
    _, _ -> None
  }

  let capture = case newly_occupied {
    board.Empty -> None
    board.Occupied(piece) -> Some(#(move.to, piece))
  }

  let capture = case Some(move.to) == game.en_passant && was_pawn_move {
    False -> capture
    True -> {
      let captured_pawn = move.from / 8 * 8 + move.to % 8
      Some(#(
        captured_pawn,
        Piece(colour: piece.reverse_colour(game.to_move), kind: Pawn),
      ))
    }
  }

  let castling = case moved_piece, move.from % 8 {
    Piece(White, piece.King), _ ->
      game.Castling(
        ..game.castling,
        white_kingside: False,
        white_queenside: False,
      )
    Piece(Black, piece.King), _ ->
      game.Castling(
        ..game.castling,
        black_kingside: False,
        black_queenside: False,
      )
    Piece(White, piece.Rook), 7 ->
      game.Castling(..game.castling, white_kingside: False)
    Piece(White, piece.Rook), 0 ->
      game.Castling(..game.castling, white_queenside: False)
    Piece(Black, piece.Rook), 7 ->
      game.Castling(..game.castling, black_kingside: False)
    Piece(Black, piece.Rook), 0 ->
      game.Castling(..game.castling, black_queenside: False)
    _, _ -> game.castling
  }

  MoveInfo(
    moved_from: move.from,
    moved_to: move.to,
    moved_piece:,
    promotion:,
    capture:,
    new_en_passant_square: en_passant,
    new_castling: castling,
    reset_half_move_counter:,
  )
}
