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

pub fn map(list, f) {
  do_map(list, f, [])
}

fn do_map(list: List(a), f: fn(a) -> b, acc: List(b)) -> List(b) {
  case list {
    [] -> acc
    [first, ..rest] -> do_map(rest, f, [f(first), ..acc])
  }
}

pub fn filter(list, f) {
  do_filter(list, f, [])
}

fn do_filter(list, f, acc) {
  case list {
    [] -> acc
    [first, ..rest] ->
      case f(first) {
        True -> do_filter(rest, f, [first, ..acc])
        False -> do_filter(rest, f, acc)
      }
  }
}

pub fn filter_map(list, f) {
  do_filter_map(list, f, [])
}

fn do_filter_map(list, f, acc) {
  case list {
    [] -> acc
    [first, ..rest] ->
      case f(first) {
        Ok(value) -> do_filter_map(rest, f, [value, ..acc])
        Error(_) -> do_filter_map(rest, f, acc)
      }
  }
}

pub fn flat_map(list, f) {
  do_flat_map(list, f, [])
}

fn do_flat_map(list, f, acc) {
  case list {
    [] -> acc
    [first, ..rest] -> do_flat_map(rest, f, append(f(first), acc))
  }
}

pub fn append(a, b) {
  case a, b {
    [], other | other, [] -> other
    [first, ..a], b -> append(a, [first, ..b])
  }
}
