///|
/// Built once from the generated table. A case-insensitive hash map beats the
/// old linear scan ~7x on lookup, and `get_view` probes the byte view in place
/// so no normalized key is allocated. The generated names are already
/// lowercase, but the map folds case anyway, so callers need not normalize.
let x11_color_table : @cimap.CiStrMap[RGB] = @cimap.CiStrMap::from_entries(
  x11_color_entries,
)

///|
pub fn x11_color_lookup(value : BytesView) -> RGB? {
  let (start, end_) = trim_name_bounds(value)
  if start >= end_ {
    return None
  }
  x11_color_table.get_view(value[start:end_])
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
