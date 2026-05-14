///|
priv enum ScreenEraseLineMode {
  Right
  Left
  Complete
}

///|
priv enum ScreenEraseDisplayMode {
  Below
  Above
  Complete
  ScrollComplete
}

///|
priv struct ScreenGridState {
  rows : CellCountInt
  cols : CellCountInt
  row_states : Array[PageRowState]
  cells : Array[PageCellState]
}

///|
fn ScreenGridState::new(
  rows : CellCountInt,
  cols : CellCountInt,
) -> ScreenGridState {
  let actual_rows = screen_dimension(rows)
  let actual_cols = screen_dimension(cols)
  let row_states : Array[PageRowState] = []
  let cells : Array[PageCellState] = []
  for _ in 0..<actual_rows.to_int() {
    row_states.push(PageRowState::new())
  }
  for _ in 0..<(actual_rows.to_int() * actual_cols.to_int()) {
    cells.push(PageCellState::new())
  }
  { rows: actual_rows, cols: actual_cols, row_states, cells }
}

///|
fn ScreenGridState::row(
  self : ScreenGridState,
  row : CellCountInt,
) -> PageRowState? {
  let idx = row.to_int()
  if idx < 0 || idx >= self.rows.to_int() {
    None
  } else {
    Some(self.row_states[idx])
  }
}

///|
fn ScreenGridState::print(
  self : ScreenGridState,
  cursor : TerminalCursorState,
  codepoint : UInt,
  width : Int,
  style : CellStyle,
  protected_flag : Bool,
  semantic_content : SemanticContent,
  row_prompt : RowSemanticPrompt,
  hyperlink : CellHyperlink?,
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
        PageCellWide::Narrow,
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
            self.row_states[cursor.y.to_int()].set_wrap(true)
            self.print_cell(
              cursor,
              0U,
              PageCellWide::SpacerHead,
              style,
              protected_flag,
              semantic_content,
              hyperlink,
            )
          } else {
            self.print_cell(
              cursor,
              0U,
              PageCellWide::Narrow,
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
          PageCellWide::Wide,
          style,
          protected_flag,
          semantic_content,
          hyperlink,
        )
        cursor.x = cursor.x + 1
        self.print_cell(
          cursor,
          0U,
          PageCellWide::SpacerTail,
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
          PageCellWide::Narrow,
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
fn ScreenGridState::print_repeat(
  self : ScreenGridState,
  cursor : TerminalCursorState,
  codepoint : UInt,
  width : Int,
  style : CellStyle,
  protected_flag : Bool,
  semantic_content : SemanticContent,
  row_prompt : RowSemanticPrompt,
  hyperlink : CellHyperlink?,
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
fn ScreenGridState::insert_blanks(
  self : ScreenGridState,
  cursor : TerminalCursorState,
  style : CellStyle,
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
  let blank_style = style
  let cell = self.cells[self.cell_index(row_idx, x)]
  if cell.wide() == PageCellWide::SpacerTail && x > 0 {
    self.clear_row_range(row_idx, x - 1, x + 1, blank_style, false)
  }

  let rem = right - x + 1
  let right_cell = self.cells[self.cell_index(row_idx, right)]
  if right_cell.wide() == PageCellWide::Wide && right + 1 < self.cols.to_int() {
    self.clear_row_range(row_idx, right, right + 2, blank_style, false)
  }

  let adjusted_count = min_int(count.to_int(), rem)
  let scroll_amount = rem - adjusted_count
  if scroll_amount > 0 {
    let end_col = x + scroll_amount - 1
    let end_cell = self.cells[self.cell_index(row_idx, end_col)]
    if end_cell.wide() == PageCellWide::Wide && end_col + 1 < self.cols.to_int() {
      self.clear_row_range(row_idx, end_col, end_col + 2, blank_style, false)
    }

    let mut col = end_col
    while col >= x {
      self.set_cell(
        row_idx,
        col + adjusted_count,
        self.cells[self.cell_index(row_idx, col)],
      )
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
fn ScreenGridState::delete_chars(
  self : ScreenGridState,
  cursor : TerminalCursorState,
  style : CellStyle,
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
      self.set_cell(
        row_idx,
        col,
        self.cells[self.cell_index(row_idx, col + count)],
      )
      col += 1
    }
  }

  self.clear_row_range(row_idx, x + scroll_amount, x + rem, style, false)
  self.cursor_reset_wrap(cursor, style)
  self.cursor_mark_dirty(cursor)
}

///|
fn ScreenGridState::erase_chars(
  self : ScreenGridState,
  cursor : TerminalCursorState,
  style : CellStyle,
  protected_mode : ProtectedMode,
  count_req : UInt16,
) -> Unit {
  let x = cursor.x.to_int()
  let remaining = self.cols.to_int() - x
  let requested = max_int(count_req.to_int(), 1)
  let mut count = min_int(remaining, requested)
  if count != remaining {
    let last_col = x + count - 1
    let last = self.cells[self.cell_index(cursor.y.to_int(), last_col)]
    if last.wide() == PageCellWide::Wide {
      count += 1
    }
  }

  self.split_cell_boundary(cursor.y.to_int(), x, style)
  self.split_cell_boundary(cursor.y.to_int(), x + count, style)
  self.cursor_reset_wrap(cursor, style)
  self.cursor_mark_dirty(cursor)

  let respect_protected = protected_mode == ProtectedMode::Iso
  self.clear_row_range(
    cursor.y.to_int(),
    x,
    x + count,
    style,
    respect_protected,
  )
}

///|
fn ScreenGridState::erase_line(
  self : ScreenGridState,
  cursor : TerminalCursorState,
  style : CellStyle,
  mode : ScreenEraseLineMode,
  protected_mode : ProtectedMode,
  protected_req : Bool,
) -> Unit {
  let row_idx = cursor.y.to_int()
  let x = cursor.x.to_int()
  let start = 0
  let end_ = self.cols.to_int()
  let (actual_start, actual_end) = match mode {
    ScreenEraseLineMode::Right => {
      self.cursor_reset_wrap(cursor, style)
      (
        if x > 0 &&
          self.cells[self.cell_index(row_idx, x)].wide() ==
          PageCellWide::SpacerTail {
          x - 1
        } else {
          x
        },
        end_,
      )
    }
    ScreenEraseLineMode::Left =>
      (
        start,
        if self.cells[self.cell_index(row_idx, x)].wide() == PageCellWide::Wide {
          x + 2
        } else {
          x + 1
        },
      )
    ScreenEraseLineMode::Complete => (start, end_)
  }

  cursor.pending_wrap = false
  self.cursor_mark_dirty(cursor)
  let respect_protected = protected_mode == ProtectedMode::Iso || protected_req
  self.clear_row_range(
    row_idx, actual_start, actual_end, style, respect_protected,
  )
}

///|
fn ScreenGridState::erase_display(
  self : ScreenGridState,
  cursor : TerminalCursorState,
  style : CellStyle,
  mode : ScreenEraseDisplayMode,
  protected_mode : ProtectedMode,
  protected_req : Bool,
) -> Unit {
  let respect_protected = protected_mode == ProtectedMode::Iso || protected_req
  match mode {
    ScreenEraseDisplayMode::ScrollComplete =>
      self.erase_display(
        cursor,
        style,
        ScreenEraseDisplayMode::Complete,
        protected_mode,
        protected_req,
      )
    ScreenEraseDisplayMode::Complete => {
      self.clear_rows(0, self.rows.to_int(), style, respect_protected)
      cursor.pending_wrap = false
    }
    ScreenEraseDisplayMode::Below => {
      self.erase_line(
        cursor,
        style,
        ScreenEraseLineMode::Right,
        protected_mode,
        protected_req,
      )
      if cursor.y.to_int() + 1 < self.rows.to_int() {
        self.clear_rows(
          cursor.y.to_int() + 1,
          self.rows.to_int(),
          style,
          respect_protected,
        )
      }
    }
    ScreenEraseDisplayMode::Above => {
      self.erase_line(
        cursor,
        style,
        ScreenEraseLineMode::Left,
        protected_mode,
        protected_req,
      )
      if cursor.y.to_int() > 0 {
        self.clear_rows(0, cursor.y.to_int(), style, respect_protected)
      }
    }
  }
}

///|
fn ScreenGridState::insert_lines(
  self : ScreenGridState,
  cursor : TerminalCursorState,
  style : CellStyle,
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
fn ScreenGridState::delete_lines(
  self : ScreenGridState,
  cursor : TerminalCursorState,
  style : CellStyle,
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
fn ScreenGridState::scroll_down(
  self : ScreenGridState,
  cursor : TerminalCursorState,
  style : CellStyle,
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
fn ScreenGridState::scroll_up(
  self : ScreenGridState,
  cursor : TerminalCursorState,
  style : CellStyle,
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
fn ScreenGridState::decaln(self : ScreenGridState, style : CellStyle) -> Unit {
  let mut row_idx = 0
  while row_idx < self.rows.to_int() {
    self.clear_full_row(row_idx, CellStyle::new(), false)
    let mut col_idx = 0
    while col_idx < self.cols.to_int() {
      self.write_cell(
        row_idx,
        col_idx,
        0x45U,
        PageCellWide::Narrow,
        style,
        false,
        SemanticContent::Output,
        None,
      )
      col_idx += 1
    }
    self.row_states[row_idx].set_dirty(true)
    row_idx += 1
  }
}

///|
fn ScreenGridState::full_reset(self : ScreenGridState) -> Unit {
  let mut row_idx = 0
  while row_idx < self.rows.to_int() {
    self.clear_full_row(row_idx, CellStyle::new(), false)
    self.row_states[row_idx].set_dirty(false)
    row_idx += 1
  }
}

///|
fn ScreenGridState::cell_index(
  self : ScreenGridState,
  row_idx : Int,
  col_idx : Int,
) -> Int {
  row_idx * self.cols.to_int() + col_idx
}

///|
fn ScreenGridState::print_cell(
  self : ScreenGridState,
  cursor : TerminalCursorState,
  codepoint : UInt,
  wide : PageCellWide,
  style : CellStyle,
  protected_flag : Bool,
  semantic_content : SemanticContent,
  hyperlink : CellHyperlink?,
) -> Unit {
  let row_idx = cursor.y.to_int()
  let col_idx = cursor.x.to_int()
  let current = self.cells[self.cell_index(row_idx, col_idx)]
  if current.wide() != wide {
    match current.wide() {
      PageCellWide::Narrow => ()
      PageCellWide::Wide => {
        if col_idx < self.cols.to_int() - 1 {
          self.clear_row_range(row_idx, col_idx, col_idx + 2, style, false)
        }
        if row_idx > 0 && col_idx <= 1 {
          self.clear_prev_row_spacer_head(row_idx, style)
        }
      }
      PageCellWide::SpacerTail => {
        if col_idx > 0 {
          self.clear_row_range(row_idx, col_idx - 1, col_idx + 1, style, false)
        }
        if row_idx > 0 && col_idx <= 1 {
          self.clear_prev_row_spacer_head(row_idx, style)
        }
      }
      PageCellWide::SpacerHead => ()
    }
  }

  self.write_cell(
    row_idx, col_idx, codepoint, wide, style, protected_flag, semantic_content, hyperlink,
  )
  self.recompute_row_flags(row_idx)
}

///|
fn ScreenGridState::print_wrap(
  self : ScreenGridState,
  cursor : TerminalCursorState,
  style : CellStyle,
  semantic_content : SemanticContent,
) -> Unit {
  let row_idx = cursor.y.to_int()
  let mark_wrap = cursor.x.to_int() == self.cols.to_int() - 1
  if mark_wrap {
    self.row_states[row_idx].set_wrap(true)
  }

  cursor.pending_wrap = false
  self.index(cursor, style)
  cursor.x = cursor.left_margin
  if semantic_content == SemanticContent::Prompt {
    self.row_states[cursor.y.to_int()].set_semantic_prompt(
      RowSemanticPrompt::PromptContinuation,
    )
  }
  if mark_wrap {
    self.row_states[cursor.y.to_int()].set_wrap_continuation(true)
  }
}

///|
fn ScreenGridState::index(
  self : ScreenGridState,
  cursor : TerminalCursorState,
  style : CellStyle,
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
  style : CellStyle,
) -> Unit {
  let rem = bottom - start_y + 1
  let count = min_int(count_req, rem)
  let full_width = left == 0 && right == self.cols.to_int() - 1
  let mut row_idx = bottom
  while row_idx >= start_y {
    self.row_will_be_shifted(row_idx, left, right, style)
    if row_idx - count >= start_y {
      let src = row_idx - count
      self.row_will_be_shifted(src, left, right, style)
      if full_width {
        self.copy_full_row_for_shift(src, row_idx)
      } else {
        self.copy_row_region(src, row_idx, left, right)
      }
    } else if full_width {
      self.clear_full_row(row_idx, style, false)
    } else {
      self.clear_row_range(row_idx, left, right + 1, style, false)
    }
    if !full_width {
      self.recompute_row_flags(row_idx)
    }
    self.row_states[row_idx].set_dirty(true)
    if row_idx == start_y {
      break
    }
    row_idx -= 1
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
  style : CellStyle,
) -> Unit {
  let rem = bottom - start_y + 1
  let count = min_int(count_req, rem)
  let full_width = left == 0 && right == self.cols.to_int() - 1
  let mut row_idx = start_y
  while row_idx <= bottom {
    self.row_will_be_shifted(row_idx, left, right, style)
    if row_idx + count <= bottom {
      let src = row_idx + count
      self.row_will_be_shifted(src, left, right, style)
      if full_width {
        self.copy_full_row_for_shift(src, row_idx)
      } else {
        self.copy_row_region(src, row_idx, left, right)
      }
    } else if full_width {
      self.clear_full_row(row_idx, style, false)
    } else {
      self.clear_row_range(row_idx, left, right + 1, style, false)
    }
    if !full_width {
      self.recompute_row_flags(row_idx)
    }
    self.row_states[row_idx].set_dirty(true)
    row_idx += 1
  }
}

///|
fn ScreenGridState::row_will_be_shifted(
  self : ScreenGridState,
  row_idx : Int,
  left : Int,
  right : Int,
  style : CellStyle,
) -> Unit {
  let mut changed = false
  if right == self.cols.to_int() - 1 || left < 2 {
    let end_cell = self.cells[self.cell_index(row_idx, self.cols.to_int() - 1)]
    if end_cell.wide() == PageCellWide::SpacerHead {
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

  let left_cell = self.cells[self.cell_index(row_idx, left)]
  if left > 0 && left_cell.wide() == PageCellWide::SpacerTail {
    self.clear_row_range(row_idx, left - 1, left + 1, style, false)
    changed = true
  }

  let right_cell = self.cells[self.cell_index(row_idx, right)]
  if right + 1 < self.cols.to_int() && right_cell.wide() == PageCellWide::Wide {
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
  style : CellStyle,
) -> Unit {
  if x == self.cols.to_int() {
    if !self.row_states[row_idx].wrap() {
      return
    }

    let end_cell = self.cells[self.cell_index(row_idx, self.cols.to_int() - 1)]
    if end_cell.wide() == PageCellWide::SpacerHead {
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

  if (x == 0 || x == 1) &&
    self.row_states[row_idx].wrap_continuation() &&
    row_idx > 0 {
    let first = self.cells[self.cell_index(row_idx, 0)]
    if first.wide() == PageCellWide::Wide {
      self.clear_prev_row_spacer_head(row_idx, style)
    }
  }

  if x == 0 {
    return
  }

  let left_cell = self.cells[self.cell_index(row_idx, x - 1)]
  if left_cell.wide() == PageCellWide::Wide {
    self.clear_row_range(row_idx, x - 1, x + 1, style, false)
  }
}

///|
fn ScreenGridState::cursor_reset_wrap(
  self : ScreenGridState,
  cursor : TerminalCursorState,
  style : CellStyle,
) -> Unit {
  let row_idx = cursor.y.to_int()
  cursor.pending_wrap = false
  self.row_states[row_idx].set_wrap(false)
  if row_idx + 1 < self.rows.to_int() {
    self.row_states[row_idx + 1].set_wrap_continuation(false)
  }
  let end_cell = self.cells[self.cell_index(row_idx, self.cols.to_int() - 1)]
  if end_cell.wide() == PageCellWide::SpacerHead {
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
  cursor : TerminalCursorState,
) -> Unit {
  self.row_states[cursor.y.to_int()].set_dirty(true)
}

///|
fn ScreenGridState::apply_row_prompt(
  self : ScreenGridState,
  row_idx : Int,
  row_prompt : RowSemanticPrompt,
) -> Unit {
  if row_prompt != RowSemanticPrompt::None {
    self.row_states[row_idx].set_semantic_prompt(row_prompt)
  }
}

///|
fn ScreenGridState::clear_rows(
  self : ScreenGridState,
  start_row : Int,
  end_row : Int,
  style : CellStyle,
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
  style : CellStyle,
  respect_protected : Bool,
) -> Unit {
  if respect_protected {
    self.clear_row_range(row_idx, 0, self.cols.to_int(), style, true)
  } else {
    let mut col_idx = 0
    while col_idx < self.cols.to_int() {
      self.set_cell(row_idx, col_idx, blank_cell(style))
      col_idx += 1
    }
    self.row_states[row_idx].full_reset()
  }
  self.row_states[row_idx].set_dirty(true)
}

///|
fn ScreenGridState::clear_row_range(
  self : ScreenGridState,
  row_idx : Int,
  start_col : Int,
  end_col : Int,
  style : CellStyle,
  respect_protected : Bool,
) -> Unit {
  let mut col_idx = clamp_int(start_col, 0, self.cols.to_int())
  let limit = clamp_int(end_col, 0, self.cols.to_int())
  while col_idx < limit {
    let cell = self.cells[self.cell_index(row_idx, col_idx)]
    if !respect_protected || !cell.is_protected() {
      self.set_cell(row_idx, col_idx, blank_cell(style))
    }
    col_idx += 1
  }
  self.recompute_row_flags(row_idx)
}

///|
fn ScreenGridState::copy_full_row_for_shift(
  self : ScreenGridState,
  src_row : Int,
  dst_row : Int,
) -> Unit {
  let copied = copy_page_row(self.row_states[src_row])
  copied.set_wrap(false)
  copied.set_wrap_continuation(false)
  self.row_states[dst_row] = copied
  let mut col_idx = 0
  while col_idx < self.cols.to_int() {
    self.set_cell(
      dst_row,
      col_idx,
      self.cells[self.cell_index(src_row, col_idx)],
    )
    col_idx += 1
  }
}

///|
fn ScreenGridState::copy_row_region(
  self : ScreenGridState,
  src_row : Int,
  dst_row : Int,
  left : Int,
  right : Int,
) -> Unit {
  let mut col_idx = left
  while col_idx <= right {
    self.set_cell(
      dst_row,
      col_idx,
      self.cells[self.cell_index(src_row, col_idx)],
    )
    col_idx += 1
  }
}

///|
fn ScreenGridState::clear_prev_row_spacer_head(
  self : ScreenGridState,
  row_idx : Int,
  style : CellStyle,
) -> Unit {
  let prev_row = row_idx - 1
  let last_col = self.cols.to_int() - 1
  let head = self.cells[self.cell_index(prev_row, last_col)]
  if head.wide() == PageCellWide::SpacerHead {
    self.clear_row_range(prev_row, last_col, self.cols.to_int(), style, false)
  }
}

///|
fn ScreenGridState::write_cell(
  self : ScreenGridState,
  row_idx : Int,
  col_idx : Int,
  codepoint : UInt,
  wide : PageCellWide,
  style : CellStyle,
  protected_flag : Bool,
  semantic_content : SemanticContent,
  hyperlink : CellHyperlink?,
) -> Unit {
  let cell = PageCellState::new()
  cell.set_codepoint(codepoint, false)
  cell.set_style(style)
  cell.set_wide(wide)
  cell.set_protected(protected_flag)
  cell.set_hyperlink(hyperlink)
  cell.set_semantic_content(semantic_content)
  self.cells[self.cell_index(row_idx, col_idx)] = cell
}

///|
fn ScreenGridState::set_cell(
  self : ScreenGridState,
  row_idx : Int,
  col_idx : Int,
  source : PageCellState,
) -> Unit {
  self.cells[self.cell_index(row_idx, col_idx)] = copy_page_cell(source)
}

///|
fn ScreenGridState::recompute_row_flags(
  self : ScreenGridState,
  row_idx : Int,
) -> Unit {
  let row = self.row_states[row_idx]
  let mut grapheme = false
  let mut styled = false
  let mut hyperlink = false
  let mut col_idx = 0
  while col_idx < self.cols.to_int() {
    let cell = self.cells[self.cell_index(row_idx, col_idx)]
    if cell.has_grapheme() {
      grapheme = true
    }
    if cell.has_styling() {
      styled = true
    }
    if cell.hyperlink() != None {
      hyperlink = true
    }
    col_idx += 1
  }
  row.set_grapheme(grapheme)
  row.set_styled(styled)
  row.set_hyperlink(hyperlink)
  row.set_kitty_virtual_placeholder(false)
}

///|
fn screen_dimension(value : CellCountInt) -> CellCountInt {
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
fn blank_cell(style : CellStyle) -> PageCellState {
  let cell = PageCellState::new()
  match style.bg_color() {
    None => ()
    Palette(index) => cell.set_background_palette(index)
    Rgb(rgb) => cell.set_background_rgb(rgb)
  }
  cell
}

///|
fn copy_page_row(row : PageRowState) -> PageRowState {
  {
    wrap: row.wrap,
    wrap_continuation: row.wrap_continuation,
    grapheme: row.grapheme,
    styled: row.styled,
    hyperlink: row.hyperlink,
    semantic_prompt: row.semantic_prompt,
    kitty_virtual_placeholder: row.kitty_virtual_placeholder,
    dirty: row.dirty,
  }
}

///|
fn copy_page_cell(cell : PageCellState) -> PageCellState {
  {
    content_tag: cell.content_tag,
    codepoint: cell.codepoint,
    palette_index: cell.palette_index,
    bg_rgb: cell.bg_rgb,
    style: copy_cell_style(cell.style),
    wide: cell.wide,
    protected_flag: cell.protected_flag,
    hyperlink: cell.hyperlink,
    semantic_content: cell.semantic_content,
  }
}
