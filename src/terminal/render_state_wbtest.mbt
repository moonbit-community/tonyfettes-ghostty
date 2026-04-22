///|
test "render state/internal fallback helpers stay safe" {
  let terminal = StreamTerminal::new()

  guard resolve_viewport_origin(terminal, 0, terminal.columns()) == None &&
    resolve_viewport_origin(terminal, terminal.rows(), 0) == None else {
    fail("expected zero-dimension viewport origin lookup to stay empty")
  }

  terminal.bridge().cursor.x = terminal.columns() + 1
  guard resolve_cursor_viewport(terminal) == (None, false) else {
    fail("expected invalid cursor point to have no viewport snapshot")
  }

  let missing_row = snapshot_render_row(terminal, terminal.rows() + 1)
  let missing_cells = snapshot_render_cells(terminal, terminal.rows() + 1, 2)
  guard missing_row == PageRowState::new() &&
    missing_cells.length() == 2 &&
    missing_cells[0].is_zero() &&
    missing_cells[1].is_zero() else {
    fail("expected out-of-range row snapshots to degrade safely")
  }

  terminal.deinit()
}

///|
test "render state/internal mismatch helpers report false or none" {
  let state = RenderState::new()
  state.row_states = [PageRowState::new()]
  guard !render_row_storage_matches(state, 1, 1) else {
    fail("expected missing row-cell storage to fail dimension check")
  }

  state.row_cells = [[]]
  guard !render_row_storage_matches(state, 1, 1) else {
    fail("expected wrong row width to fail dimension check")
  }

  guard !render_row_cells_equal([PageCellState::new()], []) else {
    fail("expected row-cell equality to reject mismatched lengths")
  }

  let first_palette = [RGB::new(1, 2, 3)]
  guard !render_palette_equals(first_palette, []) &&
    !render_palette_equals(first_palette, [RGB::new(4, 5, 6)]) else {
    fail("expected palette equality to reject mismatched lengths and values")
  }

  guard render_cell_at(state, -1, 0) == None &&
    render_cell_at(state, 0, 0) == None &&
    render_cell_background_color_at(state, 0, 0) == None &&
    render_cell_foreground_color_at(state, 0, 0) == None else {
    fail("expected invalid cell access to stay empty")
  }
}
