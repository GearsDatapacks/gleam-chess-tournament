import gleam/string

pub type Piece {
  Piece(colour: Colour, kind: Kind)
}

pub type Colour {
  White
  Black
}

pub type Kind {
  King
  Queen
  Bishop
  Knight
  Rook
  Pawn
}

pub fn from_fen(fen: String) -> Result(Piece, Nil) {
  case fen {
    "K" -> Ok(Piece(White, King))
    "Q" -> Ok(Piece(White, Queen))
    "B" -> Ok(Piece(White, Bishop))
    "N" -> Ok(Piece(White, Knight))
    "R" -> Ok(Piece(White, Rook))
    "P" -> Ok(Piece(White, Pawn))
    "k" -> Ok(Piece(Black, King))
    "q" -> Ok(Piece(Black, Queen))
    "b" -> Ok(Piece(Black, Bishop))
    "n" -> Ok(Piece(Black, Knight))
    "r" -> Ok(Piece(Black, Rook))
    "p" -> Ok(Piece(Black, Pawn))
    _ -> Error(Nil)
  }
}

pub fn to_fen(piece: Piece) -> String {
  let kind = case piece.kind {
    Bishop -> "B"
    King -> "K"
    Knight -> "N"
    Pawn -> "P"
    Queen -> "Q"
    Rook -> "R"
  }

  case piece.colour {
    Black -> string.lowercase(kind)
    White -> kind
  }
}

pub const promotion_kinds = [Queen, Bishop, Knight, Rook]

pub fn reverse_colour(colour: Colour) -> Colour {
  case colour {
    Black -> White
    White -> Black
  }
}
