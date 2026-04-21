///|
priv struct StreamTerminalHandler {
  bridge : StreamTerminalBridgeState
}

///|
impl StreamHandler for StreamTerminalHandler with vt(self, action) {
  ignore(self.bridge.apply(action))
}

///|
impl StreamHandler for StreamTerminalHandler with deinit(_self) {
  ()
}

///|
struct StreamTerminal {
  stream : Stream[StreamTerminalHandler]
}

///|
pub fn StreamTerminal::new(
  write_pty? : (Bytes) -> Unit = fn(_data) { () },
  bell? : () -> Unit = fn() { () },
  color_scheme? : () -> ColorScheme? = fn() { None },
  device_attributes? : () -> DeviceAttributes? = fn() { None },
  enquiry? : () -> Bytes = fn() { b"" },
  size? : () -> Size? = fn() { None },
  title_changed? : () -> Unit = fn() { () },
  xtversion? : () -> String = fn() { "" },
) -> StreamTerminal {
  let bridge = StreamTerminalBridgeState::with_effects(
    StreamTerminalBridgeEffects::new(
      write_pty~,
      bell~,
      color_scheme~,
      device_attributes~,
      enquiry~,
      size~,
      title_changed~,
      xtversion~,
    ),
  )
  { stream: Stream::new({ bridge, }) }
}

///|
pub fn StreamTerminal::deinit(self : StreamTerminal) -> Unit {
  self.stream.deinit()
}

///|
pub fn StreamTerminal::next(self : StreamTerminal, byte : Byte) -> Unit {
  self.stream.next(byte)
}

///|
pub fn StreamTerminal::next_slice(self : StreamTerminal, input : Bytes) -> Unit {
  self.stream.next_slice(input)
}

///|
pub fn StreamTerminal::title(self : StreamTerminal) -> String? {
  self.bridge().title()
}

///|
pub fn StreamTerminal::cursor_x(self : StreamTerminal) -> CellCountInt {
  self.bridge().cursor_x()
}

///|
pub fn StreamTerminal::cursor_y(self : StreamTerminal) -> CellCountInt {
  self.bridge().cursor_y()
}

///|
pub fn StreamTerminal::cursor_visual_style(
  self : StreamTerminal,
) -> CursorVisualStyle {
  self.bridge().cursor_visual_style()
}

///|
pub fn StreamTerminal::palette_dirty(self : StreamTerminal) -> Bool {
  self.bridge().palette_dirty()
}

///|
pub fn StreamTerminal::clear_palette_dirty(self : StreamTerminal) -> Unit {
  self.bridge().clear_palette_dirty()
}

///|
pub fn StreamTerminal::screen_row_snapshot(
  self : StreamTerminal,
  row : CellCountInt,
) -> PageRowState? {
  self.bridge().screen_row_snapshot(row)
}

///|
pub fn StreamTerminal::screen_cell_snapshot(
  self : StreamTerminal,
  row : CellCountInt,
  col : CellCountInt,
) -> PageCellState? {
  self.bridge().screen_cell_snapshot(row, col)
}

///|
fn StreamTerminal::bridge(self : StreamTerminal) -> StreamTerminalBridgeState {
  self.stream.handler.bridge
}
