import chess/board.{type Position}
import chess/game
import chess/move.{type Move}
import chess/piece
import engine/hash
import engine/table
import gleam/option.{type Option, None, Some}
import iv

pub type Positions {
  Positions(white: Position, black: Position)
}

/// Extra information about game state, so it doesn't need to be recalculated
/// every time.
pub type Game {
  Game(
    game: game.Game,
    attack_information: Option(move.AttackInformation),
    legal_moves: Option(List(Move)),
    captures: Option(List(Move)),
    hash_data: hash.HashData,
    piece_tables: table.PieceTables,
    zobrist_hash: Int,
    king_positions: Positions,
  )
}

/// Calculate initial information to be stored
pub fn new(
  game: game.Game,
  hash_data: hash.HashData,
  tables: table.PieceTables,
) -> Game {
  let king_positions = find_kings(game.board)

  Game(
    game:,
    attack_information: None,
    legal_moves: None,
    captures: None,
    zobrist_hash: hash.hash_position(game, hash_data),
    hash_data:,
    piece_tables: tables,
    king_positions:,
  )
}

fn find_kings(board: iv.Array(board.Square)) -> Positions {
  use positions, square, position <- iv.index_fold(board, Positions(0, 0))
  case square {
    board.Occupied(piece.Piece(kind: piece.King, colour: piece.White)) ->
      Positions(white: position, black: positions.black)
    board.Occupied(piece.Piece(kind: piece.King, colour: piece.Black)) ->
      Positions(white: positions.white, black: position)
    _ -> positions
  }
}

/// Apply a move to the game, updating relevant information if necessary
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
    Ok(info) -> hash.update(game.zobrist_hash, info, game.hash_data)
    // If the move isn't a basic move (e.g. castling), we can't easily update
    // the hash so we must recalculate it
    Error(_) -> hash.hash_position(board, game.hash_data)
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

/// Get or recalculate information about which squares are attacked on the board
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

/// Get or recalculate the current legal moves on the board
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

/// Get or recalculate available captures on the board
pub fn captures(game: Game) -> #(Game, List(Move)) {
  case game.captures {
    Some(captures) -> #(game, captures)
    None -> {
      let #(game, information) = attack_information(game)
      let captures = move.do_legal(game.game, information, move.OnlyCaptures)
      #(Game(..game, captures: Some(captures)), captures)
    }
  }
}
