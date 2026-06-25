///|
pub(all) enum ScreenEraseLineMode {
  Right
  Left
  Complete
}

///|
pub(all) enum ScreenEraseDisplayMode {
  Below
  Above
  Complete
  ScrollComplete
}

///|
// A screen's rows are stored as two parallel arrays — `descs[i]` is row `i`'s
// descriptor and `cells[i]` is the `cols`-wide buffer of its cells — rather than
// a single `Array[GridLine]` of heap row objects.
//
// Why parallel arrays instead of one array of row values? The descriptor
// (`@page.PageRowState`, an unboxed `Int`) and the cells (a `FixedArray` reference)
// have opposite update profiles. A row descriptor is rewritten on nearly every
// printed cell (`mark_dirty`, flag maintenance); keeping `descs` a flat scalar
// array makes that a plain int store with no refcount traffic. A scroll instead
// slides whole rows: `descs` blits as a scalar memmove (zero refcount) and
// `cells` blits the row buffers by reference — exactly the moves Zig's
// `rows: Offset(Row)` / `cells: Offset(Cell)` split performs, minus the per-row
// heap object the old `GridLine` wrapper allocated and dropped on every scroll.
//
// (The cells stay per-row `FixedArray`s rather than one flat buffer because a
// row scrolled into history is handed off by reference, zero-copy; a contiguous
// flat buffer would force a copy there. Fusing `descs`/`cells` into one flat
// value grid is the follow-on `#valtype @page.PageCellState` change.)

///|
pub fn make_row_cells(cols : Int) -> FixedArray[@page.PageCellState] {
  // Allocate the row's cells in one shot. `FixedArray::make` fills every slot
  // with a copy of the (immutable value) blank cell — a single allocation,
  // versus a `push` loop that reallocs and ref-blits the growing buffer
  // ~log2(cols) times.
  FixedArray::make(cols, @page.default_page_cell_state)
}

///|
/// `pub(all)` because this is shared low-level cell storage: the owning
/// `PageList` reads AND writes `descs`/`cells`/`link_ids` directly (scroll,
/// reflow, history rebuild), and `active_grid` aliases a page's arrays into a
/// grid view — so the storage is genuinely shared between this package and
/// `pagelist`, mirroring upstream's freely-touched `Page` arrays. MoonBit
/// visibility is per-package, so there is no way to open this to `pagelist`
/// while sealing it from read-only consumers (formatter/render, which only read
/// `rows`/`cols` and the intern tables). The fields are immutable *bindings*
/// (the arrays are never reassigned), so what's exposed is the storage handles,
/// not the ability to swap them out.
pub(all) struct ScreenGridState {
  rows : @size.CellCountInt
  cols : @size.CellCountInt
  // Ring-buffer rotation: the physical index of logical row 0. Logical row `r`
  // lives at physical slot `phys(r) = (base + r) % rows`, so a full-screen scroll
  // is an O(1) `base` bump (plus blanking the freed rows) instead of an O(rows)
  // ref-array blit.
  //
  // `base` is owned by this grid view, not the shared page storage — the active
  // page's `descs`/`cells` arrays rotate in place, but the rotation *offset* lives
  // only here. This is sound because the one long-lived view (`self.grid` in the
  // bridge) is created once and mutated in place by scrolls; `active_grid` mints a
  // fresh `base: 0` view ONLY at points where the page storage is fresh or fully
  // blank (construction, post-`full_reset` re-fetch, post-resize rebuild), where a
  // zero offset is correct regardless of the prior rotation. INVARIANT: never call
  // `active_grid` (or otherwise build a `base: 0` view) over storage that is both
  // rotated and non-blank — it would read rows at the wrong offset.
  mut base : Int
  // Parallel per-row arrays: `descs[i]` and `cells[i]` are physical row `i`'s
  // descriptor and cell buffer (index through `phys`). See the comment above for
  // why they are split.
  descs : FixedArray[@page.PageRowState]
  cells : FixedArray[FixedArray[@page.PageCellState]]
  // Per-row hyperlink ids, parallel to `cells`. `link_ids[i]` is `None` for the
  // overwhelmingly common link-free row (no allocation, the hot path), otherwise
  // a `cols`-wide array whose `[col]` is the cell's `@hyperlink.HyperlinkId`. Only meaningful
  // where the cell's `has_hyperlink()` presence bit is set; entries under a
  // link-free cell are dead and never read. The id is stored out-of-cell so the
  // cell fits a `u64`; this side array travels with `cells` through every
  // scroll/blit/shift so a cell keeps its link as its row moves.
  link_ids : FixedArray[FixedArray[@hyperlink.HyperlinkId]?]
  // Free list of `cols`-wide cell arrays harvested from rows evicted out of
  // scrollback, reused in place as the blank rows scrolled in at the bottom.
  // At a full scrollback buffer this makes a line feed allocation-free: the row
  // evicted from history becomes the new blank row instead of being GC'd while
  // a fresh 80-cell row is allocated. Bounded to the screen height.
  cell_pool : Array[FixedArray[@page.PageCellState]]
  // The style intern table shared with the owning `PageList` (and thus with every
  // other grid view and scrollback row of the same screen). Cells store a
  // `StyleId` into this table rather than an inline style; writes intern here and
  // reads resolve here. A standalone grid (tests, fresh screen) owns its own
  // table; grids that share rows with a `PageList` must share its table, or a
  // cell's id would resolve against the wrong table after a scroll/resize.
  style_table : @style.StyleTable
  // The hyperlink intern table, shared the same way as `style_table`: cells store
  // a `@hyperlink.HyperlinkId` into it (0 = no link), writes intern here, the rare full-link
  // read resolves here. See `@hyperlink.HyperlinkTable`.
  hyperlink_table : @hyperlink.HyperlinkTable
  // The grapheme intern table, shared the same way: cells store a `@page.GraphemeId`
  // (0 = no combining marks), the append path interns here, and text emission
  // resolves the marks here. See `@page.GraphemeTable`.
  grapheme_table : @page.GraphemeTable
}

///|
/// Standalone grid that mints its own intern tables. Production paths that must
/// share tables with a `PageList` use `new_with_table` instead.
pub fn ScreenGridState::new(
  rows : @size.CellCountInt,
  cols : @size.CellCountInt,
) -> ScreenGridState {
  ScreenGridState::new_with_table(
    rows,
    cols,
    @style.StyleTable::new(),
    @hyperlink.HyperlinkTable::new(),
    @page.GraphemeTable::new(),
  )
}

///|
pub fn ScreenGridState::new_with_table(
  rows : @size.CellCountInt,
  cols : @size.CellCountInt,
  style_table : @style.StyleTable,
  hyperlink_table : @hyperlink.HyperlinkTable,
  grapheme_table : @page.GraphemeTable,
) -> ScreenGridState {
  let actual_rows = screen_dimension(rows)
  let actual_cols = screen_dimension(cols)
  let descs : FixedArray[@page.PageRowState] = FixedArray::makei(
    actual_rows.to_int(),
    _ => @page.PageRowState::new(),
  )
  let cells : FixedArray[FixedArray[@page.PageCellState]] = FixedArray::makei(
    actual_rows.to_int(),
    _ => make_row_cells(actual_cols.to_int()),
  )
  {
    rows: actual_rows,
    cols: actual_cols,
    base: 0,
    descs,
    cells,
    link_ids: FixedArray::make(actual_rows.to_int(), None),
    cell_pool: [],
    style_table,
    hyperlink_table,
    grapheme_table,
  }
}

///|
/// Physical slot backing logical row `logical`. `base` and `logical` are both in
/// `[0, rows)`, so their sum is in `[0, 2*rows)` and a single conditional subtract
/// normalizes it — cheaper than `%` on the per-row hot path.
///
/// `#inline`: this is called on every per-row access in the print/scroll hot
/// paths; left as a real call it cost ~10% self time in the wrapped-blob profile
/// (pure call overhead around two integer ops), so fold it into callers.
#inline
fn ScreenGridState::phys(self : ScreenGridState, logical : Int) -> Int {
  let p = self.base + logical
  let n = self.rows.to_int()
  if p >= n {
    p - n
  } else {
    p
  }
}

///|
/// Physical slot for logical row `logical`, for owners (`pagelist`) that index the
/// shared `descs`/`cells`/`link_ids` arrays directly. The arrays alias the active
/// page, but `base` rotates only the grid's logical view, so a consumer reading a
/// raw slot must translate logical→physical through here.
pub fn ScreenGridState::phys_row(self : ScreenGridState, logical : Int) -> Int {
  self.phys(logical)
}

///|
/// Logical row `r`'s descriptor. `#inline`: a thin `phys` wrapper on the hot path.
#inline
fn ScreenGridState::desc(self : ScreenGridState, r : Int) -> @page.PageRowState {
  self.descs[self.phys(r)]
}

///|
/// Write logical row `r`'s descriptor. `#inline`: thin `phys` wrapper, hot path.
#inline
fn ScreenGridState::set_desc(
  self : ScreenGridState,
  r : Int,
  value : @page.PageRowState,
) -> Unit {
  self.descs[self.phys(r)] = value
}

///|
/// Logical row `r`'s cell buffer. `#inline`: thin `phys` wrapper, hot path.
#inline
fn ScreenGridState::row_cells(
  self : ScreenGridState,
  r : Int,
) -> FixedArray[@page.PageCellState] {
  self.cells[self.phys(r)]
}

///|
/// Install logical row `r`'s cell buffer. `#inline`: thin `phys` wrapper.
#inline
fn ScreenGridState::set_row_cells(
  self : ScreenGridState,
  r : Int,
  value : FixedArray[@page.PageCellState],
) -> Unit {
  self.cells[self.phys(r)] = value
}

///|
/// Logical row `r`'s hyperlink-id side array (`None` when link-free). `#inline`:
/// thin `phys` wrapper.
#inline
fn ScreenGridState::link_row(
  self : ScreenGridState,
  r : Int,
) -> FixedArray[@hyperlink.HyperlinkId]? {
  self.link_ids[self.phys(r)]
}

///|
/// Install logical row `r`'s hyperlink-id side array. `#inline`: thin wrapper.
#inline
fn ScreenGridState::set_link_row(
  self : ScreenGridState,
  r : Int,
  value : FixedArray[@hyperlink.HyperlinkId]?,
) -> Unit {
  self.link_ids[self.phys(r)] = value
}

///|
/// Read the `@hyperlink.HyperlinkId` stored for the cell at `(row_idx, col_idx)`. Returns
/// `@hyperlink.no_hyperlink_id` when the row has no link array (the common case). Callers
/// should gate on the cell's `has_hyperlink()` presence bit; a non-none result
/// here always coincides with that bit being set, but the converse read of a
/// dead slot is harmless.
pub fn ScreenGridState::link_id_at(
  self : ScreenGridState,
  row_idx : Int,
  col_idx : Int,
) -> @hyperlink.HyperlinkId {
  match self.link_row(row_idx) {
    Some(row) => row[col_idx]
    None => @hyperlink.no_hyperlink_id
  }
}

///|
/// Store `id` for the cell at `(row_idx, col_idx)`, allocating the row's link
/// array on first use. Only called when `id` is a real link; the caller also sets
/// the cell's `has_hyperlink()` presence bit.
fn ScreenGridState::set_link_id(
  self : ScreenGridState,
  row_idx : Int,
  col_idx : Int,
  id : @hyperlink.HyperlinkId,
) -> Unit {
  let row = match self.link_row(row_idx) {
    Some(row) => row
    None => {
      let row = FixedArray::make(self.cols.to_int(), @hyperlink.no_hyperlink_id)
      self.set_link_row(row_idx, Some(row))
      row
    }
  }
  row[col_idx] = id
}

///|
/// Offer a `cols`-wide cell array (from a row evicted out of scrollback) to the
/// blank-row free list. Wrong-width arrays (e.g. across a resize) and overflow
/// past the screen height are dropped to GC rather than pooled.
pub fn ScreenGridState::recycle_row_cells(
  self : ScreenGridState,
  cells : FixedArray[@page.PageCellState],
) -> Unit {
  if cells.length() == self.cols.to_int() &&
    self.cell_pool.length() < self.rows.to_int() {
    self.cell_pool.push(cells)
  }
}

///|
/// Fill row `row_idx`'s slot with a blank full-width line for a scroll, writing
/// the `descs[row_idx]`/`cells[row_idx]` slots directly — no intermediate row
/// object or tuple is allocated. Reuses a recycled cell array (resetting every
/// cell in place) when one is pooled, otherwise allocates a fresh one. Always a
/// *distinct* cell buffer from any active row — the moved rows above may
/// transiently alias their source slot, and a distinct buffer breaks that alias
/// instead of clearing a shared line in place.
fn ScreenGridState::set_blank_row(
  self : ScreenGridState,
  row_idx : Int,
  style : @style.CellStyle,
) -> Unit {
  let cells = match self.cell_pool.pop() {
    Some(cells) => {
      // Reuse the pooled array buffer, refilling every slot with a fresh blank
      // cell value (cells are immutable, so we replace rather than reset).
      for index in 0..<cells.length() {
        cells[index] = blank_cell(style, self.style_table)
      }
      cells
    }
    None => make_blank_row_cells(self.cols.to_int(), style, self.style_table)
  }
  let phys = self.phys(row_idx)
  self.descs[phys] = @page.PageRowState::new().with_styled(
    blank_row_is_styled(style),
  )
  self.cells[phys] = cells
  // A blank row carries no hyperlinks; drop any link array the recycled slot had.
  self.link_ids[phys] = None
}

///|
pub fn ScreenGridState::row(
  self : ScreenGridState,
  row : @size.CellCountInt,
) -> @page.PageRowState? {
  let idx = row.to_int()
  if idx < 0 || idx >= self.rows.to_int() {
    None
  } else {
    Some(self.desc(idx))
  }
}

///|
/// Set the semantic-prompt tag on a row by index, bounds-checked. `@page.PageRowState`
/// is a value type, so callers cannot mutate the descriptor returned by `row`
/// in place — they go through here to write the `descs[idx]` slot.
pub fn ScreenGridState::set_row_semantic_prompt(
  self : ScreenGridState,
  row : @size.CellCountInt,
  prompt : @page.RowSemanticPrompt,
) -> Unit {
  let idx = row.to_int()
  if idx >= 0 && idx < self.rows.to_int() {
    self.set_desc(idx, self.desc(idx).with_semantic_prompt(prompt))
  }
}

///|
pub fn ScreenGridState::print(
  self : ScreenGridState,
  cursor : @cursor.TerminalCursorState,
  codepoint : UInt,
  width : Int,
  style : @style.CellStyle,
  protected_flag : Bool,
  semantic_content : @page.SemanticContent,
  row_prompt : @page.RowSemanticPrompt,
  hyperlink : @hyperlink.CellHyperlink?,
  wraparound : Bool,
  insert_mode : Bool,
) -> Unit {
  if width <= 0 {
    return
  }

  let right_limit = if cursor.x > cursor.right_margin {
    self.cols.to_int()
  } else {
    cursor.right_margin.to_int() + 1
  }

  if cursor.pending_wrap && wraparound {
    self.print_wrap(cursor, style, semantic_content)
  }

  if insert_mode && cursor.x.to_int() + width < self.cols.to_int() {
    self.insert_blanks(cursor, style, width.to_uint16())
  }

  match width {
    1 => {
      self.cursor_mark_dirty(cursor)
      self.apply_row_prompt(cursor.y.to_int(), row_prompt)
      self.print_cell(
        cursor,
        codepoint,
        Narrow,
        style,
        protected_flag,
        semantic_content,
        hyperlink,
      )
    }
    2 =>
      if right_limit - cursor.left_margin.to_int() > 1 {
        if cursor.x.to_int() == right_limit - 1 {
          if !wraparound {
            return
          }

          self.apply_row_prompt(cursor.y.to_int(), row_prompt)
          if right_limit == self.cols.to_int() {
            let cy = cursor.y.to_int()
            self.set_desc(cy, self.desc(cy).with_wrap(true))
            self.print_cell(
              cursor,
              0U,
              SpacerHead,
              style,
              protected_flag,
              semantic_content,
              hyperlink,
            )
          } else {
            self.print_cell(
              cursor,
              0U,
              Narrow,
              style,
              protected_flag,
              semantic_content,
              hyperlink,
            )
          }
          self.print_wrap(cursor, style, semantic_content)
        }

        self.cursor_mark_dirty(cursor)
        self.apply_row_prompt(cursor.y.to_int(), row_prompt)
        self.print_cell(
          cursor,
          codepoint,
          Wide,
          style,
          protected_flag,
          semantic_content,
          hyperlink,
        )
        cursor.x = cursor.x + 1
        self.print_cell(
          cursor,
          0U,
          SpacerTail,
          style,
          protected_flag,
          semantic_content,
          hyperlink,
        )
      } else {
        self.cursor_mark_dirty(cursor)
        self.apply_row_prompt(cursor.y.to_int(), row_prompt)
        self.print_cell(
          cursor,
          0U,
          Narrow,
          style,
          protected_flag,
          semantic_content,
          hyperlink,
        )
      }
    _ => return
  }

  if cursor.x.to_int() == right_limit - 1 {
    cursor.pending_wrap = true
    return
  }

  cursor.x = cursor.x + 1
}

///|
pub fn ScreenGridState::print_repeat(
  self : ScreenGridState,
  cursor : @cursor.TerminalCursorState,
  codepoint : UInt,
  width : Int,
  style : @style.CellStyle,
  protected_flag : Bool,
  semantic_content : @page.SemanticContent,
  row_prompt : @page.RowSemanticPrompt,
  hyperlink : @hyperlink.CellHyperlink?,
  wraparound : Bool,
  insert_mode : Bool,
  count_req : UInt16,
) -> Unit {
  let count = repeat_count(count_req)
  for _ in 0..<count {
    self.print(
      cursor, codepoint, width, style, protected_flag, semantic_content, row_prompt,
      hyperlink, wraparound, insert_mode,
    )
  }
}

///|
// Combine a zero-width codepoint onto the preceding logical cell.
// When cursor.pending_wrap is set the last-printed cell is at cursor.x;
// otherwise it is at cursor.x - 1. Skips SpacerTail to find the Wide base.
// Silently discards the codepoint when there is no preceding cell on this row.
pub fn ScreenGridState::append_grapheme(
  self : ScreenGridState,
  cursor : @cursor.TerminalCursorState,
  codepoint : UInt,
) -> Unit {
  let row_idx = cursor.y.to_int()
  if row_idx < 0 || row_idx >= self.descs.length() {
    return
  }
  let prev_x = if cursor.pending_wrap {
    cursor.x.to_int()
  } else if cursor.x.to_int() > 0 {
    cursor.x.to_int() - 1
  } else {
    return
  }
  if prev_x >= self.cols.to_int() {
    return
  }
  let row_cells = self.row_cells(row_idx)
  // Resolve SpacerTail → Wide base cell one column to the left.
  let target_x = if prev_x > 0 && row_cells[prev_x].wide() == SpacerTail {
    prev_x - 1
  } else {
    prev_x
  }
  let cell = row_cells[target_x]
  if cell.has_text() {
    // Variation selectors retroactively request emoji (U+FE0F → wide) or text
    // (U+FE0E → narrow) presentation for the base cluster. We don't re-width a
    // cell that's already been placed, so keep a selector only when it agrees
    // with the base's current width; otherwise the emitted grapheme would be
    // wider/narrower than its grid cell and overlap neighbours on a formatter
    // round-trip. (Full VS-driven re-width is part of the deferred
    // grapheme-width work.)
    let base_is_wide = cell.wide() == Wide
    if (codepoint == 0xFE0FU && !base_is_wide) ||
      (codepoint == 0xFE0EU && base_is_wide) {
      return
    }
    row_cells[target_x] = cell.with_grapheme_id(
      self.grapheme_table.append(cell.grapheme_id(), codepoint),
    )
    self.set_desc(
      row_idx,
      self.desc(row_idx).with_grapheme(true).with_dirty(true),
    )
  }
}

///|
pub fn ScreenGridState::insert_blanks(
  self : ScreenGridState,
  cursor : @cursor.TerminalCursorState,
  style : @style.CellStyle,
  count : UInt16,
) -> Unit {
  cursor.pending_wrap = false
  if count == 0 {
    return
  }

  let x = cursor.x.to_int()
  let left = cursor.left_margin.to_int()
  let right = cursor.right_margin.to_int()
  if x < left || x > right {
    return
  }

  let row_idx = cursor.y.to_int()
  let row_cells = self.row_cells(row_idx)
  let blank_style = style
  let cell = row_cells[x]
  if cell.wide() == SpacerTail && x > 0 {
    self.clear_row_range(row_idx, x - 1, x + 1, blank_style, false)
  }

  let rem = right - x + 1
  let right_cell = row_cells[right]
  if right_cell.wide() == Wide && right + 1 < self.cols.to_int() {
    self.clear_row_range(row_idx, right, right + 2, blank_style, false)
  }

  let adjusted_count = min_int(count.to_int(), rem)
  let scroll_amount = rem - adjusted_count
  if scroll_amount > 0 {
    let end_col = x + scroll_amount - 1
    let end_cell = row_cells[end_col]
    if end_cell.wide() == Wide && end_col + 1 < self.cols.to_int() {
      self.clear_row_range(row_idx, end_col, end_col + 2, blank_style, false)
    }

    let mut col = end_col
    while col >= x {
      self.move_cell_in_row(row_idx, col + adjusted_count, col)
      if col == x {
        break
      }
      col -= 1
    }
  }

  self.clear_row_range(row_idx, x, x + adjusted_count, blank_style, false)
  self.cursor_mark_dirty(cursor)
}

///|
pub fn ScreenGridState::delete_chars(
  self : ScreenGridState,
  cursor : @cursor.TerminalCursorState,
  style : @style.CellStyle,
  count_req : UInt16,
) -> Unit {
  if count_req == 0 {
    return
  }

  let x = cursor.x.to_int()
  let left = cursor.left_margin.to_int()
  let right = cursor.right_margin.to_int()
  if x < left || x > right {
    return
  }

  let row_idx = cursor.y.to_int()
  let count = min_int(count_req.to_int(), right - x + 1)
  self.split_cell_boundary(row_idx, x, style)
  self.split_cell_boundary(row_idx, x + count, style)
  self.split_cell_boundary(row_idx, right + 1, style)

  let rem = right - x + 1
  let scroll_amount = rem - count
  if scroll_amount > 0 {
    let mut col = x
    let last = x + scroll_amount - 1
    while col <= last {
      self.move_cell_in_row(row_idx, col, col + count)
      col += 1
    }
  }

  self.clear_row_range(row_idx, x + scroll_amount, x + rem, style, false)
  self.cursor_reset_wrap(cursor, style)
  self.cursor_mark_dirty(cursor)
}

///|
pub fn ScreenGridState::erase_chars(
  self : ScreenGridState,
  cursor : @cursor.TerminalCursorState,
  style : @style.CellStyle,
  protected_mode : @ansi.ProtectedMode,
  count_req : UInt16,
) -> Unit {
  let x = cursor.x.to_int()
  let remaining = self.cols.to_int() - x
  let requested = max_int(count_req.to_int(), 1)
  let mut count = min_int(remaining, requested)
  if count != remaining {
    let last_col = x + count - 1
    let last = self.row_cells(cursor.y.to_int())[last_col]
    if last.wide() == Wide {
      count += 1
    }
  }

  self.split_cell_boundary(cursor.y.to_int(), x, style)
  self.split_cell_boundary(cursor.y.to_int(), x + count, style)
  self.cursor_reset_wrap(cursor, style)
  self.cursor_mark_dirty(cursor)

  let respect_protected = protected_mode == Iso
  self.clear_row_range(
    cursor.y.to_int(),
    x,
    x + count,
    style,
    respect_protected,
  )
}

///|
pub fn ScreenGridState::erase_line(
  self : ScreenGridState,
  cursor : @cursor.TerminalCursorState,
  style : @style.CellStyle,
  mode : ScreenEraseLineMode,
  protected_mode : @ansi.ProtectedMode,
  protected_req : Bool,
) -> Unit {
  let row_idx = cursor.y.to_int()
  let x = cursor.x.to_int()
  let start = 0
  let end_ = self.cols.to_int()
  let (actual_start, actual_end) = match mode {
    Right => {
      self.cursor_reset_wrap(cursor, style)
      (
        if x > 0 && self.row_cells(row_idx)[x].wide() == SpacerTail {
          x - 1
        } else {
          x
        },
        end_,
      )
    }
    Left =>
      (
        start,
        if self.row_cells(row_idx)[x].wide() == Wide {
          x + 2
        } else {
          x + 1
        },
      )
    Complete => (start, end_)
  }

  cursor.pending_wrap = false
  self.cursor_mark_dirty(cursor)
  let respect_protected = protected_mode == Iso || protected_req
  self.clear_row_range(
    row_idx, actual_start, actual_end, style, respect_protected,
  )
}

///|
pub fn ScreenGridState::erase_display(
  self : ScreenGridState,
  cursor : @cursor.TerminalCursorState,
  style : @style.CellStyle,
  mode : ScreenEraseDisplayMode,
  protected_mode : @ansi.ProtectedMode,
  protected_req : Bool,
) -> Unit {
  let respect_protected = protected_mode == Iso || protected_req
  match mode {
    ScrollComplete =>
      self.erase_display(cursor, style, Complete, protected_mode, protected_req)
    Complete => {
      self.clear_rows(0, self.rows.to_int(), style, respect_protected)
      cursor.pending_wrap = false
    }
    Below => {
      self.erase_line(cursor, style, Right, protected_mode, protected_req)
      if cursor.y.to_int() + 1 < self.rows.to_int() {
        self.clear_rows(
          cursor.y.to_int() + 1,
          self.rows.to_int(),
          style,
          respect_protected,
        )
      }
    }
    Above => {
      self.erase_line(cursor, style, Left, protected_mode, protected_req)
      if cursor.y.to_int() > 0 {
        self.clear_rows(0, cursor.y.to_int(), style, respect_protected)
      }
    }
  }
}

///|
pub fn ScreenGridState::insert_lines(
  self : ScreenGridState,
  cursor : @cursor.TerminalCursorState,
  style : @style.CellStyle,
  count : UInt16,
) -> Unit {
  if count == 0 {
    return
  }

  let x = cursor.x.to_int()
  let y = cursor.y.to_int()
  let top = cursor.top_margin.to_int()
  let bottom = cursor.bottom_margin.to_int()
  let left = cursor.left_margin.to_int()
  let right = cursor.right_margin.to_int()
  if y < top || y > bottom || x < left || x > right {
    return
  }

  let start_y = y
  self.shift_region_down(start_y, bottom, left, right, count.to_int(), style)
  cursor.x = cursor.left_margin
  cursor.pending_wrap = false
}

///|
pub fn ScreenGridState::delete_lines(
  self : ScreenGridState,
  cursor : @cursor.TerminalCursorState,
  style : @style.CellStyle,
  count : UInt16,
) -> Unit {
  if count == 0 {
    return
  }

  let x = cursor.x.to_int()
  let y = cursor.y.to_int()
  let top = cursor.top_margin.to_int()
  let bottom = cursor.bottom_margin.to_int()
  let left = cursor.left_margin.to_int()
  let right = cursor.right_margin.to_int()
  if y < top || y > bottom || x < left || x > right {
    return
  }

  let start_y = y
  self.shift_region_up(start_y, bottom, left, right, count.to_int(), style)
  cursor.x = cursor.left_margin
  cursor.pending_wrap = false
}

///|
pub fn ScreenGridState::scroll_down(
  self : ScreenGridState,
  cursor : @cursor.TerminalCursorState,
  style : @style.CellStyle,
  count : UInt16,
) -> Unit {
  let old_x = cursor.x
  let old_y = cursor.y
  let old_wrap = cursor.pending_wrap
  cursor.x = cursor.left_margin
  cursor.y = cursor.top_margin
  self.insert_lines(cursor, style, count)
  cursor.x = old_x
  cursor.y = old_y
  cursor.pending_wrap = old_wrap
}

///|
pub fn ScreenGridState::scroll_up(
  self : ScreenGridState,
  cursor : @cursor.TerminalCursorState,
  style : @style.CellStyle,
  count : UInt16,
) -> Unit {
  let old_x = cursor.x
  let old_y = cursor.y
  let old_wrap = cursor.pending_wrap
  cursor.x = cursor.left_margin
  cursor.y = cursor.top_margin
  self.delete_lines(cursor, style, count)
  cursor.x = old_x
  cursor.y = old_y
  cursor.pending_wrap = old_wrap
}

///|
pub fn ScreenGridState::decaln(
  self : ScreenGridState,
  style : @style.CellStyle,
) -> Unit {
  let mut row_idx = 0
  while row_idx < self.rows.to_int() {
    self.clear_full_row(row_idx, @style.CellStyle::new(), false)
    let mut col_idx = 0
    while col_idx < self.cols.to_int() {
      self.write_cell(
        row_idx,
        col_idx,
        0x45U,
        Narrow,
        style,
        false,
        Output,
        None,
      )
      col_idx += 1
    }
    // Every cell in the row was written with `style`, so the row is styled
    // exactly when `style` is non-default. `write_cell` does not maintain row
    // flags, so set it here — otherwise a styled DECALN row scrolled into
    // scrollback would report `styled == false`, since the harvest path trusts
    // the live descriptor flag instead of rescanning the cells.
    self.set_desc(
      row_idx,
      self.desc(row_idx).with_styled(!style.is_default()).with_dirty(true),
    )
    row_idx += 1
  }
}

///|
pub fn ScreenGridState::full_reset(self : ScreenGridState) -> Unit {
  let mut row_idx = 0
  while row_idx < self.rows.to_int() {
    self.clear_full_row(row_idx, @style.CellStyle::new(), false)
    self.set_desc(row_idx, self.desc(row_idx).with_dirty(false))
    row_idx += 1
  }
  // A reset screen is canonically unrotated. The rows are now all blank, so the
  // value is cosmetic, but normalizing keeps physical==logical for any later
  // consumer that reads a raw slot before the next scroll re-rotates.
  self.base = 0
}

///|
fn ScreenGridState::print_cell(
  self : ScreenGridState,
  cursor : @cursor.TerminalCursorState,
  codepoint : UInt,
  wide : @page.PageCellWide,
  style : @style.CellStyle,
  protected_flag : Bool,
  semantic_content : @page.SemanticContent,
  hyperlink : @hyperlink.CellHyperlink?,
) -> Unit {
  let row_idx = cursor.y.to_int()
  let col_idx = cursor.x.to_int()
  let current = self.row_cells(row_idx)[col_idx]
  // Only an existing Wide or SpacerTail cell needs cleanup when the new cell's
  // width differs (Narrow/SpacerHead were no-ops in the old `!= wide` form).
  // Folding the width-changed test into the tag match keeps it a plain tag
  // comparison (`is`) instead of a polymorphic Eq::not_equal/equal call.
  match current.wide() {
    Wide =>
      if !(wide is Wide) {
        if col_idx < self.cols.to_int() - 1 {
          self.clear_row_range(row_idx, col_idx, col_idx + 2, style, false)
        }
        if row_idx > 0 && col_idx <= 1 {
          self.clear_prev_row_spacer_head(row_idx, style)
        }
      }
    SpacerTail =>
      if !(wide is SpacerTail) {
        if col_idx > 0 {
          self.clear_row_range(row_idx, col_idx - 1, col_idx + 1, style, false)
        }
        if row_idx > 0 && col_idx <= 1 {
          self.clear_prev_row_spacer_head(row_idx, style)
        }
      }
    Narrow | SpacerHead => ()
  }

  // Flags the cell being overwritten contributed to the row. If the new cell
  // drops any of them, the row flag may need clearing, which only a full rescan
  // can decide. Capture before the write replaces the cell object.
  let lost_grapheme = current.has_grapheme()
  let lost_styled = current.has_styling()
  let lost_hyperlink = current.has_hyperlink()
  self.write_cell_and_update_row_flags(
    row_idx, col_idx, codepoint, wide, style, protected_flag, semantic_content, hyperlink,
    lost_grapheme, lost_styled, lost_hyperlink,
  )
}

///|
/// Fused write + row-flag maintenance for the single-cell print hot path.
///
/// Splitting this across `write_cell` + `update_row_flags_after_write` made the
/// row's cell slot touched three times per printed cell (read old, write new,
/// read new) and recomputed the new cell's flags by re-reading the word that was
/// just packed. Here the new cell's flag contributions are known directly: a
/// printed base char never carries a grapheme, so `has_grapheme` is always
/// false; `has_styled` is `style_id != default`; `has_hyperlink` is `has_link`.
/// So the post-write rescan decision and the OR-in use those values without
/// re-reading the cell. `write_cell` stays as the standalone path for `decaln`
/// and tests, which maintain row flags differently (or in bulk).
fn ScreenGridState::write_cell_and_update_row_flags(
  self : ScreenGridState,
  row_idx : Int,
  col_idx : Int,
  codepoint : UInt,
  wide : @page.PageCellWide,
  style : @style.CellStyle,
  protected_flag : Bool,
  semantic_content : @page.SemanticContent,
  hyperlink : @hyperlink.CellHyperlink?,
  lost_grapheme : Bool,
  lost_styled : Bool,
  lost_hyperlink : Bool,
) -> Unit {
  // Intern the optional link; `None` is the free fast path → id 0. Guard on
  // `Some` so the common unlinked write skips the call and its table refcount.
  let link_id = if hyperlink is Some(_) {
    self.hyperlink_table.intern(hyperlink)
  } else {
    @hyperlink.no_hyperlink_id
  }
  let has_link = !link_id.is_none()
  let style_id = self.style_table.intern(style)
  let has_styled = !style_id.is_default()
  // Pack into a local first so the indexed store below has no intervening call;
  // otherwise the row array is held live across the interns and takes a per-cell
  // incref/decref.
  let cell = @page.PageCellState::new(
    codepoint~,
    style_id~,
    wide~,
    protected_flag~,
    hyperlink_present=has_link,
    semantic_content~,
  )
  // Resolve the ring offset once for this printed cell; the store and the row-flag
  // update below both index the same physical row.
  let phys = self.phys(row_idx)
  self.cells[phys][col_idx] = cell
  if has_link {
    self.set_link_id(row_idx, col_idx, link_id)
  }
  // Row-flag maintenance. `has_grapheme` of the new cell is always false on this
  // path, so the rescan-needed test reduces to `lost_grapheme || (lost_styled &&
  // !has_styled) || (lost_hyperlink && !has_link)`, and grapheme is never OR'd in.
  if lost_grapheme ||
    (lost_styled && !has_styled) ||
    (lost_hyperlink && !has_link) {
    self.recompute_row_flags(row_idx)
    return
  }
  let descs = self.descs
  descs[phys] = descs[phys].record_cell_write(
    styled=has_styled,
    hyperlink=has_link,
  )
}

///|
fn ScreenGridState::print_wrap(
  self : ScreenGridState,
  cursor : @cursor.TerminalCursorState,
  style : @style.CellStyle,
  semantic_content : @page.SemanticContent,
) -> Unit {
  let row_idx = cursor.y.to_int()
  let mark_wrap = cursor.x.to_int() == self.cols.to_int() - 1
  if mark_wrap {
    self.set_desc(row_idx, self.desc(row_idx).with_wrap(true))
  }

  cursor.pending_wrap = false
  self.index(cursor, style)
  cursor.x = cursor.left_margin
  let cy = cursor.y.to_int()
  if semantic_content == Prompt {
    self.set_desc(cy, self.desc(cy).with_semantic_prompt(PromptContinuation))
  }
  if mark_wrap {
    self.set_desc(cy, self.desc(cy).with_wrap_continuation(true))
  }
}

///|
pub fn ScreenGridState::index(
  self : ScreenGridState,
  cursor : @cursor.TerminalCursorState,
  style : @style.CellStyle,
) -> Unit {
  if cursor.y == cursor.bottom_margin {
    self.shift_region_up(
      cursor.top_margin.to_int(),
      cursor.bottom_margin.to_int(),
      cursor.left_margin.to_int(),
      cursor.right_margin.to_int(),
      1,
      style,
    )
  } else if cursor.y.to_int() < self.rows.to_int() - 1 {
    cursor.y = cursor.y + 1
  }
}

///|
fn ScreenGridState::shift_region_down(
  self : ScreenGridState,
  start_y : Int,
  bottom : Int,
  left : Int,
  right : Int,
  count_req : Int,
  style : @style.CellStyle,
) -> Unit {
  let rem = bottom - start_y + 1
  let count = min_int(count_req, rem)
  if left == 0 && right == self.cols.to_int() - 1 {
    self.shift_full_width_down(start_y, bottom, count, style)
    return
  }
  let mut row_idx = bottom
  while row_idx >= start_y {
    self.row_will_be_shifted(row_idx, left, right, style)
    if row_idx - count >= start_y {
      let src = row_idx - count
      self.row_will_be_shifted(src, left, right, style)
      self.copy_row_region(src, row_idx, left, right)
    } else {
      self.clear_row_range(row_idx, left, right + 1, style, false)
    }
    self.recompute_row_flags(row_idx)
    self.set_desc(row_idx, self.desc(row_idx).with_dirty(true))
    if row_idx == start_y {
      break
    }
    row_idx -= 1
  }
}

///|
/// Full-width scroll-down of rows `[start_y, bottom]` by `count`: the bottom
/// `count` rows scroll off, the survivors slide down, and `count` fresh blank
/// rows fill the top. The full-width mirror of `shift_full_width_up` — a single
/// line-array blit plus a hoisted clean/wrap pass, instead of `rem` per-row ref
/// stores. Unlike scroll-up this path never harvests into history, so the
/// survivor rows can be cleaned in place freely.
fn ScreenGridState::shift_full_width_down(
  self : ScreenGridState,
  start_y : Int,
  bottom : Int,
  count : Int,
  style : @style.CellStyle,
) -> Unit {
  let move_len = bottom - start_y + 1 - count
  if move_len > 0 {
    // Survivors are the rows above the scrolled-off block: `[start_y, bottom -
    // count]`. Detaching each from the row that used to precede it breaks any
    // wrap link and orphans a trailing SpacerHead, so clean both before moving.
    // (Done at the pre-rotation `base`, while these logical indices still resolve
    // to the survivors' current physical slots.)
    let mut src = bottom - count
    while src >= start_y {
      self.clean_trailing_spacer_head(src, style)
      self.set_desc(
        src,
        self.desc(src).with_wrap(false).with_wrap_continuation(false),
      )
      src -= 1
    }
    if start_y == 0 && bottom == self.rows.to_int() - 1 {
      // Whole-screen scroll-down: the survivors don't move physically — rotate the
      // ring backward so logical row `count` maps to their slots. O(1) versus the
      // O(rows) ref-array blit. `phys(rows - count)` is the survivors' old
      // physical row 0, which becomes the new logical 0.
      self.base = self.phys(self.rows.to_int() - count)
    } else {
      // Sub-screen full-width region: rotating `base` would disturb rows outside
      // the region, so slide the survivor rows down by `count` one ref at a time
      // (physical slots may wrap, so a single blit won't do). High→low so a source
      // is read before it is overwritten.
      let mut r = bottom
      while r >= start_y + count {
        self.set_desc(r, self.desc(r - count))
        self.set_row_cells(r, self.row_cells(r - count))
        self.set_link_row(r, self.link_row(r - count))
        r -= 1
      }
    }
  }
  // Fresh blank rows scroll in at the top (reusing pooled cell arrays). Resolved at
  // the post-rotation `base`, so these land on the freed (scrolled-off) slots.
  let mut row_idx = start_y
  while row_idx < start_y + count {
    self.set_blank_row(row_idx, style)
    row_idx += 1
  }
  // Every row's contents moved, so the whole region is dirty.
  let mut dirty_idx = start_y
  while dirty_idx <= bottom {
    self.set_desc(dirty_idx, self.desc(dirty_idx).with_dirty(true))
    dirty_idx += 1
  }
}

///|
fn ScreenGridState::shift_region_up(
  self : ScreenGridState,
  start_y : Int,
  bottom : Int,
  left : Int,
  right : Int,
  count_req : Int,
  style : @style.CellStyle,
) -> Unit {
  let rem = bottom - start_y + 1
  let count = min_int(count_req, rem)
  // The full-width case is the line-feed/scroll hot path; it moves whole line
  // refs (not per-cell) and so can hoist the per-row work out of the move and
  // bulk-shift the line array. See `shift_full_width_up`.
  if left == 0 && right == self.cols.to_int() - 1 {
    self.shift_full_width_up(start_y, bottom, count, style)
    return
  }
  let mut row_idx = start_y
  while row_idx <= bottom {
    self.row_will_be_shifted(row_idx, left, right, style)
    if row_idx + count <= bottom {
      let src = row_idx + count
      self.row_will_be_shifted(src, left, right, style)
      self.copy_row_region(src, row_idx, left, right)
    } else {
      self.clear_row_range(row_idx, left, right + 1, style, false)
    }
    self.recompute_row_flags(row_idx)
    self.set_desc(row_idx, self.desc(row_idx).with_dirty(true))
    row_idx += 1
  }
}

///|
/// Full-width scroll-up of rows `[start_y, bottom]` by `count`: the top `count`
/// rows scroll off (already harvested into history by the caller, so their cell
/// arrays must not be touched here), the survivors slide up, and `count` fresh
/// blank rows fill the bottom.
///
/// The win over the generic per-row loop: each surviving row keeps its cells, so
/// the move is a single line-array blit instead of `rem` individual ref stores.
/// The only per-row work left — clearing the now-broken wrap link and any
/// orphaned trailing wide-char fragment — is hoisted into one pass before the
/// blit, and dirtying is a separate cheap pass of descriptor bit flips.
fn ScreenGridState::shift_full_width_up(
  self : ScreenGridState,
  start_y : Int,
  bottom : Int,
  count : Int,
  style : @style.CellStyle,
) -> Unit {
  let move_len = bottom - start_y + 1 - count
  if move_len > 0 {
    // Survivors are the rows below the scrolled-off block: `[start_y + count,
    // bottom]`. Clean each before the move — the move detaches it from the row
    // that used to follow it, so any wrap relationship is gone and a trailing
    // SpacerHead (a wide char deferred across the old wrap boundary) is orphaned.
    // (Done at the pre-rotation `base`, while these logical indices still resolve
    // to the survivors' current physical slots.)
    let mut src = start_y + count
    while src <= bottom {
      self.clean_trailing_spacer_head(src, style)
      self.set_desc(
        src,
        self.desc(src).with_wrap(false).with_wrap_continuation(false),
      )
      src += 1
    }
    if start_y == 0 && bottom == self.rows.to_int() - 1 {
      // Whole-screen scroll-up (the line-feed hot path): the survivors keep their
      // cells in place — rotate the ring forward so logical row `count` maps to
      // logical 0. O(1) versus the O(rows) ref-array blit (and its per-row
      // incref/decref). The scrolled-off top rows were already harvested into
      // history by reference; the blank-row pass below reclaims their slots.
      self.base = self.phys(count)
    } else {
      // Sub-screen full-width region: rotating `base` would disturb rows outside
      // the region, so slide the survivor rows up by `count` one ref at a time
      // (physical slots may wrap, so a single blit won't do). Low→high so a source
      // is read before it is overwritten.
      let mut r = start_y
      while r <= bottom - count {
        self.set_desc(r, self.desc(r + count))
        self.set_row_cells(r, self.row_cells(r + count))
        self.set_link_row(r, self.link_row(r + count))
        r += 1
      }
    }
  }
  // Fresh blank rows scroll in at the bottom (reusing pooled cell arrays). Resolved
  // at the post-rotation `base`, so they land on the just-vacated top slots.
  let mut row_idx = bottom - count + 1
  while row_idx <= bottom {
    self.set_blank_row(row_idx, style)
    row_idx += 1
  }
  // Every row's contents moved, so the whole region is dirty.
  let mut dirty_idx = start_y
  while dirty_idx <= bottom {
    self.set_desc(dirty_idx, self.desc(dirty_idx).with_dirty(true))
    dirty_idx += 1
  }
}

///|
/// Clear a lone trailing SpacerHead at the last column. A SpacerHead there marks
/// a wide char that did not fit and was deferred to the next (wrapped) row; once
/// this row's wrap link is broken the fragment is meaningless, so blank it.
fn ScreenGridState::clean_trailing_spacer_head(
  self : ScreenGridState,
  row_idx : Int,
  style : @style.CellStyle,
) -> Unit {
  let last = self.cols.to_int() - 1
  if self.row_cells(row_idx)[last].wide() == SpacerHead {
    // clear_row_range recomputes the row flags, so no separate rescan is needed.
    self.clear_row_range(row_idx, last, last + 1, style, false)
  }
}

///|
fn ScreenGridState::row_will_be_shifted(
  self : ScreenGridState,
  row_idx : Int,
  left : Int,
  right : Int,
  style : @style.CellStyle,
) -> Unit {
  let mut changed = false
  let row_cells = self.row_cells(row_idx)
  if right == self.cols.to_int() - 1 || left < 2 {
    let end_cell = row_cells[self.cols.to_int() - 1]
    if end_cell.wide() == SpacerHead {
      self.clear_row_range(
        row_idx,
        self.cols.to_int() - 1,
        self.cols.to_int(),
        style,
        false,
      )
      changed = true
    }
  }

  let left_cell = row_cells[left]
  if left > 0 && left_cell.wide() == SpacerTail {
    self.clear_row_range(row_idx, left - 1, left + 1, style, false)
    changed = true
  }

  let right_cell = row_cells[right]
  if right + 1 < self.cols.to_int() && right_cell.wide() == Wide {
    self.clear_row_range(row_idx, right, right + 2, style, false)
    changed = true
  }

  if changed {
    self.recompute_row_flags(row_idx)
  }
}

///|
fn ScreenGridState::split_cell_boundary(
  self : ScreenGridState,
  row_idx : Int,
  x : Int,
  style : @style.CellStyle,
) -> Unit {
  if x == self.cols.to_int() {
    if !self.desc(row_idx).wrap() {
      return
    }

    let end_cell = self.row_cells(row_idx)[self.cols.to_int() - 1]
    if end_cell.wide() == SpacerHead {
      self.clear_row_range(
        row_idx,
        self.cols.to_int() - 1,
        self.cols.to_int(),
        style,
        false,
      )
    }
    return
  }

  if (x == 0 || x == 1) && self.desc(row_idx).wrap_continuation() && row_idx > 0 {
    let first = self.row_cells(row_idx)[0]
    if first.wide() == Wide {
      self.clear_prev_row_spacer_head(row_idx, style)
    }
  }

  if x == 0 {
    return
  }

  let left_cell = self.row_cells(row_idx)[x - 1]
  if left_cell.wide() == Wide {
    self.clear_row_range(row_idx, x - 1, x + 1, style, false)
  }
}

///|
fn ScreenGridState::cursor_reset_wrap(
  self : ScreenGridState,
  cursor : @cursor.TerminalCursorState,
  style : @style.CellStyle,
) -> Unit {
  let row_idx = cursor.y.to_int()
  cursor.pending_wrap = false
  self.set_desc(row_idx, self.desc(row_idx).with_wrap(false))
  if row_idx + 1 < self.rows.to_int() {
    self.set_desc(
      row_idx + 1,
      self.desc(row_idx + 1).with_wrap_continuation(false),
    )
  }
  let end_cell = self.row_cells(row_idx)[self.cols.to_int() - 1]
  if end_cell.wide() == SpacerHead {
    self.clear_row_range(
      row_idx,
      self.cols.to_int() - 1,
      self.cols.to_int(),
      style,
      false,
    )
  }
}

///|
fn ScreenGridState::cursor_mark_dirty(
  self : ScreenGridState,
  cursor : @cursor.TerminalCursorState,
) -> Unit {
  let cy = cursor.y.to_int()
  self.set_desc(cy, self.desc(cy).with_dirty(true))
}

///|
fn ScreenGridState::apply_row_prompt(
  self : ScreenGridState,
  row_idx : Int,
  row_prompt : @page.RowSemanticPrompt,
) -> Unit {
  if row_prompt != None {
    self.set_desc(row_idx, self.desc(row_idx).with_semantic_prompt(row_prompt))
  }
}

///|
fn ScreenGridState::clear_rows(
  self : ScreenGridState,
  start_row : Int,
  end_row : Int,
  style : @style.CellStyle,
  respect_protected : Bool,
) -> Unit {
  let mut row_idx = start_row
  while row_idx < end_row {
    self.clear_full_row(row_idx, style, respect_protected)
    row_idx += 1
  }
}

///|
fn ScreenGridState::clear_full_row(
  self : ScreenGridState,
  row_idx : Int,
  style : @style.CellStyle,
  respect_protected : Bool,
) -> Unit {
  if respect_protected {
    self.clear_row_range(row_idx, 0, self.cols.to_int(), style, true)
  } else {
    // Load the row's cell buffer once: indexing `self.row_cells(row_idx)` per
    // column would re-resolve the ring offset and reload (and refcount) the
    // `FixedArray` reference out of the parallel `cells` array on every cell.
    let row_cells = self.row_cells(row_idx)
    for col_idx in 0..<self.cols.to_int() {
      row_cells[col_idx] = blank_cell(style, self.style_table)
    }
    // Reset to a blank descriptor, then restore `styled`: `full_reset` cleared
    // it, but a colored erase fills the row with bg-styled blanks, so the flag
    // must track the cells.
    self.set_desc(
      row_idx,
      @page.PageRowState::new().with_styled(blank_row_is_styled(style)),
    )
  }
  self.set_desc(row_idx, self.desc(row_idx).with_dirty(true))
}

///|
fn ScreenGridState::clear_row_range(
  self : ScreenGridState,
  row_idx : Int,
  start_col : Int,
  end_col : Int,
  style : @style.CellStyle,
  respect_protected : Bool,
) -> Unit {
  let row_cells = self.row_cells(row_idx)
  let mut col_idx = clamp_int(start_col, 0, self.cols.to_int())
  let limit = clamp_int(end_col, 0, self.cols.to_int())
  while col_idx < limit {
    let cell = row_cells[col_idx]
    if !respect_protected || !cell.is_protected() {
      row_cells[col_idx] = blank_cell(style, self.style_table)
    }
    col_idx += 1
  }
  self.recompute_row_flags(row_idx)
}

///|
fn ScreenGridState::copy_row_region(
  self : ScreenGridState,
  src_row : Int,
  dst_row : Int,
  left : Int,
  right : Int,
) -> Unit {
  let src_cells = self.row_cells(src_row)
  let dst_cells = self.row_cells(dst_row)
  let mut col_idx = left
  while col_idx <= right {
    dst_cells[col_idx] = src_cells[col_idx]
    col_idx += 1
  }
  // Carry the hyperlink ids for the moved column range. Only the source rows that
  // actually hold links allocate a destination array; a link-free source leaves
  // the destination untouched, since its copied cells have no presence bit and any
  // stale destination slot is dead.
  if self.link_row(src_row) is Some(src_links) {
    let dst_links = match self.link_row(dst_row) {
      Some(row) => row
      None => {
        let row = FixedArray::make(
          self.cols.to_int(),
          @hyperlink.no_hyperlink_id,
        )
        self.set_link_row(dst_row, Some(row))
        row
      }
    }
    let mut col = left
    while col <= right {
      dst_links[col] = src_links[col]
      col += 1
    }
  }
}

///|
fn ScreenGridState::clear_prev_row_spacer_head(
  self : ScreenGridState,
  row_idx : Int,
  style : @style.CellStyle,
) -> Unit {
  let prev_row = row_idx - 1
  let last_col = self.cols.to_int() - 1
  let head = self.row_cells(prev_row)[last_col]
  if head.wide() == SpacerHead {
    self.clear_row_range(prev_row, last_col, self.cols.to_int(), style, false)
  }
}

///|
pub fn ScreenGridState::write_cell(
  self : ScreenGridState,
  row_idx : Int,
  col_idx : Int,
  codepoint : UInt,
  wide : @page.PageCellWide,
  style : @style.CellStyle,
  protected_flag : Bool,
  semantic_content : @page.SemanticContent,
  hyperlink : @hyperlink.CellHyperlink?,
) -> Unit {
  // Intern the optional link; `None` is the free fast path → id 0. The id is kept
  // in the per-row `link_ids` side array (not the cell); the cell only records
  // its presence as a flag bit. Guard the call on `Some`: `intern(None)` only
  // fast-returns `no_hyperlink_id`, but the call itself forces a per-cell
  // incref/decref of the table, so the common unlinked write skips it entirely.
  let link_id = if hyperlink is Some(_) {
    self.hyperlink_table.intern(hyperlink)
  } else {
    @hyperlink.no_hyperlink_id
  }
  let has_link = !link_id.is_none()
  // Intern the incoming style into the screen's shared table; the cell keeps only
  // the id. Default/unstyled prints hit the table's pre-seeded id 0.
  let style_id = self.style_table.intern(style)
  // A printed character fully defines the cell, so pack one fresh `u64` — there is
  // nothing to read from the old cell. Pack into a local first so the indexed
  // store below has no intervening call; otherwise the row array is held live
  // across `style_table.intern` and takes an incref/decref per cell.
  let cell = @page.PageCellState::new(
    codepoint~,
    style_id~,
    wide~,
    protected_flag~,
    // A printed base char has no combining marks yet; they are appended later via
    // the grapheme table. (`write_cell` is never the grapheme-append path.)
    hyperlink_present=has_link,
    semantic_content~,
  )
  // The store is a single inline word write, no allocation.
  self.row_cells(row_idx)[col_idx] = cell
  // Record the link id by column only when there is one; a link-free write leaves
  // the row's (possibly absent) link array untouched, since the cleared presence
  // bit makes any stale slot dead.
  if has_link {
    self.set_link_id(row_idx, col_idx, link_id)
  }
}

///|
/// Move the cell (and its hyperlink id) from `src_col` to `dst_col` within one
/// row — the per-cell step of the intra-row shifts (`insert_blanks` /
/// `delete_chars`). The cell value carries its own presence bit; the link id
/// lives in the row's side array, so it is moved alongside when the row has one.
fn ScreenGridState::move_cell_in_row(
  self : ScreenGridState,
  row_idx : Int,
  dst_col : Int,
  src_col : Int,
) -> Unit {
  let row_cells = self.row_cells(row_idx)
  row_cells[dst_col] = row_cells[src_col]
  if self.link_row(row_idx) is Some(links) {
    links[dst_col] = links[src_col]
  }
}

///|
pub fn ScreenGridState::recompute_row_flags(
  self : ScreenGridState,
  row_idx : Int,
) -> Unit {
  let row_cells = self.row_cells(row_idx)
  let mut grapheme = false
  let mut styled = false
  let mut hyperlink = false
  let mut col_idx = 0
  while col_idx < self.cols.to_int() {
    let cell = row_cells[col_idx]
    if cell.has_grapheme() {
      grapheme = true
    }
    if cell.has_styling() {
      styled = true
    }
    if cell.has_hyperlink() {
      hyperlink = true
    }
    col_idx += 1
  }
  self.set_desc(
    row_idx,
    self
    .desc(row_idx)
    .with_grapheme(grapheme)
    .with_styled(styled)
    .with_hyperlink(hyperlink)
    .with_kitty_virtual_placeholder(false),
  )
}

///|
pub fn screen_dimension(value : @size.CellCountInt) -> @size.CellCountInt {
  if value == 0 {
    1
  } else {
    value
  }
}

///|
fn repeat_count(count_req : UInt16) -> Int {
  let value = count_req.to_int()
  if value <= 0 {
    1
  } else {
    value
  }
}

///|
fn min_int(a : Int, b : Int) -> Int {
  if a < b {
    a
  } else {
    b
  }
}

///|
fn max_int(a : Int, b : Int) -> Int {
  if a > b {
    a
  } else {
    b
  }
}

///|
fn clamp_int(value : Int, min_ : Int, max_ : Int) -> Int {
  if value < min_ {
    min_
  } else if value > max_ {
    max_
  } else {
    value
  }
}

///|
// A blank cell that carries the erase style's background color (and nothing
// else): a glyph-less cell whose `style` holds just the bg, so a run of them
// renders as a colored gap.
fn blank_cell(
  style : @style.CellStyle,
  style_table : @style.StyleTable,
) -> @page.PageCellState {
  let bg = style.bg_color()
  // Common case (erase with no SGR background): the shared blank cell, no alloc
  // and no intern. Only a colored erase pays to intern a bg-only style.
  if bg.is_default() {
    @page.default_page_cell_state
  } else {
    let bg_style = @style.CellStyle::new().with_bg_color(bg)
    @page.PageCellState::new(style_id=style_table.intern(bg_style))
  }
}

///|
// Whether a row filled entirely with `blank_cell(style)` should report
// `styled()`. A blank carries at most a background color — never a grapheme or
// hyperlink — so such a row is styled exactly when that background is
// non-default, mirroring `blank_cell`'s own default-vs-bg-only choice. The
// full-row blank/clear paths use this to keep the row descriptor's flags in sync
// with its cells in O(1), upholding the same invariant `recompute_row_flags`
// would (otherwise a colored erase leaves `styled()`/`managed_memory()` false
// while the cells report `has_styling()`).
fn blank_row_is_styled(style : @style.CellStyle) -> Bool {
  !style.bg_color().is_default()
}

///|
/// A fresh `cols`-wide buffer of blank cells for a full-width scroll's
/// scrolled-in row. A *distinct* buffer from any active row — the moved rows
/// above may transiently alias their source slot, and a fresh buffer breaks that
/// alias instead of clearing a shared line in place.
fn make_blank_row_cells(
  cols : Int,
  style : @style.CellStyle,
  style_table : @style.StyleTable,
) -> FixedArray[@page.PageCellState] {
  // One allocation filled with the blank cell value, instead of growing an empty
  // array by `push` (which reallocs and ref-blits ~log2(cols) times). This is the
  // hot path for a line feed when the cell pool is empty (scrollback not yet full).
  FixedArray::make(cols, blank_cell(style, style_table))
}
