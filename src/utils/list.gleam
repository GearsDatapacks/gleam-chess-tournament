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

pub fn map(list: List(a), f: fn(a) -> b) -> List(b) {
  do_map(list, f, [])
}

fn do_map(list: List(a), f: fn(a) -> b, acc: List(b)) -> List(b) {
  case list {
    [] -> acc
    [first, ..rest] -> do_map(rest, f, [f(first), ..acc])
  }
}

pub fn filter(list: List(a), f: fn(a) -> Bool) -> List(a) {
  do_filter(list, f, [])
}

fn do_filter(list: List(a), f: fn(a) -> Bool, acc: List(a)) -> List(a) {
  case list {
    [] -> acc
    [first, ..rest] ->
      case f(first) {
        True -> do_filter(rest, f, [first, ..acc])
        False -> do_filter(rest, f, acc)
      }
  }
}

pub fn filter_map(list: List(a), f: fn(a) -> Result(b, c)) -> List(b) {
  do_filter_map(list, f, [])
}

fn do_filter_map(
  list: List(a),
  f: fn(a) -> Result(b, c),
  acc: List(b),
) -> List(b) {
  case list {
    [] -> acc
    [first, ..rest] ->
      case f(first) {
        Ok(value) -> do_filter_map(rest, f, [value, ..acc])
        Error(_) -> do_filter_map(rest, f, acc)
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
