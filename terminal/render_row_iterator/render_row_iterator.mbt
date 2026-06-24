///|
/// A render snapshot's per-row component arrays plus the intern tables and
/// palette needed to resolve cell styles, graphemes, hyperlinks, and colors.
///
/// `RenderState` (in the hub) captures these each `update` and hands them to
/// `RenderRowIterator::new`, so iteration resolves entirely from the snapshot
/// and never reaches back into the live terminal. The arrays are shared by
/// reference with the originating `RenderState`, so `set_dirty` writes back into
/// its `row_states` (the iterator is meant to be built and consumed within one
/// update cycle).
priv struct RenderSnapshot {
  row_states : Array[@page.PageRowState]
  row_cells : Array[FixedArray[@page.PageCellState]]
  row_link_ids : Array[FixedArray[@hyperlink.HyperlinkId]?]
  style_table : @style.StyleTable
  grapheme_table : @page.GraphemeTable
  hyperlink_table : @hyperlink.HyperlinkTable
  palette : Array[@color.RGB]
}

///|
struct RenderRowIterator {
  snapshot : RenderSnapshot
  mut y : Int
}

///|
struct RenderRowCells {
  snapshot : RenderSnapshot
  row : Int
  mut x : Int
}

///|
/// Build an iterator over a captured render snapshot. `RenderState::row_iterator`
/// is the sole caller; the component arrays are taken by reference so a later
/// `set_dirty` updates the originating state's `row_states`.
pub fn RenderRowIterator::new(
  row_states~ : Array[@page.PageRowState],
  row_cells~ : Array[FixedArray[@page.PageCellState]],
  row_link_ids~ : Array[FixedArray[@hyperlink.HyperlinkId]?],
  style_table~ : @style.StyleTable,
  grapheme_table~ : @page.GraphemeTable,
  hyperlink_table~ : @hyperlink.HyperlinkTable,
  palette~ : Array[@color.RGB],
) -> RenderRowIterator {
  {
    snapshot: {
      row_states,
      row_cells,
      row_link_ids,
      style_table,
      grapheme_table,
      hyperlink_table,
      palette,
    },
    y: -1,
  }
}

///|
pub fn RenderRowIterator::next(self : RenderRowIterator) -> Bool {
  let next_y = self.y + 1
  if next_y >= self.snapshot.row_states.length() {
    false
  } else {
    self.y = next_y
    true
  }
}

///|
pub fn RenderRowIterator::y(self : RenderRowIterator) -> @size.CellCountInt? {
  if self.y < 0 || self.y >= self.snapshot.row_states.length() {
    None
  } else {
    Some(self.y.to_uint16())
  }
}

///|
pub fn RenderRowIterator::row(self : RenderRowIterator) -> @page.PageRowState? {
  render_row_at(self.snapshot, self.y)
}

///|
pub fn RenderRowIterator::dirty(self : RenderRowIterator) -> Bool? {
  render_row_dirty_at(self.snapshot, self.y)
}

///|
pub fn RenderRowIterator::set_dirty(
  self : RenderRowIterator,
  value : Bool,
) -> Bool {
  render_set_row_dirty_at(self.snapshot, self.y, value)
}

///|
pub fn RenderRowIterator::cells(self : RenderRowIterator) -> RenderRowCells? {
  if self.y < 0 || self.y >= self.snapshot.row_states.length() {
    None
  } else {
    Some({ snapshot: self.snapshot, row: self.y, x: -1 })
  }
}

///|
pub fn RenderRowCells::next(self : RenderRowCells) -> Bool {
  let next_x = self.x + 1
  if self.row < 0 ||
    self.row >= self.snapshot.row_cells.length() ||
    next_x >= self.snapshot.row_cells[self.row].length() {
    false
  } else {
    self.x = next_x
    true
  }
}

///|
pub fn RenderRowCells::select(
  self : RenderRowCells,
  x : @size.CellCountInt,
) -> Bool {
  let x_idx = x.to_int()
  if self.row < 0 ||
    self.row >= self.snapshot.row_cells.length() ||
    x_idx < 0 ||
    x_idx >= self.snapshot.row_cells[self.row].length() {
    false
  } else {
    self.x = x_idx
    true
  }
}

///|
pub fn RenderRowCells::x(self : RenderRowCells) -> @size.CellCountInt? {
  if self.row < 0 ||
    self.row >= self.snapshot.row_cells.length() ||
    self.x < 0 ||
    self.x >= self.snapshot.row_cells[self.row].length() {
    None
  } else {
    Some(self.x.to_uint16())
  }
}

///|
pub fn RenderRowCells::cell(self : RenderRowCells) -> @page.PageCellState? {
  render_cell_at(self.snapshot, self.row, self.x)
}

///|
// The resolved style of the current cell, via the render snapshot's style table.
// Cells store only a `StyleId`, so style reads go through the table here.
pub fn RenderRowCells::cell_style(self : RenderRowCells) -> @style.CellStyle? {
  match render_cell_at(self.snapshot, self.row, self.x) {
    Some(cell) => Some(self.snapshot.style_table.get(cell.style_id()))
    None => None
  }
}

///|
// The resolved combining codepoints of the current cell, via the render
// snapshot's grapheme table. Empty when the cell is not a grapheme cluster.
pub fn RenderRowCells::cell_grapheme_codepoints(
  self : RenderRowCells,
) -> ReadOnlyArray[UInt] {
  match render_cell_at(self.snapshot, self.row, self.x) {
    Some(cell) => self.snapshot.grapheme_table.get(cell.grapheme_id())
    None => []
  }
}

///|
// The resolved hyperlink of the current cell, via the render snapshot's
// hyperlink table. `None` when the cell carries no link. The cell stores only a
// presence bit; the id is held in the snapshot's per-row `row_link_ids`, so this
// resolves from the snapshot alone (no live-terminal access), like `cell_style`.
pub fn RenderRowCells::cell_hyperlink(
  self : RenderRowCells,
) -> @hyperlink.CellHyperlink? {
  render_cell_hyperlink_at(self.snapshot, self.row, self.x)
}

///|
pub fn RenderRowCells::background_color(self : RenderRowCells) -> @color.RGB? {
  render_cell_background_color_at(self.snapshot, self.row, self.x)
}

///|
pub fn RenderRowCells::foreground_color(self : RenderRowCells) -> @color.RGB? {
  render_cell_foreground_color_at(self.snapshot, self.row, self.x)
}

// -- snapshot accessors ----------------------------------------------------

///|
fn render_row_at(snap : RenderSnapshot, row_idx : Int) -> @page.PageRowState? {
  if row_idx < 0 || row_idx >= snap.row_states.length() {
    None
  } else {
    Some(snap.row_states[row_idx])
  }
}

///|
fn render_row_dirty_at(snap : RenderSnapshot, row_idx : Int) -> Bool? {
  if row_idx < 0 || row_idx >= snap.row_states.length() {
    None
  } else {
    Some(snap.row_states[row_idx].dirty())
  }
}

///|
fn render_set_row_dirty_at(
  snap : RenderSnapshot,
  row_idx : Int,
  value : Bool,
) -> Bool {
  if row_idx < 0 || row_idx >= snap.row_states.length() {
    false
  } else {
    snap.row_states[row_idx] = snap.row_states[row_idx].with_dirty(value)
    true
  }
}

///|
fn render_cell_at(
  snap : RenderSnapshot,
  row_idx : Int,
  col_idx : Int,
) -> @page.PageCellState? {
  if row_idx < 0 || row_idx >= snap.row_cells.length() {
    return None
  }
  if col_idx < 0 || col_idx >= snap.row_cells[row_idx].length() {
    return None
  }
  Some(snap.row_cells[row_idx][col_idx])
}

///|
// The resolved hyperlink of the snapshot cell at (row, col), or `None` when it
// carries no link. Gated on the cell's presence bit (the snapshot's source of
// truth); the id comes from the parallel `row_link_ids` and resolves through the
// captured `hyperlink_table`, so no live-terminal access is needed.
fn render_cell_hyperlink_at(
  snap : RenderSnapshot,
  row_idx : Int,
  col_idx : Int,
) -> @hyperlink.CellHyperlink? {
  match render_cell_at(snap, row_idx, col_idx) {
    Some(cell) =>
      if cell.has_hyperlink() {
        // `render_cell_at` validated (row_idx, col_idx) against `row_cells`. The
        // parallel `row_link_ids` normally has the same shape, but `new` does not
        // enforce that, so guard the indexing here: a malformed snapshot degrades
        // to "no link" rather than aborting, keeping the iterator a safe host API.
        let id = if row_idx < snap.row_link_ids.length() {
          match snap.row_link_ids[row_idx] {
            Some(links) =>
              if col_idx < links.length() {
                links[col_idx]
              } else {
                @hyperlink.no_hyperlink_id
              }
            None => @hyperlink.no_hyperlink_id
          }
        } else {
          @hyperlink.no_hyperlink_id
        }
        snap.hyperlink_table.get(id)
      } else {
        None
      }
    None => None
  }
}

///|
fn render_cell_background_color_at(
  snap : RenderSnapshot,
  row_idx : Int,
  col_idx : Int,
) -> @color.RGB? {
  match render_cell_at(snap, row_idx, col_idx) {
    Some(cell) =>
      render_cell_background_color(
        snap.style_table.get(cell.style_id()),
        snap.palette,
      )
    None => None
  }
}

///|
fn render_cell_foreground_color_at(
  snap : RenderSnapshot,
  row_idx : Int,
  col_idx : Int,
) -> @color.RGB? {
  match render_cell_at(snap, row_idx, col_idx) {
    Some(cell) =>
      render_cell_foreground_color(
        snap.style_table.get(cell.style_id()),
        snap.palette,
      )
    None => None
  }
}

///|
fn render_cell_background_color(
  style : @style.CellStyle,
  palette : Array[@color.RGB],
) -> @color.RGB? {
  // Every cell keeps its background in the style now (no separate background
  // content kind), so this is just the style's resolved bg.
  style.bg_color_rgb(palette)
}

///|
fn render_cell_foreground_color(
  style : @style.CellStyle,
  palette : Array[@color.RGB],
) -> @color.RGB? {
  style.fg_rgb(palette)
}
