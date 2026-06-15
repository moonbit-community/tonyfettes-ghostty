///|
pub fn x11_color_lookup(value : BytesView) -> RGB? {
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
fn trim_name_bounds(input : BytesView) -> (Int, Int) {
  let mut start = 0
  let mut end_ = input.length()
  while start < end_ && input[start] == b' ' {
    start += 1
  }
  while end_ > start && input[end_ - 1] == b' ' {
    end_ -= 1
  }
  (start, end_)
}

///|
fn ascii_equals_ignore_case(
  input : BytesView,
  start : Int,
  expected : String,
) -> Bool {
  let mut i = 0
  while i < expected.length() {
    if ascii_lower(input[start + i]).to_int() != expected[i].to_int() {
      return false
    }
    i += 1
  }
  true
}

///|
fn ascii_lower(value : Byte) -> Byte {
  if value >= b'A' && value <= b'Z' {
    (value.to_int() - b'A'.to_int() + b'a'.to_int()).to_byte()
  } else {
    value
  }
}
