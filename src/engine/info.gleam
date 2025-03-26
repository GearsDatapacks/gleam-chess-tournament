import chess/game
import chess/move.{type Move}
import engine/hash
import gleam/option.{type Option, None, Some}

pub type Game {
  Game(
    game: game.Game,
    attack_information: Option(move.AttackInformation),
    legal_moves: Option(List(Move)),
    hash_data: hash.HashData,
    zobrist_hash: Int,
  )
}

pub fn new(game: game.Game) -> Game {
  let hash_data = hash.generate_data()
  Game(
    game:,
    attack_information: None,
    legal_moves: None,
    zobrist_hash: hash.hash_position(game, hash_data),
    hash_data:,
  )
}

pub fn apply_move(game: Game, move: Move) -> Game {
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
  )
}

pub fn attack_information(game: Game) -> #(Game, move.AttackInformation) {
  case game.attack_information {
    Some(information) -> #(game, information)
    None -> {
      let information = move.attack_information(game.game)
      #(Game(..game, attack_information: Some(information)), information)
    }
  }
}

pub fn legal(game: Game) -> #(Game, List(Move)) {
  case game.legal_moves {
    Some(moves) -> #(game, moves)
    None -> {
      let #(game, information) = attack_information(game)
      let moves = move.do_legal(game.game, information)
      #(Game(..game, legal_moves: Some(moves)), moves)
    }
  }
}
