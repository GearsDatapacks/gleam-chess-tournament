//// A reimplementation of several `gleam/list` functions for improved performance.
//// Includes functions such as map without reversing the list at the end, when 
//// order preservation is not necessary.

import gleam/list
import gleam/order

pub fn contains(list: List(a), value: a) -> Bool {
  case list {
    [] -> False
    [first, ..] if first == value -> True
    [_, ..list] -> contains(list, value)
  }
}

pub fn find_map(list: List(a), f: fn(a) -> Result(b, c)) -> Result(b, Nil) {
  case list {
    [] -> Error(Nil)
    [first, ..rest] ->
      case f(first) {
        Error(_) -> find_map(rest, f)
        Ok(value) -> Ok(value)
      }
  }
}

pub fn any(list: List(a), f: fn(a) -> Bool) -> Bool {
  case list {
    [] -> False
    [first, ..rest] ->
      case f(first) {
        True -> True
        False -> any(rest, f)
      }
  }
}

/// Maps a list with a function, while reversing the list. This is faster than
/// `gleam/list.map` as the recursive algorithm already reverses it, so no extra
/// reverse is required at the end.
pub fn map_reverse(list: List(a), f: fn(a) -> b) -> List(b) {
  do_map_reverse(list, f, [])
}

fn do_map_reverse(list: List(a), f: fn(a) -> b, acc: List(b)) -> List(b) {
  case list {
    [] -> acc
    [first, ..rest] -> do_map_reverse(rest, f, [f(first), ..acc])
  }
}

/// Filters a list while reversing it. Similar to `reverse_map`, this is more
/// efficient than preserving the order.
pub fn filter_reverse(list: List(a), f: fn(a) -> Bool) -> List(a) {
  do_filter_reverse(list, f, [])
}

fn do_filter_reverse(list: List(a), f: fn(a) -> Bool, acc: List(a)) -> List(a) {
  case list {
    [] -> acc
    [first, ..rest] ->
      case f(first) {
        True -> do_filter_reverse(rest, f, [first, ..acc])
        False -> do_filter_reverse(rest, f, acc)
      }
  }
}

/// Just like `filter_reverse` and `map_reverse`, this is more efficient that
/// a regular `filter_map`, when order is not needed.
pub fn filter_map_reverse(list: List(a), f: fn(a) -> Result(b, c)) -> List(b) {
  do_filter_map_reverse(list, f, [])
}

fn do_filter_map_reverse(
  list: List(a),
  f: fn(a) -> Result(b, c),
  acc: List(b),
) -> List(b) {
  case list {
    [] -> acc
    [first, ..rest] ->
      case f(first) {
        Ok(value) -> do_filter_map_reverse(rest, f, [value, ..acc])
        Error(_) -> do_filter_map_reverse(rest, f, acc)
      }
  }
}

pub fn fold(list: List(a), acc: b, f: fn(b, a) -> b) -> b {
  case list {
    [] -> acc
    [first, ..rest] -> fold(rest, f(acc, first), f)
  }
}

pub fn sort(list: List(a), compare: fn(a, a) -> order.Order) -> List(a) {
  list.sort(list, compare)
}

pub fn length(list: List(a)) -> Int {
  do_length(list, 0)
}

fn do_length(list: List(a), count: Int) -> Int {
  case list {
    [] -> count
    [_, ..list] -> do_length(list, count + 1)
  }
}
