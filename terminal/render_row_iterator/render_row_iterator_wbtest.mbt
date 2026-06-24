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
