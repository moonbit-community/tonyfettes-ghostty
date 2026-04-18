///|
pub fn x11_color_lookup(value : String) -> RGB? {
  let (start, end_) = trim_name_bounds(value)
  if start >= end_ {
    return None
  }

  for i in 0..<x11_color_entries.length() {
    let entry = x11_color_entries[i]
    let name = entry.0
    if name.length() != end_ - start {
      continue
    }
    if ascii_equals_ignore_case(value, start, name) {
      return Some(entry.1)
    }
  }

  None
}

///|
fn trim_name_bounds(input : String) -> (Int, Int) {
  let mut start = 0
  let mut end_ = input.length()
  while start < end_ && input[start] == ' ' {
    start += 1
  }
  while end_ > start && input[end_ - 1] == ' ' {
    end_ -= 1
  }
  (start, end_)
}

///|
fn ascii_equals_ignore_case(
  input : String,
  start : Int,
  expected : String,
) -> Bool {
  let mut i = 0
  while i < expected.length() {
    if ascii_lower(input[start + i]) != expected[i] {
      return false
    }
    i += 1
  }
  true
}

///|
fn ascii_lower(value : UInt16) -> UInt16 {
  if value >= 'A' && value <= 'Z' {
    (value.to_int() - 'A'.to_int() + 'a'.to_int()).to_uint16()
  } else {
    value
  }
}
