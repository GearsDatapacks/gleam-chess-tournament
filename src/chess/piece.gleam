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
  case piece {
    Piece(White, King) -> "K"
    Piece(White, Queen) -> "Q"
    Piece(White, Bishop) -> "B"
    Piece(White, Knight) -> "N"
    Piece(White, Rook) -> "R"
    Piece(White, Pawn) -> "P"
    Piece(Black, King) -> "k"
    Piece(Black, Queen) -> "q"
    Piece(Black, Bishop) -> "b"
    Piece(Black, Knight) -> "n"
    Piece(Black, Rook) -> "r"
    Piece(Black, Pawn) -> "p"
  }
}

/// The types of pieces which a pawn can promote to
pub const promotion_kinds = [Queen, Bishop, Knight, Rook]

pub fn reverse_colour(colour: Colour) -> Colour {
  case colour {
    Black -> White
    White -> Black
  }
}
