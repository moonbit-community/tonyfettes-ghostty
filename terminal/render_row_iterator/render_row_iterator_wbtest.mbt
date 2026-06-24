///|
// Bounds safety of the snapshot accessors: a row present in `row_states` but
// with no matching `row_cells` entry (and out-of-range indices) must resolve to
// `None` rather than abort. Mirrors the invalid-cell-access checks that lived in
// the hub render-state white-box test before the iterator moved here.
test "render row iterator/invalid cell access stays empty" {
  let snap : RenderSnapshot = {
    row_states: [@page.PageRowState::new()],
    row_cells: [[]],
    row_link_ids: [None],
    style_table: @style.StyleTable::new(),
    grapheme_table: @page.GraphemeTable::new(),
    hyperlink_table: @hyperlink.HyperlinkTable::new(),
    palette: [],
  }
  guard render_cell_at(snap, -1, 0) == None &&
    render_cell_at(snap, 0, 0) == None &&
    render_cell_background_color_at(snap, 0, 0) == None &&
    render_cell_foreground_color_at(snap, 0, 0) == None else {
    fail("expected invalid cell access to stay empty")
  }
}

///|
// A snapshot whose parallel `row_link_ids` is shorter than `row_cells` (a
// hyperlink cell with no matching link entry) must degrade to "no link" rather
// than abort — `new` does not enforce the parallel-array invariant, so the
// accessor guards the indexing itself.
test "render row iterator/out-of-sync link ids degrade to no link" {
  let snap : RenderSnapshot = {
    row_states: [@page.PageRowState::new()],
    row_cells: [[@page.PageCellState::new(hyperlink_present=true)]],
    row_link_ids: [], // intentionally shorter than row_cells
    style_table: @style.StyleTable::new(),
    grapheme_table: @page.GraphemeTable::new(),
    hyperlink_table: @hyperlink.HyperlinkTable::new(),
    palette: [],
  }
  guard render_cell_hyperlink_at(snap, 0, 0) == None else {
    fail("expected out-of-sync hyperlink lookup to report no link")
  }
}
