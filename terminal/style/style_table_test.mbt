///|
test "style table interns default at id 0 and dedups" {
  let table = @style.StyleTable::new()
  // The default style is pre-seeded at id 0.
  guard table.len() == 1 else {
    fail("fresh table should hold only the default")
  }
  let default = @style.CellStyle::new()
  guard table.intern(default) == @style.default_style_id else {
    fail("default style must intern to id 0")
  }
  guard table.len() == 1 else { fail("interning the default must not grow") }

  // A distinct style gets a fresh id; re-interning returns the same id.
  let bold = @style.CellStyle::new().apply_attribute(Bold)
  let bold_id = table.intern(bold)
  guard !bold_id.is_default() else { fail("bold must not be the default id") }
  guard table.len() == 2 else { fail("a new style should grow the table") }
  guard table.intern(bold) == bold_id else {
    fail("re-intern must be idempotent")
  }
  guard table.len() == 2 else { fail("re-intern must not grow") }

  // Round-trips back to the same value.
  guard table.get(bold_id) == bold else {
    fail("get must return the interned style")
  }
  guard table.get(@style.default_style_id) == default else {
    fail("id 0 must resolve to the default")
  }
}
