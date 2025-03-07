import chess/board.{type Position, Position}
import chess/game.{type Game, Game}
import chess/move/direction.{type Direction}
import chess/piece.{Bishop, Black, King, Knight, Pawn, Piece, Queen, Rook, White}
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

type AttackInformation {
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

pub fn legal(game: Game) -> List(Move) {
  let attacks =
    attacks(Game(..game, to_move: piece.reverse_colour(game.to_move)))

  let king_position =
    dict.fold(game.board, Position(0, 0), fn(acc, position, square) {
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

  let attack_information =
    AttackInformation(
      attacks:,
      in_check:,
      check_attack_lines:,
      check_block_line:,
      pin_lines:,
    )

  do_legal(game, attack_information)
}

fn get_check_attack_lines(game: Game) -> List(List(Position)) {
  use lines, position, square <- dict.fold(game.board, [])
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
      case dict.get(game.board, new_position) {
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
  use lines, position, square <- dict.fold(game.board, dict.new())
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
      case dict.get(game.board, new_position), pinned_piece {
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
  use line, position, square <- dict.fold(game.board, NoLine)
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
            get_moves_for_piece(
              game,
              AttackInformation(
                attacks: [],
                in_check: False,
                check_attack_lines: [],
                check_block_line: [],
                pin_lines: dict.new(),
              ),
              piece,
              position,
            )
            |> list.any(fn(move) {
              case move {
                Basic(Move(to:, ..)) | Promotion(Move(to:, ..), ..) ->
                  to == king_position
                _ -> False
              }
            })
          {
            _, False -> line
            NoLine, True -> Single([position])
            _, _ -> Multiple
          }
      }
    _ -> line
  }
}

fn do_legal(game: Game, attack_information: AttackInformation) -> List(Move) {
  use moves, position, square <- dict.fold(game.board, [])
  case square {
    board.Occupied(piece) if piece.colour == game.to_move ->
      list.append(
        get_moves_for_piece(game, attack_information, piece, position),
        moves,
      )
    _ -> moves
  }
}

fn get_moves_for_piece(
  game: Game,
  attack_information: AttackInformation,
  piece: piece.Piece,
  position: Position,
) -> List(Move) {
  case piece.kind {
    Bishop ->
      get_sliding_moves(
        game,
        position,
        direction.bishop_directions,
        attack_information,
      )
    Queen ->
      get_sliding_moves(
        game,
        position,
        direction.queen_directions,
        attack_information,
      )
    Rook ->
      get_sliding_moves(
        game,
        position,
        direction.rook_directions,
        attack_information,
      )
    King -> get_king_moves(game, attack_information, position)
    Pawn -> get_pawn_moves(game, position, attack_information)
    Knight -> get_knight_moves(game, position, attack_information)
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
  attack_information: AttackInformation,
) -> List(Move) {
  get_sliding_lines(game, position, directions)
  |> list.flat_map(
    list.filter_map(_, fn(move) {
      case piece_can_move(move, attack_information) {
        True -> Ok(Basic(move))
        False -> Error(Nil)
      }
    }),
  )
}

fn get_sliding_lines(
  game: Game,
  position: Position,
  directions: List(Direction),
) -> List(List(BasicMove)) {
  list.map(directions, get_sliding_moves_loop(game, position, position, _, []))
}

fn get_sliding_moves_loop(
  game: Game,
  original_position: Position,
  position: Position,
  direction: Direction,
  moves: List(BasicMove),
) -> List(BasicMove) {
  case direction.in_direction(position, direction) {
    Error(_) -> moves
    Ok(new_position) ->
      case
        dict.get(game.board, new_position)
        |> result.map(move_validity(_, game.to_move))
      {
        Error(_) | Ok(Invalid) -> moves
        Ok(ValidThenStop) -> [
          Move(from: original_position, to: new_position),
          ..moves
        ]
        Ok(Valid) ->
          get_sliding_moves_loop(
            game,
            original_position,
            new_position,
            direction,
            [Move(from: original_position, to: new_position), ..moves],
          )
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
) -> List(Move) {
  let king_moves =
    direction.queen_directions
    |> list.filter_map(fn(direction) {
      case maybe_move(game, position, direction, True) {
        Error(_) -> Error(Nil)
        Ok(move) ->
          case king_can_move(move, attack_information) {
            True -> Ok(Basic(move))
            False -> Error(Nil)
          }
      }
    })
  case attack_information.in_check {
    True -> king_moves
    False ->
      list.append(king_moves, get_castling_moves(game, attack_information))
  }
}

fn get_castling_moves(
  game: Game,
  attack_information: AttackInformation,
) -> List(Move) {
  let is_free = fn(position) {
    case dict.get(game.board, position) {
      Ok(board.Empty) -> !list.contains(attack_information.attacks, position)
      _ -> False
    }
  }

  let moves = case game.to_move {
    Black if game.castling.black_kingside ->
      case
        dict.get(game.board, Position(4, 7)),
        is_free(Position(5, 7)),
        is_free(Position(6, 7)),
        dict.get(game.board, Position(7, 7))
      {
        Ok(board.Occupied(Piece(Black, King))),
          True,
          True,
          Ok(board.Occupied(Piece(Black, Rook)))
        -> [ShortCastle]
        _, _, _, _ -> []
      }
    White if game.castling.white_kingside ->
      case
        dict.get(game.board, Position(4, 0)),
        is_free(Position(5, 0)),
        is_free(Position(6, 0)),
        dict.get(game.board, Position(7, 0))
      {
        Ok(board.Occupied(Piece(White, King))),
          True,
          True,
          Ok(board.Occupied(Piece(White, Rook)))
        -> [ShortCastle]
        _, _, _, _ -> []
      }
    _ -> []
  }
  case game.to_move {
    Black if game.castling.black_queenside ->
      case
        dict.get(game.board, Position(4, 7)),
        is_free(Position(3, 7)),
        is_free(Position(2, 7)),
        dict.get(game.board, Position(1, 7)),
        dict.get(game.board, Position(0, 7))
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
        dict.get(game.board, Position(4, 0)),
        is_free(Position(3, 0)),
        is_free(Position(2, 0)),
        dict.get(game.board, Position(1, 0)),
        dict.get(game.board, Position(0, 0))
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
) -> List(Move) {
  direction.knight_directions
  |> list.filter_map(fn(direction) {
    case maybe_move(game, position, direction, True) {
      Error(_) -> Error(Nil)
      Ok(move) ->
        case piece_can_move(move, attack_information) {
          True -> Ok(Basic(move))
          False -> Error(Nil)
        }
    }
  })
}

fn get_pawn_moves(
  game: Game,
  position: Position,
  attack_information: AttackInformation,
) -> List(Move) {
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
              case move_validity(square, game.to_move) == ValidThenStop {
                True -> Ok(Move(from: position, to:))
                False ->
                  case game.en_passant == Some(to) {
                    False -> Error(Nil)
                    True ->
                      case
                        in_check_after_en_passant(
                          game,
                          position,
                          Position(rank: position.rank, file: to.file),
                        )
                      {
                        True -> Error(Nil)
                        False -> Ok(Move(from: position, to:))
                      }
                  }
              }
          }
      }
    })

  let moves = case
    maybe_move(game, position, direction, False),
    can_double_move
  {
    Ok(move), False -> [move, ..moves]
    Ok(single_move), True ->
      case maybe_move(game, position, direction.multiply(direction, 2), False) {
        Error(_) -> [single_move, ..moves]
        Ok(double_move) -> [single_move, double_move, ..moves]
      }
    Error(_), _ -> moves
  }

  list.flat_map(moves, fn(move) {
    case piece_can_move(move, attack_information) {
      False -> []
      True ->
        case game.to_move, move.to.rank {
          Black, 0 | White, 7 ->
            piece.promotion_kinds |> list.map(Promotion(move, _))
          _, _ -> [Basic(move)]
        }
    }
  })
}

type FoundPiece {
  NoPiece
  KingPiece
  EnemyPiece
  Both
}

fn sort(a: Position, b: Position) -> #(Position, Position) {
  case a.file < b.file {
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
      case dict.get(game.board, new_position), found_piece {
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
  use positions, position, square <- dict.fold(game.board, [])
  case square {
    board.Occupied(piece) if piece.colour == game.to_move ->
      list.append(get_attacks_for_piece(game, piece, position), positions)
    _ -> positions
  }
}

fn get_attacks_for_piece(
  game: Game,
  piece: piece.Piece,
  position: Position,
) -> List(Position) {
  case piece.kind {
    Bishop -> get_sliding_attacks(game, position, direction.bishop_directions)
    Queen -> get_sliding_attacks(game, position, direction.queen_directions)
    Rook -> get_sliding_attacks(game, position, direction.rook_directions)
    King -> get_king_attacks(position)
    Pawn -> get_pawn_attacks(game, position)
    Knight -> get_knight_attacks(position)
  }
}

fn get_sliding_attacks(
  game: Game,
  position: Position,
  directions: List(Direction),
) -> List(Position) {
  list.flat_map(directions, get_sliding_attacks_loop(game, position, _, []))
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
      case
        dict.get(game.board, new_position)
        |> result.map(move_validity(_, game.to_move))
      {
        Ok(Valid) ->
          get_sliding_attacks_loop(game, new_position, direction, [
            new_position,
            ..positions
          ])
        _ -> [new_position, ..positions]
      }
  }
}

fn get_king_attacks(position: Position) -> List(Position) {
  direction.queen_directions
  |> list.filter_map(direction.in_direction(position, _))
}

fn get_knight_attacks(position: Position) -> List(Position) {
  direction.knight_directions
  |> list.filter_map(direction.in_direction(position, _))
}

fn get_pawn_attacks(game: Game, position: Position) -> List(Position) {
  let take_directions = case game.to_move {
    Black -> [direction.down_left, direction.down_right]
    White -> [direction.up_left, direction.up_right]
  }
  take_directions |> list.filter_map(direction.in_direction(position, _))
}

pub fn apply(game: Game, move: Move) -> Game {
  let game = case move {
    ShortCastle -> {
      let board = case game.to_move {
        Black ->
          game.board
          |> dict.insert(Position(4, 7), board.Empty)
          |> dict.insert(Position(5, 7), board.Occupied(Piece(Black, Rook)))
          |> dict.insert(Position(6, 7), board.Occupied(Piece(Black, King)))
          |> dict.insert(Position(7, 7), board.Empty)
        White ->
          game.board
          |> dict.insert(Position(4, 0), board.Empty)
          |> dict.insert(Position(5, 0), board.Occupied(Piece(White, Rook)))
          |> dict.insert(Position(6, 0), board.Occupied(Piece(White, King)))
          |> dict.insert(Position(7, 0), board.Empty)
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
          |> dict.insert(Position(4, 7), board.Empty)
          |> dict.insert(Position(3, 7), board.Occupied(Piece(Black, Rook)))
          |> dict.insert(Position(2, 7), board.Occupied(Piece(Black, King)))
          |> dict.insert(Position(1, 7), board.Empty)
          |> dict.insert(Position(0, 7), board.Empty)
        White ->
          game.board
          |> dict.insert(Position(4, 0), board.Empty)
          |> dict.insert(Position(3, 0), board.Occupied(Piece(White, Rook)))
          |> dict.insert(Position(2, 0), board.Occupied(Piece(White, King)))
          |> dict.insert(Position(1, 0), board.Empty)
          |> dict.insert(Position(0, 0), board.Empty)
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
    board.Occupied(Piece(kind: Pawn, ..)) -> True
    _ -> False
  }

  let half_moves = case was_capture || was_pawn_move {
    False -> game.half_moves + 1
    True -> 0
  }

  let en_passant = case was_pawn_move, move.to.rank - move.from.rank {
    True, 2 -> Some(Position(file: move.to.file, rank: move.to.rank - 1))
    True, -2 -> Some(Position(file: move.to.file, rank: move.to.rank + 1))
    _, _ -> None
  }

  let board = case Some(move.to) == game.en_passant && was_pawn_move {
    False -> board
    True -> {
      let captured_pawn = Position(file: move.to.file, rank: move.from.rank)
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
