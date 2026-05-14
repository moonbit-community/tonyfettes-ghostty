///|
const DefaultRows : CellCountInt = 24

///|
const DefaultColumns : CellCountInt = 80

///|
const DefaultMaxScrollback : Int = 10_000

///|
const DefaultXtversion : String = "libghostty"

///|
const MaxTitleBytes : Int = 1024

///|
const MaxEnquiryBytes : Int = 256

///|
const MaxXtversionBytes : Int = 256

///|
priv struct StreamTerminalBridgeEffects {
  mut write_pty : (Bytes) -> Unit
  mut bell : () -> Unit
  mut color_scheme : () -> ColorScheme?
  mut device_attributes : () -> DeviceAttributes?
  mut enquiry : () -> Bytes
  mut size : () -> Size?
  mut title_changed : () -> Unit
  mut xtversion : () -> String
}

///|
fn StreamTerminalBridgeEffects::new(
  write_pty? : (Bytes) -> Unit = fn(_data) { () },
  bell? : () -> Unit = fn() { () },
  color_scheme? : () -> ColorScheme? = fn() { None },
  device_attributes? : () -> DeviceAttributes? = fn() { None },
  enquiry? : () -> Bytes = fn() { b"" },
  size? : () -> Size? = fn() { None },
  title_changed? : () -> Unit = fn() { () },
  xtversion? : () -> String = fn() { "" },
) -> StreamTerminalBridgeEffects {
  {
    write_pty,
    bell,
    color_scheme,
    device_attributes,
    enquiry,
    size,
    title_changed,
    xtversion,
  }
}

///|
fn StreamTerminalBridgeEffects::set_write_pty(
  self : StreamTerminalBridgeEffects,
  callback : (Bytes) -> Unit,
) -> Unit {
  self.write_pty = callback
}

///|
fn StreamTerminalBridgeEffects::clear_write_pty(
  self : StreamTerminalBridgeEffects,
) -> Unit {
  self.write_pty = fn(_data) { () }
}

///|
fn StreamTerminalBridgeEffects::set_bell(
  self : StreamTerminalBridgeEffects,
  callback : () -> Unit,
) -> Unit {
  self.bell = callback
}

///|
fn StreamTerminalBridgeEffects::clear_bell(
  self : StreamTerminalBridgeEffects,
) -> Unit {
  self.bell = fn() { () }
}

///|
fn StreamTerminalBridgeEffects::set_color_scheme(
  self : StreamTerminalBridgeEffects,
  callback : () -> ColorScheme?,
) -> Unit {
  self.color_scheme = callback
}

///|
fn StreamTerminalBridgeEffects::clear_color_scheme(
  self : StreamTerminalBridgeEffects,
) -> Unit {
  self.color_scheme = fn() { None }
}

///|
fn StreamTerminalBridgeEffects::set_device_attributes(
  self : StreamTerminalBridgeEffects,
  callback : () -> DeviceAttributes?,
) -> Unit {
  self.device_attributes = callback
}

///|
fn StreamTerminalBridgeEffects::clear_device_attributes(
  self : StreamTerminalBridgeEffects,
) -> Unit {
  self.device_attributes = fn() { None }
}

///|
fn StreamTerminalBridgeEffects::set_enquiry(
  self : StreamTerminalBridgeEffects,
  callback : () -> Bytes,
) -> Unit {
  self.enquiry = callback
}

///|
fn StreamTerminalBridgeEffects::clear_enquiry(
  self : StreamTerminalBridgeEffects,
) -> Unit {
  self.enquiry = fn() { b"" }
}

///|
fn StreamTerminalBridgeEffects::set_size(
  self : StreamTerminalBridgeEffects,
  callback : () -> Size?,
) -> Unit {
  self.size = callback
}

///|
fn StreamTerminalBridgeEffects::clear_size(
  self : StreamTerminalBridgeEffects,
) -> Unit {
  self.size = fn() { None }
}

///|
fn StreamTerminalBridgeEffects::set_title_changed(
  self : StreamTerminalBridgeEffects,
  callback : () -> Unit,
) -> Unit {
  self.title_changed = callback
}

///|
fn StreamTerminalBridgeEffects::clear_title_changed(
  self : StreamTerminalBridgeEffects,
) -> Unit {
  self.title_changed = fn() { () }
}

///|
fn StreamTerminalBridgeEffects::set_xtversion(
  self : StreamTerminalBridgeEffects,
  callback : () -> String,
) -> Unit {
  self.xtversion = callback
}

///|
fn StreamTerminalBridgeEffects::clear_xtversion(
  self : StreamTerminalBridgeEffects,
) -> Unit {
  self.xtversion = fn() { "" }
}

///|
priv struct StreamTerminalBridgeState {
  effects : StreamTerminalBridgeEffects
  apc_handler : ApcHandler
  protected_state : ScreenProtectedState
  display_state : TerminalDisplayState
  colors : TerminalColors
  modes : ModeState
  mut cursor : TerminalCursorState
  input_flags : TerminalInputFlags
  kitty_keyboard : KittyKeyboardState
  mut tabstops : TerminalTabstopsState
  hyperlink : ScreenHyperlinkState
  semantic : ScreenSemanticState
  metadata : TerminalMetadataState
  mut grid : ScreenGridState
  mut scrollback : PageList
  mut kitty_graphics : KittyGraphicsState
  mut primary_storage : TerminalScreenStorage
  mut alternate_storage : TerminalScreenStorage
  mut charset : ScreenCharsetState
  mut current_style : CellStyle
  mut previous_char : UInt?
  mut mouse_event : MouseEvent
  mut mouse_format : MouseFormat
  mut palette_dirty : Bool
  mut active_screen : TerminalScreen
  mut width_px : UInt
  mut height_px : UInt
  mut scrollback_cleared : Bool
}

///|
fn StreamTerminalBridgeState::with_effects(
  effects : StreamTerminalBridgeEffects,
) -> StreamTerminalBridgeState {
  let primary_storage = TerminalScreenStorage::new(
    DefaultRows,
    DefaultColumns,
    DefaultMaxScrollback,
  )
  let alternate_storage = TerminalScreenStorage::new(
    DefaultRows,
    DefaultColumns,
    0,
  )
  {
    effects,
    apc_handler: ApcHandler::new(),
    protected_state: ScreenProtectedState::new(),
    display_state: TerminalDisplayState::new(),
    colors: TerminalColors::new(),
    modes: ModeState::new(),
    cursor: primary_storage.cursor,
    input_flags: TerminalInputFlags::new(),
    kitty_keyboard: KittyKeyboardState::new(),
    tabstops: TerminalTabstopsState::new(DefaultColumns),
    hyperlink: ScreenHyperlinkState::new(),
    semantic: ScreenSemanticState::new(),
    metadata: TerminalMetadataState::new(),
    grid: primary_storage.grid,
    scrollback: primary_storage.scrollback,
    kitty_graphics: primary_storage.kitty_graphics,
    primary_storage,
    alternate_storage,
    charset: ScreenCharsetState::new(),
    current_style: CellStyle::new(),
    previous_char: None,
    mouse_event: MouseEvent::None,
    mouse_format: MouseFormat::X10,
    palette_dirty: false,
    active_screen: TerminalScreen::Primary,
    width_px: 0U,
    height_px: 0U,
    scrollback_cleared: false,
  }
}

///|
fn StreamTerminalBridgeState::palette_dirty(
  self : StreamTerminalBridgeState,
) -> Bool {
  self.palette_dirty
}

///|
fn StreamTerminalBridgeState::clear_palette_dirty(
  self : StreamTerminalBridgeState,
) -> Unit {
  self.palette_dirty = false
}

///|
fn StreamTerminalBridgeState::take_scrollback_cleared(
  self : StreamTerminalBridgeState,
) -> Bool {
  let value = self.scrollback_cleared
  self.scrollback_cleared = false
  value
}

///|
fn StreamTerminalBridgeState::mode_enabled(
  self : StreamTerminalBridgeState,
  mode : Mode,
) -> Bool {
  self.modes.get(mode)
}

///|
fn StreamTerminalBridgeState::cursor_x(
  self : StreamTerminalBridgeState,
) -> CellCountInt {
  self.cursor.x()
}

///|
fn StreamTerminalBridgeState::cursor_y(
  self : StreamTerminalBridgeState,
) -> CellCountInt {
  self.cursor.y()
}

///|
fn StreamTerminalBridgeState::cursor_visual_style(
  self : StreamTerminalBridgeState,
) -> CursorVisualStyle {
  self.cursor.visual_style()
}

///|
fn StreamTerminalBridgeState::cursor_visible(
  self : StreamTerminalBridgeState,
) -> Bool {
  self.modes.get(Mode::CursorVisible)
}

///|
fn StreamTerminalBridgeState::cursor_pending_wrap(
  self : StreamTerminalBridgeState,
) -> Bool {
  self.cursor.pending_wrap()
}

///|
fn StreamTerminalBridgeState::cursor_top_margin(
  self : StreamTerminalBridgeState,
) -> CellCountInt {
  self.cursor.top_margin()
}

///|
fn StreamTerminalBridgeState::cursor_bottom_margin(
  self : StreamTerminalBridgeState,
) -> CellCountInt {
  self.cursor.bottom_margin()
}

///|
fn StreamTerminalBridgeState::cursor_left_margin(
  self : StreamTerminalBridgeState,
) -> CellCountInt {
  self.cursor.left_margin()
}

///|
fn StreamTerminalBridgeState::cursor_right_margin(
  self : StreamTerminalBridgeState,
) -> CellCountInt {
  self.cursor.right_margin()
}

///|
fn StreamTerminalBridgeState::modify_other_keys_2(
  self : StreamTerminalBridgeState,
) -> Bool {
  self.input_flags.modify_other_keys_2()
}

///|
fn StreamTerminalBridgeState::kitty_keyboard_flags(
  self : StreamTerminalBridgeState,
) -> KittyKeyboardFlags {
  self.kitty_keyboard.current()
}

///|
fn StreamTerminalBridgeState::mouse_event(
  self : StreamTerminalBridgeState,
) -> MouseEvent {
  self.mouse_event
}

///|
fn StreamTerminalBridgeState::mouse_format(
  self : StreamTerminalBridgeState,
) -> MouseFormat {
  self.mouse_format
}

///|
fn StreamTerminalBridgeState::mouse_tracking(
  self : StreamTerminalBridgeState,
) -> Bool {
  self.mouse_event != MouseEvent::None
}

///|
fn StreamTerminalBridgeState::current_style_snapshot(
  self : StreamTerminalBridgeState,
) -> CellStyle {
  copy_cell_style(self.current_style)
}

///|
fn StreamTerminalBridgeState::title(
  self : StreamTerminalBridgeState,
) -> String? {
  self.metadata.title()
}

///|
fn StreamTerminalBridgeState::set_title(
  self : StreamTerminalBridgeState,
  title : String,
) -> Unit {
  self.metadata.set_title(title)
}

///|
fn StreamTerminalBridgeState::pwd(self : StreamTerminalBridgeState) -> String? {
  self.metadata.pwd()
}

///|
fn StreamTerminalBridgeState::set_pwd(
  self : StreamTerminalBridgeState,
  pwd : String,
) -> Unit {
  self.metadata.set_pwd(pwd)
}

///|
fn StreamTerminalBridgeState::set_default_foreground_color(
  self : StreamTerminalBridgeState,
  color : RGB?,
) -> Unit {
  self.colors.set_default_foreground(color)
  self.palette_dirty = true
}

///|
fn StreamTerminalBridgeState::set_default_background_color(
  self : StreamTerminalBridgeState,
  color : RGB?,
) -> Unit {
  self.colors.set_default_background(color)
  self.palette_dirty = true
}

///|
fn StreamTerminalBridgeState::set_default_cursor_color(
  self : StreamTerminalBridgeState,
  color : RGB?,
) -> Unit {
  self.colors.set_default_cursor(color)
  self.palette_dirty = true
}

///|
fn StreamTerminalBridgeState::set_default_palette(
  self : StreamTerminalBridgeState,
  palette : Array[RGB]?,
) -> TerminalResultCode {
  if !self.colors.set_default_palette(palette) {
    return TerminalResultCode::InvalidValue
  }
  self.palette_dirty = true
  TerminalResultCode::Success
}

///|
fn StreamTerminalBridgeState::screen_row_snapshot(
  self : StreamTerminalBridgeState,
  row : CellCountInt,
) -> PageRowState? {
  self.scrollback.row(self.grid, row)
}

///|
fn StreamTerminalBridgeState::screen_cell_snapshot(
  self : StreamTerminalBridgeState,
  row : CellCountInt,
  col : CellCountInt,
) -> PageCellState? {
  self.scrollback.cell(self.grid, row, col)
}

///|
fn StreamTerminalBridgeState::point_from_point(
  self : StreamTerminalBridgeState,
  point : Point,
  tag : Tag,
) -> Coordinate? {
  self.scrollback.point_from_point(self.grid, point, tag)
}

///|
fn StreamTerminalBridgeState::cell_at_point(
  self : StreamTerminalBridgeState,
  point : Point,
) -> PageCellState? {
  self.scrollback.cell_at_point(self.grid, point)
}

///|
fn StreamTerminalBridgeState::rows(
  self : StreamTerminalBridgeState,
) -> CellCountInt {
  self.grid.rows
}

///|
fn StreamTerminalBridgeState::columns(
  self : StreamTerminalBridgeState,
) -> CellCountInt {
  self.grid.cols
}

///|
fn StreamTerminalBridgeState::active_screen(
  self : StreamTerminalBridgeState,
) -> TerminalScreen {
  self.active_screen
}

///|
fn StreamTerminalBridgeState::total_rows(
  self : StreamTerminalBridgeState,
) -> UInt {
  self.scrollback.total_rows(self.grid.rows)
}

///|
fn StreamTerminalBridgeState::scrollback_rows(
  self : StreamTerminalBridgeState,
) -> UInt {
  self.scrollback.scrollback_rows()
}

///|
fn StreamTerminalBridgeState::scrollbar(
  self : StreamTerminalBridgeState,
) -> TerminalScrollbar {
  self.scrollback.scrollbar(self.grid.rows)
}

///|
fn StreamTerminalBridgeState::width_px(
  self : StreamTerminalBridgeState,
) -> UInt {
  self.width_px
}

///|
fn StreamTerminalBridgeState::height_px(
  self : StreamTerminalBridgeState,
) -> UInt {
  self.height_px
}

///|
fn StreamTerminalBridgeState::foreground_color(
  self : StreamTerminalBridgeState,
) -> RGB? {
  self.colors.foreground()
}

///|
fn StreamTerminalBridgeState::background_color(
  self : StreamTerminalBridgeState,
) -> RGB? {
  self.colors.background()
}

///|
fn StreamTerminalBridgeState::cursor_color(
  self : StreamTerminalBridgeState,
) -> RGB? {
  self.colors.cursor()
}

///|
fn StreamTerminalBridgeState::default_foreground_color(
  self : StreamTerminalBridgeState,
) -> RGB? {
  self.colors.default_foreground()
}

///|
fn StreamTerminalBridgeState::default_background_color(
  self : StreamTerminalBridgeState,
) -> RGB? {
  self.colors.default_background()
}

///|
fn StreamTerminalBridgeState::default_cursor_color(
  self : StreamTerminalBridgeState,
) -> RGB? {
  self.colors.default_cursor()
}

///|
fn StreamTerminalBridgeState::palette(
  self : StreamTerminalBridgeState,
) -> Array[RGB] {
  self.colors.palette_snapshot()
}

///|
fn StreamTerminalBridgeState::default_palette(
  self : StreamTerminalBridgeState,
) -> Array[RGB] {
  self.colors.default_palette_snapshot()
}

///|
fn StreamTerminalBridgeState::reset(self : StreamTerminalBridgeState) -> Unit {
  self.full_reset()
}

///|
fn StreamTerminalBridgeState::mode_get(
  self : StreamTerminalBridgeState,
  mode : Mode,
) -> Bool {
  self.mode_enabled(mode)
}

///|
fn StreamTerminalBridgeState::mode_set(
  self : StreamTerminalBridgeState,
  mode : Mode,
  enabled : Bool,
) -> Unit {
  self.set_mode(mode, enabled)
}

///|
fn StreamTerminalBridgeState::set_write_pty(
  self : StreamTerminalBridgeState,
  callback : (Bytes) -> Unit,
) -> Unit {
  self.effects.set_write_pty(callback)
}

///|
fn StreamTerminalBridgeState::clear_write_pty(
  self : StreamTerminalBridgeState,
) -> Unit {
  self.effects.clear_write_pty()
}

///|
fn StreamTerminalBridgeState::set_bell(
  self : StreamTerminalBridgeState,
  callback : () -> Unit,
) -> Unit {
  self.effects.set_bell(callback)
}

///|
fn StreamTerminalBridgeState::clear_bell(
  self : StreamTerminalBridgeState,
) -> Unit {
  self.effects.clear_bell()
}

///|
fn StreamTerminalBridgeState::set_color_scheme(
  self : StreamTerminalBridgeState,
  callback : () -> ColorScheme?,
) -> Unit {
  self.effects.set_color_scheme(callback)
}

///|
fn StreamTerminalBridgeState::clear_color_scheme(
  self : StreamTerminalBridgeState,
) -> Unit {
  self.effects.clear_color_scheme()
}

///|
fn StreamTerminalBridgeState::set_device_attributes(
  self : StreamTerminalBridgeState,
  callback : () -> DeviceAttributes?,
) -> Unit {
  self.effects.set_device_attributes(callback)
}

///|
fn StreamTerminalBridgeState::clear_device_attributes(
  self : StreamTerminalBridgeState,
) -> Unit {
  self.effects.clear_device_attributes()
}

///|
fn StreamTerminalBridgeState::set_enquiry(
  self : StreamTerminalBridgeState,
  callback : () -> Bytes,
) -> Unit {
  self.effects.set_enquiry(callback)
}

///|
fn StreamTerminalBridgeState::clear_enquiry(
  self : StreamTerminalBridgeState,
) -> Unit {
  self.effects.clear_enquiry()
}

///|
fn StreamTerminalBridgeState::set_size(
  self : StreamTerminalBridgeState,
  callback : () -> Size?,
) -> Unit {
  self.effects.set_size(callback)
}

///|
fn StreamTerminalBridgeState::clear_size(
  self : StreamTerminalBridgeState,
) -> Unit {
  self.effects.clear_size()
}

///|
fn StreamTerminalBridgeState::set_title_changed(
  self : StreamTerminalBridgeState,
  callback : () -> Unit,
) -> Unit {
  self.effects.set_title_changed(callback)
}

///|
fn StreamTerminalBridgeState::clear_title_changed(
  self : StreamTerminalBridgeState,
) -> Unit {
  self.effects.clear_title_changed()
}

///|
fn StreamTerminalBridgeState::set_xtversion(
  self : StreamTerminalBridgeState,
  callback : () -> String,
) -> Unit {
  self.effects.set_xtversion(callback)
}

///|
fn StreamTerminalBridgeState::clear_xtversion(
  self : StreamTerminalBridgeState,
) -> Unit {
  self.effects.clear_xtversion()
}

///|
fn StreamTerminalBridgeState::resize(
  self : StreamTerminalBridgeState,
  columns : CellCountInt,
  rows : CellCountInt,
  cell_width_px : UInt,
  cell_height_px : UInt,
) -> TerminalResultCode {
  if columns == 0 || rows == 0 {
    return TerminalResultCode::InvalidValue
  }

  self.store_active_screen()
  let active_screen = self.active_screen
  ignore(self.primary_storage.resize(rows, columns))
  ignore(self.alternate_storage.resize(rows, columns))
  self.load_active_screen(active_screen)
  self.tabstops = TerminalTabstopsState::new(columns)
  self.width_px = saturated_dimension(columns, cell_width_px)
  self.height_px = saturated_dimension(rows, cell_height_px)
  self.modes.set(Mode::SynchronizedOutput, false)
  if self.modes.get(Mode::InBandSizeReports) {
    self.write_pty(
      encode(Mode2048, Size::new(rows, columns, cell_width_px, cell_height_px)),
    )
  }
  TerminalResultCode::Success
}

///|
fn StreamTerminalBridgeState::scroll_viewport_top(
  self : StreamTerminalBridgeState,
) -> Unit {
  self.scrollback.scroll_top()
}

///|
fn StreamTerminalBridgeState::scroll_viewport_bottom(
  self : StreamTerminalBridgeState,
) -> Unit {
  self.scrollback.scroll_bottom()
}

///|
fn StreamTerminalBridgeState::scroll_viewport_delta(
  self : StreamTerminalBridgeState,
  delta : Int,
) -> Unit {
  self.scrollback.scroll_delta(delta)
}

///|
fn StreamTerminalBridgeState::apply(
  self : StreamTerminalBridgeState,
  action : StreamAction,
) -> Bool {
  match action {
    StreamPrint(codepoint) => {
      self.print(codepoint)
      true
    }
    StreamPrintRepeat(count) => {
      self.print_repeat(count)
      true
    }
    StreamBell => {
      self.bell()
      true
    }
    StreamBackspace => {
      self.cursor_left(CursorMovement(1))
      true
    }
    StreamCarriageReturn => {
      self.carriage_return()
      true
    }
    StreamLinefeed => {
      self.linefeed()
      true
    }
    StreamIndex => {
      self.index()
      true
    }
    StreamNextLine => {
      self.index()
      self.carriage_return()
      true
    }
    StreamReverseIndex => {
      self.reverse_index()
      true
    }
    StreamEnquiry => {
      self.report_enquiry()
      true
    }
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
    StreamKittyColorReport(command) => {
      self.apply_kitty_color_report(command)
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
    StreamRequestMode(mode) => {
      self.request_mode(mode)
      true
    }
    StreamRequestModeUnknown(tag) => {
      self.request_mode_unknown(tag)
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
    StreamSetAttribute(attribute) => {
      self.current_style.apply_attribute(attribute)
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
    StreamSizeReport(style) => {
      self.report_size(style)
      true
    }
    StreamTitlePush(_) => true
    StreamTitlePop(_) => true
    StreamXtversion => {
      self.report_xtversion()
      true
    }
    StreamWindowTitle(title) => {
      self.window_title(title)
      true
    }
    StreamClipboardContents(_) => true
    StreamReportPwd(_) => true
    StreamShowDesktopNotification(_) => true
    StreamProgressReport(_) => true
    StreamEraseDisplayBelow(protected_req) => {
      self.grid.erase_display(
        self.cursor,
        self.current_style,
        ScreenEraseDisplayMode::Below,
        self.protected_state.mode(),
        protected_req,
      )
      true
    }
    StreamEraseDisplayAbove(protected_req) => {
      self.grid.erase_display(
        self.cursor,
        self.current_style,
        ScreenEraseDisplayMode::Above,
        self.protected_state.mode(),
        protected_req,
      )
      true
    }
    StreamEraseDisplayComplete(protected_req) => {
      self.grid.erase_display(
        self.cursor,
        self.current_style,
        ScreenEraseDisplayMode::Complete,
        self.protected_state.mode(),
        protected_req,
      )
      true
    }
    StreamEraseDisplayScrollback(protected_req) => {
      ignore(protected_req)
      self.scrollback.clear_history()
      self.scrollback_cleared = true
      true
    }
    StreamEraseDisplayScrollComplete(protected_req) => {
      self.scrollback.clear_history()
      self.scrollback_cleared = true
      self.grid.erase_display(
        self.cursor,
        self.current_style,
        ScreenEraseDisplayMode::ScrollComplete,
        self.protected_state.mode(),
        protected_req,
      )
      true
    }
    StreamEraseLineRight(protected_req) => {
      self.grid.erase_line(
        self.cursor,
        self.current_style,
        ScreenEraseLineMode::Right,
        self.protected_state.mode(),
        protected_req,
      )
      true
    }
    StreamEraseLineLeft(protected_req) => {
      self.grid.erase_line(
        self.cursor,
        self.current_style,
        ScreenEraseLineMode::Left,
        self.protected_state.mode(),
        protected_req,
      )
      true
    }
    StreamEraseLineComplete(protected_req) => {
      self.grid.erase_line(
        self.cursor,
        self.current_style,
        ScreenEraseLineMode::Complete,
        self.protected_state.mode(),
        protected_req,
      )
      true
    }
    StreamEraseLineRightUnlessPendingWrap(protected_req) => {
      if !self.cursor.pending_wrap() {
        self.grid.erase_line(
          self.cursor,
          self.current_style,
          ScreenEraseLineMode::Right,
          self.protected_state.mode(),
          protected_req,
        )
      }
      true
    }
    StreamDeleteChars(count) => {
      self.grid.delete_chars(self.cursor, self.current_style, count)
      true
    }
    StreamEraseChars(count) => {
      self.grid.erase_chars(
        self.cursor,
        self.current_style,
        self.protected_state.mode(),
        count,
      )
      true
    }
    StreamInsertLines(count) => {
      self.grid.insert_lines(self.cursor, self.current_style, count)
      true
    }
    StreamInsertBlanks(count) => {
      self.grid.insert_blanks(self.cursor, self.current_style, count)
      true
    }
    StreamDeleteLines(count) => {
      self.grid.delete_lines(self.cursor, self.current_style, count)
      true
    }
    StreamScrollUp(count) => {
      if self.primary_top_scroll_region_captures_scrollback() {
        self.scrollback.capture_top_scroll_region_up(
          self.grid,
          self.cursor.bottom_margin().to_int(),
          count.to_int(),
        )
      }
      self.grid.scroll_up(self.cursor, self.current_style, count)
      true
    }
    StreamScrollDown(count) => {
      if self.active_screen == TerminalScreen::Primary &&
        self.cursor.top_margin() == 0 &&
        self.cursor.bottom_margin() == self.grid.rows - 1 &&
        self.cursor.left_margin() == 0 &&
        self.cursor.right_margin() == self.grid.cols - 1 {
        self.scrollback.capture_full_screen_scroll_down(
          self.grid,
          count.to_int(),
        )
      }
      self.grid.scroll_down(self.cursor, self.current_style, count)
      true
    }
    StreamDecaln => {
      self.decaln()
      true
    }
    StreamFullReset => {
      self.full_reset()
      true
    }
    StreamStartHyperlink(link) => {
      self.hyperlink.start(link.uri(), link.id())
      true
    }
    StreamEndHyperlink => {
      self.hyperlink.end()
      true
    }
    StreamSemanticPrompt(prompt) => {
      self.apply_semantic_prompt(prompt)
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
    StreamDeviceAttributes(request) => {
      self.report_device_attributes(request)
      true
    }
    StreamDeviceStatus(request) => {
      self.device_status(request)
      true
    }
    StreamKittyKeyboardQuery => {
      self.query_kitty_keyboard()
      true
    }
    StreamDcsHook(_) => true
    StreamDcsPut(_) => true
    StreamDcsUnhook => true
    StreamApcStart => {
      self.apc_handler.start()
      true
    }
    StreamApcPut(value) => {
      self.apc_handler.feed(value)
      true
    }
    StreamApcEnd => {
      self.handle_apc_end()
      true
    }
  }
}

///|
fn StreamTerminalBridgeState::save_cursor(
  self : StreamTerminalBridgeState,
) -> Unit {
  match self.active_screen {
    TerminalScreen::Primary =>
      self.primary_storage.saved_cursor.save(
        self.cursor,
        self.current_style,
        self.protected_state.cursor_protected(),
        self.modes.get(Mode::Origin),
        self.charset,
      )
    TerminalScreen::Alternate =>
      self.alternate_storage.saved_cursor.save(
        self.cursor,
        self.current_style,
        self.protected_state.cursor_protected(),
        self.modes.get(Mode::Origin),
        self.charset,
      )
  }
}

///|
fn StreamTerminalBridgeState::restore_cursor(
  self : StreamTerminalBridgeState,
) -> Unit {
  let saved = match self.active_screen {
    TerminalScreen::Primary => self.primary_storage.saved_cursor.restore()
    TerminalScreen::Alternate => self.alternate_storage.saved_cursor.restore()
  }
  self.current_style = saved.style()
  self.charset = saved.charset()
  self.modes.set(Mode::Origin, saved.origin())
  self.cursor.set_pending_wrap(saved.pending_wrap())
  self.protected_state.set_cursor_protected(saved.cursor_protected())
  self.cursor.set_cursor_pos(saved.y() + 1, saved.x() + 1, false)
  self.cursor.set_pending_wrap(saved.pending_wrap())
}

///|
fn StreamTerminalBridgeState::print(
  self : StreamTerminalBridgeState,
  codepoint : UInt,
) -> Unit {
  if self.display_state.status_display() != StatusDisplay::Main {
    return
  }

  let width = codepoint_width(codepoint)
  if width <= 0 {
    return
  }

  self.grid.print(
    self.cursor,
    codepoint,
    width,
    self.current_style,
    self.protected_state.cursor_protected(),
    self.semantic.cursor_content(),
    self.semantic.row_prompt(),
    self.active_hyperlink(),
    self.modes.get(Mode::Wraparound),
    self.modes.get(Mode::Insert),
  )
  self.previous_char = Some(codepoint)
}

///|
fn StreamTerminalBridgeState::print_repeat(
  self : StreamTerminalBridgeState,
  count : UInt16,
) -> Unit {
  if self.display_state.status_display() != StatusDisplay::Main {
    return
  }

  match self.previous_char {
    Some(codepoint) => {
      let width = codepoint_width(codepoint)
      if width <= 0 {
        return
      }

      self.grid.print_repeat(
        self.cursor,
        codepoint,
        width,
        self.current_style,
        self.protected_state.cursor_protected(),
        self.semantic.cursor_content(),
        self.semantic.row_prompt(),
        self.active_hyperlink(),
        self.modes.get(Mode::Wraparound),
        self.modes.get(Mode::Insert),
        count,
      )
      self.previous_char = Some(codepoint)
    }
    None => ()
  }
}

///|
fn StreamTerminalBridgeState::carriage_return(
  self : StreamTerminalBridgeState,
) -> Unit {
  self.cursor.set_pending_wrap(false)
  let target = if self.modes.get(Mode::Origin) {
    self.cursor.left_margin().to_int()
  } else if self.cursor.x().to_int() >= self.cursor.left_margin().to_int() {
    self.cursor.left_margin().to_int()
  } else {
    0
  }
  self.cursor.x = target.to_uint16()
}

///|
fn StreamTerminalBridgeState::linefeed(
  self : StreamTerminalBridgeState,
) -> Unit {
  self.index()
  if self.modes.get(Mode::Linefeed) {
    self.carriage_return()
  }
}

///|
fn StreamTerminalBridgeState::index(self : StreamTerminalBridgeState) -> Unit {
  self.cursor.set_pending_wrap(false)
  if self.cursor_outside_scroll_region() {
    if self.cursor.y().to_int() < self.grid.rows.to_int() - 1 {
      self.cursor.y = self.cursor.y() + 1
    }
  } else {
    if self.active_screen == TerminalScreen::Primary &&
      self.cursor.y() == self.cursor.bottom_margin() &&
      self.primary_top_scroll_region_captures_scrollback() {
      self.scrollback.capture_top_scroll_region_up(
        self.grid,
        self.cursor.bottom_margin().to_int(),
        1,
      )
    }
    self.grid.index(self.cursor, self.current_style)
  }
  self.apply_semantic_after_newline()
}

///|
fn StreamTerminalBridgeState::primary_top_scroll_region_captures_scrollback(
  self : StreamTerminalBridgeState,
) -> Bool {
  self.active_screen == TerminalScreen::Primary &&
  self.cursor.top_margin() == 0 &&
  self.cursor.left_margin() == 0 &&
  self.cursor.right_margin() == self.grid.cols - 1
}

///|
fn StreamTerminalBridgeState::reverse_index(
  self : StreamTerminalBridgeState,
) -> Unit {
  if self.cursor.y() != self.cursor.top_margin() ||
    self.cursor.x().to_int() < self.cursor.left_margin().to_int() ||
    self.cursor.x().to_int() > self.cursor.right_margin().to_int() {
    self.cursor_up(CursorMovement(1))
    return
  }

  if self.active_screen == TerminalScreen::Primary &&
    self.cursor.top_margin() == 0 &&
    self.cursor.bottom_margin() == self.grid.rows - 1 &&
    self.cursor.left_margin() == 0 &&
    self.cursor.right_margin() == self.grid.cols - 1 {
    self.scrollback.capture_full_screen_scroll_down(self.grid, 1)
  }
  self.grid.scroll_down(self.cursor, self.current_style, 1)
}

///|
fn StreamTerminalBridgeState::decaln(self : StreamTerminalBridgeState) -> Unit {
  let style = CellStyle::new()
  style.fg_color = self.current_style.fg_color
  style.bg_color = self.current_style.bg_color
  self.current_style = copy_cell_style(style)
  self.modes.set(Mode::Origin, false)
  self.cursor.full_reset()
  self.grid.decaln(self.current_style)
  self.cursor.set_cursor_pos(1, 1, false)
}

///|
fn StreamTerminalBridgeState::full_reset(
  self : StreamTerminalBridgeState,
) -> Unit {
  let rows = self.grid.rows
  let cols = self.grid.cols
  self.primary_storage = TerminalScreenStorage::new(
    rows,
    cols,
    DefaultMaxScrollback,
  )
  self.alternate_storage = TerminalScreenStorage::new(rows, cols, 0)
  self.active_screen = TerminalScreen::Primary
  self.load_active_screen(TerminalScreen::Primary)
  self.protected_state.reset()
  self.display_state.full_reset()
  self.modes.reset()
  self.input_flags.full_reset()
  self.kitty_keyboard.reset()
  self.tabstops = TerminalTabstopsState::new(cols)
  self.hyperlink.full_reset()
  self.semantic.full_reset()
  self.metadata.full_reset()
  self.charset.reset()
  self.current_style.reset()
  self.previous_char = None
  self.mouse_event = MouseEvent::None
  self.mouse_format = MouseFormat::X10
  self.palette_dirty = false
  self.scrollback_cleared = true
}

///|
fn StreamTerminalBridgeState::apply_semantic_prompt(
  self : StreamTerminalBridgeState,
  prompt : SemanticPrompt,
) -> Unit {
  match prompt.action() {
    FreshLine => self.semantic_prompt_fresh_line()
    FreshLineNewPrompt => {
      self.semantic_prompt_fresh_line()
      self.semantic.apply_fresh_line_new_prompt(prompt)
      match prompt.redraw() {
        Some(value) => self.metadata.set_shell_redraws_prompt(value)
        None => ()
      }
      self.sync_current_row_prompt()
    }
    NewCommand => {
      self.semantic_prompt_fresh_line()
      self.semantic.apply_fresh_line_new_prompt(prompt)
      match prompt.redraw() {
        Some(value) => self.metadata.set_shell_redraws_prompt(value)
        None => ()
      }
      self.sync_current_row_prompt()
    }
    PromptStart => {
      self.semantic.apply_prompt_start(prompt)
      self.sync_current_row_prompt()
    }
    EndPromptStartInput => self.semantic.start_input(false)
    EndPromptStartInputTerminateEol => self.semantic.start_input(true)
    EndInputStartOutput => {
      self.semantic.set_output()
      if self.cursor.x() == 0 {
        match self.grid.row(self.cursor.y()) {
          Some(row) => row.set_semantic_prompt(RowSemanticPrompt::None)
          None => ()
        }
      }
    }
    EndCommand => self.semantic.set_output()
  }
}

///|
fn StreamTerminalBridgeState::semantic_prompt_fresh_line(
  self : StreamTerminalBridgeState,
) -> Unit {
  let left_margin = if self.cursor.x().to_int() <
    self.cursor.left_margin().to_int() {
    0
  } else {
    self.cursor.left_margin().to_int()
  }
  if self.cursor.x().to_int() == left_margin {
    return
  }

  self.carriage_return()
  self.index()
}

///|
fn StreamTerminalBridgeState::sync_current_row_prompt(
  self : StreamTerminalBridgeState,
) -> Unit {
  match self.grid.row(self.cursor.y()) {
    Some(row) => row.set_semantic_prompt(self.semantic.row_prompt())
    None => ()
  }
}

///|
fn StreamTerminalBridgeState::apply_semantic_after_newline(
  self : StreamTerminalBridgeState,
) -> Unit {
  if self.semantic.cursor_content() == SemanticContent::Output {
    return
  }

  if self.semantic.cursor_content_clear_eol() {
    self.semantic.set_output()
    return
  }

  self.semantic.row_prompt = RowSemanticPrompt::PromptContinuation
  match self.grid.row(self.cursor.y()) {
    Some(row) => row.set_semantic_prompt(RowSemanticPrompt::PromptContinuation)
    None => ()
  }
}

///|
fn StreamTerminalBridgeState::cursor_outside_scroll_region(
  self : StreamTerminalBridgeState,
) -> Bool {
  self.cursor.y().to_int() < self.cursor.top_margin().to_int() ||
  self.cursor.y().to_int() > self.cursor.bottom_margin().to_int() ||
  self.cursor.x().to_int() < self.cursor.left_margin().to_int() ||
  self.cursor.x().to_int() > self.cursor.right_margin().to_int()
}

///|
fn StreamTerminalBridgeState::active_hyperlink(
  self : StreamTerminalBridgeState,
) -> CellHyperlink? {
  match self.hyperlink.uri() {
    Some(uri) =>
      match self.hyperlink.explicit_id() {
        Some(id) => Some(CellHyperlink::explicit(uri, id))
        None =>
          match self.hyperlink.implicit_id() {
            Some(id) => Some(CellHyperlink::implicit(uri, id))
            None => None
          }
      }
    None => None
  }
}

///|
fn StreamTerminalBridgeState::write_pty(
  self : StreamTerminalBridgeState,
  data : Bytes,
) -> Unit {
  (self.effects.write_pty)(data)
}

///|
fn StreamTerminalBridgeState::bell(self : StreamTerminalBridgeState) -> Unit {
  (self.effects.bell)()
}

///|
fn StreamTerminalBridgeState::report_device_attributes(
  self : StreamTerminalBridgeState,
  request : DeviceAttributeRequest,
) -> Unit {
  match (self.effects.device_attributes)() {
    Some(attributes) => self.write_pty(attributes.encode(request))
    None => self.write_pty(DeviceAttributes::default().encode(request))
  }
}

///|
fn StreamTerminalBridgeState::device_status(
  self : StreamTerminalBridgeState,
  request : DeviceStatusRequest,
) -> Unit {
  match request {
    OperatingStatus => self.write_pty(b"\x1B[0n")
    CursorPosition => {
      let x = if self.modes.get(Mode::Origin) {
        self.cursor.x().to_int() - self.cursor.left_margin().to_int()
      } else {
        self.cursor.x().to_int()
      }
      let y = if self.modes.get(Mode::Origin) {
        self.cursor.y().to_int() - self.cursor.top_margin().to_int()
      } else {
        self.cursor.y().to_int()
      }
      let buffer = @buffer.new()
      buffer.write_bytes(b"\x1B[")
      write_uint_ascii(buffer, (y + 1).to_uint64())
      buffer.write_byte(b';')
      write_uint_ascii(buffer, (x + 1).to_uint64())
      buffer.write_byte(b'R')
      self.write_pty(buffer.contents())
    }
    ColorScheme =>
      match (self.effects.color_scheme)() {
        Some(Dark) => self.write_pty(b"\x1B[?997;1n")
        Some(Light) => self.write_pty(b"\x1B[?997;2n")
        None => ()
      }
  }
}

///|
fn StreamTerminalBridgeState::report_enquiry(
  self : StreamTerminalBridgeState,
) -> Unit {
  let response = (self.effects.enquiry)()
  if response.length() == 0 || response.length() >= MaxEnquiryBytes {
    return
  }
  self.write_pty(response)
}

///|
fn StreamTerminalBridgeState::report_xtversion(
  self : StreamTerminalBridgeState,
) -> Unit {
  let version_bytes = utf8_bytes((self.effects.xtversion)())
  let reported = if version_bytes.length() == 0 {
    utf8_bytes(DefaultXtversion)
  } else {
    version_bytes
  }
  if reported.length() > MaxXtversionBytes {
    return
  }

  let buffer = @buffer.new(size_hint=reported.length() + 5)
  buffer.write_bytes(b"\x1BP>|")
  buffer.write_bytes(reported)
  buffer.write_bytes(b"\x1B\\")
  self.write_pty(buffer.contents())
}

///|
fn StreamTerminalBridgeState::report_size(
  self : StreamTerminalBridgeState,
  style : SizeReportStyle,
) -> Unit {
  match style {
    Csi14t =>
      match (self.effects.size)() {
        Some(size) => self.write_pty(encode(Csi14t, size))
        None => ()
      }
    Csi16t =>
      match (self.effects.size)() {
        Some(size) => self.write_pty(encode(Csi16t, size))
        None => ()
      }
    Csi18t =>
      match (self.effects.size)() {
        Some(size) => self.write_pty(encode(Csi18t, size))
        None => ()
      }
    Csi21t => {
      let buffer = @buffer.new()
      buffer.write_bytes(b"\x1B]l")
      match self.metadata.title() {
        Some(title) => buffer.write_string_utf8(title)
        None => ()
      }
      buffer.write_bytes(b"\x1B\\")
      self.write_pty(buffer.contents())
    }
  }
}

///|
fn StreamTerminalBridgeState::window_title(
  self : StreamTerminalBridgeState,
  raw_title : String,
) -> Unit {
  self.metadata.set_title(truncate_utf8(raw_title, MaxTitleBytes))
  (self.effects.title_changed)()
}

///|
fn StreamTerminalBridgeState::request_mode(
  self : StreamTerminalBridgeState,
  mode : Mode,
) -> Unit {
  self.send_mode_report(self.modes.get_report(mode.tag()))
}

///|
fn StreamTerminalBridgeState::request_mode_unknown(
  self : StreamTerminalBridgeState,
  tag : ModeTag,
) -> Unit {
  self.send_mode_report(self.modes.get_report(tag))
}

///|
fn StreamTerminalBridgeState::send_mode_report(
  self : StreamTerminalBridgeState,
  report : Report,
) -> Unit {
  self.write_pty(report.encode())
}

///|
fn StreamTerminalBridgeState::query_kitty_keyboard(
  self : StreamTerminalBridgeState,
) -> Unit {
  let buffer = @buffer.new()
  buffer.write_bytes(b"\x1B[?")
  write_uint_ascii(buffer, self.kitty_keyboard.current().0.to_uint64())
  buffer.write_byte(b'u')
  self.write_pty(buffer.contents())
}

///|
fn StreamTerminalBridgeState::handle_apc_end(
  self : StreamTerminalBridgeState,
) -> Unit {
  match self.apc_handler.end() {
    Some(Kitty(command)) => self.apply_kitty_graphics(command)
    None => ()
  }
}

///|
fn StreamTerminalBridgeState::apply_kitty_graphics(
  self : StreamTerminalBridgeState,
  command : KittyGraphicsCommand,
) -> Unit {
  match command.control {
    Query(transmission) =>
      self.write_kitty_graphics_response(
        command.quiet,
        Some(self.execute_kitty_graphics_query(transmission, command.data)),
      )
    Transmit(transmission) => {
      let (quiet, response) = self.execute_kitty_graphics_transmit(
        transmission,
        command.quiet,
        None,
        command.data,
      )
      self.write_kitty_graphics_response(quiet, response)
    }
    TransmitAndDisplay(value) => {
      let (quiet, response) = self.execute_kitty_graphics_transmit(
        value.transmission,
        command.quiet,
        Some(value.display),
        command.data,
      )
      self.write_kitty_graphics_response(quiet, response)
    }
    Display(display) =>
      self.write_kitty_graphics_response(
        command.quiet,
        Some(self.execute_kitty_graphics_display(display)),
      )
    Delete(delete) => self.execute_kitty_graphics_delete(delete)
    Unsupported(action) => {
      ignore(action)
      self.write_kitty_graphics_response(
        command.quiet,
        Some(KittyGraphicsResponse::new(message=b"ERROR: unimplemented action")),
      )
    }
  }
}

///|
fn StreamTerminalBridgeState::write_kitty_graphics_response(
  self : StreamTerminalBridgeState,
  quiet : KittyGraphicsQuiet,
  response : KittyGraphicsResponse?,
) -> Unit {
  match response {
    Some(value) => {
      let should_write = match quiet {
        KittyGraphicsQuiet::No => !value.empty()
        KittyGraphicsQuiet::Ok => !value.ok()
        KittyGraphicsQuiet::Failures => false
      }
      if should_write {
        let encoded = value.encode()
        if encoded.length() > 0 {
          self.write_pty(encoded)
        }
      }
    }
    None => ()
  }
}

///|
fn StreamTerminalBridgeState::execute_kitty_graphics_query(
  _self : StreamTerminalBridgeState,
  transmission : KittyImageTransmission,
  data : Bytes,
) -> KittyGraphicsResponse {
  // These parsed fields are preserved for upstream parity, but this bridge
  // currently only validates direct in-band payloads.
  ignore(transmission.size)
  ignore(transmission.offset)
  let result = KittyGraphicsResponse::new(
    id=transmission.image_id,
    image_number=transmission.image_number,
    placement_id=transmission.placement_id,
  )
  if transmission.image_id == 0U {
    result.message = b"EINVAL: image ID required"
    return result
  }

  match kitty_graphics_validate_transmission_header(transmission) {
    Some(error) => {
      result.message = kitty_graphics_error_message(error)
      result
    }
    None => {
      let loading = KittyGraphicsLoadingImage::new(
        transmission,
        data,
        KittyGraphicsQuiet::No,
        None,
      )
      match finalize_kitty_graphics_loading(loading, 0UL) {
        Ok(_) => result
        Err(error) => {
          result.message = kitty_graphics_error_message(error)
          result
        }
      }
    }
  }
}

///|
fn StreamTerminalBridgeState::execute_kitty_graphics_transmit(
  self : StreamTerminalBridgeState,
  transmission : KittyImageTransmission,
  quiet : KittyGraphicsQuiet,
  display : KittyImageDisplay?,
  data : Bytes,
) -> (KittyGraphicsQuiet, KittyGraphicsResponse?) {
  // Offset/declared-size transport semantics are not modeled yet, but the
  // parsed header stays faithful to upstream.
  ignore(transmission.size)
  ignore(transmission.offset)
  let response = KittyGraphicsResponse::new(
    id=transmission.image_id,
    image_number=transmission.image_number,
    placement_id=transmission.placement_id,
  )
  if transmission.image_id > 0U && transmission.image_number > 0U {
    response.message = b"EINVAL: image ID and number are mutually exclusive"
    return (quiet, Some(response))
  }

  match self.kitty_graphics.loading {
    Some(loading) => {
      let effective_quiet = match quiet {
        KittyGraphicsQuiet::No => loading.quiet
        KittyGraphicsQuiet::Ok | KittyGraphicsQuiet::Failures => quiet
      }
      if quiet != KittyGraphicsQuiet::No {
        loading.quiet = quiet
      }
      loading.append(data)

      if transmission.more_chunks {
        self.kitty_graphics.loading = Some(loading)
        return (effective_quiet, None)
      }

      let pending_display = loading.display
      let seq = self.kitty_graphics.reserve_transmit_seq()
      self.kitty_graphics.loading = None
      match finalize_kitty_graphics_loading(loading, seq) {
        Ok(image) => {
          let finished = self.finish_kitty_graphics_transmit(
            transmission, image, pending_display,
          )
          (effective_quiet, Some(finished))
        }
        Err(error) => {
          response.message = kitty_graphics_error_message(error)
          (effective_quiet, Some(response))
        }
      }
    }
    None =>
      match kitty_graphics_validate_transmission_header(transmission) {
        Some(error) => {
          response.message = kitty_graphics_error_message(error)
          (quiet, Some(response))
        }
        None => {
          let loading = KittyGraphicsLoadingImage::new(
            transmission, data, quiet, display,
          )
          if loading.image.id == 0U {
            loading.image.id = self.kitty_graphics.allocate_image_id()
            if loading.image.number == 0U {
              loading.image.implicit_id = true
            }
          }

          if transmission.more_chunks {
            self.kitty_graphics.loading = Some(loading)
            (quiet, None)
          } else {
            let seq = self.kitty_graphics.reserve_transmit_seq()
            match finalize_kitty_graphics_loading(loading, seq) {
              Ok(image) => {
                let finished = self.finish_kitty_graphics_transmit(
                  transmission, image, display,
                )
                (quiet, Some(finished))
              }
              Err(error) => {
                response.message = kitty_graphics_error_message(error)
                (quiet, Some(response))
              }
            }
          }
        }
      }
  }
}

///|
fn StreamTerminalBridgeState::finish_kitty_graphics_transmit(
  self : StreamTerminalBridgeState,
  transmission : KittyImageTransmission,
  image : KittyGraphicsImage,
  display : KittyImageDisplay?,
) -> KittyGraphicsResponse {
  self.kitty_graphics.add_image(image)

  let mut result = KittyGraphicsResponse::new(
    id=transmission.image_id,
    image_number=transmission.image_number,
    placement_id=transmission.placement_id,
  )
  match display {
    Some(value) => {
      let display_copy = value
      display_copy.image_id = image.id
      result = self.execute_kitty_graphics_display(display_copy)
    }
    None => ()
  }

  if image.implicit_id {
    return KittyGraphicsResponse::new()
  }

  result.id = image.id
  result
}

///|
fn StreamTerminalBridgeState::execute_kitty_graphics_display(
  self : StreamTerminalBridgeState,
  display : KittyImageDisplay,
) -> KittyGraphicsResponse {
  // Parsed placement-offset metadata is preserved even though the current
  // MoonBit host surface does not apply those variants yet.
  ignore(display.parent_placement_id)
  ignore(display.horizontal_offset)
  ignore(display.vertical_offset)
  let result = KittyGraphicsResponse::new(
    id=display.image_id,
    image_number=display.image_number,
    placement_id=display.placement_id,
  )
  if display.image_id == 0U && display.image_number == 0U {
    result.message = b"EINVAL: image ID or number required"
    return result
  }

  let image = if display.image_id != 0U {
    self.kitty_graphics.image_by_id(display.image_id)
  } else {
    self.kitty_graphics.image_by_number(display.image_number)
  }
  let image = match image {
    Some(value) => value
    None => {
      result.message = b"ENOENT: image not found"
      return result
    }
  }
  result.id = image.id

  if display.virtual_placement && display.parent_id > 0U {
    result.message = b"EINVAL: virtual placement cannot refer to a parent"
    return result
  }

  let location = if display.virtual_placement {
    KittyGraphicsPlacementLocation::Virtual
  } else {
    match self.kitty_graphics_cursor_pin() {
      Some(pin) => KittyGraphicsPlacementLocation::Pin(pin)
      None => {
        result.message = b"EINVAL: failed to prepare terminal state"
        return result
      }
    }
  }

  let placement = self.kitty_graphics.add_placement(
    self.scrollback,
    image.id,
    display.placement_id,
    location,
    display,
  )
  self.apply_kitty_graphics_cursor_movement(placement, image, display)
  result
}

///|
fn StreamTerminalBridgeState::execute_kitty_graphics_delete(
  self : StreamTerminalBridgeState,
  delete : KittyGraphicsDelete,
) -> Unit {
  match delete {
    All(delete_images) =>
      self.kitty_graphics.delete_all(self.scrollback, delete_images)
    Id(value) =>
      self.kitty_graphics.delete_by_id(
        self.scrollback,
        value.image_id,
        value.placement_id,
        value.delete,
      )
    Newest(value) =>
      self.kitty_graphics.delete_newest(
        self.scrollback,
        value.image_number,
        value.placement_id,
        value.delete,
      )
    IntersectCursor(delete) => ignore(delete)
    AnimationFrames(delete) => ignore(delete)
    IntersectCell(value) => {
      ignore(value.delete)
      ignore(value.x)
      ignore(value.y)
    }
    IntersectCellZ(value) => {
      ignore(value.delete)
      ignore(value.x)
      ignore(value.y)
      ignore(value.z)
    }
    Range(value) => {
      ignore(value.delete)
      ignore(value.first)
      ignore(value.last)
    }
    Column(value) => {
      ignore(value.delete)
      ignore(value.x)
    }
    Row(value) => {
      ignore(value.delete)
      ignore(value.y)
    }
    Z(value) => {
      ignore(value.delete)
      ignore(value.z)
    }
  }
}

///|
fn StreamTerminalBridgeState::kitty_graphics_cursor_pin(
  self : StreamTerminalBridgeState,
) -> UInt64? {
  self.scrollback.track_pin_at_point(
    self.grid,
    Point::Active(Coordinate::new(self.cursor.x(), self.cursor.y().to_uint())),
  )
}

///|
fn StreamTerminalBridgeState::apply_kitty_graphics_cursor_movement(
  self : StreamTerminalBridgeState,
  placement : KittyGraphicsPlacement,
  image : KittyGraphicsImage,
  display : KittyImageDisplay,
) -> Unit {
  if display.cursor_movement == KittyImageCursorMovement::None ||
    placement.is_virtual() {
    return
  }

  let size = placement.grid_size(
    image,
    self.grid.cols,
    self.grid.rows,
    self.width_px,
    self.height_px,
  )
  let mut remaining = size.rows.reinterpret_as_int()
  while remaining > 0 {
    self.index()
    remaining -= 1
  }

  match placement.location {
    Pin(id) =>
      match self.scrollback.pin_x(id) {
        Some(x) => {
          let target_col = (x.to_int() + size.cols.reinterpret_as_int() + 1).to_uint16()
          self.cursor.set_cursor_pos(self.cursor.y() + 1, target_col, false)
        }
        None => ()
      }
    Virtual => ()
  }
}

///|
priv enum ScreenMode {
  Mode47
  Mode1047
  Mode1049
}

///|
fn StreamTerminalBridgeState::store_active_screen(
  self : StreamTerminalBridgeState,
) -> Unit {
  match self.active_screen {
    TerminalScreen::Primary => {
      self.primary_storage.grid = self.grid
      self.primary_storage.cursor = self.cursor
      self.primary_storage.scrollback = self.scrollback
      self.primary_storage.kitty_graphics = self.kitty_graphics
    }
    TerminalScreen::Alternate => {
      self.alternate_storage.grid = self.grid
      self.alternate_storage.cursor = self.cursor
      self.alternate_storage.scrollback = self.scrollback
      self.alternate_storage.kitty_graphics = self.kitty_graphics
    }
  }
}

///|
fn StreamTerminalBridgeState::load_active_screen(
  self : StreamTerminalBridgeState,
  screen : TerminalScreen,
) -> Unit {
  match screen {
    TerminalScreen::Primary => {
      self.grid = self.primary_storage.grid
      self.cursor = self.primary_storage.cursor
      self.scrollback = self.primary_storage.scrollback
      self.kitty_graphics = self.primary_storage.kitty_graphics
    }
    TerminalScreen::Alternate => {
      self.grid = self.alternate_storage.grid
      self.cursor = self.alternate_storage.cursor
      self.scrollback = self.alternate_storage.scrollback
      self.kitty_graphics = self.alternate_storage.kitty_graphics
    }
  }
  self.active_screen = screen
}

///|
fn StreamTerminalBridgeState::switch_active_screen(
  self : StreamTerminalBridgeState,
  screen : TerminalScreen,
) -> Bool {
  if self.active_screen == screen {
    return false
  }

  self.store_active_screen()
  self.load_active_screen(screen)
  true
}

///|
fn StreamTerminalBridgeState::copy_cursor_between_screens(
  self : StreamTerminalBridgeState,
  from : TerminalScreen,
  to : TerminalScreen,
) -> Unit {
  let source = match from {
    TerminalScreen::Primary => self.primary_storage.cursor
    TerminalScreen::Alternate => self.alternate_storage.cursor
  }
  let target = match to {
    TerminalScreen::Primary => self.primary_storage.cursor
    TerminalScreen::Alternate => self.alternate_storage.cursor
  }
  target.x = min_int(source.x().to_int(), target.columns.to_int() - 1).to_uint16()
  target.y = min_int(source.y().to_int(), target.rows.to_int() - 1).to_uint16()
  target.visual_style = source.visual_style()
  target.pending_wrap = source.pending_wrap()
  target.top_margin = source.top_margin()
  target.bottom_margin = min_int(
    source.bottom_margin().to_int(),
    target.rows.to_int() - 1,
  ).to_uint16()
  target.left_margin = source.left_margin()
  target.right_margin = min_int(
    source.right_margin().to_int(),
    target.columns.to_int() - 1,
  ).to_uint16()
}

///|
fn StreamTerminalBridgeState::clear_active_screen(
  self : StreamTerminalBridgeState,
) -> Unit {
  self.kitty_graphics.full_reset(self.scrollback)
  self.grid.full_reset()
  self.scrollback.full_reset(self.grid.rows)
}

///|
fn StreamTerminalBridgeState::switch_screen_mode(
  self : StreamTerminalBridgeState,
  mode : ScreenMode,
  enabled : Bool,
) -> Unit {
  match mode {
    ScreenMode::Mode47 => ()
    ScreenMode::Mode1047 =>
      if !enabled && self.active_screen == TerminalScreen::Alternate {
        self.clear_active_screen()
      }
    ScreenMode::Mode1049 => if enabled { self.save_cursor() }
  }

  let from = self.active_screen
  let to = if enabled {
    TerminalScreen::Alternate
  } else {
    TerminalScreen::Primary
  }
  let changed = self.switch_active_screen(to)
  match mode {
    ScreenMode::Mode47 | ScreenMode::Mode1047 =>
      if changed {
        self.copy_cursor_between_screens(from, to)
        self.load_active_screen(to)
      }
    ScreenMode::Mode1049 =>
      if enabled {
        self.clear_active_screen()
        self.store_active_screen()
        if changed {
          self.copy_cursor_between_screens(from, to)
          self.load_active_screen(to)
        }
      } else {
        self.restore_cursor()
      }
  }
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
    AltScreenLegacy => self.switch_screen_mode(ScreenMode::Mode47, enabled)
    AltScreen => self.switch_screen_mode(ScreenMode::Mode1047, enabled)
    AltScreenSaveCursorClearEnter =>
      self.switch_screen_mode(ScreenMode::Mode1049, enabled)
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
  let wrap_mode = if !self.modes.get(Mode::Wraparound) {
    0
  } else if self.modes.get(Mode::ReverseWrapExtended) {
    2
  } else if self.modes.get(Mode::ReverseWrap) {
    1
  } else {
    0
  }

  let mut count = movement_count_int(movement)
  if wrap_mode == 0 {
    let x = self.cursor.x().to_int()
    let left_limit = if self.modes.get(Mode::Origin) {
      self.cursor.left_margin().to_int()
    } else {
      0
    }
    let max = if x >= left_limit { x - left_limit } else { x }
    self.cursor.set_pending_wrap(false)
    self.cursor.set_cursor_pos(
      self.cursor.y() + 1,
      (x - bounded_count(count, max) + 1).to_uint16(),
      false,
    )
    return
  }

  if self.cursor.pending_wrap() {
    count -= 1
    self.cursor.set_pending_wrap(false)
  }
  if count <= 0 {
    return
  }

  let top = self.cursor.top_margin().to_int()
  let bottom = self.cursor.bottom_margin().to_int()
  let right_margin = self.cursor.right_margin().to_int()
  let left_margin = if self.cursor.x().to_int() <
    self.cursor.left_margin().to_int() {
    0
  } else {
    self.cursor.left_margin().to_int()
  }

  if self.cursor.x().to_int() == left_margin &&
    wrap_mode == 1 &&
    self.cursor.y().to_int() <= top {
    self.cursor.x = left_margin.to_uint16()
    self.cursor.y = top.to_uint16()
    return
  }

  while true {
    let max = self.cursor.x().to_int() - left_margin
    let amount = min_int(max, count)
    count -= amount
    self.cursor.set_cursor_pos(
      self.cursor.y() + 1,
      (self.cursor.x().to_int() - amount + 1).to_uint16(),
      false,
    )
    if count == 0 {
      return
    }

    if self.cursor.y().to_int() == top {
      if wrap_mode != 2 {
        return
      }
      self.cursor.x = right_margin.to_uint16()
      self.cursor.y = bottom.to_uint16()
      count -= 1
      continue
    }

    if self.cursor.y().to_int() == 0 {
      return
    }

    if wrap_mode != 2 {
      match self.grid.row(self.cursor.y() - 1) {
        Some(prev_row) => if !prev_row.wrap() { return }
        None => return
      }
    }

    self.cursor.x = right_margin.to_uint16()
    self.cursor.y = self.cursor.y() - 1
    count -= 1
  }
}

///|
fn StreamTerminalBridgeState::apply_color_operation(
  self : StreamTerminalBridgeState,
  command : ColorCommand,
) -> Unit {
  let requests = command.requests()
  if requests.length() == 0 {
    return
  }

  for request in requests {
    match request {
      Set(set) => self.apply_color_set(set)
      Query(target) => self.apply_color_query(target, command.terminator())
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
fn StreamTerminalBridgeState::apply_color_query(
  self : StreamTerminalBridgeState,
  target : ColorTarget,
  terminator : Terminator,
) -> Unit {
  match target {
    Palette(index) => {
      let buffer = @buffer.new()
      buffer.write_bytes(b"\x1B]4;")
      write_uint_ascii(buffer, index.to_uint64())
      buffer.write_byte(b';')
      write_osc_rgb(buffer, self.colors.palette_color(index))
      write_osc_terminator(buffer, terminator)
      self.write_pty(buffer.contents())
    }
    Dynamic(dynamic) =>
      match self.dynamic_color_query(dynamic) {
        Some(color) => {
          let buffer = @buffer.new()
          buffer.write_bytes(b"\x1B]")
          write_uint_ascii(buffer, dynamic.code().to_uint64())
          buffer.write_byte(b';')
          write_osc_rgb(buffer, color)
          write_osc_terminator(buffer, terminator)
          self.write_pty(buffer.contents())
        }
        None => ()
      }
    Special(_) => ()
  }
}

///|
fn StreamTerminalBridgeState::dynamic_color_query(
  self : StreamTerminalBridgeState,
  dynamic : Dynamic,
) -> RGB? {
  match dynamic {
    Foreground =>
      match self.colors.foreground() {
        Some(color) => Some(color)
        None => self.colors.default_foreground()
      }
    Background =>
      match self.colors.background() {
        Some(color) => Some(color)
        None => self.colors.default_background()
      }
    Cursor =>
      match self.colors.cursor() {
        Some(color) => Some(color)
        None => self.colors.default_cursor()
      }
    PointerForeground
    | PointerBackground
    | TektronixForeground
    | TektronixBackground
    | HighlightBackground
    | TektronixCursor
    | HighlightForeground => None
  }
}

///|
fn write_osc_rgb(buffer : @buffer.Buffer, color : RGB) -> Unit {
  buffer.write_bytes(b"rgb:")
  write_hex_byte(buffer, color.r())
  buffer.write_byte(b'/')
  write_hex_byte(buffer, color.g())
  buffer.write_byte(b'/')
  write_hex_byte(buffer, color.b())
}

///|
fn write_osc_terminator(
  buffer : @buffer.Buffer,
  terminator : Terminator,
) -> Unit {
  match terminator {
    Bel => buffer.write_byte(b'\x07')
    St => buffer.write_bytes(b"\x1B\\")
  }
}

///|
fn StreamTerminalBridgeState::apply_kitty_color_report(
  self : StreamTerminalBridgeState,
  command : KittyColorOsc,
) -> Unit {
  for request in command.requests() {
    match request {
      KittyQuery(_) => ()
      KittySet(value) =>
        match value.key() {
          KittyPalette(index) => {
            self.colors.set_palette_color(index, value.color())
            self.palette_dirty = true
          }
          KittySpecial(special) =>
            match special {
              KittyForeground => self.colors.set_foreground(value.color())
              KittyBackground => self.colors.set_background(value.color())
              KittyCursor => self.colors.set_cursor(value.color())
              KittySelectionForeground
              | KittySelectionBackground
              | KittyCursorText
              | KittyVisualBell
              | KittySecondTransparentBackground => ()
            }
        }
      KittyReset(key) =>
        match key {
          KittyPalette(index) => {
            self.colors.reset_palette_color(index)
            self.palette_dirty = true
          }
          KittySpecial(special) =>
            match special {
              KittyForeground => self.colors.reset_foreground()
              KittyBackground => self.colors.reset_background()
              KittyCursor => self.colors.reset_cursor()
              KittySelectionForeground
              | KittySelectionBackground
              | KittyCursorText
              | KittyVisualBell
              | KittySecondTransparentBackground => ()
            }
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

///|
fn codepoint_width(codepoint : UInt) -> Int {
  if codepoint == 0U || is_zero_width(codepoint) {
    0
  } else if is_wide_codepoint(codepoint) {
    2
  } else {
    1
  }
}

///|
let zero_width_codepoint_ranges : ReadOnlyArray[(UInt, UInt)] = [
  (0x0300U, 0x036FU),
  (0x0483U, 0x0489U),
  (0x0591U, 0x05BDU),
  (0x05BFU, 0x05BFU),
  (0x05C1U, 0x05C2U),
  (0x05C4U, 0x05C5U),
  (0x0610U, 0x061AU),
  (0x064BU, 0x065FU),
  (0x0670U, 0x0670U),
  (0x06D6U, 0x06DCU),
  (0x06DFU, 0x06E4U),
  (0x06E7U, 0x06E8U),
  (0x06EAU, 0x06EDU),
  (0x0711U, 0x0711U),
  (0x0730U, 0x074AU),
  (0x07A6U, 0x07B0U),
  (0x07EBU, 0x07F3U),
  (0x0816U, 0x0819U),
  (0x081BU, 0x0823U),
  (0x0825U, 0x0827U),
  (0x0829U, 0x082DU),
  (0x0859U, 0x085BU),
  (0x08D3U, 0x0902U),
  (0x093AU, 0x093AU),
  (0x093CU, 0x093CU),
  (0x0941U, 0x0948U),
  (0x094DU, 0x094DU),
  (0x0951U, 0x0957U),
  (0x0962U, 0x0963U),
  (0x0981U, 0x0981U),
  (0x09BCU, 0x09BCU),
  (0x09C1U, 0x09C4U),
  (0x09CDU, 0x09CDU),
  (0x09E2U, 0x09E3U),
  (0x0A01U, 0x0A02U),
  (0x0A3CU, 0x0A3CU),
  (0x0A41U, 0x0A42U),
  (0x0A47U, 0x0A48U),
  (0x0A4BU, 0x0A4DU),
  (0x0A51U, 0x0A51U),
  (0x0A70U, 0x0A71U),
  (0x0A75U, 0x0A75U),
  (0x0A81U, 0x0A82U),
  (0x0ABCU, 0x0ABCU),
  (0x0AC1U, 0x0AC5U),
  (0x0AC7U, 0x0AC8U),
  (0x0ACDU, 0x0ACDU),
  (0x0AE2U, 0x0AE3U),
  (0x0B3CU, 0x0B3CU),
  (0x0B3FU, 0x0B3FU),
  (0x0B41U, 0x0B44U),
  (0x0B4DU, 0x0B4DU),
  (0x0B56U, 0x0B56U),
  (0x0B62U, 0x0B63U),
  (0x0B82U, 0x0B82U),
  (0x0BC0U, 0x0BC0U),
  (0x0BCDU, 0x0BCDU),
  (0x0C00U, 0x0C00U),
  (0x0C04U, 0x0C04U),
  (0x0C3EU, 0x0C40U),
  (0x0C46U, 0x0C48U),
  (0x0C4AU, 0x0C4DU),
  (0x0C55U, 0x0C56U),
  (0x0C62U, 0x0C63U),
  (0x0C81U, 0x0C81U),
  (0x0CBCU, 0x0CBCU),
  (0x0CBFU, 0x0CBFU),
  (0x0CC6U, 0x0CC6U),
  (0x0CCCU, 0x0CCDU),
  (0x0CE2U, 0x0CE3U),
  (0x0D00U, 0x0D01U),
  (0x0D3BU, 0x0D3CU),
  (0x0D41U, 0x0D44U),
  (0x0D4DU, 0x0D4DU),
  (0x0D62U, 0x0D63U),
  (0x0DCAU, 0x0DCAU),
  (0x0DD2U, 0x0DD4U),
  (0x0DD6U, 0x0DD6U),
  (0x0E31U, 0x0E31U),
  (0x0E34U, 0x0E3AU),
  (0x0E47U, 0x0E4EU),
  (0x0EB1U, 0x0EB1U),
  (0x0EB4U, 0x0EBCU),
  (0x0EC8U, 0x0ECDU),
  (0x0F18U, 0x0F19U),
  (0x0F35U, 0x0F35U),
  (0x0F37U, 0x0F37U),
  (0x0F39U, 0x0F39U),
  (0x0F71U, 0x0F7EU),
  (0x0F80U, 0x0F84U),
  (0x0F86U, 0x0F87U),
  (0x0F8DU, 0x0F97U),
  (0x0F99U, 0x0FBCU),
  (0x0FC6U, 0x0FC6U),
  (0x102DU, 0x1030U),
  (0x1032U, 0x1037U),
  (0x1039U, 0x103AU),
  (0x103DU, 0x103EU),
  (0x1058U, 0x1059U),
  (0x105EU, 0x1060U),
  (0x1071U, 0x1074U),
  (0x1082U, 0x1082U),
  (0x1085U, 0x1086U),
  (0x108DU, 0x108DU),
  (0x109DU, 0x109DU),
  (0x135DU, 0x135FU),
  (0x1712U, 0x1714U),
  (0x1732U, 0x1734U),
  (0x1752U, 0x1753U),
  (0x1772U, 0x1773U),
  (0x17B4U, 0x17B5U),
  (0x17B7U, 0x17BDU),
  (0x17C6U, 0x17C6U),
  (0x17C9U, 0x17D3U),
  (0x17DDU, 0x17DDU),
  (0x180BU, 0x180FU),
  (0x1885U, 0x1886U),
  (0x18A9U, 0x18A9U),
  (0x1920U, 0x1922U),
  (0x1927U, 0x1928U),
  (0x1932U, 0x1932U),
  (0x1939U, 0x193BU),
  (0x1A17U, 0x1A18U),
  (0x1A1BU, 0x1A1BU),
  (0x1A56U, 0x1A56U),
  (0x1A58U, 0x1A5EU),
  (0x1A60U, 0x1A60U),
  (0x1A62U, 0x1A62U),
  (0x1A65U, 0x1A6CU),
  (0x1A73U, 0x1A7CU),
  (0x1A7FU, 0x1A7FU),
  (0x1AB0U, 0x1AC0U),
  (0x1B00U, 0x1B03U),
  (0x1B34U, 0x1B34U),
  (0x1B36U, 0x1B3AU),
  (0x1B3CU, 0x1B3CU),
  (0x1B42U, 0x1B42U),
  (0x1B6BU, 0x1B73U),
  (0x1B80U, 0x1B81U),
  (0x1BA2U, 0x1BA5U),
  (0x1BA8U, 0x1BA9U),
  (0x1BABU, 0x1BADU),
  (0x1BE6U, 0x1BE6U),
  (0x1BE8U, 0x1BE9U),
  (0x1BEDU, 0x1BEDU),
  (0x1BEFU, 0x1BF1U),
  (0x1C2CU, 0x1C33U),
  (0x1C36U, 0x1C37U),
  (0x1CD0U, 0x1CD2U),
  (0x1CD4U, 0x1CE0U),
  (0x1CE2U, 0x1CE8U),
  (0x1CEDU, 0x1CEDU),
  (0x1CF4U, 0x1CF4U),
  (0x1CF8U, 0x1CF9U),
  (0x1DC0U, 0x1DFFU),
  (0x200BU, 0x200FU),
  (0x202AU, 0x202EU),
  (0x2060U, 0x2064U),
  (0x2066U, 0x206FU),
  (0x20D0U, 0x20F0U),
  (0x2DE0U, 0x2DFFU),
  (0x302AU, 0x302FU),
  (0x3099U, 0x309AU),
  (0xA66FU, 0xA672U),
  (0xA674U, 0xA67DU),
  (0xA69EU, 0xA69FU),
  (0xA6F0U, 0xA6F1U),
  (0xA802U, 0xA802U),
  (0xA806U, 0xA806U),
  (0xA80BU, 0xA80BU),
  (0xA825U, 0xA826U),
  (0xA8C4U, 0xA8C5U),
  (0xA8E0U, 0xA8F1U),
  (0xA926U, 0xA92DU),
  (0xA947U, 0xA951U),
  (0xA980U, 0xA982U),
  (0xA9B3U, 0xA9B3U),
  (0xA9B6U, 0xA9B9U),
  (0xA9BCU, 0xA9BCU),
  (0xA9E5U, 0xA9E5U),
  (0xAA29U, 0xAA2EU),
  (0xAA31U, 0xAA32U),
  (0xAA35U, 0xAA36U),
  (0xAA43U, 0xAA43U),
  (0xAA4CU, 0xAA4CU),
  (0xAA7CU, 0xAA7CU),
  (0xAAB0U, 0xAAB0U),
  (0xAAB2U, 0xAAB4U),
  (0xAAB7U, 0xAAB8U),
  (0xAABEU, 0xAABFU),
  (0xAAC1U, 0xAAC1U),
  (0xAAECU, 0xAAEDU),
  (0xAAF6U, 0xAAF6U),
  (0xABE5U, 0xABE5U),
  (0xABE8U, 0xABE8U),
  (0xABEDU, 0xABEDU),
  (0xFB1EU, 0xFB1EU),
  (0xFE00U, 0xFE0FU),
  (0xFE20U, 0xFE2FU),
  (0xFEFFU, 0xFEFFU),
  (0xFFF9U, 0xFFFBU),
  (0x101FBU, 0x101FBU),
  (0x10A01U, 0x10A03U),
  (0x10A05U, 0x10A06U),
  (0x10A0CU, 0x10A0FU),
  (0x10A38U, 0x10A3AU),
  (0x10A3FU, 0x10A3FU),
  (0x10AE5U, 0x10AE6U),
  (0x10D24U, 0x10D27U),
  (0x10EABU, 0x10EACU),
  (0x10F46U, 0x10F50U),
  (0x11001U, 0x11001U),
  (0x11038U, 0x11046U),
  (0x1107FU, 0x11081U),
  (0x110B3U, 0x110B6U),
  (0x110B9U, 0x110BAU),
  (0x11100U, 0x11102U),
  (0x11127U, 0x1112BU),
  (0x1112DU, 0x11134U),
  (0x11173U, 0x11173U),
  (0x11180U, 0x11181U),
  (0x111B6U, 0x111BEU),
  (0x111C9U, 0x111CCU),
  (0x1122FU, 0x11231U),
  (0x11234U, 0x11234U),
  (0x11236U, 0x11237U),
  (0x1123EU, 0x1123EU),
  (0x112DFU, 0x112DFU),
  (0x112E3U, 0x112EAU),
  (0x11300U, 0x11301U),
  (0x1133BU, 0x1133CU),
  (0x11340U, 0x11340U),
  (0x11366U, 0x1136CU),
  (0x11370U, 0x11374U),
  (0x11438U, 0x1143FU),
  (0x11442U, 0x11444U),
  (0x11446U, 0x11446U),
  (0x1145EU, 0x1145EU),
  (0x114B3U, 0x114B8U),
  (0x114BAU, 0x114BAU),
  (0x114BFU, 0x114C0U),
  (0x114C2U, 0x114C3U),
  (0x115B2U, 0x115B5U),
  (0x115BCU, 0x115BDU),
  (0x115BFU, 0x115C0U),
  (0x115DCU, 0x115DDU),
  (0x11633U, 0x1163AU),
  (0x1163DU, 0x1163DU),
  (0x1163FU, 0x11640U),
  (0x116ABU, 0x116ABU),
  (0x116ADU, 0x116ADU),
  (0x116B0U, 0x116B5U),
  (0x116B7U, 0x116B7U),
  (0x1171DU, 0x1171FU),
  (0x11722U, 0x11725U),
  (0x11727U, 0x1172BU),
  (0x1182FU, 0x11837U),
  (0x11839U, 0x1183AU),
  (0x1193BU, 0x1193CU),
  (0x1193EU, 0x1193EU),
  (0x11943U, 0x11943U),
  (0x119D4U, 0x119D7U),
  (0x119DAU, 0x119DBU),
  (0x119E0U, 0x119E0U),
  (0x11A01U, 0x11A0AU),
  (0x11A33U, 0x11A38U),
  (0x11A3BU, 0x11A3EU),
  (0x11A47U, 0x11A47U),
  (0x11A51U, 0x11A56U),
  (0x11A59U, 0x11A5BU),
  (0x11A8AU, 0x11A96U),
  (0x11A98U, 0x11A99U),
  (0x11C30U, 0x11C36U),
  (0x11C38U, 0x11C3DU),
  (0x11C3FU, 0x11C3FU),
  (0x11C92U, 0x11CA7U),
  (0x11CAAU, 0x11CB0U),
  (0x11CB2U, 0x11CB3U),
  (0x11CB5U, 0x11CB6U),
  (0x11D31U, 0x11D36U),
  (0x11D3AU, 0x11D3AU),
  (0x11D3CU, 0x11D3DU),
  (0x11D3FU, 0x11D45U),
  (0x11D47U, 0x11D47U),
  (0x11D90U, 0x11D91U),
  (0x11D95U, 0x11D95U),
  (0x11D97U, 0x11D97U),
  (0x11EF3U, 0x11EF4U),
  (0x13430U, 0x13438U),
  (0x16AF0U, 0x16AF4U),
  (0x16B30U, 0x16B36U),
  (0x16F4FU, 0x16F4FU),
  (0x16F8FU, 0x16F92U),
  (0x16FE4U, 0x16FE4U),
  (0x1BC9DU, 0x1BC9EU),
  (0x1CF00U, 0x1CF2DU),
  (0x1D167U, 0x1D169U),
  (0x1D17BU, 0x1D182U),
  (0x1D185U, 0x1D18BU),
  (0x1D1AAU, 0x1D1ADU),
  (0x1D242U, 0x1D244U),
  (0x1DA00U, 0x1DA36U),
  (0x1DA3BU, 0x1DA6CU),
  (0x1DA75U, 0x1DA75U),
  (0x1DA84U, 0x1DA84U),
  (0x1DA9BU, 0x1DA9FU),
  (0x1DAA1U, 0x1DAAFU),
  (0x1E000U, 0x1E006U),
  (0x1E008U, 0x1E018U),
  (0x1E01BU, 0x1E021U),
  (0x1E023U, 0x1E024U),
  (0x1E026U, 0x1E02AU),
  (0x1E08FU, 0x1E08FU),
  (0x1E130U, 0x1E136U),
  (0x1E2AEU, 0x1E2AEU),
  (0x1E2ECU, 0x1E2EFU),
  (0x1E4ECU, 0x1E4EFU),
  (0x1E8D0U, 0x1E8D6U),
  (0x1E944U, 0x1E94AU),
  (0xE0100U, 0xE01EFU),
]

///|
let wide_codepoint_ranges : ReadOnlyArray[(UInt, UInt)] = [
  (0x1100U, 0x115FU),
  (0x231AU, 0x231BU),
  (0x2329U, 0x232AU),
  (0x23E9U, 0x23ECU),
  (0x23F0U, 0x23F0U),
  (0x23F3U, 0x23F3U),
  (0x25FDU, 0x25FEU),
  (0x2614U, 0x2615U),
  (0x2648U, 0x2653U),
  (0x267FU, 0x267FU),
  (0x2693U, 0x2693U),
  (0x26A1U, 0x26A1U),
  (0x26AAU, 0x26ABU),
  (0x26BDU, 0x26BEU),
  (0x26C4U, 0x26C5U),
  (0x26CEU, 0x26CEU),
  (0x26D4U, 0x26D4U),
  (0x26EAU, 0x26EAU),
  (0x26F2U, 0x26F3U),
  (0x26F5U, 0x26F5U),
  (0x26FAU, 0x26FAU),
  (0x26FDU, 0x26FDU),
  (0x2705U, 0x2705U),
  (0x270AU, 0x270BU),
  (0x2728U, 0x2728U),
  (0x274CU, 0x274CU),
  (0x274EU, 0x274EU),
  (0x2753U, 0x2755U),
  (0x2757U, 0x2757U),
  (0x2795U, 0x2797U),
  (0x27B0U, 0x27B0U),
  (0x27BFU, 0x27BFU),
  (0x2B1BU, 0x2B1CU),
  (0x2B50U, 0x2B50U),
  (0x2B55U, 0x2B55U),
  (0x2E80U, 0x2FFBU),
  (0x3000U, 0x303EU),
  (0x3041U, 0x33FFU),
  (0x3400U, 0x4DBFU),
  (0x4E00U, 0xA4C6U),
  (0xA960U, 0xA97CU),
  (0xAC00U, 0xD7A3U),
  (0xF900U, 0xFAFFU),
  (0xFE10U, 0xFE19U),
  (0xFE30U, 0xFE6BU),
  (0xFF01U, 0xFF60U),
  (0xFFE0U, 0xFFE6U),
  (0x16FE0U, 0x16FE4U),
  (0x17000U, 0x187F7U),
  (0x18800U, 0x18CD5U),
  (0x18D00U, 0x18D08U),
  (0x1AFF0U, 0x1AFF3U),
  (0x1AFF5U, 0x1AFFBU),
  (0x1AFFDU, 0x1AFFEU),
  (0x1B000U, 0x1B122U),
  (0x1B132U, 0x1B132U),
  (0x1B150U, 0x1B152U),
  (0x1B155U, 0x1B155U),
  (0x1B164U, 0x1B167U),
  (0x1F004U, 0x1F004U),
  (0x1F0CFU, 0x1F0CFU),
  (0x1F18EU, 0x1F18EU),
  (0x1F191U, 0x1F19AU),
  (0x1F200U, 0x1F202U),
  (0x1F210U, 0x1F23BU),
  (0x1F240U, 0x1F248U),
  (0x1F250U, 0x1F251U),
  (0x1F260U, 0x1F265U),
  (0x1F300U, 0x1F6D7U),
  (0x1F6DCU, 0x1F6ECU),
  (0x1F6F0U, 0x1F6FCU),
  (0x1F7E0U, 0x1F7EBU),
  (0x1F7F0U, 0x1F7F0U),
  (0x1F90CU, 0x1F93AU),
  (0x1F93CU, 0x1F945U),
  (0x1F947U, 0x1F9FFU),
  (0x1FA70U, 0x1FA7CU),
  (0x1FA80U, 0x1FA88U),
  (0x1FA90U, 0x1FABDU),
  (0x1FABFU, 0x1FAC5U),
  (0x1FACEU, 0x1FAD9U),
  (0x1FADDU, 0x1FAE9U),
  (0x1FAF0U, 0x1FAF8U),
  (0x20000U, 0x2FFFDU),
  (0x30000U, 0x3FFFDU),
]

///|
fn is_zero_width(codepoint : UInt) -> Bool {
  codepoint_in_ranges(codepoint, zero_width_codepoint_ranges[:])
}

///|
fn is_wide_codepoint(codepoint : UInt) -> Bool {
  codepoint_in_ranges(codepoint, wide_codepoint_ranges[:])
}

///|
fn codepoint_in_ranges(
  codepoint : UInt,
  ranges : ArrayView[(UInt, UInt)],
) -> Bool {
  for range in ranges {
    if codepoint_in_range(codepoint, range.0, range.1) {
      return true
    }
  }
  false
}

///|
fn codepoint_in_range(codepoint : UInt, start : UInt, end_ : UInt) -> Bool {
  codepoint >= start && codepoint <= end_
}

///|
fn saturated_dimension(count : CellCountInt, unit : UInt) -> UInt {
  let product = count.to_uint64() * unit.to_uint64()
  if product > 0xFFFFFFFFUL {
    0xFFFFFFFF
  } else {
    product.to_uint()
  }
}

///|
fn utf8_bytes(value : String) -> Bytes {
  let buffer = @buffer.new()
  buffer.write_string_utf8(value)
  buffer.contents()
}

///|
fn truncate_utf8(value : String, max_bytes : Int) -> String {
  let original = utf8_bytes(value)
  if original.length() <= max_bytes {
    return value
  }

  let buffer = @buffer.new(size_hint=max_bytes)
  for char in value {
    let encoded = @buffer.new()
    encoded.write_char_utf8(char)
    let bytes = encoded.contents()
    if buffer.length() + bytes.length() > max_bytes {
      break
    }
    buffer.write_bytes(bytes)
  }
  buffer.to_string()
}

///|
