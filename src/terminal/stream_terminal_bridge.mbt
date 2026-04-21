///|
const DefaultRows : CellCountInt = 24

///|
const DefaultColumns : CellCountInt = 80

///|
struct StreamTerminalBridgeState {
  protected_state : ScreenProtectedState
  display_state : TerminalDisplayState
  colors : TerminalColors
  modes : ModeState
  cursor : TerminalCursorState
  input_flags : TerminalInputFlags
  kitty_keyboard : KittyKeyboardState
  tabstops : TerminalTabstopsState
  saved_cursor : ScreenSavedCursorState
  mut charset : ScreenCharsetState
  mut current_style : CellStyle
  mut mouse_event : MouseEvent
  mut mouse_format : MouseFormat
  mut palette_dirty : Bool
} derive(Eq, Debug)

///|
pub fn StreamTerminalBridgeState::new() -> StreamTerminalBridgeState {
  {
    protected_state: ScreenProtectedState::new(),
    display_state: TerminalDisplayState::new(),
    colors: TerminalColors::new(),
    modes: ModeState::new(),
    cursor: TerminalCursorState::new(DefaultRows, DefaultColumns),
    input_flags: TerminalInputFlags::new(),
    kitty_keyboard: KittyKeyboardState::new(),
    tabstops: TerminalTabstopsState::new(DefaultColumns),
    saved_cursor: ScreenSavedCursorState::new(),
    charset: ScreenCharsetState::new(),
    current_style: CellStyle::new(),
    mouse_event: MouseEvent::None,
    mouse_format: MouseFormat::X10,
    palette_dirty: false,
  }
}

///|
pub fn StreamTerminalBridgeState::protected_state(
  self : StreamTerminalBridgeState,
) -> ScreenProtectedState {
  self.protected_state
}

///|
pub fn StreamTerminalBridgeState::display_state(
  self : StreamTerminalBridgeState,
) -> TerminalDisplayState {
  self.display_state
}

///|
pub fn StreamTerminalBridgeState::colors(
  self : StreamTerminalBridgeState,
) -> TerminalColors {
  self.colors
}

///|
pub fn StreamTerminalBridgeState::palette_dirty(
  self : StreamTerminalBridgeState,
) -> Bool {
  self.palette_dirty
}

///|
pub fn StreamTerminalBridgeState::clear_palette_dirty(
  self : StreamTerminalBridgeState,
) -> Unit {
  self.palette_dirty = false
}

///|
pub fn StreamTerminalBridgeState::mode_enabled(
  self : StreamTerminalBridgeState,
  mode : Mode,
) -> Bool {
  self.modes.get(mode)
}

///|
pub fn StreamTerminalBridgeState::cursor_x(
  self : StreamTerminalBridgeState,
) -> CellCountInt {
  self.cursor.x()
}

///|
pub fn StreamTerminalBridgeState::cursor_y(
  self : StreamTerminalBridgeState,
) -> CellCountInt {
  self.cursor.y()
}

///|
pub fn StreamTerminalBridgeState::cursor_visual_style(
  self : StreamTerminalBridgeState,
) -> CursorVisualStyle {
  self.cursor.visual_style()
}

///|
pub fn StreamTerminalBridgeState::cursor_pending_wrap(
  self : StreamTerminalBridgeState,
) -> Bool {
  self.cursor.pending_wrap()
}

///|
pub fn StreamTerminalBridgeState::cursor_top_margin(
  self : StreamTerminalBridgeState,
) -> CellCountInt {
  self.cursor.top_margin()
}

///|
pub fn StreamTerminalBridgeState::cursor_bottom_margin(
  self : StreamTerminalBridgeState,
) -> CellCountInt {
  self.cursor.bottom_margin()
}

///|
pub fn StreamTerminalBridgeState::cursor_left_margin(
  self : StreamTerminalBridgeState,
) -> CellCountInt {
  self.cursor.left_margin()
}

///|
pub fn StreamTerminalBridgeState::cursor_right_margin(
  self : StreamTerminalBridgeState,
) -> CellCountInt {
  self.cursor.right_margin()
}

///|
pub fn StreamTerminalBridgeState::mouse_shift_capture(
  self : StreamTerminalBridgeState,
) -> Bool? {
  self.input_flags.mouse_shift_capture()
}

///|
pub fn StreamTerminalBridgeState::modify_other_keys_2(
  self : StreamTerminalBridgeState,
) -> Bool {
  self.input_flags.modify_other_keys_2()
}

///|
pub fn StreamTerminalBridgeState::kitty_keyboard_flags(
  self : StreamTerminalBridgeState,
) -> KittyKeyboardFlags {
  self.kitty_keyboard.current()
}

///|
pub fn StreamTerminalBridgeState::tabstop(
  self : StreamTerminalBridgeState,
  col : CellCountInt,
) -> Bool {
  self.tabstops.get(col)
}

///|
pub fn StreamTerminalBridgeState::mouse_event(
  self : StreamTerminalBridgeState,
) -> MouseEvent {
  self.mouse_event
}

///|
pub fn StreamTerminalBridgeState::mouse_format(
  self : StreamTerminalBridgeState,
) -> MouseFormat {
  self.mouse_format
}

///|
pub fn StreamTerminalBridgeState::charset(
  self : StreamTerminalBridgeState,
  slot : Slots,
) -> Charset {
  self.charset.charset(slot)
}

///|
pub fn StreamTerminalBridgeState::charset_gl(
  self : StreamTerminalBridgeState,
) -> Slots {
  self.charset.gl()
}

///|
pub fn StreamTerminalBridgeState::charset_gr(
  self : StreamTerminalBridgeState,
) -> Slots {
  self.charset.gr()
}

///|
pub fn StreamTerminalBridgeState::charset_single_shift(
  self : StreamTerminalBridgeState,
) -> Slots? {
  self.charset.single_shift()
}

///|
pub fn StreamTerminalBridgeState::has_saved_cursor(
  self : StreamTerminalBridgeState,
) -> Bool {
  self.saved_cursor.has_saved()
}

///|
pub fn StreamTerminalBridgeState::apply(
  self : StreamTerminalBridgeState,
  action : StreamAction,
) -> Bool {
  match action {
    StreamProtectedModeOff => {
      self.protected_state.set(ProtectedMode::Off)
      true
    }
    StreamProtectedModeIso => {
      self.protected_state.set(ProtectedMode::Iso)
      true
    }
    StreamProtectedModeDec => {
      self.protected_state.set(ProtectedMode::Dec)
      true
    }
    StreamActiveStatusDisplay(display) => {
      self.display_state.set_status_display(display)
      true
    }
    StreamMouseShape(shape) => {
      self.display_state.set_mouse_shape(shape)
      true
    }
    StreamColorOperation(command) => {
      self.apply_color_operation(command)
      true
    }
    StreamInvokeCharset(charset) => {
      self.charset.invoke(charset.bank, charset.charset, charset.locking)
      true
    }
    StreamConfigureCharset(charset) => {
      self.charset.configure(charset.slot, charset.charset)
      true
    }
    StreamSaveCursor => {
      self.save_cursor()
      true
    }
    StreamRestoreCursor => {
      self.restore_cursor()
      true
    }
    StreamSetMode(mode) => {
      self.set_mode(mode, true)
      true
    }
    StreamResetMode(mode) => {
      self.set_mode(mode, false)
      true
    }
    StreamSaveMode(mode) => {
      self.modes.save(mode)
      true
    }
    StreamRestoreMode(mode) => {
      self.set_mode(mode, self.modes.restore(mode))
      true
    }
    StreamCursorUp(movement) => {
      self.cursor_up(movement)
      true
    }
    StreamCursorDown(movement) => {
      self.cursor_down(movement)
      true
    }
    StreamCursorLeft(movement) => {
      self.cursor_left(movement)
      true
    }
    StreamCursorRight(movement) => {
      self.cursor_right(movement)
      true
    }
    StreamCursorCol(movement) => {
      self.cursor.set_cursor_pos(
        self.cursor.y() + 1,
        movement_count(movement),
        self.modes.get(Mode::Origin),
      )
      true
    }
    StreamCursorRow(movement) => {
      self.cursor.set_cursor_pos(
        movement_count(movement),
        self.cursor.x() + 1,
        self.modes.get(Mode::Origin),
      )
      true
    }
    StreamCursorColRelative(movement) => {
      self.cursor.set_cursor_pos(
        self.cursor.y() + 1,
        saturated_request(
          self.cursor.x().to_int() + 1 + movement_count_int(movement),
        ),
        self.modes.get(Mode::Origin),
      )
      true
    }
    StreamCursorRowRelative(movement) => {
      self.cursor.set_cursor_pos(
        saturated_request(
          self.cursor.y().to_int() + 1 + movement_count_int(movement),
        ),
        self.cursor.x() + 1,
        self.modes.get(Mode::Origin),
      )
      true
    }
    StreamCursorPos(position) => {
      self.cursor.set_cursor_pos(
        position.row,
        position.col,
        self.modes.get(Mode::Origin),
      )
      true
    }
    StreamCursorStyle(style) => {
      self.modes.set(
        Mode::CursorBlinking,
        self.cursor.apply_cursor_style(style),
      )
      true
    }
    StreamTabSet => {
      self.tabstops.set(self.cursor.x())
      true
    }
    StreamTabClearCurrent => {
      self.tabstops.unset(self.cursor.x())
      true
    }
    StreamTabClearAll => {
      self.tabstops.reset(0)
      true
    }
    StreamTabReset => {
      self.tabstops.reset(8)
      true
    }
    StreamHorizontalTab(count) => {
      self.horizontal_tab(count)
      true
    }
    StreamHorizontalTabBack(count) => {
      self.horizontal_tab_back(count)
      true
    }
    StreamTopAndBottomMargin(margin) => {
      self.cursor.set_top_and_bottom_margin(
        margin.top_left,
        margin.bottom_right,
        self.modes.get(Mode::Origin),
      )
      true
    }
    StreamLeftAndRightMargin(margin) => {
      self.cursor.set_left_and_right_margin(
        self.modes.get(Mode::EnableLeftAndRightMargin),
        margin.top_left,
        margin.bottom_right,
        self.modes.get(Mode::Origin),
      )
      true
    }
    StreamLeftAndRightMarginAmbiguous => {
      if self.modes.get(Mode::EnableLeftAndRightMargin) {
        self.cursor.set_left_and_right_margin(
          true,
          0,
          0,
          self.modes.get(Mode::Origin),
        )
      } else {
        self.save_cursor()
      }
      true
    }
    StreamModifyKeyFormat(format) => {
      self.input_flags.apply_modify_key_format(format)
      true
    }
    StreamMouseShiftCapture(enabled) => {
      self.input_flags.set_mouse_shift_capture(enabled)
      true
    }
    StreamKittyKeyboardPush(flags) => {
      self.kitty_keyboard.push(flags)
      true
    }
    StreamKittyKeyboardPop(count) => {
      self.kitty_keyboard.pop(count)
      true
    }
    StreamKittyKeyboardSet(flags) => {
      self.kitty_keyboard.set(flags)
      true
    }
    StreamKittyKeyboardSetOr(flags) => {
      self.kitty_keyboard.set_or(flags)
      true
    }
    StreamKittyKeyboardSetNot(flags) => {
      self.kitty_keyboard.set_not(flags)
      true
    }
    _ => false
  }
}

///|
fn StreamTerminalBridgeState::save_cursor(
  self : StreamTerminalBridgeState,
) -> Unit {
  self.saved_cursor.save(
    self.cursor,
    self.current_style,
    self.protected_state.cursor_protected(),
    self.modes.get(Mode::Origin),
    self.charset,
  )
}

///|
fn StreamTerminalBridgeState::restore_cursor(
  self : StreamTerminalBridgeState,
) -> Unit {
  let saved = self.saved_cursor.restore()
  self.current_style = saved.style()
  self.charset = saved.charset()
  self.modes.set(Mode::Origin, saved.origin())
  self.cursor.set_pending_wrap(saved.pending_wrap())
  self.protected_state.set_cursor_protected(saved.cursor_protected())
  self.cursor.set_cursor_pos(saved.y() + 1, saved.x() + 1, false)
  self.cursor.set_pending_wrap(saved.pending_wrap())
}

///|
fn StreamTerminalBridgeState::set_mode(
  self : StreamTerminalBridgeState,
  mode : Mode,
  enabled : Bool,
) -> Unit {
  self.modes.set(mode, enabled)
  match mode {
    Origin => self.cursor.set_cursor_pos(1, 1, self.modes.get(Mode::Origin))
    EnableLeftAndRightMargin =>
      if !enabled {
        self.reset_left_and_right_margin()
      }
    SaveCursor =>
      if enabled {
        self.save_cursor()
      } else {
        self.restore_cursor()
      }
    MouseEventX10 =>
      self.mouse_event = if enabled {
        MouseEvent::X10
      } else {
        MouseEvent::None
      }
    MouseEventNormal =>
      self.mouse_event = if enabled {
        MouseEvent::Normal
      } else {
        MouseEvent::None
      }
    MouseEventButton =>
      self.mouse_event = if enabled {
        MouseEvent::Button
      } else {
        MouseEvent::None
      }
    MouseEventAny =>
      self.mouse_event = if enabled {
        MouseEvent::Any
      } else {
        MouseEvent::None
      }
    MouseFormatUtf8 =>
      self.mouse_format = if enabled {
        MouseFormat::Utf8
      } else {
        MouseFormat::X10
      }
    MouseFormatSgr =>
      self.mouse_format = if enabled {
        MouseFormat::Sgr
      } else {
        MouseFormat::X10
      }
    MouseFormatUrxvt =>
      self.mouse_format = if enabled {
        MouseFormat::Urxvt
      } else {
        MouseFormat::X10
      }
    MouseFormatSgrPixels =>
      self.mouse_format = if enabled {
        MouseFormat::SgrPixels
      } else {
        MouseFormat::X10
      }
    _ => ()
  }
}

///|
fn StreamTerminalBridgeState::reset_left_and_right_margin(
  self : StreamTerminalBridgeState,
) -> Unit {
  let x = self.cursor.x()
  let y = self.cursor.y()
  let pending_wrap = self.cursor.pending_wrap()
  self.cursor.set_left_and_right_margin(
    true,
    1,
    DefaultColumns,
    self.modes.get(Mode::Origin),
  )
  self.cursor.set_cursor_pos(y + 1, x + 1, false)
  self.cursor.set_pending_wrap(pending_wrap)
}

///|
fn StreamTerminalBridgeState::horizontal_tab(
  self : StreamTerminalBridgeState,
  count : UInt16,
) -> Unit {
  let mut remaining = count.to_int()
  while remaining > 0 {
    let x = self.cursor.x()
    self.horizontal_tab_once()
    if x == self.cursor.x() {
      return
    }
    remaining -= 1
  }
}

///|
fn StreamTerminalBridgeState::horizontal_tab_once(
  self : StreamTerminalBridgeState,
) -> Unit {
  let right_limit = self.cursor.right_margin().to_int()
  while self.cursor.x().to_int() < right_limit {
    self.cursor_right(CursorMovement(1))
    if self.tabstops.get(self.cursor.x()) {
      return
    }
  }
}

///|
fn StreamTerminalBridgeState::horizontal_tab_back(
  self : StreamTerminalBridgeState,
  count : UInt16,
) -> Unit {
  let mut remaining = count.to_int()
  while remaining > 0 {
    let x = self.cursor.x()
    self.horizontal_tab_back_once()
    if x == self.cursor.x() {
      return
    }
    remaining -= 1
  }
}

///|
fn StreamTerminalBridgeState::horizontal_tab_back_once(
  self : StreamTerminalBridgeState,
) -> Unit {
  let left_limit = if self.modes.get(Mode::Origin) {
    self.cursor.left_margin().to_int()
  } else {
    0
  }

  while true {
    if self.cursor.x().to_int() <= left_limit {
      return
    }
    self.cursor_left(CursorMovement(1))
    if self.tabstops.get(self.cursor.x()) {
      return
    }
  }
}

///|
fn StreamTerminalBridgeState::cursor_up(
  self : StreamTerminalBridgeState,
  movement : CursorMovement,
) -> Unit {
  self.cursor.set_pending_wrap(false)
  let y = self.cursor.y().to_int()
  let top = self.cursor.top_margin().to_int()
  let max = if y >= top { y - top } else { y }
  let count = bounded_count(movement_count_int(movement), max)
  self.cursor.set_cursor_pos(
    (y - count + 1).to_uint16(),
    self.cursor.x() + 1,
    false,
  )
}

///|
fn StreamTerminalBridgeState::cursor_down(
  self : StreamTerminalBridgeState,
  movement : CursorMovement,
) -> Unit {
  self.cursor.set_pending_wrap(false)
  let y = self.cursor.y().to_int()
  let bottom = self.cursor.bottom_margin().to_int()
  let max = if y <= bottom { bottom - y } else { DefaultRows.to_int() - y - 1 }
  let count = bounded_count(movement_count_int(movement), max)
  self.cursor.set_cursor_pos(
    (y + count + 1).to_uint16(),
    self.cursor.x() + 1,
    false,
  )
}

///|
fn StreamTerminalBridgeState::cursor_right(
  self : StreamTerminalBridgeState,
  movement : CursorMovement,
) -> Unit {
  self.cursor.set_pending_wrap(false)
  let x = self.cursor.x().to_int()
  let right = self.cursor.right_margin().to_int()
  let max = if x <= right { right - x } else { DefaultColumns.to_int() - x - 1 }
  let count = bounded_count(movement_count_int(movement), max)
  self.cursor.set_cursor_pos(
    self.cursor.y() + 1,
    (x + count + 1).to_uint16(),
    false,
  )
}

///|
fn StreamTerminalBridgeState::cursor_left(
  self : StreamTerminalBridgeState,
  movement : CursorMovement,
) -> Unit {
  // Reverse-wrap needs row soft-wrap state from the screen model, so this
  // bridge slice keeps the non-wrap clamp behavior only.
  self.cursor.set_pending_wrap(false)
  let x = self.cursor.x().to_int()
  let left_limit = if self.modes.get(Mode::Origin) {
    self.cursor.left_margin().to_int()
  } else {
    0
  }
  let max = if x >= left_limit { x - left_limit } else { x }
  let count = bounded_count(movement_count_int(movement), max)
  self.cursor.set_cursor_pos(
    self.cursor.y() + 1,
    (x - count + 1).to_uint16(),
    false,
  )
}

///|
fn StreamTerminalBridgeState::apply_color_operation(
  self : StreamTerminalBridgeState,
  command : ColorCommand,
) -> Unit {
  let _ = command.op()
  let requests = command.requests()
  if requests.length() == 0 {
    return
  }

  for request in requests {
    match request {
      Set(set) => self.apply_color_set(set)
      Query(_) => ()
      Reset(target) => self.apply_color_reset(target)
      ResetPalette =>
        if self.colors.has_palette_changes() {
          self.colors.reset_palette()
          self.palette_dirty = true
        }
    }
  }
}

///|
fn StreamTerminalBridgeState::apply_color_set(
  self : StreamTerminalBridgeState,
  set : ColoredTarget,
) -> Unit {
  match set.target() {
    Palette(index) => {
      self.colors.set_palette_color(index, set.color())
      self.palette_dirty = true
    }
    Dynamic(dynamic) =>
      match dynamic {
        Foreground => self.colors.set_foreground(set.color())
        Background => self.colors.set_background(set.color())
        Cursor => self.colors.set_cursor(set.color())
        PointerForeground
        | PointerBackground
        | TektronixForeground
        | TektronixBackground
        | HighlightBackground
        | TektronixCursor
        | HighlightForeground => ()
      }
    Special(_) => ()
  }
}

///|
fn StreamTerminalBridgeState::apply_color_reset(
  self : StreamTerminalBridgeState,
  target : ColorTarget,
) -> Unit {
  match target {
    Palette(index) => {
      self.colors.reset_palette_color(index)
      self.palette_dirty = true
    }
    Dynamic(dynamic) =>
      match dynamic {
        Foreground => self.colors.reset_foreground()
        Background => self.colors.reset_background()
        Cursor => self.colors.reset_cursor()
        PointerForeground
        | PointerBackground
        | TektronixForeground
        | TektronixBackground
        | HighlightBackground
        | TektronixCursor
        | HighlightForeground => ()
      }
    Special(_) => ()
  }
}

///|
fn movement_count(movement : CursorMovement) -> CellCountInt {
  if movement.0 == 0 {
    1
  } else {
    movement.0
  }
}

///|
fn movement_count_int(movement : CursorMovement) -> Int {
  movement_count(movement).to_int()
}

///|
fn bounded_count(request : Int, max : Int) -> Int {
  if request > max {
    max
  } else {
    request
  }
}

///|
fn saturated_request(value : Int) -> CellCountInt {
  if value > 0xFFFF {
    0xFFFF
  } else {
    value.to_uint16()
  }
}
