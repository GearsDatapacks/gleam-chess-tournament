import chess/board.{type Position}

/// A direction along the board. This could be a cardinal direction such as left
/// or up, or even a direction which jumps squares, such as how a knight moves.
pub type Direction {
  Direction(file_change: Int, rank_change: Int)
}

/// Returns a position moved in a given direction, checking for it being within
/// the bounds of the board.
pub fn in_direction(
  position: Position,
  direction: Direction,
) -> Result(Position, Nil) {
  case
    position % 8 + direction.file_change,
    position / 8 + direction.rank_change
  {
    file, rank if file < 0 || rank < 0 -> Error(Nil)
    file, rank if file >= board.side_length || rank >= board.side_length ->
      Error(Nil)
    file, rank -> Ok(rank * 8 + file)
  }
}

/// Multiply a direction by a number, effectively getting the result of moving
/// in that direction multiple times.
pub fn multiply(direction: Direction, by: Int) -> Direction {
  Direction(
    file_change: direction.file_change * by,
    rank_change: direction.rank_change * by,
  )
}

pub const left = Direction(-1, 0)

pub const right = Direction(1, 0)

pub const up = Direction(0, 1)

pub const down = Direction(0, -1)

pub const up_left = Direction(-1, 1)

pub const down_left = Direction(-1, -1)

pub const up_right = Direction(1, 1)

pub const down_right = Direction(1, -1)

pub const rook_directions = [left, right, up, down]

pub const bishop_directions = [up_left, up_right, down_left, down_right]

pub const queen_directions = [
  left,
  right,
  up,
  down,
  up_left,
  up_right,
  down_left,
  down_right,
]

pub const knight_directions = [
  Direction(-1, -2),
  Direction(1, -2),
  Direction(-1, 2),
  Direction(1, 2),
  Direction(2, -1),
  Direction(2, 1),
  Direction(-2, -1),
  Direction(-2, 1),
]
