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
pub fn StreamTerminal::reset(self : StreamTerminal) -> Unit {
  self.bridge().reset()
}

///|
pub fn StreamTerminal::title(self : StreamTerminal) -> String? {
  self.bridge().title()
}

///|
pub fn StreamTerminal::set_title(self : StreamTerminal, title : String) -> Unit {
  self.bridge().set_title(title)
}

///|
pub fn StreamTerminal::pwd(self : StreamTerminal) -> String? {
  self.bridge().pwd()
}

///|
pub fn StreamTerminal::set_pwd(self : StreamTerminal, pwd : String) -> Unit {
  self.bridge().set_pwd(pwd)
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
pub fn StreamTerminal::mode_get(self : StreamTerminal, mode : Mode) -> Bool {
  self.bridge().mode_get(mode)
}

///|
pub fn StreamTerminal::mode_set(
  self : StreamTerminal,
  mode : Mode,
  enabled : Bool,
) -> Unit {
  self.bridge().mode_set(mode, enabled)
}

///|
pub fn StreamTerminal::resize(
  self : StreamTerminal,
  columns : CellCountInt,
  rows : CellCountInt,
  cell_width_px : UInt,
  cell_height_px : UInt,
) -> TerminalResultCode {
  self.bridge().resize(columns, rows, cell_width_px, cell_height_px)
}

///|
pub fn StreamTerminal::scroll_viewport_top(self : StreamTerminal) -> Unit {
  self.bridge().scroll_viewport_top()
}

///|
pub fn StreamTerminal::scroll_viewport_bottom(self : StreamTerminal) -> Unit {
  self.bridge().scroll_viewport_bottom()
}

///|
pub fn StreamTerminal::scroll_viewport_delta(
  self : StreamTerminal,
  delta : Int,
) -> Unit {
  self.bridge().scroll_viewport_delta(delta)
}

///|
pub fn StreamTerminal::rows(self : StreamTerminal) -> CellCountInt {
  self.bridge().rows()
}

///|
pub fn StreamTerminal::columns(self : StreamTerminal) -> CellCountInt {
  self.bridge().columns()
}

///|
pub fn StreamTerminal::active_screen(self : StreamTerminal) -> TerminalScreen {
  self.bridge().active_screen()
}

///|
pub fn StreamTerminal::total_rows(self : StreamTerminal) -> UInt {
  self.bridge().total_rows()
}

///|
pub fn StreamTerminal::scrollback_rows(self : StreamTerminal) -> UInt {
  self.bridge().scrollback_rows()
}

///|
pub fn StreamTerminal::width_px(self : StreamTerminal) -> UInt {
  self.bridge().width_px()
}

///|
pub fn StreamTerminal::height_px(self : StreamTerminal) -> UInt {
  self.bridge().height_px()
}

///|
pub fn StreamTerminal::screen_row_snapshot(
  self : StreamTerminal,
  row : CellCountInt,
) -> PageRowState? {
  self.bridge().screen_row_snapshot(row)
}

///|
pub fn StreamTerminal::grid_ref(
  self : StreamTerminal,
  point : Point,
) -> GridRef? {
  self.bridge().grid_ref(point)
}

///|
pub fn StreamTerminal::point_from_grid_ref(
  self : StreamTerminal,
  grid_ref : GridRef,
  tag : Tag,
) -> Coordinate? {
  self.bridge().point_from_grid_ref(grid_ref, tag)
}

///|
pub fn StreamTerminal::grid_ref_row(
  self : StreamTerminal,
  grid_ref : GridRef,
) -> PageRowState? {
  self.bridge().grid_ref_row(grid_ref)
}

///|
pub fn StreamTerminal::grid_ref_cell(
  self : StreamTerminal,
  grid_ref : GridRef,
) -> PageCellState? {
  self.bridge().grid_ref_cell(grid_ref)
}

///|
pub fn StreamTerminal::grid_ref_style(
  self : StreamTerminal,
  grid_ref : GridRef,
) -> CellStyle? {
  self.bridge().grid_ref_style(grid_ref)
}

///|
pub fn StreamTerminal::grid_ref_graphemes(
  self : StreamTerminal,
  grid_ref : GridRef,
) -> Array[UInt]? {
  self.bridge().grid_ref_graphemes(grid_ref)
}

///|
pub fn StreamTerminal::grid_ref_hyperlink_uri(
  self : StreamTerminal,
  grid_ref : GridRef,
) -> String? {
  self.bridge().grid_ref_hyperlink_uri(grid_ref)
}

///|
pub fn StreamTerminal::set_write_pty(
  self : StreamTerminal,
  callback : (Bytes) -> Unit,
) -> Unit {
  self.bridge().set_write_pty(callback)
}

///|
pub fn StreamTerminal::clear_write_pty(self : StreamTerminal) -> Unit {
  self.bridge().clear_write_pty()
}

///|
pub fn StreamTerminal::set_bell(
  self : StreamTerminal,
  callback : () -> Unit,
) -> Unit {
  self.bridge().set_bell(callback)
}

///|
pub fn StreamTerminal::clear_bell(self : StreamTerminal) -> Unit {
  self.bridge().clear_bell()
}

///|
pub fn StreamTerminal::set_color_scheme(
  self : StreamTerminal,
  callback : () -> ColorScheme?,
) -> Unit {
  self.bridge().set_color_scheme(callback)
}

///|
pub fn StreamTerminal::clear_color_scheme(self : StreamTerminal) -> Unit {
  self.bridge().clear_color_scheme()
}

///|
pub fn StreamTerminal::set_device_attributes(
  self : StreamTerminal,
  callback : () -> DeviceAttributes?,
) -> Unit {
  self.bridge().set_device_attributes(callback)
}

///|
pub fn StreamTerminal::clear_device_attributes(self : StreamTerminal) -> Unit {
  self.bridge().clear_device_attributes()
}

///|
pub fn StreamTerminal::set_enquiry(
  self : StreamTerminal,
  callback : () -> Bytes,
) -> Unit {
  self.bridge().set_enquiry(callback)
}

///|
pub fn StreamTerminal::clear_enquiry(self : StreamTerminal) -> Unit {
  self.bridge().clear_enquiry()
}

///|
pub fn StreamTerminal::set_size(
  self : StreamTerminal,
  callback : () -> Size?,
) -> Unit {
  self.bridge().set_size(callback)
}

///|
pub fn StreamTerminal::clear_size(self : StreamTerminal) -> Unit {
  self.bridge().clear_size()
}

///|
pub fn StreamTerminal::set_title_changed(
  self : StreamTerminal,
  callback : () -> Unit,
) -> Unit {
  self.bridge().set_title_changed(callback)
}

///|
pub fn StreamTerminal::clear_title_changed(self : StreamTerminal) -> Unit {
  self.bridge().clear_title_changed()
}

///|
pub fn StreamTerminal::set_xtversion(
  self : StreamTerminal,
  callback : () -> String,
) -> Unit {
  self.bridge().set_xtversion(callback)
}

///|
pub fn StreamTerminal::clear_xtversion(self : StreamTerminal) -> Unit {
  self.bridge().clear_xtversion()
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
