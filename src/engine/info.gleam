import chess/board.{type Positions, Positions}
import chess/game
import chess/move.{type Move}
import chess/piece
import engine/hash
import gleam/option.{type Option, None, Some}
import iv

pub type Game {
  Game(
    game: game.Game,
    attack_information: Option(move.AttackInformation),
    legal_moves: Option(List(Move)),
    hash_data: hash.HashData,
    zobrist_hash: Int,
    king_positions: Positions,
  )
}

pub fn new(game: game.Game) -> Game {
  let king_positions = find_kings(game.board)
  let hash_data = hash.generate_data()

  Game(
    game:,
    attack_information: None,
    legal_moves: None,
    zobrist_hash: hash.hash_position(game, hash_data),
    hash_data:,
    king_positions:,
  )
}

fn find_kings(board: board.Board) -> Positions {
  use positions, square, position <- iv.index_fold(board, Positions(0, 0))
  case square {
    board.Occupied(piece.Piece(kind: piece.King, colour: piece.White)) ->
      Positions(white: position, black: positions.black)
    board.Occupied(piece.Piece(kind: piece.King, colour: piece.Black)) ->
      Positions(white: positions.white, black: position)
    _ -> positions
  }
}

pub fn apply_move(game: Game, move: Move) -> Game {
  let Positions(white:, black:) = game.king_positions
  let king_positions = case move, game.game.to_move {
    move.Basic(move.Move(from:, to:)), piece.White if from == white ->
      Positions(white: to, black:)
    move.Basic(move.Move(from:, to:)), piece.Black if from == black ->
      Positions(white:, black: to)
    move.LongCastle, piece.White -> Positions(white: 2, black:)
    move.LongCastle, piece.Black -> Positions(white:, black: 58)
    move.ShortCastle, piece.White -> Positions(white: 6, black:)
    move.ShortCastle, piece.Black -> Positions(white:, black: 62)
    move.Basic(_), _ | move.Promotion(..), _ -> game.king_positions
  }

  let board = move.apply(game.game, move)
  let new_hash = case move.info(game.game, move) {
    Error(_) -> hash.hash_position(board, game.hash_data)
    Ok(info) -> hash.update(game.zobrist_hash, info, game.hash_data)
  }

  Game(
    ..game,
    game: board,
    attack_information: None,
    legal_moves: None,
    zobrist_hash: new_hash,
    king_positions:,
  )
}

pub fn attack_information(game: Game) -> #(Game, move.AttackInformation) {
  case game.attack_information {
    Some(information) -> #(game, information)
    None -> {
      let king_position = case game.game.to_move {
        piece.White -> game.king_positions.white
        piece.Black -> game.king_positions.black
      }
      let information = move.attack_information(game.game, king_position)
      #(Game(..game, attack_information: Some(information)), information)
    }
  }
}

pub fn legal(game: Game) -> #(Game, List(Move)) {
  case game.legal_moves {
    Some(moves) -> #(game, moves)
    None -> {
      let #(game, information) = attack_information(game)
      let moves = move.do_legal(game.game, information, move.AllMoves)
      #(Game(..game, legal_moves: Some(moves)), moves)
    }
  }
}

pub fn captures(game: Game) -> #(Game, List(Move)) {
  let #(game, attack_information) = attack_information(game)
  #(game, move.do_legal(game.game, attack_information, move.OnlyCaptures))
}
